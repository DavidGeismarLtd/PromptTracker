# frozen_string_literal: true

# Assistant Chatbot Configuration Example
# This file shows the configuration options for the Assistant Chatbot feature.
# Copy relevant sections to your config/initializers/prompt_tracker.rb

PromptTracker.configure do |config|
  # ... existing configuration ...

  # =========================================================================
  # ASSISTANT CHATBOT CONFIGURATION
  # =========================================================================

  # Enable or disable the assistant chatbot feature
  # When disabled, the floating button and chat panel will not appear
  config.assistant_chatbot = {
    # Feature toggle
    enabled: true,

    # -----------------------------------------------------------------------
    # MODEL CONFIGURATION
    # -----------------------------------------------------------------------
    # Configure which LLM provider and model powers the chatbot
    model: {
      provider: :openai,           # :openai, :anthropic, :google, etc.
      api: :chat_completions,      # :chat_completions, :messages, etc.
      model: "gpt-4o",             # Model name (e.g., "gpt-4o", "claude-3-5-sonnet-20241022")
      temperature: 0.7             # Creativity level (0.0 = deterministic, 1.0 = creative)
    },

    # Alternative: Use Claude for more detailed reasoning
    # model: {
    #   provider: :anthropic,
    #   api: :messages,
    #   model: "claude-3-5-sonnet-20241022",
    #   temperature: 0.7
    # },

    # -----------------------------------------------------------------------
    # UI CUSTOMIZATION
    # -----------------------------------------------------------------------
    ui: {
      name: "PromptTracker Assistant",  # Display name in chat header
      position: :bottom_right,          # :bottom_right or :bottom_left
      theme: :light                    # :light, :dark, or :auto (match system)

      # Optional: Custom colors
      # primary_color: "#007bff",
      # background_color: "#ffffff",
      # text_color: "#212529"
    },

    # -----------------------------------------------------------------------
    # CONVERSATION SETTINGS
    # -----------------------------------------------------------------------
    conversation: {
      max_messages: 50,      # Limit conversation history to prevent large sessions
      ttl: 24.hours,         # Auto-expire conversations after 24h of inactivity

      # Store conversations in Redis (uses existing cache_store)
      storage: :cache_store  # or :session (default)
    },

    # -----------------------------------------------------------------------
    # FEATURE CAPABILITIES
    # -----------------------------------------------------------------------
    # Enable/disable individual chatbot capabilities
    capabilities: {
      create_prompts: true,       # Allow creating new prompts
      generate_tests: true,       # Allow generating tests for prompts
      run_tests: true,            # Allow running test suites
      generate_datasets: true,    # Allow generating dataset rows
      run_ab_tests: false,        # Future: Run A/B test comparisons
      navigate: true,             # Provide navigation suggestions
      export_data: false          # Future: Export data
    },

    # -----------------------------------------------------------------------
    # SECURITY & RATE LIMITING
    # -----------------------------------------------------------------------
    security: {
      # Rate limiting (messages per minute per user)
      rate_limit: {
        enabled: true,
        requests_per_minute: 30
      },

      # Require authentication (inherits from basic_auth_enabled?)
      require_auth: true,

      # Audit trail for all function executions
      audit_enabled: true
    },

    # -----------------------------------------------------------------------
    # CONTEXT AWARENESS
    # -----------------------------------------------------------------------
    # Configure how the assistant detects and uses page context
    context: {
      # Automatically detect current page and entities
      auto_detect: true,

      # Include user preferences in context
      include_user_prefs: true

      # Custom context providers (advanced)
      # providers: [MyApp::CustomContextProvider]
    },

    # -----------------------------------------------------------------------
    # SUGGESTIONS
    # -----------------------------------------------------------------------
    # Configure suggested actions
    suggestions: {
      enabled: true,
      max_suggestions: 3  # Show up to 3 suggestions at a time

      # Context-based suggestion rules
      # Override default suggestion logic
      # provider: MyApp::CustomSuggestionProvider
    },

    # -----------------------------------------------------------------------
    # ADVANCED SETTINGS
    # -----------------------------------------------------------------------
    advanced: {
      # Enable streaming responses (token-by-token)
      # Requires SSE (Server-Sent Events) support
      streaming: false,

      # Enable markdown rendering in messages
      markdown: true,

      # Enable code syntax highlighting
      syntax_highlighting: true,

      # Custom system prompt template
      # Leave nil to use default
      system_prompt_template: nil
      # system_prompt_template: File.read(Rails.root.join("config", "assistant_system_prompt.txt"))

      # Custom function definitions (add your own functions)
      # custom_functions: [
      #   MyApp::AssistantFunctions::CustomFunction
      # ]
    }
  }

  # -----------------------------------------------------------------------
  # ALTERNATIVE: Minimal Configuration
  # -----------------------------------------------------------------------
  # If you just want to enable the chatbot with defaults:
  #
  # config.assistant_chatbot = { enabled: true }
  #
  # This uses:
  # - Model: gpt-4o (OpenAI)
  # - UI: Bottom-right, light theme
  # - All capabilities enabled
  # - Default rate limits

  # -----------------------------------------------------------------------
  # ALTERNATIVE: Disable Chatbot
  # -----------------------------------------------------------------------
  # To completely disable the chatbot:
  #
  # config.assistant_chatbot = { enabled: false }
  #
  # OR
  #
  # config.features[:assistant_chatbot] = false

  # -----------------------------------------------------------------------
  # ALTERNATIVE: Feature-Specific Disable
  # -----------------------------------------------------------------------
  # Disable specific capabilities while keeping chatbot enabled:
  #
  # config.assistant_chatbot = {
  #   enabled: true,
  #   capabilities: {
  #     create_prompts: true,
  #     generate_tests: true,
  #     run_tests: false,        # Disable running tests
  #     generate_datasets: false # Disable dataset generation
  #   }
  # }
end
