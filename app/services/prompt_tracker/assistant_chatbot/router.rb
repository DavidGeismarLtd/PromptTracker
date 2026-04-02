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
      def self.assistant_for(message:, context: {}, conversation_history: [])
        new(message: message, context: context, conversation_history: conversation_history).assistant
      end

      def initialize(message:, context: {}, conversation_history: [])
        @message = message.to_s
        @context = context || {}
        @conversation_history = conversation_history || []
      end

      def assistant
        # Only call the LLM router when there is an actual user message.
        # This avoids unnecessary LLM calls for things like suggestions,
        # where we don't have a message and just want context-based hints.
        if message.strip.empty?
          Rails.logger.info "[AssistantChatbot::Router] Blank message – falling back to :default assistant"
          return :default
        end

        unless route_with_llm?
          Rails.logger.info "[AssistantChatbot::Router] Routing disabled for context=#{context.inspect} – using :default assistant"
          return :default
        end

        Rails.logger.info "[AssistantChatbot::Router] Routing message=#{message.inspect} context=#{context.inspect} using model=#{router_model}"
        assistant = classify_with_llm
        Rails.logger.info "[AssistantChatbot::Router] Routed to assistant=#{assistant.inspect} for message=#{message.inspect}"
        assistant
      end

      private

      attr_reader :message, :context, :conversation_history

      def route_with_llm?
        true
      end

      def classify_with_llm
        system_prompt = <<~PROMPT.strip
          You are a router for the PromptTracker assistant.

          Read the current page context and the user's message.
          Decide which specialized assistant (if any) should handle
          the request.

          Return exactly ONE word from this list:
          - "default"
          - "test_runner_wizard"
          - "test_creator_wizard"
          - "dataset_wizard"
          - "agent_creation_wizard"
          - "deployment_wizard"

          Use these guidelines:
          - Use "test_runner_wizard" when the user clearly wants to run
            or execute existing tests for a prompt or prompt version
            (e.g. "run all tests", "execute the tests", "run regression
            tests"). This is most relevant on prompt version pages.
          - Use "test_creator_wizard" when the user wants to create,
            write, or generate new tests for a prompt or prompt version
            (e.g. "write tests for this prompt", "generate tests",
            "create tests", "add tests"). This is most relevant on
            prompt version pages.
          - Use "dataset_wizard" when the user wants to create or set
            up a dataset for a prompt version (e.g. "create a dataset",
            "generate a dataset for this version").
          - Use "agent_creation_wizard" when the user wants to create
            a brand new agent or prompt from scratch (e.g. "create a new prompt",
            "create a new agent", "save this playground as a prompt").
            This is most relevant on prompts list or playground pages.
          - Use "deployment_wizard" when the user wants to deploy a
            prompt version as a live agent
            (e.g. "deploy this as an agent", "deploy this prompt version").
          - Use "default" for all other cases or when you are unsure.

          IMPORTANT: You will receive recent conversation history when
          available. If the conversation shows an ongoing wizard flow
          (e.g. the assistant asked for a name and the user is answering),
          continue routing to the SAME wizard. Only switch to a different
          assistant if the user clearly changes topic.

          Do not add any explanation.
        PROMPT

        history_section = if conversation_history.any?
          lines = conversation_history.filter_map do |msg|
            content = msg[:content].to_s.strip
            next if content.empty?

            case msg[:role]
            when "user" then "User: #{content}"
            when "assistant" then "Assistant: #{content}"
            end
          end

          "Recent conversation:\n#{lines.join("\n")}\n\n"
        else
          ""
        end

        routing_prompt = <<~PROMPT.strip
          Page type: #{context[:page_type] || "none"}
          Prompt version id: #{context[:prompt_version_id] || "none"}

          #{history_section}User message:
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
        Rails.logger.info "[AssistantChatbot::Router] LLM routing label=#{label.inspect} for message=#{message.inspect} context=#{context.inspect}"

        case label
        when "test_runner_wizard"
          :test_runner_wizard
        when "test_creator_wizard"
          :test_creator_wizard
        when "dataset_wizard"
          :dataset_wizard
        when "agent_creation_wizard"
          :agent_creation_wizard
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
