"""Shared fixtures for the test suite."""

import pytest


@pytest.fixture(autouse=True)
def _base_env(monkeypatch):
    """Inject the minimum required environment variables for every test.

    Tests that need a specific value should override it with their own
    ``monkeypatch.setenv`` call after this fixture runs.
    """
    monkeypatch.setenv("AZURE_OPENAI_API_KEY", "test-oai-key")
    monkeypatch.setenv("AZURE_OPENAI_ENDPOINT", "https://test.openai.azure.com/")
    monkeypatch.setenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4o-test")
    monkeypatch.setenv("DIRECT_LINE_SECRET_RH", "secret-rh")
    monkeypatch.setenv("DIRECT_LINE_SECRET_TI", "secret-ti")
    # Ensure optional vars are absent so defaults are exercised
    for var in [
        "COPILOT_AGENTS",
        "COPILOT_RH_NAME",
        "COPILOT_TI_NAME",
        "POWER_PLATFORM_ENV_RH",
        "POWER_PLATFORM_ENV_TI",
        "DIRECT_LINE_TIMEOUT_SEC",
        "DIRECT_LINE_POLL_INTERVAL_SEC",
        "DEBUG_MODE",
        "STRUCTURED_LOGGING",
    ]:
        monkeypatch.delenv(var, raising=False)
