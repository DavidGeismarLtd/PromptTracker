# frozen_string_literal: true

# PromptTracker Configuration
#
# This file is used to configure PromptTracker settings.

PromptTracker.configure do |config|
  # Path to the directory containing prompt YAML files
  # Default: Rails.root.join("app", "prompts")
  config.prompts_path = Rails.root.join("app", "prompts")

  # Auto-sync prompts from files in development environment
  # When enabled, prompts will be automatically synced from YAML files
  # on application startup in development mode.
  # Default: true
  # Auto-sync prompts from files in production environment
  # When enabled, prompts will be automatically synced from YAML files
  # on application startup in production mode.
  # WARNING: This is disabled by default for safety. In production,
  # you should sync prompts as part of your deployment process using:
  #   rake prompt_tracker:sync
  # Default: false

  # Basic Authentication for Web UI
  # If both username and password are set, the web UI will require
  # HTTP Basic Authentication. If either is nil, the UI is public.
  #
  # SECURITY: It's recommended to use environment variables for credentials
  # and enable basic auth in production to protect sensitive data.
  #
  # Example with environment variables:
  #   config.basic_auth_username = ENV["PROMPT_TRACKER_USERNAME"]
  #   config.basic_auth_password = ENV["PROMPT_TRACKER_PASSWORD"]
  #
  # Default: nil (public access)
  config.basic_auth_username = nil
  config.basic_auth_password = nil

  # ============================================================================
  # Available Models Configuration (REQUIRED)
  # ============================================================================
  # Define all available LLM models for your application.
  # The UI will dynamically generate dropdowns based on this configuration.
  #
  # Structure:
  #   config.available_models = {
  #     provider_key: [
  #       { id: "model-id", name: "Display Name", category: "Category" }
  #     ]
  #   }
  #
  # - provider_key: Symbol matching the provider name (e.g., :openai, :anthropic)
  # - id: The actual model ID used in API calls
  # - name: Human-readable name shown in the UI
  # - category: Used to group models in optgroups (e.g., "Latest", "Legacy")

  config.available_models = {
    openai: [
      { id: "gpt-4o", name: "GPT-4o", category: "Latest" },
      { id: "gpt-4o-mini", name: "GPT-4o Mini", category: "Latest" },
      { id: "gpt-4-turbo", name: "GPT-4 Turbo", category: "GPT-4" },
      { id: "gpt-4", name: "GPT-4", category: "GPT-4" },
      { id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", category: "GPT-3.5" }
    ],
    anthropic: [
      { id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", category: "Claude 3.5" },
      { id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", category: "Claude 3.5" },
      { id: "claude-3-opus-20240229", name: "Claude 3 Opus", category: "Claude 3" },
      { id: "claude-3-sonnet-20240229", name: "Claude 3 Sonnet", category: "Claude 3" },
      { id: "claude-3-haiku-20240307", name: "Claude 3 Haiku", category: "Claude 3" }
    ],
    openai_assistants: [
      { id: "asst_afXcN6qT5RnxXuYJQ4qY8NXG", name: "Dr Alain Firmier", category: "Medical" },
      { id: "asst_Rp8RFTBJuMsJgtPaODCFsalw", name: "Dr Hormone Granger", category: "Medical" },
      { id: "asst_rUVKiJMkR2GQdKecvlOvMB4L", name: "Opticien Obi-Wan Kénoptique", category: "Medical" },
      { id: "asst_BKPUhtBAJK6nunqxDW0NnAEs", name: "Thérapeute Dumble Dort", category: "Medical" },
      { id: "asst_kVDgt2IN9EMjL6hu8u37MCIN", name: "Dr Gandalf Le Blanc", category: "Medical" },
      { id: "asst_njJTsfk1F3XlpMlKoK9SFWe3", name: "Coach Rocky Bal-Yoga", category: "Wellness" },
      { id: "asst_AOBGuBZSetLu93FAMJOmFrxT", name: "Agent 00-Sébum", category: "Wellness" },
      { id: "asst_BkAoJFSxztp0AARP4VRfrJB7", name: "Pédiatre Petit Ours Brun", category: "Medical" },
      { id: "asst_BFFPyjOtwA7IUdwSQVhVfJIX", name: "Dr Léa Chéprise", category: "Medical" },
      { id: "asst_HPnWFrxtUBbk4PoLJ9d83pS6", name: "Nutritioniste Leonardo DiCarpaccio", category: "Wellness" }
    ]
  }

  # ============================================================================
  # Provider API Key Environment Variables (REQUIRED)
  # ============================================================================
  # Map each provider to its API key environment variable name.
  # This is used to check if a provider is configured before showing it in the UI.
  #
  # Structure:
  #   config.provider_api_key_env_vars = {
  #     provider_key: "ENV_VARIABLE_NAME"
  #   }

  config.provider_api_key_env_vars = {
    openai: "OPENAI_API_KEY",
    anthropic: "ANTHROPIC_API_KEY",
    google: "GOOGLE_API_KEY",
    openai_assistants: "OPENAI_LOUNA_API_KEY"  # Uses same API key as OpenAI
  }

  # ============================================================================
  # Default Models for AI-Powered Features (OPTIONAL)
  # ============================================================================
  # These settings control which models are used for specific AI-powered features.
  # Users can still select different models in the UI - these are just defaults.
  # If not set, the UI will use the first available model from the configuration.

  # Model used for AI-powered prompt generation in the playground
  config.prompt_generator_model = "gpt-4o-mini"

  # Model used for generating dataset rows
  config.dataset_generator_model = "gpt-4o"

  # Default model for LLM judge evaluators
  config.llm_judge_model = "gpt-4o"
end
