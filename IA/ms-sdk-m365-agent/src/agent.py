import os
import sys
import json
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

load_dotenv()
apply_sdk_workarounds()

# Load configuration
config = Config(os.environ)
agents_sdk_config = load_configuration_from_env(os.environ)

client = AsyncAzureOpenAI(
    api_version=config.azure_openai_api_version,
    api_key=config.azure_openai_api_key,
    azure_endpoint=config.azure_openai_endpoint,
    azure_deployment=config.azure_openai_deployment_name,
)

def load_prompt_config(prompt_name: str):
    # Get the absolute path to the prompt directory
    prompt_dir = os.path.join(os.path.dirname(__file__), "prompts", prompt_name)
    
    # Load system prompt template
    with open(os.path.join(prompt_dir, "skprompt.txt"), "r", encoding="utf-8") as f:
        system_prompt = f.read().strip()
    
    # Load completion configuration
    with open(os.path.join(prompt_dir, "config.json"), "r", encoding="utf-8") as f:
        config_data = json.load(f)
        
    return system_prompt, config_data.get("completion", {})

# Load initial prompt configuration
prompt_text, prompt_params = load_prompt_config("chat")

# Define storage and application
storage = MemoryStorage()
connection_manager = MsalConnectionManager(**agents_sdk_config)
adapter = CloudAdapter(connection_manager=connection_manager)

agent_app = AgentApplication[TurnState](
    storage=storage, 
    adapter=adapter, 
    **agents_sdk_config
)

@agent_app.conversation_update("membersAdded")
async def on_members_added(context: TurnContext, _state: TurnState):
    await context.send_activity("Hi there! I'm an agent to chat with you.")

# Listen for ANY message to be received. MUST BE AFTER ANY OTHER MESSAGE HANDLERS
@agent_app.activity(ActivityTypes.message)
async def on_message(context: TurnContext, state: TurnState):
    response = context.streaming_response
    chunk_count = 0

    # Load conversation history from state
    history: list = state.conversation.get_value("history", list) or []

    user_text = context.activity.text or ""
    history.append({"role": "user", "content": user_text})

    # Trim to keep only the last MAX_HISTORY_TURNS messages
    if len(history) > config.max_history_turns:
        history = history[-config.max_history_turns:]

    print(
        "[stream] start",
        json.dumps(
            {
                "feedback_loop": config.ai_feedback_loop_enabled,
                "generated_by_ai_label": config.ai_generated_label_enabled,
                "sensitivity_name": config.sensitivity_name,
                "history_turns": len(history),
                "channel_id": getattr(context.activity, "channel_id", None),
                "conversation_id": getattr(context.activity.conversation, "id", None),
            }
        ),
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
    response.queue_informative_update("Generating response...")
    print('[stream] queued informative update: "Generating response..."', flush=True)

    assistant_message = ""
    try:
        result = await client.chat.completions.create(
            messages=[{"role": "system", "content": prompt_text}, *history],
            model=config.azure_openai_deployment_name,
            stream=True,
            **prompt_params
        )

        async for chunk in result:
            if not chunk.choices:
                continue

            content = chunk.choices[0].delta.content
            if content:
                chunk_count += 1
                assistant_message += content
                response.queue_text_chunk(content)
                print(
                    f"[stream] queued chunk #{chunk_count} ({len(content)} chars)",
                    flush=True,
                )
    finally:
        print(
            "[stream] ending",
            json.dumps(
                {
                    "chunk_count": chunk_count,
                    "message_length": len(response.get_message() or ""),
                }
            ),
            flush=True,
        )
        await response.end_stream()
        print("[stream] end_stream completed", flush=True)

    # Save assistant response to history and persist
    if assistant_message:
        history.append({"role": "assistant", "content": assistant_message})
    state.conversation.set_value("history", history)

@agent_app.error
async def on_error(context: TurnContext, error: Exception):
    # This check writes out errors to console log .vs. app insights.
    # NOTE: In production environment, you should consider logging this to Azure
    #       application insights.
    print(f"\n [on_turn_error] unhandled error: {error}", file=sys.stderr)
    traceback.print_exc()

    # Send a message to the user
    await context.send_activity("The agent encountered an error or bug.")
