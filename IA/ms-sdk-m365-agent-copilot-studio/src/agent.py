import json
import os
import sys
import traceback

from dotenv import load_dotenv
from microsoft_agents.hosting.core import (
    AgentApplication,
    TurnState,
    TurnContext,
    MemoryStorage,
)
from microsoft_agents.activity import (
    load_configuration_from_env,
    ActivityTypes,
    SensitivityUsageInfo,
)
from microsoft_agents.hosting.aiohttp import CloudAdapter
from microsoft_agents.authentication.msal import MsalConnectionManager
from openai import AsyncAzureOpenAI

from config import Config
from sdk_workarounds import apply_sdk_workarounds
from core.config import build_agent_registry, build_direct_line_runtime_config
from core.copilot_client import CopilotClient
from core.session_store import CopilotConversationState

load_dotenv()
apply_sdk_workarounds()

# ── Configuration ─────────────────────────────────────────────────────────────

config = Config(os.environ)
agents_sdk_config = load_configuration_from_env(os.environ)

client = AsyncAzureOpenAI(
    api_version=config.azure_openai_api_version,
    api_key=config.azure_openai_api_key,
    azure_endpoint=config.azure_openai_endpoint,
    azure_deployment=config.azure_openai_deployment_name,
)


def load_prompt_config(prompt_name: str):
    prompt_dir = os.path.join(os.path.dirname(__file__), "prompts", prompt_name)
    with open(os.path.join(prompt_dir, "skprompt.txt"), "r", encoding="utf-8") as f:
        system_prompt = f.read().strip()
    with open(os.path.join(prompt_dir, "config.json"), "r", encoding="utf-8") as f:
        config_data = json.load(f)
    return system_prompt, config_data.get("completion", {})


prompt_text, prompt_params = load_prompt_config("chat")

# ── Agent registry & Direct Line runtime ──────────────────────────────────────

agent_registry = build_agent_registry()
direct_line_runtime_config = build_direct_line_runtime_config()

# OpenAI function definitions built once from the registry at startup.
# Adding a new Copilot Studio agent only requires env-var changes — no code change.
_openai_tools: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": f"ask_{key.replace('AGENT_', '').lower()}_agent",
            "description": cfg.tool_description,
            "parameters": {
                "type": "object",
                "properties": {
                    "question": {
                        "type": "string",
                        "description": "The question to forward to the specialist agent.",
                    }
                },
                "required": ["question"],
            },
        },
    }
    for key, cfg in agent_registry.items()
]

# Reverse map: tool function name → registry key  (e.g. "ask_rh_agent" → "AGENT_RH")
_tool_name_to_key: dict[str, str] = {
    f"ask_{key.replace('AGENT_', '').lower()}_agent": key
    for key in agent_registry
}

# Module-level CopilotClient cache keyed by "{teams_conv_id}:{agent_key}".
# Clients are reused across turns to preserve TCP connections and Direct Line
# conversation IDs. The associated CopilotConversationState (which holds the
# Direct Line conversation_id and watermark) is stored in ConversationState by
# the Teams SDK and passed by reference, so mutations inside CopilotClient are
# automatically reflected in persisted state.
_copilot_clients: dict[str, CopilotClient] = {}


def _get_copilot_client(
    teams_conv_id: str,
    agent_key: str,
    conv_state: CopilotConversationState,
) -> CopilotClient:
    cache_key = f"{teams_conv_id}:{agent_key}"
    if cache_key not in _copilot_clients:
        _copilot_clients[cache_key] = CopilotClient(
            agent_config=agent_registry[agent_key],
            conversation_state=conv_state,
            runtime_config=direct_line_runtime_config,
        )
    return _copilot_clients[cache_key]


async def _call_agent(
    agent_key: str,
    question: str,
    teams_conv_id: str,
    copilot_states: dict,
    streaming_response=None,
) -> str:
    """Send a question to a Copilot Studio agent and return its text response."""
    if agent_key not in copilot_states:
        copilot_states[agent_key] = CopilotConversationState()

    agent_name = agent_registry[agent_key].name
    if streaming_response is not None:
        streaming_response.queue_informative_update(f"Consultando {agent_name}...")

    conv_state = copilot_states[agent_key]
    copilot_client = _get_copilot_client(teams_conv_id, agent_key, conv_state)

    success = await copilot_client.send_message(question)
    if not success:
        return f"[Erro] Não foi possível enviar a mensagem para o agente {agent_key}."

    result = await copilot_client.get_response()
    return result.text


async def _run_supervisor(
    messages: list[dict],
    teams_conv_id: str,
    copilot_states: dict,
    streaming_response=None,
) -> str:
    """Tool-calling loop: supervisor delegates to Copilot Studio agents until done.

    Calls Azure OpenAI with the registered tools. When the model issues tool_calls,
    each call is dispatched to the corresponding CopilotClient (Direct Line polling).
    The loop continues until the model returns a final text response.
    """
    while True:
        completion = await client.chat.completions.create(
            messages=messages,
            model=config.azure_openai_deployment_name,
            tools=_openai_tools,
            tool_choice="auto",
            **prompt_params,
        )
        choice = completion.choices[0]

        if choice.finish_reason == "tool_calls":
            # Append the assistant turn with its tool_calls before adding results
            messages.append(choice.message.model_dump(exclude_none=True))

            for tool_call in choice.message.tool_calls:
                tool_name = tool_call.function.name
                agent_key = _tool_name_to_key.get(tool_name)

                if agent_key is None:
                    tool_result = f"[Erro] Tool desconhecida: {tool_name}"
                else:
                    args = json.loads(tool_call.function.arguments)
                    question = args.get("question", "")
                    print(
                        f"[tool] {tool_name} → {agent_key}: {question[:80]!r}",
                        flush=True,
                    )
                    tool_result = await _call_agent(
                        agent_key, question, teams_conv_id, copilot_states,
                        streaming_response=streaming_response,
                    )
                    print(
                        f"[tool] {agent_key} responded ({len(tool_result)} chars)",
                        flush=True,
                    )

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": tool_result,
                })
        else:
            return choice.message.content or ""


# ── Teams SDK setup ───────────────────────────────────────────────────────────

storage = MemoryStorage()
connection_manager = MsalConnectionManager(**agents_sdk_config)
adapter = CloudAdapter(connection_manager=connection_manager)

agent_app = AgentApplication[TurnState](
    storage=storage,
    adapter=adapter,
    **agents_sdk_config,
)


@agent_app.conversation_update("membersAdded")
async def on_members_added(context: TurnContext, _state: TurnState):
    await context.send_activity("Olá! Sou o assistente corporativo da TRC. Como posso ajudar você hoje?")


@agent_app.activity(ActivityTypes.message)
async def on_message(context: TurnContext, state: TurnState):
    response = context.streaming_response

    # Load conversation history and Direct Line states from persistent storage.
    # copilot_states is a dict[str, CopilotConversationState] keyed by agent key.
    # MemoryStorage preserves Python object references, so mutations inside
    # CopilotClient (conversation_id, watermark) are reflected here automatically.
    history: list = state.conversation.get_value("history", list) or []
    copilot_states: dict = state.conversation.get_value("copilot_states", dict) or {}

    user_text = context.activity.text or ""
    teams_conv_id = context.activity.conversation.id

    history.append({"role": "user", "content": user_text})
    if len(history) > config.max_history_turns:
        history = history[-config.max_history_turns:]

    print(
        "[turn] start",
        json.dumps({
            "history_turns": len(history),
            "registered_agents": list(agent_registry.keys()),
            "teams_conv_id": teams_conv_id,
        }),
        flush=True,
    )

    response.set_feedback_loop(config.ai_feedback_loop_enabled)
    if config.ai_feedback_loop_enabled:
        response.set_feedback_loop_type("default")
    response.set_generated_by_ai_label(config.ai_generated_label_enabled)
    response.set_sensitivity_label(
        SensitivityUsageInfo(
            type=config.sensitivity_type,
            schema_type=config.sensitivity_schema_type,
            name=config.sensitivity_name,
        )
    )
    response.queue_informative_update("Pensando...")

    messages = [{"role": "system", "content": prompt_text}, *history]

    final_text = ""
    try:
        final_text = await _run_supervisor(
            messages, teams_conv_id, copilot_states, streaming_response=response
        )
        response.queue_text_chunk(final_text)
    finally:
        await response.end_stream()
        print(f"[turn] end_stream completed ({len(final_text)} chars)", flush=True)

    if final_text:
        history.append({"role": "assistant", "content": final_text})
    state.conversation.set_value("history", history)
    state.conversation.set_value("copilot_states", copilot_states)


@agent_app.error
async def on_error(context: TurnContext, error: Exception):
    print(f"\n [on_turn_error] unhandled error: {error}", file=sys.stderr)
    traceback.print_exc()
    await context.send_activity("The agent encountered an error or bug.")
