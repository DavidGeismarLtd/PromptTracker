# frozen_string_literal: true

module PromptTracker
  # Orchestrates the assistant chatbot by delegating to specialized
  # wizard assistants for system prompts, tool definitions, and
  # JSON plan extraction.
  #
  # @example Process a user message
  #   result = AssistantChatbotService.call(
  #     message: "Create a prompt called Test",
  #     session_id: "session_123",
  #     context: { page_type: :prompts_list }
  #   )
  #
  class AssistantChatbotService
    Result = Struct.new(:success?, :response, :links, :suggestions, :pending_action, :error, keyword_init: true)

    ASSISTANT_MAP = {
      test_runner_wizard: AssistantChatbot::Assistants::TestRunnerWizardAssistant,
      test_creator_wizard: AssistantChatbot::Assistants::TestCreatorWizardAssistant,
      dataset_wizard: AssistantChatbot::Assistants::DatasetWizardAssistant,
      deployment_wizard: AssistantChatbot::Assistants::DeploymentWizardAssistant,
      agent_creation_wizard: AssistantChatbot::Assistants::AgentCreationWizardAssistant,
      default: AssistantChatbot::Assistants::DefaultAssistant
    }.freeze

    def self.call(message:, session_id:, context: {})
      new(message, session_id, context).call
    end

    def self.execute_function(session_id:, function_name:, arguments:)
      new(nil, session_id, {}).execute_function(function_name, arguments)
    end

    def self.generate_suggestions(context)
      new(nil, nil, context).generate_suggestions
    end

    def initialize(message, session_id, context)
      @message = message
      @session_id = session_id
      @context = context
      @config = PromptTracker.configuration.assistant_chatbot
    end

    def call
      conversation_history = load_conversation_history
      @assistant_mode = resolve_assistant_mode(conversation_history)

      Rails.logger.info "[AssistantChatbot] Request: mode=#{@assistant_mode} message=#{@message.inspect}"

      llm_response = call_llm(assistant.system_prompt, conversation_history, @message)

      if llm_response[:function_call]
        handle_function_call(llm_response[:function_call])
      else
        handle_text_response(llm_response[:text])
      end
    end

    def execute_function(function_name, arguments)
      executor_result = AssistantChatbot::FunctionExecutor.call(
        function_name: function_name,
        arguments: arguments,
        context: @context
      )

      if executor_result.success?
        save_to_conversation(role: "function", content: "Executed #{function_name}")
        save_to_conversation(role: "assistant", content: executor_result.message)

        Result.new(
          success?: true,
          response: executor_result.message,
          links: executor_result.links || [],
          suggestions: generate_suggestions,
          pending_action: nil
        )
      else
        Result.new(
          success?: false,
          response: nil,
          links: [],
          suggestions: [],
          pending_action: nil,
          error: executor_result.error
        )
      end
    end

    def generate_suggestions
      AssistantChatbot::ContextDetector.suggestions_for(@context)
    end

    private

    def assistant
      @assistant ||= begin
        klass = ASSISTANT_MAP[@assistant_mode] || ASSISTANT_MAP[:default]
        klass.new(context: @context)
      end
    end

    def handle_function_call(function_call)
      function_name = function_call[:name]
      arguments = function_call[:arguments]

      save_to_conversation(role: "user", content: @message)

      if AssistantChatbot::Functions::Registry.requires_confirmation?(function_name)
        confirmation_message = build_confirmation_message(function_name, arguments)
        save_to_conversation(role: "assistant", content: confirmation_message)

        Result.new(
          success?: true,
          response: confirmation_message,
          links: [],
          suggestions: [],
          pending_action: {
            function_name: function_name,
            arguments: arguments,
            confirmation_message: confirmation_message
          }
        )
      else
        execute_function(function_name, arguments)
      end
    end

    def handle_text_response(text)
      save_to_conversation(role: "user", content: @message)
      save_to_conversation(role: "assistant", content: text)

      Result.new(
        success?: true,
        response: text,
        links: [],
        suggestions: generate_suggestions,
        pending_action: nil
      )
    end

    def load_conversation_history
      return [] if @session_id.blank?

      messages = Rails.cache.read(conversation_cache_key)
      return [] if messages.nil?

      Array(messages).map do |msg|
        { role: msg[:role], content: msg[:content] }
      end
    end

    def save_to_conversation(role:, content:)
      return if @session_id.blank? || content.blank?

      conversation_settings = @config[:conversation] || {}
      max_messages = conversation_settings[:max_messages] || 50
      ttl = conversation_settings[:ttl] || 24.hours

      key = conversation_cache_key
      messages = Rails.cache.read(key) || []
      messages << { role: role, content: content, timestamp: Time.current.iso8601 }
      messages = messages.last(max_messages)

      Rails.cache.write(key, messages, expires_in: ttl)
    end

    def resolve_assistant_mode(conversation_history)
      AssistantChatbot::Router.assistant_for(
        message: @message,
        context: @context,
        conversation_history: conversation_history
      )
    end

    def conversation_cache_key
      self.class.conversation_cache_key_for(@session_id)
    end

    def self.conversation_cache_key_for(session_id)
      "assistant_chatbot_conversation:#{session_id}"
    end

    def call_llm(system_prompt, history, message)
      model_config = @config[:model] || {}
      model = model_config[:model] || "gpt-4o"
      temperature = model_config[:temperature] || 0.7

      # Build conversation-aware prompt
      history_lines = Array(history).filter_map do |msg|
        content = msg[:content].to_s.strip
        next if content.empty?

        case msg[:role]
        when "user" then "User: #{content}"
        when "assistant" then "Assistant: #{content}"
        end
      end

      prompt = if history_lines.any?
        <<~PROMPT.strip
          Here is the recent conversation between the user and the assistant:

          #{history_lines.join("\n\n")}

          Now the user says:
          User: #{message}
        PROMPT
      else
        message
      end

      # Build tool config from assistant's tool definitions
      tool_defs = assistant.tool_definitions.map(&:deep_stringify_keys)
      tool_config = { "functions" => tool_defs }
      tools = tool_defs.any? ? [ :functions ] : []

      normalized = LlmClients::RubyLlmService.call(
        model: model,
        prompt: prompt,
        system: system_prompt,
        tools: tools,
        tool_config: tool_config,
        temperature: temperature
      )

      # For wizard assistants, try to extract a JSON plan from the text
      function_call = assistant.extract_function_call(normalized.text)
      return function_call if function_call

      # For default assistant, surface tool calls from the LLM
      if normalized.tool_calls.present?
        tool_call = normalized.tool_calls.last
        args = (tool_call[:arguments] || {}).with_indifferent_access

        {
          function_call: {
            name: tool_call[:function_name],
            arguments: args
          }
        }
      else
        { text: normalized.text }
      end
    end

    def build_confirmation_message(function_name, arguments)
      "🔧 I'll #{function_name.humanize.downcase} with these parameters:\n" \
        "#{arguments.inspect}\n\n" \
        "Do you want me to proceed?"
    end
  end
end
