"""Environment-driven configuration for the MS Agent Framework orchestrator.

Agent registry modes
--------------------
Dynamic (recommended for multi-agent corporate deployments):
    Set ``COPILOT_AGENTS=RH,TI,JURIDICO`` and, for each agent ID, define:
      - ``COPILOT_{ID}_NAME``              — display name (optional, default "Copilot {ID}")
      - ``COPILOT_{ID}_DEPARTMENT``        — department label (optional, default ID)
      - ``COPILOT_{ID}_DIRECT_LINE_SECRET`` — Direct Line secret (required)
      - ``COPILOT_{ID}_DESCRIPTION``       — tool docstring hint for the LLM (optional)
      - ``POWER_PLATFORM_ENV_{ID}``        — Power Platform env ID (optional, informational)

Legacy (backward-compat, only RH + TI):
    If ``COPILOT_AGENTS`` is not set, falls back to the original
    ``DIRECT_LINE_SECRET_RH`` / ``DIRECT_LINE_SECRET_TI`` variables.
"""

import os
from dataclasses import dataclass

DEFAULT_DIRECT_LINE_TIMEOUT_SEC = 45
DEFAULT_DIRECT_LINE_POLL_INTERVAL_SEC = 2.0

# Legacy built-in descriptor used when COPILOT_AGENTS is not set
_LEGACY_AGENTS: dict[str, dict[str, str]] = {
    "RH": {
        "name_env": "COPILOT_RH_NAME",
        "name_default": "Copilot RH",
        "department": "RH",
        "env_env": "POWER_PLATFORM_ENV_RH",
        "secret_env": "DIRECT_LINE_SECRET_RH",
        "description": (
            "Use for HR requests such as vacations, payslips, payroll, "
            "benefits, hiring or HR policies."
        ),
    },
    "TI": {
        "name_env": "COPILOT_TI_NAME",
        "name_default": "Copilot TI",
        "department": "TI",
        "env_env": "POWER_PLATFORM_ENV_TI",
        "secret_env": "DIRECT_LINE_SECRET_TI",
        "description": (
            "Use for IT requests such as password reset, VPN, software "
            "access, devices or printers."
        ),
    },
}


@dataclass(frozen=True)
class CopilotAgentConfig:
    key: str              # e.g. "AGENT_RH"
    name: str             # display name
    department: str       # e.g. "RH"
    environment: str      # Power Platform env ID
    direct_line_secret: str
    tool_description: str  # LLM-facing docstring for the generated tool function


@dataclass(frozen=True)
class DirectLineRuntimeConfig:
    timeout_sec: int
    poll_interval_sec: float
    debug_mode: bool
    structured_logging: bool


# ── Helper readers ────────────────────────────────────────────────────────────

def _required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def _env_int(name: str, default: int) -> int:
    value = os.environ.get(name)
    return default if (value is None or value == "") else int(value)


def _env_float(name: str, default: float) -> float:
    value = os.environ.get(name)
    return default if (value is None or value == "") else float(value)


def _env_bool(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None or value == "":
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


# ── Agent registry builders ───────────────────────────────────────────────────

def _build_agent_from_prefix(agent_id: str) -> CopilotAgentConfig:
    """Build a config from COPILOT_{ID}_* env vars (dynamic mode)."""
    upper = agent_id.upper()
    prefix = f"COPILOT_{upper}_"

    # Accept new-style key first, fall back to legacy DIRECT_LINE_SECRET_{ID}
    secret = os.environ.get(f"{prefix}DIRECT_LINE_SECRET") or os.environ.get(
        f"DIRECT_LINE_SECRET_{upper}"
    )
    if not secret:
        raise ValueError(
            f"Direct Line secret for agent '{agent_id}' not found. "
            f"Set {prefix}DIRECT_LINE_SECRET or DIRECT_LINE_SECRET_{upper}."
        )

    return CopilotAgentConfig(
        key=f"AGENT_{upper}",
        name=os.environ.get(f"{prefix}NAME", f"Copilot {agent_id}"),
        department=os.environ.get(f"{prefix}DEPARTMENT", agent_id),
        environment=os.environ.get(f"POWER_PLATFORM_ENV_{upper}", "unknown"),
        direct_line_secret=secret,
        tool_description=os.environ.get(
            f"{prefix}DESCRIPTION",
            f"Use for {os.environ.get(f'{prefix}DEPARTMENT', agent_id)} department requests.",
        ),
    )


def build_agent_registry() -> dict[str, CopilotAgentConfig]:
    """Build the agent registry from environment variables.

    Supports dynamic multi-agent mode via ``COPILOT_AGENTS`` and falls back
    to the legacy two-agent (RH + TI) configuration when the variable is unset.
    """
    agents_raw = os.environ.get("COPILOT_AGENTS", "").strip()

    if agents_raw:
        # Dynamic mode: explicit agent list
        ids = [a.strip().upper() for a in agents_raw.split(",") if a.strip()]
        return {f"AGENT_{aid}": _build_agent_from_prefix(aid) for aid in ids}

    # Legacy mode: scan built-in descriptors
    registry: dict[str, CopilotAgentConfig] = {}
    for agent_id, meta in _LEGACY_AGENTS.items():
        key = f"AGENT_{agent_id}"
        try:
            registry[key] = CopilotAgentConfig(
                key=key,
                name=os.environ.get(meta["name_env"], meta["name_default"]),
                department=meta["department"],
                environment=os.environ.get(meta["env_env"], "unknown"),
                direct_line_secret=_required_env(meta["secret_env"]),
                tool_description=meta["description"],
            )
        except ValueError:
            # Secret not set — skip; consumers will raise if the agent is needed
            pass

    if not registry:
        raise ValueError(
            "No agents configured. Set COPILOT_AGENTS=RH,TI or provide "
            "DIRECT_LINE_SECRET_RH and DIRECT_LINE_SECRET_TI."
        )
    return registry


def build_direct_line_runtime_config() -> DirectLineRuntimeConfig:
    return DirectLineRuntimeConfig(
        timeout_sec=_env_int("DIRECT_LINE_TIMEOUT_SEC", DEFAULT_DIRECT_LINE_TIMEOUT_SEC),
        poll_interval_sec=_env_float(
            "DIRECT_LINE_POLL_INTERVAL_SEC", DEFAULT_DIRECT_LINE_POLL_INTERVAL_SEC
        ),
        debug_mode=_env_bool("DEBUG_MODE", False),
        structured_logging=_env_bool("STRUCTURED_LOGGING", False),
    )
