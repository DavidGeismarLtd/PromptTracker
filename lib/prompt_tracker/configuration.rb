# frozen_string_literal: true

module PromptTracker
  # Configuration for PromptTracker.
  #
  # @example Configure in an initializer
  #   PromptTracker.configure do |config|
  #     config.prompts_path = Rails.root.join("app", "prompts")
  #     config.auto_sync_in_development = true
  #     config.basic_auth_username = "admin"
  #     config.basic_auth_password = "secret"
  #   end
  #
  class Configuration
    # Path to the directory containing prompt YAML files.
    # @return [String] the prompts directory path
    attr_accessor :prompts_path

    # Basic authentication username for web UI access.
    # If nil, basic auth is disabled and URLs are public.
    # @return [String, nil] the username
    attr_accessor :basic_auth_username

    # Basic authentication password for web UI access.
    # If nil, basic auth is disabled and URLs are public.
    # @return [String, nil] the password
    attr_accessor :basic_auth_password

    # Available models for each provider (shown in dropdowns).
    # Users MUST define this in their initializer.
    #
    # @return [Hash] hash of provider => array of model hashes
    # @example Define in initializer
    #   PromptTracker.configure do |config|
    #     config.available_models = {
    #       openai: [
    #         { id: "gpt-4o", name: "GPT-4o", category: "Latest" },
    #         { id: "gpt-4", name: "GPT-4", category: "GPT-4" }
    #       ],
    #       anthropic: [
    #         { id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", category: "Claude 3.5" }
    #       ]
    #     }
    #   end
    attr_accessor :available_models

    # Mapping of provider names to their API key environment variable names.
    # Used to check if a provider is configured before showing it in the UI.
    #
    # @return [Hash] hash of provider => ENV variable name
    # @example Define in initializer
    #   PromptTracker.configure do |config|
    #     config.provider_api_key_env_vars = {
    #       openai: "OPENAI_API_KEY",
    #       anthropic: "ANTHROPIC_API_KEY",
    #       google: "GOOGLE_API_KEY",
    #       custom_provider: "CUSTOM_PROVIDER_API_KEY"
    #     }
    #   end
    attr_accessor :provider_api_key_env_vars

    # Default model for AI-powered prompt generation in playground.
    # @return [String] the model identifier
    attr_accessor :prompt_generator_model

    # Default model for dataset row generation.
    # @return [String] the model identifier
    attr_accessor :dataset_generator_model

    # Default model for LLM judge evaluator.
    # @return [String] the model identifier
    attr_accessor :llm_judge_model

    # Initialize with default values.
    def initialize
      @prompts_path = default_prompts_path
      @basic_auth_username = nil
      @basic_auth_password = nil
      @available_models = {}
      @provider_api_key_env_vars = {}
      @prompt_generator_model = nil
      @dataset_generator_model = nil
      @llm_judge_model = nil
    end

    # Check if basic authentication is enabled.
    #
    # @return [Boolean] true if both username and password are set
    def basic_auth_enabled?
      basic_auth_username.present? && basic_auth_password.present?
    end

    private

    # Get the default prompts path.
    #
    # @return [String] default path
    def default_prompts_path
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join("app", "prompts").to_s
      else
        File.join(Dir.pwd, "app", "prompts")
      end
    end
  end

  # Get the current configuration.
  #
  # @return [Configuration] the configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure PromptTracker.
  #
  # @yield [Configuration] the configuration instance
  # @example
  #   PromptTracker.configure do |config|
  #     config.prompts_path = "/custom/path"
  #   end
  def self.configure
    yield(configuration)
  end

  # Reset configuration to defaults.
  # Mainly used for testing.
  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
