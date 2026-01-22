# frozen_string_literal: true

module PromptTracker
  # Factory for building API executors based on model configuration.
  #
  # This service encapsulates the logic for selecting the appropriate
  # executor class based on the API type (provider + api combination).
  #
  # All executors are namespaced under their provider to maintain clear
  # separation of concerns and make it easy to add provider-specific logic.
  #
  # @example Build an executor for OpenAI Chat Completions
  #   executor = ApiExecutorFactory.build(
  #     model_config: { provider: "openai", api: "chat_completions", model: "gpt-4o" },
  #     use_real_llm: true,
  #     testable: prompt_version
  #   )
  #   # Returns: TestRunners::ApiExecutors::Openai::CompletionApiExecutor
  #
  # @example Build an executor for OpenAI Response API
  #   executor = ApiExecutorFactory.build(
  #     model_config: { provider: "openai", api: "responses", model: "gpt-4o" },
  #     use_real_llm: true
  #   )
  #   # Returns: TestRunners::ApiExecutors::Openai::ResponseApiExecutor
  #
  class ApiExecutorFactory
    class << self
      # Build an API executor instance
      #
      # @param model_config [Hash] model configuration with provider, api, model
      # @param use_real_llm [Boolean] whether to use real LLM API or mock
      # @param testable [Object, nil] optional testable object (for test runners)
      # @return [TestRunners::ApiExecutors::Base] executor instance
      # @raise [ArgumentError] if model_config is missing required keys
      def build(model_config:, use_real_llm: false, testable: nil)
        validate_model_config!(model_config)

        executor_class = executor_class_for(model_config)

        executor_class.new(
          model_config: model_config,
          use_real_llm: use_real_llm,
          testable: testable
        )
      end

      private

      # Validate model configuration has required keys
      #
      # @param model_config [Hash] model configuration
      # @raise [ArgumentError] if required keys are missing
      def validate_model_config!(model_config)
        config = model_config.with_indifferent_access

        if config[:provider].blank?
          raise ArgumentError, "model_config must include :provider"
        end

        if config[:api].blank?
          raise ArgumentError, "model_config must include :api"
        end
      end

      # Determine executor class based on model config
      #
      # Routes to provider-specific executors based on the API type.
      # All executors are namespaced under TestRunners::ApiExecutors::{Provider}::
      #
      # @param model_config [Hash] model configuration
      # @return [Class] executor class
      def executor_class_for(model_config)
        config = model_config.with_indifferent_access
        api_type = ApiTypes.from_config(config[:provider], config[:api])

        case api_type
        when :openai_responses
          # OpenAI Response API has special stateful conversation handling
          TestRunners::ApiExecutors::Openai::ResponseApiExecutor
        when :openai_chat_completions
          # OpenAI Chat Completions API
          TestRunners::ApiExecutors::Openai::CompletionApiExecutor
        when :anthropic_messages
          # Anthropic uses the same completion pattern as OpenAI
          # For now, use the OpenAI executor (could be split later if needed)
          TestRunners::ApiExecutors::Openai::CompletionApiExecutor
        when :google_gemini
          # Google Gemini uses the same completion pattern
          TestRunners::ApiExecutors::Openai::CompletionApiExecutor
        else
          # Fallback to OpenAI completion executor for unknown API types
          # This handles any custom or future API types that follow the chat completion pattern
          TestRunners::ApiExecutors::Openai::CompletionApiExecutor
        end
      end
    end
  end
end
