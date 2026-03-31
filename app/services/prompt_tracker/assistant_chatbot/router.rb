# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    # Routes incoming assistant requests to specialized assistants
    # based on the current page context and user message.
    #
    # Routing is performed with a lightweight LLM classification
    # call. This keeps the AssistantChatbotService free from
    # brittle string matching while making it easy to extend to
    # more assistants (dataset wizard, deployment wizard, etc.).
    class Router
      def self.assistant_for(message:, context: {})
        new(message: message, context: context).assistant
      end

      def initialize(message:, context: {})
        @message = message.to_s
        @context = context || {}
      end

      def assistant
          # Only call the LLM router when there is an actual user message.
          # This avoids unnecessary LLM calls for things like suggestions,
          # where we don't have a message and just want context-based hints.
          return :default if message.strip.empty?
          return :default unless route_with_llm?

          classify_with_llm
      end

      private

      attr_reader :message, :context

      def route_with_llm?
        # Only enable routing on pages where specialized wizards are
        # relevant. This keeps latency low on purely informational
        # pages.
        case context[:page_type]
        when :prompt_version_detail, # tests / datasets / deployment
             :prompts_list,          # prompt creation
             :playground,            # save-as-prompt
             :agents                 # deployment from agents index
          true
        else
          false
        end
      end

      def classify_with_llm
        system_prompt = <<~PROMPT.strip
          You are a router for the PromptTracker assistant.

          Read the current page context and the user's message.
          Decide which specialized assistant (if any) should handle
          the request.

          Return exactly ONE word from this list:
          - "default"
          - "test_wizard"
          - "dataset_wizard"
          - "prompt_creation_wizard"
          - "deployment_wizard"

          Use these guidelines:
          - Use "test_wizard" when the user clearly wants to run tests
            for a prompt or prompt version (e.g. "run all tests",
            "execute the tests", "run regression tests"). This is
            most relevant on prompt version pages.
          - Use "dataset_wizard" when the user wants to create or set
            up a dataset for a prompt version (e.g. "create a dataset",
            "generate a dataset for this version").
          - Use "prompt_creation_wizard" when the user wants to create
            a brand new prompt (e.g. "create a new prompt",
            "save this playground as a prompt"). This is most relevant
            on prompts list or playground pages.
          - Use "deployment_wizard" when the user wants to deploy a
            prompt version as a live agent or create a new agent
            (e.g. "deploy this as an agent", "create a task agent").
          - Use "default" for all other cases or when you are unsure.

          Do not add any explanation.
        PROMPT

        routing_prompt = <<~PROMPT.strip
          Page type: #{context[:page_type] || "none"}
          Prompt version id: #{context[:prompt_version_id] || "none"}

          User message:
          #{message}
        PROMPT

        normalized = LlmClients::RubyLlmService.call(
          model: router_model,
          prompt: routing_prompt,
          system: system_prompt,
          tools: [],
          tool_config: {},
          temperature: 0
        )

        label = normalized.text.to_s.strip.downcase

        case label
        when "test_wizard"
          :test_wizard
        when "dataset_wizard"
          :dataset_wizard
        when "prompt_creation_wizard"
          :prompt_creation_wizard
        when "deployment_wizard"
          :deployment_wizard
        else
          :default
        end
      end

      def router_model
        config = PromptTracker.configuration.assistant_chatbot
        model_config = config[:model] || {}
        router_config = config[:router] || {}

        router_config[:model] || model_config[:model] || "gpt-4o-mini"
      end
    end
  end
end
