from __future__ import annotations

from typing import Optional

from microsoft_agents.activity import Activity, ClientCitation, SensitivityUsageInfo
from microsoft_agents.activity.entity import AIEntity
from microsoft_agents.hosting.aiohttp.app.streaming.streaming_response import StreamingResponse


def apply_sdk_workarounds() -> None:
    """Patch known SDK 0.8.0 streaming issues that block Teams AI metadata."""

    _patch_activity_add_ai_metadata()
    _patch_streaming_response_feedback_loop()
    _patch_jwks_client_cache()


def _patch_activity_add_ai_metadata() -> None:
    """Fix SDK bug: native add_ai_metadata only adds AIEntity when citations exist.
    Teams requires the entity (with additionalType=AIGeneratedContent) even without citations.
    """
    if getattr(Activity.add_ai_metadata, "_patched_for_teams_ai_metadata", False):
        return

    def add_ai_metadata(
        self: Activity,
        citations: Optional[list[ClientCitation]] = None,
        usage_info: Optional[SensitivityUsageInfo] = None,
    ) -> None:
        ai_entity = AIEntity(
            type="https://schema.org/Message",
            schema_type="Message",
            context="https://schema.org",
            id="",
            additional_type=["AIGeneratedContent"],
            citation=citations or [],
            usage_info=usage_info,
        )

        if self.entities is None:
            self.entities = []

        self.entities.append(ai_entity)

    add_ai_metadata._patched_for_teams_ai_metadata = True
    Activity.add_ai_metadata = add_ai_metadata


def _patch_streaming_response_feedback_loop() -> None:
    """Fix SDK bug: feedbackLoop is set on streaminfo entity but Teams expects it in channel_data."""
    if getattr(StreamingResponse._send_activity, "_patched_for_feedback_channel_data", False):
        return

    original_send_activity = StreamingResponse._send_activity

    async def _send_activity(self: StreamingResponse, activity) -> None:
        # Teams expects feedbackLoop in channel_data, not only in streaminfo entity
        if self._ended and self._enable_feedback_loop and self._feedback_loop_type:
            channel_data = dict(activity.channel_data or {})
            channel_data["feedbackLoop"] = {"type": self._feedback_loop_type}
            activity.channel_data = channel_data
        await original_send_activity(self, activity)

    _send_activity._patched_for_feedback_channel_data = True
    StreamingResponse._send_activity = _send_activity


def _patch_jwks_client_cache() -> None:
    """Fix SDK bug: PyJWKClient created on every request with no cache,
    causing a remote HTTPS fetch per turn that times out under slow networks.
    Patch caches one client per JWKS URI with a 1-hour key lifespan.
    """
    from microsoft_agents.hosting.core.authorization import jwt_token_validator as _mod
    from jwt import PyJWKClient

    if getattr(_mod.JwtTokenValidator._get_public_key_or_secret, "_patched_jwks_cache", False):
        return

    _jwks_clients: dict[str, PyJWKClient] = {}

    original = _mod.JwtTokenValidator._get_public_key_or_secret

    async def _get_public_key_or_secret(self, token: str):
        import asyncio
        from jwt import get_unverified_header, decode

        header = get_unverified_header(token)
        unverified_payload: dict = decode(token, options={"verify_signature": False})

        jwks_uri = (
            "https://login.botframework.com/v1/.well-known/keys"
            if unverified_payload.get("iss") == "https://api.botframework.com"
            else f"https://login.microsoftonline.com/{self.configuration.TENANT_ID}/discovery/v2.0/keys"
        )

        if jwks_uri not in _jwks_clients:
            _jwks_clients[jwks_uri] = PyJWKClient(jwks_uri, lifespan=3600)

        return await asyncio.to_thread(_jwks_clients[jwks_uri].get_signing_key, header["kid"])

    _get_public_key_or_secret._patched_jwks_cache = True
    _mod.JwtTokenValidator._get_public_key_or_secret = _get_public_key_or_secret
