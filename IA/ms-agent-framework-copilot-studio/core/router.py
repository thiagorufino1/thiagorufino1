"""Supervisor agent router — orchestrates calls to Copilot Studio sub-agents.

Changes from the previous version
-----------------------------------
- ``session_store`` is now typed as ``AbstractSessionStore`` (Protocol), so any
  compliant implementation (Redis, Azure Table Storage, etc.) can be injected
  without touching this file.
- Agent tools are generated dynamically via ``make_agent_tool``, reading the
  ``tool_description`` field from each ``CopilotAgentConfig``.  Adding a new
  agent only requires updating environment variables — no code change needed.
- ``route_and_process`` uses ``bind_session`` / ``unbind_session`` which now
  additionally propagate the session's ``correlation_id`` to logging.
- ``describe_session`` exposes ``latency_ms`` in the tool events snapshot.
"""

import logging
import os

from agent_framework.openai import OpenAIChatClient

from core.config import build_agent_registry, build_direct_line_runtime_config
from core.session_store import AbstractSessionStore, InMemorySessionStore, OrchestratorSession
from core.tools.copilot_tools import (
    bind_session,
    configure_tool_runtime,
    make_agent_tool,
    unbind_session,
)

logger = logging.getLogger(__name__)

SUPERVISOR_INSTRUCTIONS = (
    "You are an internal support supervisor running as a continuous chat. "
    "Your job is to decide when to call the HR agent, when to call the IT agent, "
    "and when to call both in sequence. "
    "Always prioritise the specialist agent's response. "
    "When a tool returns a useful answer, preserve the main content and avoid "
    "rewriting, summarising, or replacing it with your own knowledge. "
    "You may briefly introduce or connect responses. "
    "Only supplement with your own knowledge when a tool fails, returns empty "
    "content, or clearly insufficient information. "
    "If the answer is already clear from session context, maintain continuity "
    "without asking the user to repeat the question."
)


class AgentRouter:
    """Supervisor that routes user requests to specialised Copilot Studio agents.

    Args:
        session_store: Any object satisfying ``AbstractSessionStore``.
                       Defaults to ``InMemorySessionStore``.
    """

    def __init__(self, session_store: AbstractSessionStore | None = None) -> None:
        self.azure_endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
        self.api_key = os.environ.get("AZURE_OPENAI_API_KEY")
        self.deployment_name = os.environ.get("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4o")

        self.agent_registry = build_agent_registry()
        self.direct_line_runtime_config = build_direct_line_runtime_config()
        self.session_store: AbstractSessionStore = session_store or InMemorySessionStore()

        configure_tool_runtime(self.agent_registry, self.direct_line_runtime_config)

        # Build tool list dynamically from the registry — no hardcoded agent names.
        tools = [
            make_agent_tool(cfg.key, cfg.tool_description)
            for cfg in self.agent_registry.values()
        ]

        self.client = OpenAIChatClient(
            azure_endpoint=self.azure_endpoint,
            api_key=self.api_key,
            model=self.deployment_name,
        )
        self.agent = self.client.as_agent(
            name="Copilot Studio Supervisor",
            instructions=SUPERVISOR_INSTRUCTIONS,
            tools=tools,
        )
        logger.info(
            "AgentRouter initialised with %d agent(s): %s",
            len(self.agent_registry),
            list(self.agent_registry.keys()),
        )

    # ── Session management ────────────────────────────────────────────────────

    def get_or_create_session(self, session_id: str) -> OrchestratorSession:
        existing = self.session_store.get(session_id)
        if existing is not None:
            return existing
        session = OrchestratorSession(
            session_id=session_id,
            agent_session=self.agent.create_session(session_id=session_id),
        )
        self.session_store.save(session)
        return session

    def reset_session(self, session_id: str) -> OrchestratorSession:
        self.session_store.delete(session_id)
        return self.get_or_create_session(session_id)

    # ── Introspection ─────────────────────────────────────────────────────────

    def describe_session(self, session_id: str) -> dict[str, object]:
        session = self.get_or_create_session(session_id)
        return {
            "session_id": session.session_id,
            "correlation_id": session.correlation_id,
            "copilot_conversations": {
                agent_key: {
                    "conversation_id": state.conversation_id,
                    "watermark": state.watermark,
                    "last_raw_activities": state.last_raw_activities,
                }
                for agent_key, state in session.copilot_conversations.items()
            },
            "last_agent_responses": session.last_agent_responses,
            "tool_events": [
                {
                    "agent_key": event.agent_key,
                    "status": event.status,
                    "question": event.question,
                    "response_preview": event.response_preview,
                    "latency_ms": round(event.latency_ms, 1),
                }
                for event in session.tool_events
            ],
            "registered_agents": {
                agent_key: {
                    "name": config.name,
                    "department": config.department,
                    "environment": config.environment,
                }
                for agent_key, config in self.agent_registry.items()
            },
        }

    # ── Main dispatch ─────────────────────────────────────────────────────────

    async def route_and_process(
        self, user_question: str, session_id: str = "local-console"
    ) -> str:
        session = self.get_or_create_session(session_id)
        binding = bind_session(session)
        try:
            response = await self.agent.run(user_question, session=session.agent_session)
            self.session_store.save(session)
            return response.text
        except Exception as exc:
            logger.exception("Agent Framework orchestration failed.")
            return f"[Critical Error] Orchestration failed: {exc}"
        finally:
            unbind_session(binding)
