"""Structured logging configuration for the MS Agent Framework orchestrator.

In development, logs are emitted as human-readable text to stderr.
In production (STRUCTURED_LOGGING=true), logs are emitted as single-line JSON
objects compatible with Azure Monitor / Application Insights.

Usage:
    from core.logging_config import configure_logging, CORRELATION_ID

    configure_logging(debug_mode=False, structured=False)
    CORRELATION_ID.set("my-session-correlation-id")
"""

import json
import logging
import sys
from contextvars import ContextVar
from datetime import datetime, timezone

# Per-async-context correlation ID — set automatically when a session is bound.
CORRELATION_ID: ContextVar[str] = ContextVar("correlation_id", default="")


def get_correlation_id() -> str:
    return CORRELATION_ID.get() or "no-session"


class StructuredFormatter(logging.Formatter):
    """Single-line JSON formatter, Azure Monitor / App Insights compatible."""

    def format(self, record: logging.LogRecord) -> str:
        entry: dict = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "correlation_id": get_correlation_id(),
        }
        # Optional enrichment fields set via logger.info(..., extra={...})
        for field in ("latency_ms", "agent_key"):
            if hasattr(record, field):
                entry[field] = getattr(record, field)
        return json.dumps(entry, ensure_ascii=False)


def configure_logging(debug_mode: bool = False, structured: bool = False) -> None:
    """Configure root logger.

    Args:
        debug_mode:  Log at DEBUG level for all application loggers.
        structured:  Emit JSON lines (production / Azure Monitor integration).
    """
    root = logging.getLogger()
    root.setLevel(logging.DEBUG if debug_mode else logging.WARNING)

    handler = logging.StreamHandler(sys.stderr)
    if structured:
        handler.setFormatter(StructuredFormatter())
    else:
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s %(levelname)-8s [%(name)s] %(message)s",
                datefmt="%H:%M:%S",
            )
        )

    root.handlers.clear()
    root.addHandler(handler)

    # Silence verbose third-party loggers unless debug mode is active.
    noisy = [
        "httpx", "httpcore", "openai",
        "agent_framework", "agent_framework_openai",
    ]
    if not debug_mode:
        for name in noisy:
            logging.getLogger(name).setLevel(logging.WARNING)
