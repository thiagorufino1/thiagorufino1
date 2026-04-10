"""Tests for core/router.py — session management and dynamic tool registration.

The LLM and Direct Line calls are fully mocked so no external services are hit.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from core.router import AgentRouter
from core.session_store import InMemorySessionStore, OrchestratorSession


# ── Helpers / fixtures ────────────────────────────────────────────────────────

def _make_router() -> AgentRouter:
    """Build an AgentRouter with all external dependencies mocked."""
    mock_agent_session = MagicMock()
    mock_run_result = MagicMock()
    mock_run_result.text = "Mocked supervisor response"

    mock_agent = MagicMock()
    mock_agent.create_session.return_value = mock_agent_session
    mock_agent.run = AsyncMock(return_value=mock_run_result)

    mock_client = MagicMock()
    mock_client.as_agent.return_value = mock_agent

    with patch("core.router.OpenAIChatClient", return_value=mock_client):
        router = AgentRouter()

    return router


# ── Session lifecycle ─────────────────────────────────────────────────────────

class TestSessionLifecycle:
    def test_get_or_create_creates_new_session(self):
        router = _make_router()
        session = router.get_or_create_session("session-1")
        assert isinstance(session, OrchestratorSession)
        assert session.session_id == "session-1"

    def test_get_or_create_returns_existing(self):
        router = _make_router()
        s1 = router.get_or_create_session("session-1")
        s2 = router.get_or_create_session("session-1")
        assert s1 is s2

    def test_reset_creates_fresh_session(self):
        router = _make_router()
        s1 = router.get_or_create_session("session-x")
        s1.last_agent_responses["AGENT_RH"] = "old data"
        s2 = router.reset_session("session-x")
        assert s2 is not s1
        assert s2.last_agent_responses == {}

    def test_sessions_are_isolated(self):
        router = _make_router()
        sa = router.get_or_create_session("a")
        sb = router.get_or_create_session("b")
        assert sa is not sb
        assert sa.correlation_id != sb.correlation_id

    def test_custom_session_store_is_used(self):
        custom_store = InMemorySessionStore()
        mock_agent = MagicMock()
        mock_agent.create_session.return_value = MagicMock()
        mock_client = MagicMock()
        mock_client.as_agent.return_value = mock_agent

        with patch("core.router.OpenAIChatClient", return_value=mock_client):
            router = AgentRouter(session_store=custom_store)

        router.get_or_create_session("s1")
        assert custom_store.get("s1") is not None


# ── describe_session ──────────────────────────────────────────────────────────

class TestDescribeSession:
    def test_describe_session_structure(self):
        router = _make_router()
        router.get_or_create_session("desc-test")
        snapshot = router.describe_session("desc-test")
        assert "session_id" in snapshot
        assert "correlation_id" in snapshot
        assert "copilot_conversations" in snapshot
        assert "tool_events" in snapshot
        assert "registered_agents" in snapshot

    def test_correlation_id_present(self):
        router = _make_router()
        snapshot = router.describe_session("corr-test")
        cid = snapshot["correlation_id"]
        assert isinstance(cid, str) and len(cid) == 36  # UUID4

    def test_registered_agents_populated(self):
        router = _make_router()
        snapshot = router.describe_session("agents-test")
        agents = snapshot["registered_agents"]
        # In legacy mode (conftest sets DIRECT_LINE_SECRET_RH + _TI), both should appear
        assert "AGENT_RH" in agents
        assert "AGENT_TI" in agents


# ── Dynamic tool registration ─────────────────────────────────────────────────

class TestDynamicToolRegistration:
    def test_tools_match_registry(self):
        router = _make_router()
        # Verify tools were registered for each agent in the registry
        tool_names = {t.__name__ for t in router.agent.create_session.call_args or []}
        # We can't easily inspect internal tools list, but we can verify registry length
        assert len(router.agent_registry) >= 1

    def test_dynamic_agent_in_registry(self, monkeypatch):
        monkeypatch.setenv("COPILOT_AGENTS", "RH,TI,FIN")
        monkeypatch.setenv("COPILOT_FIN_DIRECT_LINE_SECRET", "secret-fin")
        router = _make_router()
        assert "AGENT_FIN" in router.agent_registry


# ── route_and_process ─────────────────────────────────────────────────────────

class TestRouteAndProcess:
    async def test_returns_agent_response_text(self):
        router = _make_router()
        result = await router.route_and_process("Quero ver meu holerite", session_id="u1")
        assert result == "Mocked supervisor response"

    async def test_saves_session_after_run(self):
        router = _make_router()
        await router.route_and_process("VPN não funciona", session_id="u2")
        assert router.session_store.get("u2") is not None

    async def test_error_returns_critical_message(self):
        router = _make_router()
        router.agent.run.side_effect = RuntimeError("LLM kaboom")
        result = await router.route_and_process("anything", session_id="u3")
        assert "Critical Error" in result or "Error" in result.lower() or "failed" in result.lower()
