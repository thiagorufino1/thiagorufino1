"""Tests for core/config.py — environment parsing and agent registry."""

import pytest

from core.config import (
    DEFAULT_DIRECT_LINE_POLL_INTERVAL_SEC,
    DEFAULT_DIRECT_LINE_TIMEOUT_SEC,
    build_agent_registry,
    build_direct_line_runtime_config,
)


class TestBuildDirectLineRuntimeConfig:
    def test_defaults_when_env_absent(self):
        cfg = build_direct_line_runtime_config()
        assert cfg.timeout_sec == DEFAULT_DIRECT_LINE_TIMEOUT_SEC
        assert cfg.poll_interval_sec == DEFAULT_DIRECT_LINE_POLL_INTERVAL_SEC
        assert cfg.debug_mode is False
        assert cfg.structured_logging is False

    def test_overrides_from_env(self, monkeypatch):
        monkeypatch.setenv("DIRECT_LINE_TIMEOUT_SEC", "90")
        monkeypatch.setenv("DIRECT_LINE_POLL_INTERVAL_SEC", "3.5")
        monkeypatch.setenv("DEBUG_MODE", "true")
        monkeypatch.setenv("STRUCTURED_LOGGING", "1")
        cfg = build_direct_line_runtime_config()
        assert cfg.timeout_sec == 90
        assert cfg.poll_interval_sec == 3.5
        assert cfg.debug_mode is True
        assert cfg.structured_logging is True

    @pytest.mark.parametrize("value", ["true", "1", "yes", "on", "TRUE", "YES"])
    def test_bool_truthy_values(self, monkeypatch, value):
        monkeypatch.setenv("DEBUG_MODE", value)
        assert build_direct_line_runtime_config().debug_mode is True

    @pytest.mark.parametrize("value", ["false", "0", "no", "off", "FALSE"])
    def test_bool_falsy_values(self, monkeypatch, value):
        monkeypatch.setenv("DEBUG_MODE", value)
        assert build_direct_line_runtime_config().debug_mode is False


class TestBuildAgentRegistryLegacy:
    """Legacy mode: COPILOT_AGENTS not set, RH + TI secrets present."""

    def test_returns_both_agents(self):
        registry = build_agent_registry()
        assert "AGENT_RH" in registry
        assert "AGENT_TI" in registry

    def test_agent_keys_match(self):
        registry = build_agent_registry()
        assert registry["AGENT_RH"].key == "AGENT_RH"
        assert registry["AGENT_TI"].key == "AGENT_TI"

    def test_default_names(self):
        registry = build_agent_registry()
        assert registry["AGENT_RH"].name == "Copilot RH"
        assert registry["AGENT_TI"].name == "Copilot TI"

    def test_custom_name_from_env(self, monkeypatch):
        monkeypatch.setenv("COPILOT_RH_NAME", "Meu Agente RH")
        registry = build_agent_registry()
        assert registry["AGENT_RH"].name == "Meu Agente RH"

    def test_tool_description_populated(self):
        registry = build_agent_registry()
        assert len(registry["AGENT_RH"].tool_description) > 10
        assert len(registry["AGENT_TI"].tool_description) > 10

    def test_missing_secret_raises(self, monkeypatch):
        monkeypatch.delenv("DIRECT_LINE_SECRET_RH")
        monkeypatch.delenv("DIRECT_LINE_SECRET_TI")
        with pytest.raises(ValueError, match="No agents configured"):
            build_agent_registry()


class TestBuildAgentRegistryDynamic:
    """Dynamic mode: COPILOT_AGENTS is set."""

    def test_single_dynamic_agent(self, monkeypatch):
        monkeypatch.setenv("COPILOT_AGENTS", "JURIDICO")
        monkeypatch.setenv("COPILOT_JURIDICO_DIRECT_LINE_SECRET", "secret-j")
        monkeypatch.setenv("COPILOT_JURIDICO_NAME", "Agente Jurídico")
        monkeypatch.setenv("COPILOT_JURIDICO_DEPARTMENT", "Legal")
        registry = build_agent_registry()
        assert "AGENT_JURIDICO" in registry
        assert registry["AGENT_JURIDICO"].name == "Agente Jurídico"
        assert registry["AGENT_JURIDICO"].department == "Legal"
        assert registry["AGENT_JURIDICO"].direct_line_secret == "secret-j"

    def test_multiple_dynamic_agents(self, monkeypatch):
        monkeypatch.setenv("COPILOT_AGENTS", "RH,TI,FIN")
        monkeypatch.setenv("COPILOT_FIN_DIRECT_LINE_SECRET", "secret-fin")
        # RH and TI fall back to legacy env vars already set by conftest
        registry = build_agent_registry()
        assert set(registry.keys()) == {"AGENT_RH", "AGENT_TI", "AGENT_FIN"}

    def test_missing_secret_in_dynamic_mode_raises(self, monkeypatch):
        monkeypatch.setenv("COPILOT_AGENTS", "GHOST")
        # No secret set for GHOST
        with pytest.raises(ValueError, match="GHOST"):
            build_agent_registry()

    def test_dynamic_agent_legacy_secret_fallback(self, monkeypatch):
        """COPILOT_AGENTS=RH should find DIRECT_LINE_SECRET_RH as fallback."""
        monkeypatch.setenv("COPILOT_AGENTS", "RH")
        registry = build_agent_registry()
        assert registry["AGENT_RH"].direct_line_secret == "secret-rh"
