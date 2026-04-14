"""
Copyright (c) Microsoft Corporation. All rights reserved.
Licensed under the MIT License.
"""

class Config:
    """Agent Configuration"""

    def __init__(self, env):
        self.port = int(env.get("PORT", 3978))
        self.azure_openai_api_key = env["AZURE_OPENAI_API_KEY"]
        self.azure_openai_deployment_name = env["AZURE_OPENAI_DEPLOYMENT_NAME"]
        self.azure_openai_endpoint = env["AZURE_OPENAI_ENDPOINT"]
        self.azure_openai_api_version = env.get("AZURE_OPENAI_API_VERSION", "2024-12-01-preview")
        self.ai_feedback_loop_enabled = env.get("M365_AGENT_FEEDBACK_LOOP", "true").lower() == "true"
        self.ai_generated_label_enabled = env.get("M365_AGENT_AI_LABEL", "true").lower() == "true"
        self.sensitivity_name = env.get("M365_AGENT_SENSITIVITY_NAME", "Internal")
        self.sensitivity_type = env.get("M365_AGENT_SENSITIVITY_TYPE", "https://schema.org/Message")
        self.sensitivity_schema_type = env.get("M365_AGENT_SENSITIVITY_SCHEMA_TYPE", "CreativeWork")
