"""Session storage abstractions and data models for the orchestrator.

Design notes:
- ``AbstractSessionStore`` is a structural Protocol so any class implementing
  ``get / save / delete`` satisfies it without explicit inheritance.
  Swap to Redis, Azure Table Storage, etc. by providing a new implementation.
- ``OrchestratorSession.correlation_id`` is generated once per session and
  propagated into every structured log entry via ``core.logging_config.CORRELATION_ID``.
- ``OrchestratorSession.copilot_clients`` caches live ``CopilotClient`` instances
  (typed as ``dict`` to avoid a circular import with ``core.copilot_client``).
"""

import uuid
from dataclasses import dataclass, field
from typing import Protocol, runtime_checkable

from agent_framework import AgentSession


@dataclass
class CopilotConversationState:
    """Direct Line conversation state persisted across tool invocations."""

    conversation_id: str | None = None
    watermark: str | None = None
    last_raw_activities: list[dict] = field(default_factory=list)


@dataclass
class ToolEvent:
    """Single agent delegation event recorded in the session timeline."""

    agent_key: str
    status: str          # "started" | "completed" | "timeout" | "failed"
    question: str
    response_preview: str = ""
    latency_ms: float = 0.0


@dataclass
class OrchestratorSession:
    """Full state for one orchestrator session (one user conversation)."""

    session_id: str
    agent_session: AgentSession
    correlation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    # Direct Line conversation states, keyed by agent key (e.g. "AGENT_RH")
    copilot_conversations: dict[str, CopilotConversationState] = field(default_factory=dict)
    # Cached CopilotClient instances — dict[str, CopilotClient] (Any to avoid circular import)
    copilot_clients: dict = field(default_factory=dict)
    last_agent_responses: dict[str, str] = field(default_factory=dict)
    tool_events: list[ToolEvent] = field(default_factory=list)


@runtime_checkable
class AbstractSessionStore(Protocol):
    """Structural protocol for session store implementations.

    Any object implementing ``get``, ``save``, and ``delete`` satisfies this
    contract — no explicit inheritance required.  This allows swapping the
    default ``InMemorySessionStore`` for Redis, Azure Table Storage, or any
    other backend without touching the router or tool layer.
    """

    def get(self, session_id: str) -> OrchestratorSession | None: ...
    def save(self, session: OrchestratorSession) -> None: ...
    def delete(self, session_id: str) -> None: ...


class InMemorySessionStore:
    """Default session store backed by an in-process dict.

    ⚠️  All state is lost when the process restarts.
    Implement ``AbstractSessionStore`` with a durable backend for production.
    """

    def __init__(self) -> None:
        self._sessions: dict[str, OrchestratorSession] = {}

    def get(self, session_id: str) -> OrchestratorSession | None:
        return self._sessions.get(session_id)

    def save(self, session: OrchestratorSession) -> None:
        self._sessions[session.session_id] = session

    def delete(self, session_id: str) -> None:
        self._sessions.pop(session_id, None)
