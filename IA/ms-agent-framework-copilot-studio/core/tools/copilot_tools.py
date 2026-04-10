"""Tool layer: binds the LLM supervisor to Copilot Studio agents via Direct Line.

Key improvements
----------------
- ``ToolRuntime`` encapsulates the three module-level ContextVars behind a clean
  static API, making the implicit context explicit and easier to test/mock.
- ``bind_session`` now also propagates ``session.correlation_id`` into the
  ``core.logging_config.CORRELATION_ID`` ContextVar so every log entry emitted
  during a tool call is automatically tagged with the session correlation ID.
- ``_get_client`` reuses existing ``CopilotClient`` instances stored in the
  session, avoiding repeated TCP reconnections on subsequent calls.
- ``make_agent_tool`` is a factory that generates a typed async tool function for
  any agent key + description, enabling the dynamic multi-agent registry (item 7).
- ``_ask_agent`` records wall-clock latency per delegation in ``ToolEvent``.
"""

import logging
import time
from contextvars import ContextVar
from dataclasses import dataclass

from core.config import CopilotAgentConfig, DirectLineRuntimeConfig
from core.copilot_client import AgentResponseStatus, CopilotClient
from core.logging_config import CORRELATION_ID
from core.session_store import CopilotConversationState, OrchestratorSession, ToolEvent

logger = logging.getLogger(__name__)

# ── Module-level ContextVars (kept private; accessed through ToolRuntime) ─────

_ACTIVE_SESSION: ContextVar[OrchestratorSession | None] = ContextVar(
    "active_orchestrator_session", default=None
)
_AGENT_REGISTRY: ContextVar[dict[str, CopilotAgentConfig] | None] = ContextVar(
    "agent_registry", default=None
)
_DIRECT_LINE_RUNTIME_CONFIG: ContextVar[DirectLineRuntimeConfig | None] = ContextVar(
    "direct_line_runtime_config", default=None
)


@dataclass
class _SessionBinding:
    """Holds all ContextVar tokens produced by a single ``bind_session`` call."""

    session_token: object
    correlation_token: object


# ── ToolRuntime ───────────────────────────────────────────────────────────────

class ToolRuntime:
    """Static façade over the module-level ContextVars.

    All tool functions and helper methods access runtime state exclusively
    through this class, making callsites readable and mocking straightforward.
    """

    @staticmethod
    def configure(
        agent_registry: dict[str, CopilotAgentConfig],
        runtime_config: DirectLineRuntimeConfig,
    ) -> None:
        """Call once at startup to inject the registry and runtime config."""
        _AGENT_REGISTRY.set(agent_registry)
        _DIRECT_LINE_RUNTIME_CONFIG.set(runtime_config)

    @staticmethod
    def bind(session: OrchestratorSession) -> _SessionBinding:
        """Bind a session to the current async context and set the correlation ID."""
        return _SessionBinding(
            session_token=_ACTIVE_SESSION.set(session),
            correlation_token=CORRELATION_ID.set(session.correlation_id),
        )

    @staticmethod
    def unbind(binding: _SessionBinding) -> None:
        """Restore the ContextVars to their previous values."""
        _ACTIVE_SESSION.reset(binding.session_token)
        CORRELATION_ID.reset(binding.correlation_token)

    @staticmethod
    def get_session() -> OrchestratorSession:
        session = _ACTIVE_SESSION.get()
        if session is None:
            raise RuntimeError("No active orchestrator session bound to tool runtime.")
        return session

    @staticmethod
    def get_client(agent_key: str) -> CopilotClient:
        """Return a (possibly cached) ``CopilotClient`` for the given agent key."""
        session = ToolRuntime.get_session()
        registry = _AGENT_REGISTRY.get()
        if not registry or agent_key not in registry:
            raise RuntimeError(f"Agent '{agent_key}' is not configured.")

        runtime_config = _DIRECT_LINE_RUNTIME_CONFIG.get()
        if runtime_config is None:
            raise RuntimeError("Direct Line runtime config is not configured.")

        # Reuse existing client to preserve TCP connections across calls.
        if agent_key in session.copilot_clients:
            return session.copilot_clients[agent_key]  # type: ignore[return-value]

        conversation_state = session.copilot_conversations.setdefault(
            agent_key, CopilotConversationState()
        )
        client = CopilotClient(
            agent_config=registry[agent_key],
            conversation_state=conversation_state,
            runtime_config=runtime_config,
        )
        session.copilot_clients[agent_key] = client
        return client


# ── Public API preserved for backward compat ──────────────────────────────────

def configure_tool_runtime(
    agent_registry: dict[str, CopilotAgentConfig],
    direct_line_runtime_config: DirectLineRuntimeConfig,
) -> None:
    ToolRuntime.configure(agent_registry, direct_line_runtime_config)


def bind_session(session: OrchestratorSession) -> _SessionBinding:
    return ToolRuntime.bind(session)


def unbind_session(binding: _SessionBinding) -> None:
    ToolRuntime.unbind(binding)


# ── Internal helpers ──────────────────────────────────────────────────────────

def _store_last_response(agent_key: str, text: str) -> None:
    session = _ACTIVE_SESSION.get()
    if session is not None:
        session.last_agent_responses[agent_key] = text


def _record_tool_event(
    agent_key: str, status: str, question: str, response_text: str = "", latency_ms: float = 0.0
) -> None:
    session = _ACTIVE_SESSION.get()
    if session is None:
        return
    preview = response_text.strip().replace("\n", " ")
    if len(preview) > 140:
        preview = preview[:137] + "..."
    session.tool_events.append(
        ToolEvent(
            agent_key=agent_key,
            status=status,
            question=question,
            response_preview=preview,
            latency_ms=latency_ms,
        )
    )


async def _ask_agent(agent_key: str, question: str) -> str:
    """Delegate ``question`` to the specified Copilot Studio agent and return text."""
    _record_tool_event(agent_key, "started", question)
    start = time.monotonic()

    try:
        logger.info("Delegating request to %s.", agent_key)
        client = ToolRuntime.get_client(agent_key)

        success = await client.send_message(question)
        if not success:
            latency_ms = (time.monotonic() - start) * 1000
            response_text = (
                f"[Operational Failure] Could not send message to agent {agent_key}."
            )
            _store_last_response(agent_key, response_text)
            _record_tool_event(agent_key, "failed", question, response_text, latency_ms)
            return response_text

        result = await client.get_response()
        latency_ms = (time.monotonic() - start) * 1000

        _store_last_response(agent_key, result.text)
        final_status = (
            "completed" if result.status == AgentResponseStatus.OK else result.status.value
        )
        _record_tool_event(agent_key, final_status, question, result.text, latency_ms)

        logger.info(
            "Agent %s responded in %.0f ms (status=%s).",
            agent_key,
            latency_ms,
            final_status,
            extra={"latency_ms": latency_ms, "agent_key": agent_key},
        )
        return result.text

    except Exception as exc:
        latency_ms = (time.monotonic() - start) * 1000
        logger.exception("%s tool failed.", agent_key)
        response_text = f"{agent_key} tool failed: {exc}"
        _store_last_response(agent_key, response_text)
        _record_tool_event(agent_key, "failed", question, response_text, latency_ms)
        return response_text


# ── Dynamic tool factory (item 7) ─────────────────────────────────────────────

def make_agent_tool(agent_key: str, description: str):
    """Return an async tool function for ``agent_key`` with ``description`` as docstring.

    The agent framework reads ``__doc__`` to present the tool to the LLM, so
    ``description`` must be a clear, concise instruction about when to call this tool.

    Example::

        tool = make_agent_tool("AGENT_JURIDICO", "Use for legal and compliance requests.")
        agent = client.as_agent(..., tools=[tool])
    """

    async def _tool(question: str) -> str:
        return await _ask_agent(agent_key, question)

    # Give the function a meaningful name for traceability in logs and the LLM prompt.
    short = agent_key.replace("AGENT_", "").lower()
    _tool.__name__ = f"ask_{short}_agent"
    _tool.__doc__ = description
    return _tool



