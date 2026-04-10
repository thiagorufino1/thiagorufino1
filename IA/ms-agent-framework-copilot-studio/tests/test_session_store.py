"""Tests for core/session_store.py — Protocol compliance and store operations."""

import pytest

from core.session_store import (
    AbstractSessionStore,
    CopilotConversationState,
    InMemorySessionStore,
    OrchestratorSession,
    ToolEvent,
)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_session(session_id: str = "test-session") -> OrchestratorSession:
    """Create a minimal OrchestratorSession without a real AgentSession."""
    from unittest.mock import MagicMock
    return OrchestratorSession(
        session_id=session_id,
        agent_session=MagicMock(),
    )


# ── Protocol compliance ───────────────────────────────────────────────────────

class TestAbstractSessionStoreProtocol:
    def test_in_memory_satisfies_protocol(self):
        store = InMemorySessionStore()
        assert isinstance(store, AbstractSessionStore)

    def test_custom_implementation_satisfies_protocol(self):
        class MyStore:
            def get(self, session_id: str) -> OrchestratorSession | None:
                return None
            def save(self, session: OrchestratorSession) -> None:
                pass
            def delete(self, session_id: str) -> None:
                pass

        assert isinstance(MyStore(), AbstractSessionStore)

    def test_incomplete_implementation_fails_protocol(self):
        class BadStore:
            def get(self, session_id: str):
                return None
            # missing save and delete

        assert not isinstance(BadStore(), AbstractSessionStore)


# ── InMemorySessionStore ──────────────────────────────────────────────────────

class TestInMemorySessionStore:
    def test_get_missing_returns_none(self):
        store = InMemorySessionStore()
        assert store.get("nonexistent") is None

    def test_save_and_retrieve(self):
        store = InMemorySessionStore()
        session = _make_session("s1")
        store.save(session)
        retrieved = store.get("s1")
        assert retrieved is session

    def test_overwrite_existing(self):
        store = InMemorySessionStore()
        s1 = _make_session("s1")
        store.save(s1)
        s2 = _make_session("s1")
        store.save(s2)
        assert store.get("s1") is s2

    def test_delete_removes_session(self):
        store = InMemorySessionStore()
        store.save(_make_session("s1"))
        store.delete("s1")
        assert store.get("s1") is None

    def test_delete_nonexistent_does_not_raise(self):
        store = InMemorySessionStore()
        store.delete("ghost")  # Should not raise

    def test_sessions_are_isolated(self):
        store = InMemorySessionStore()
        store.save(_make_session("a"))
        store.save(_make_session("b"))
        store.delete("a")
        assert store.get("a") is None
        assert store.get("b") is not None


# ── OrchestratorSession defaults ─────────────────────────────────────────────

class TestOrchestratorSession:
    def test_correlation_id_auto_generated(self):
        s1 = _make_session("s1")
        s2 = _make_session("s2")
        assert s1.correlation_id != s2.correlation_id
        assert len(s1.correlation_id) == 36  # UUID4 format

    def test_default_fields_are_empty(self):
        s = _make_session()
        assert s.copilot_conversations == {}
        assert s.copilot_clients == {}
        assert s.last_agent_responses == {}
        assert s.tool_events == []

    def test_tool_event_latency_ms(self):
        event = ToolEvent(
            agent_key="AGENT_RH", status="completed", question="q", latency_ms=123.4
        )
        assert event.latency_ms == 123.4

    def test_copilot_conversation_state_defaults(self):
        state = CopilotConversationState()
        assert state.conversation_id is None
        assert state.watermark is None
        assert state.last_raw_activities == []
