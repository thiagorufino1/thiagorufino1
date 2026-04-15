"""Minimal session state for Copilot Studio Direct Line conversations.

The full OrchestratorSession and AbstractSessionStore from the CLI project are
not needed here — the Teams SDK (ConversationState) manages per-conversation
storage. Only CopilotConversationState is required to track Direct Line
conversation IDs and watermarks across turns.
"""

from dataclasses import dataclass, field


@dataclass
class CopilotConversationState:
    """Direct Line conversation state persisted across turns via ConversationState."""

    conversation_id: str | None = None
    watermark: str | None = None
    last_raw_activities: list[dict] = field(default_factory=list)
