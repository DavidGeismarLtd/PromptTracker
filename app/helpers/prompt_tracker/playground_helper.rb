# frozen_string_literal: true

module PromptTracker
  # Helper methods for the Playground views.
  # Provides provider detection and tool availability methods.
  module PlaygroundHelper
    # Check if the current provider is OpenAI Response API
    #
    # @return [Boolean] true if using openai_responses provider
    def response_api_provider?
      current_provider == "openai_responses"
    end

    # Check if the current provider supports multi-turn conversations
    #
    # @return [Boolean] true if provider supports conversations
    def supports_conversation?
      response_api_provider?
    end

    # Get available tools for the current provider
    #
    # @return [Array<Hash>] list of available tools with id, name, description
    def available_tools_for_provider
      return [] unless response_api_provider?

      [
        {
          id: "web_search",
          name: "Web Search",
          description: "Search the web for current information",
          icon: "bi-globe"
        },
        {
          id: "file_search",
          name: "File Search",
          description: "Search through uploaded files",
          icon: "bi-file-earmark-search"
        },
        {
          id: "code_interpreter",
          name: "Code Interpreter",
          description: "Execute Python code for analysis",
          icon: "bi-code-slash"
        }
      ]
    end

    # Get the current provider from version config or default
    #
    # @return [String] the current provider name
    def current_provider
      @version&.model_config&.dig("provider") ||
        default_provider_for(:playground)&.to_s ||
        "openai"
    end

    # Get the current model from version config or default
    #
    # @return [String] the current model name
    def current_model
      @version&.model_config&.dig("model") ||
        default_model_for(:playground) ||
        "gpt-4o"
    end

    # Check if the provider supports tools
    #
    # @param provider [String] the provider name
    # @return [Boolean] true if provider supports tools
    def provider_supports_tools?(provider = current_provider)
      %w[openai_responses openai_assistants].include?(provider.to_s)
    end

    # Get enabled tools from version config
    #
    # @return [Array<String>] list of enabled tool IDs
    def enabled_tools
      @version&.model_config&.dig("tools") || []
    end

    # Build conversation state from session
    #
    # @param session [ActionDispatch::Request::Session] the session object
    # @return [Hash] conversation state with messages and metadata
    def conversation_state_from_session(session)
      session[:playground_conversation] || {
        messages: [],
        previous_response_id: nil,
        started_at: nil
      }
    end
  end
end
