"""Tests for core/copilot_client.py — HTTP behaviour mocked via respx."""

import httpx
import pytest
import respx

from core.config import CopilotAgentConfig, DirectLineRuntimeConfig
from core.copilot_client import AgentResponseStatus, AgentResult, CopilotClient
from core.session_store import CopilotConversationState

BASE = "https://directline.botframework.com/v3/directline"


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture()
def agent_config() -> CopilotAgentConfig:
    return CopilotAgentConfig(
        key="AGENT_RH",
        name="Copilot RH",
        department="RH",
        environment="test-env",
        direct_line_secret="test-secret",
        tool_description="HR agent",
    )


@pytest.fixture()
def runtime_config() -> DirectLineRuntimeConfig:
    return DirectLineRuntimeConfig(
        timeout_sec=5,
        poll_interval_sec=0.05,  # fast polling for tests
        debug_mode=False,
        structured_logging=False,
    )


@pytest.fixture()
def conversation_state() -> CopilotConversationState:
    return CopilotConversationState()


@pytest.fixture()
def shared_http() -> httpx.AsyncClient:
    return httpx.AsyncClient()


@pytest.fixture()
def client(agent_config, conversation_state, runtime_config, shared_http) -> CopilotClient:
    return CopilotClient(
        agent_config=agent_config,
        conversation_state=conversation_state,
        runtime_config=runtime_config,
        http_client=shared_http,
    )


# ── start_conversation ────────────────────────────────────────────────────────

@respx.mock
async def test_start_conversation_sets_id(client, conversation_state):
    respx.post(f"{BASE}/conversations").mock(
        return_value=httpx.Response(200, json={"conversationId": "conv-123"})
    )
    await client.start_conversation()
    assert conversation_state.conversation_id == "conv-123"


@respx.mock
async def test_start_conversation_retries_on_503(client, conversation_state):
    route = respx.post(f"{BASE}/conversations")
    route.side_effect = [
        httpx.Response(503, text="unavailable"),
        httpx.Response(200, json={"conversationId": "conv-retry"}),
    ]
    await client.start_conversation()
    assert conversation_state.conversation_id == "conv-retry"
    assert route.call_count == 2


# ── send_message ──────────────────────────────────────────────────────────────

@respx.mock
async def test_send_message_returns_true_on_202(client, conversation_state):
    conversation_state.conversation_id = "conv-abc"
    respx.post(f"{BASE}/conversations/conv-abc/activities").mock(
        return_value=httpx.Response(202)
    )
    result = await client.send_message("Hello")
    assert result is True


@respx.mock
async def test_send_message_starts_conversation_if_missing(client, conversation_state):
    respx.post(f"{BASE}/conversations").mock(
        return_value=httpx.Response(200, json={"conversationId": "auto-conv"})
    )
    respx.post(f"{BASE}/conversations/auto-conv/activities").mock(
        return_value=httpx.Response(201)
    )
    result = await client.send_message("Hey")
    assert result is True
    assert conversation_state.conversation_id == "auto-conv"


@respx.mock
async def test_send_message_returns_false_on_400(client, conversation_state):
    conversation_state.conversation_id = "conv-bad"
    respx.post(f"{BASE}/conversations/conv-bad/activities").mock(
        return_value=httpx.Response(400, text="bad request")
    )
    # 400 is not retryable → falls back to returning False after exhausting attempts
    result = await client.send_message("Bad msg")
    assert result is False


# ── get_response ──────────────────────────────────────────────────────────────

def _activities_payload(text: str, watermark: str = "1") -> dict:
    return {
        "watermark": watermark,
        "activities": [
            {"type": "message", "from": {"id": "bot"}, "text": text}
        ],
    }


@respx.mock
async def test_get_response_returns_ok_with_text(client, conversation_state):
    conversation_state.conversation_id = "conv-xyz"
    respx.get(url__startswith=f"{BASE}/conversations/conv-xyz/activities").mock(
        return_value=httpx.Response(200, json=_activities_payload("Hello from bot"))
    )
    result = await client.get_response()
    assert result.status == AgentResponseStatus.OK
    assert result.text == "Hello from bot"


@respx.mock
async def test_get_response_skips_own_messages(client, conversation_state):
    conversation_state.conversation_id = "conv-own"
    payload = {
        "watermark": "1",
        "activities": [
            {"type": "message", "from": {"id": "serverless_orchestrator"}, "text": "echo"},
            {"type": "message", "from": {"id": "bot"}, "text": "Bot reply"},
        ],
    }
    respx.get(url__startswith=f"{BASE}/conversations/conv-own/activities").mock(
        return_value=httpx.Response(200, json=payload)
    )
    result = await client.get_response()
    assert result.text == "Bot reply"


@respx.mock
async def test_get_response_timeout(client, conversation_state):
    """When no bot messages arrive before timeout, returns TIMEOUT status."""
    conversation_state.conversation_id = "conv-slow"
    respx.get(url__startswith=f"{BASE}/conversations/conv-slow/activities").mock(
        return_value=httpx.Response(200, json={"watermark": "0", "activities": []})
    )
    result = await client.get_response(timeout_sec=0.1)
    assert result.status == AgentResponseStatus.TIMEOUT


@respx.mock
async def test_get_response_no_active_conversation(client):
    result = await client.get_response()
    assert result.status == AgentResponseStatus.SEND_FAILED


@respx.mock
async def test_get_response_watermark_forwarded(client, conversation_state):
    conversation_state.conversation_id = "conv-wm"
    conversation_state.watermark = "5"
    captured = []

    def _handler(request: httpx.Request) -> httpx.Response:
        captured.append(str(request.url))
        return httpx.Response(200, json=_activities_payload("ok", "6"))

    respx.get(url__startswith=f"{BASE}/conversations/conv-wm/activities").mock(
        side_effect=_handler
    )
    await client.get_response()
    assert "watermark=5" in captured[0]
    assert conversation_state.watermark == "6"
