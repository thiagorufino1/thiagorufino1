"""Resilient Direct Line client for Microsoft Copilot Studio agents.

Improvements over the original version
---------------------------------------
- A single ``httpx.AsyncClient`` instance is shared across all calls within one
  ``CopilotClient`` object, enabling TCP connection reuse and keep-alive.
- ``start_conversation`` and ``send_message`` retry automatically on transient
  failures (429, 502-504, network errors) using exponential back-off via tenacity.
- The response from ``get_response`` is an ``AgentResult`` dataclass with an
  ``AgentResponseStatus`` enum, eliminating fragile string-matching for timeouts.
- Individual HTTP requests carry an explicit ``httpx.Timeout`` independent of
  the overall polling timeout.
"""

import asyncio
import logging
from dataclasses import dataclass
from enum import Enum

import httpx
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)

from core.config import CopilotAgentConfig, DirectLineRuntimeConfig
from core.session_store import CopilotConversationState

logger = logging.getLogger(__name__)

# HTTP status codes that warrant an automatic retry.
_RETRYABLE_STATUS_CODES: frozenset[int] = frozenset({429, 500, 502, 503, 504})

# Timeout applied to every individual HTTP request (connect + read).
_HTTP_TIMEOUT = httpx.Timeout(30.0, connect=10.0)

# Maximum poll interval cap when applying exponential back-off between polls.
_MAX_POLL_INTERVAL_SEC = 8.0


class AgentResponseStatus(Enum):
    OK = "ok"
    TIMEOUT = "timeout"
    SEND_FAILED = "send_failed"



@dataclass
class AgentResult:
    """Typed response from a Copilot Studio agent."""

    text: str
    status: AgentResponseStatus


def _is_retryable(exc: BaseException) -> bool:
    """Return True for transient HTTP or network errors worth retrying."""
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code in _RETRYABLE_STATUS_CODES
    return isinstance(exc, httpx.RequestError)


class CopilotClient:
    """Direct Line client with persistent conversation state and resilient calls.

    Args:
        agent_config:       Immutable config for this Copilot Studio agent.
        conversation_state: Mutable state (conversation ID, watermark) shared
                            with the session store.
        runtime_config:     Polling timeout and interval from environment.
        http_client:        Optional externally-managed ``httpx.AsyncClient``.
                            When ``None``, the client manages its own instance.
    """

    BASE_URL = "https://directline.botframework.com/v3/directline"

    def __init__(
        self,
        agent_config: CopilotAgentConfig,
        conversation_state: CopilotConversationState,
        runtime_config: DirectLineRuntimeConfig,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.agent_config = agent_config
        self.conversation_state = conversation_state
        self.runtime_config = runtime_config
        self._headers = {
            "Authorization": f"Bearer {agent_config.direct_line_secret}",
            "Content-Type": "application/json",
        }
        # Owning flag: if we created the client, we must close it.
        self._owns_http_client = http_client is None
        self._http = http_client or httpx.AsyncClient(
            timeout=_HTTP_TIMEOUT,
            limits=httpx.Limits(max_keepalive_connections=5, max_connections=10),
        )

    async def aclose(self) -> None:
        """Release the underlying TCP connections. Call when session ends."""
        if self._owns_http_client:
            await self._http.aclose()

    # ── Retry-decorated one-shot operations ───────────────────────────────────

    @retry(
        retry=retry_if_exception(_is_retryable),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        stop=stop_after_attempt(3),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    async def start_conversation(self) -> None:
        """Open a new Direct Line conversation and persist the conversation ID."""
        response = await self._http.post(
            f"{self.BASE_URL}/conversations",
            headers=self._headers,
        )
        response.raise_for_status()
        data = response.json()
        self.conversation_state.conversation_id = data.get("conversationId")
        logger.info(
            "Started Direct Line conversation with %s (%s): %s",
            self.agent_config.name,
            self.agent_config.environment,
            self.conversation_state.conversation_id,
        )

    @retry(
        retry=retry_if_exception(_is_retryable),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        stop=stop_after_attempt(3),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    async def _post_activity(self, message: str) -> bool:
        """POST a message activity; returns True on 2xx."""
        url = (
            f"{self.BASE_URL}/conversations/"
            f"{self.conversation_state.conversation_id}/activities"
        )
        activity = {
            "type": "message",
            "from": {"id": "serverless_orchestrator", "name": "Agent Framework Orchestrator"},
            "text": message,
        }
        response = await self._http.post(url, headers=self._headers, json=activity)
        if response.status_code in (200, 201, 202):
            return True
        logger.error(
            "Direct Line send failed for %s: %s %s",
            self.agent_config.key,
            response.status_code,
            response.text,
        )
        return False

    async def send_message(self, message: str) -> bool:
        """Ensure conversation exists and send ``message`` to the agent."""
        if not self.conversation_state.conversation_id:
            await self.start_conversation()
        try:
            return await self._post_activity(message)
        except Exception:
            logger.exception("send_message failed for %s after retries.", self.agent_config.key)
            return False

    # ── Polling ───────────────────────────────────────────────────────────────

    async def get_response(self, timeout_sec: int | None = None) -> AgentResult:
        """Poll the Direct Line until the agent replies or the timeout elapses.

        Returns an ``AgentResult`` with a typed status — no string parsing required.
        """
        if not self.conversation_state.conversation_id:
            return AgentResult(
                text="Error: no active conversation.",
                status=AgentResponseStatus.SEND_FAILED,
            )

        base_url = (
            f"{self.BASE_URL}/conversations/"
            f"{self.conversation_state.conversation_id}/activities"
        )
        responses: list[str] = []
        elapsed = 0.0
        effective_timeout = (
            timeout_sec if timeout_sec is not None else self.runtime_config.timeout_sec
        )
        poll_interval = self.runtime_config.poll_interval_sec

        while elapsed < effective_timeout:
            poll_url = (
                f"{base_url}?watermark={self.conversation_state.watermark}"
                if self.conversation_state.watermark
                else base_url
            )
            try:
                response = await self._http.get(poll_url, headers=self._headers)
                if response.status_code == 200:
                    data = response.json()
                    self.conversation_state.watermark = data.get("watermark")
                    activities = data.get("activities", [])
                    if activities:
                        self.conversation_state.last_raw_activities = activities
                    logger.info(
                        "Direct Line returned %s activities for %s at watermark %s.",
                        len(activities),
                        self.agent_config.key,
                        self.conversation_state.watermark,
                    )
                    for activity in activities:
                        if activity.get("type") != "message":
                            continue
                        if activity.get("from", {}).get("id") == "serverless_orchestrator":
                            continue
                        text = activity.get("text")
                        if text:
                            responses.append(text)
                    if responses:
                        break
                elif response.status_code in _RETRYABLE_STATUS_CODES:
                    logger.warning(
                        "Retryable status %s while polling %s.",
                        response.status_code,
                        self.agent_config.key,
                    )
            except httpx.RequestError as exc:
                logger.warning("Network error polling %s: %s", self.agent_config.key, exc)

            await asyncio.sleep(poll_interval)
            elapsed += poll_interval

        if not responses:
            logger.warning(
                "No response from %s within %.1f s.", self.agent_config.key, effective_timeout
            )
            return AgentResult(
                text="Desculpe, o agente do Copilot Studio não respondeu a tempo.",
                status=AgentResponseStatus.TIMEOUT,
            )

        return AgentResult(text="\n\n".join(responses), status=AgentResponseStatus.OK)
