# frozen_string_literal: true

module PromptTracker
  # Service for the global assistant chatbot.
  #
  # Handles message processing, LLM interaction, and function execution.
  # Reuses the AgentConversation model for conversation storage but with
  # a virtual "assistant" deployed agent scope.
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

    def self.call(message:, session_id:, context: {})
      new(message, session_id, context).call
    end

    def self.execute_function(session_id:, function_name:, arguments:)
      Rails.logger.info "[AssistantChatbot] Class method execute_function called: #{function_name}"
      new(nil, session_id, {}).execute_function(function_name, arguments)
    end

    def self.generate_suggestions(context)
      Rails.logger.debug "[AssistantChatbot] Class method generate_suggestions called"
      new(nil, nil, context).generate_suggestions
    end

    def initialize(message, session_id, context)
      @message = message
      @session_id = session_id
      @context = context
      @config = PromptTracker.configuration.assistant_chatbot
    end

    def call
      Rails.logger.info "[AssistantChatbot] ═══ NEW REQUEST ═══"
      Rails.logger.info "[AssistantChatbot] Session ID: #{@session_id}"
      Rails.logger.info "[AssistantChatbot] User message: #{@message.inspect}"
      Rails.logger.info "[AssistantChatbot] Context: #{@context.inspect}"

        # 1. Load conversation history
        conversation_history = load_conversation_history
      Rails.logger.info "[AssistantChatbot] Loaded #{conversation_history.length} messages from history"
      Rails.logger.debug "[AssistantChatbot] History preview: #{conversation_history.first(3).inspect}..." if conversation_history.any?

        # 2. Build system prompt with context
        system_prompt = build_system_prompt
      Rails.logger.debug "[AssistantChatbot] System prompt length: #{system_prompt.length} chars"

      # 3. Call LLM with conversation history + current message
      Rails.logger.info "[AssistantChatbot] Calling LLM..."
        llm_response = call_llm(system_prompt, conversation_history, @message)
      Rails.logger.info "[AssistantChatbot] LLM response type: #{llm_response.keys.inspect}"

      # 4. Check if LLM wants to execute a function
      if llm_response[:function_call]
        # Function call detected - determine if it needs confirmation
        function_name = llm_response[:function_call][:name]
        arguments = llm_response[:function_call][:arguments]

        Rails.logger.info "[AssistantChatbot] 🔧 Function call detected: #{function_name}"
        Rails.logger.info "[AssistantChatbot] Arguments: #{arguments.inspect}"

          # Always record the user's request
          save_to_conversation(role: "user", content: @message)

        if requires_confirmation?(function_name)
          Rails.logger.info "[AssistantChatbot] ⚠️  Function requires confirmation - returning pending_action"

            # Return pending action for confirmation
            confirmation_message = build_confirmation_message(function_name, arguments)
            save_to_conversation(role: "assistant", content: confirmation_message)

          Rails.logger.info "[AssistantChatbot] Saved user + assistant confirmation to history"

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
          Rails.logger.info "[AssistantChatbot] ✅ Function does NOT require confirmation - executing immediately"
          # Execute query function immediately
          execution_result = execute_function(function_name, arguments)
          execution_result
        end
      else
        Rails.logger.info "[AssistantChatbot] 💬 Normal text response (no function call)"
        Rails.logger.debug "[AssistantChatbot] Response text: #{llm_response[:text].inspect}"

          # Normal text response
          save_to_conversation(role: "user", content: @message)
          save_to_conversation(role: "assistant", content: llm_response[:text])

        Rails.logger.info "[AssistantChatbot] Saved user + assistant messages to history"

        Result.new(
          success?: true,
          response: llm_response[:text],
          links: [],
          suggestions: generate_suggestions,
          pending_action: nil
        )
      end
    rescue => e
      Rails.logger.error("[AssistantChatbot] ❌ ERROR: #{e.message}")
      Rails.logger.error("[AssistantChatbot] Backtrace:\n#{e.backtrace.first(10).join("\n")}")
      Result.new(
        success?: false,
        response: nil,
        links: [],
        suggestions: [],
        pending_action: nil,
        error: "Sorry, I encountered an error: #{e.message}"
      )
    end

    def execute_function(function_name, arguments)
      Rails.logger.info "[AssistantChatbot] ═══ EXECUTING FUNCTION ═══"
      Rails.logger.info "[AssistantChatbot] Function: #{function_name}"
      Rails.logger.info "[AssistantChatbot] Arguments: #{arguments.inspect}"

      # Execute the function via function executor
      executor_result = AssistantChatbot::FunctionExecutor.call(
        function_name: function_name,
        arguments: arguments,
        context: @context
      )

      Rails.logger.info "[AssistantChatbot] Executor result success?: #{executor_result.success?}"

      if executor_result.success?
        Rails.logger.info "[AssistantChatbot] ✅ Function executed successfully"
        Rails.logger.debug "[AssistantChatbot] Result message: #{executor_result.message.inspect}"
        Rails.logger.debug "[AssistantChatbot] Links: #{executor_result.links.inspect}"

        # Save to conversation
        save_to_conversation(role: "function", content: "Executed #{function_name}")
        save_to_conversation(role: "assistant", content: executor_result.message)

        # Update conversation context with created entities
        update_conversation_context(function_name, executor_result.entities_created || {})

        Result.new(
          success?: true,
          response: executor_result.message,
          links: executor_result.links || [],
          suggestions: generate_suggestions,
          pending_action: nil
        )
      else
        Rails.logger.error "[AssistantChatbot] ❌ Function execution failed: #{executor_result.error}"

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
      Rails.logger.debug "[AssistantChatbot] Generating suggestions for context: #{@context.inspect}"

      # Generate context-aware suggestions based on current page
      suggestions = AssistantChatbot::ContextDetector.suggestions_for(@context)

        Rails.logger.debug "[AssistantChatbot] Generated #{suggestions&.length || 0} suggestions"
        Rails.logger.debug "[AssistantChatbot] Suggestions: #{suggestions.inspect}"

        suggestions
    end

    private

    def load_conversation_history
        return [] if @session_id.blank?

        key = conversation_cache_key
      Rails.logger.debug "[AssistantChatbot] Loading conversation from cache key: #{key}"

        messages = Rails.cache.read(key)

      if messages.nil?
        Rails.logger.debug "[AssistantChatbot] No cached conversation found - starting fresh"
        return []
      end

      Rails.logger.debug "[AssistantChatbot] Found #{messages.length} cached messages"

        Array(messages).map do |msg|
          {
            role: (msg[:role] || msg["role"]),
            content: (msg[:content] || msg["content"])
          }
        end
    end

    def save_to_conversation(role:, content:)
        return if @session_id.blank? || content.blank?

      Rails.logger.debug "[AssistantChatbot] Saving message to conversation: role=#{role}, content_length=#{content.length}"

        conversation_settings = @config[:conversation] || {}
        max_messages = conversation_settings[:max_messages] || 50
        ttl = conversation_settings[:ttl] || 24.hours

        key = conversation_cache_key
        messages = Rails.cache.read(key) || []

      previous_count = messages.length

        messages << {
          role: role,
          content: content,
          timestamp: Time.current.iso8601
        }
        messages = messages.last(max_messages)

      Rails.logger.debug "[AssistantChatbot] Conversation now has #{messages.length} messages (was #{previous_count}, max: #{max_messages})"
      Rails.logger.debug "[AssistantChatbot] Writing to cache with TTL: #{ttl}"

        Rails.cache.write(key, messages, expires_in: ttl)
    end

    def update_conversation_context(action, entities)
      # Update conversation metadata with created entities
      # TODO: Implement context tracking
    end

      def conversation_cache_key
        self.class.conversation_cache_key_for(@session_id)
      end

      def self.conversation_cache_key_for(session_id)
        "assistant_chatbot_conversation:#{session_id}"
      end

      def build_system_prompt
        context_info = if @context[:page_type]
          case @context[:page_type]
          when :prompt_version_detail
            "\n\nCurrent context: Viewing PromptVersion ##{@context[:prompt_version_id]}"
          when :prompts_list
            "\n\nCurrent context: Browsing prompts list"
          else
            ""
          end
        else
          ""
        end

        Rails.logger.debug("[AssistantChatbot] build_system_prompt page_type=#{@context[:page_type]} prompt_version_id=#{@context[:prompt_version_id].inspect}")

        model_suggestions = suggested_models_for_prompt_creation
        model_suggestions_line = if model_suggestions.any?
          "          - When asking about the model in step 4, you can suggest one of these models when appropriate: #{model_suggestions.join(', ')}\n"
        else
          ""
        end

          system_prompt = <<~PROMPT.strip
		        You are the PromptTracker Assistant, an expert AI helper for testing and deploying LLM prompts.

		        Your capabilities:
		        - Create prompts and versions with model configuration
		        - Generate comprehensive test suites using AI
		        - Run tests and analyze results
		        - Provide information about prompts, versions, and tests
		        - Search and discover existing prompts

		        Conversation format and memory:
		        - The user prompt will include the recent conversation as plain text in this format:
		          User: ...
		          Assistant: ...
		        - Treat this as the chat history and continue the conversation naturally.
		        - Use information the user already provided earlier instead of asking again.

		        Wizard behavior for creating prompts:
		        - When the user wants to create a new prompt, act as a step-by-step setup wizard.
		        - Collect the following fields one by one, with a clear question for each step:
		          1) Prompt name (required)
		          2) Short description (optional - just ask for a brief explanation of what the prompt should do; we'll enhance it with AI later so keep it short)
	          3) System prompt concept (required - ask the user to briefly describe what the AI assistant should do; this is a short concept, not the final long system prompt)
	          4) Model to use (optional - default gpt-4o if the user does not specify)
	          5) Temperature (optional - default 0.7 if the user does not specify)
#{model_suggestions_line}	        - Do NOT ask the user to provide any user-facing prompt template; the backend will use a sensible default user message for new prompts.
	        - Use previous answers from the conversation to avoid repeating questions.
		        - IMPORTANT: Do NOT try to fully write the final system prompt yourself. Just collect a clear, concise concept from the user in step 3 and pass it as `system_prompt_concept` when calling `create_prompt`. The backend will enhance it into a detailed, professional system prompt using AI.
		        - Only once you have at least the required fields (name and system_prompt_concept), you may call the `create_prompt` function.
		        - Before calling `create_prompt`, briefly summarize the final configuration you plan to create.

		        Wizard behavior for creating datasets:
		        - When the user wants to create a dataset for a prompt, act as a STRICT step-by-step wizard.
		        - CRITICAL: Ask ONLY ONE question at a time. Never ask about multiple fields in the same message.
		        - First, make sure you know which PromptVersion the dataset should belong to:
		          * If the current page context includes prompt_version_id, you MUST use that value as the prompt_version_id.
		          * Otherwise, ask the user which prompt/version to use or help them find it.
		        - Always follow this exact order of questions, and only move to the next step after the user has answered the current one:
		          1) Dataset type (single_turn or conversational - default to single_turn if the user is unsure)
		          2) Short dataset purpose / description (optional - a brief explanation of what scenarios this dataset should cover; it will be enhanced with AI)
		          3) Dataset name (optional - you can suggest a short rough name; it will be enhanced with AI)
		          4) Whether the user wants you to auto-generate rows with AI after creation
		          5) If yes, how many rows to generate (count, e.g. 10-50) and any extra instructions for the rows
		        - Each time you reply during the dataset wizard, your entire message MUST contain exactly ONE concrete question (optionally with a 1–2 sentence explanation), not a list of several questions.
		        - When calling the `create_dataset` function, pass the raw values you collected:
		          * prompt_version_id
		          * dataset_type
		          * description and name as provided by the user (even if rough)
		          * count and instructions for row generation (if requested)
		        - Do NOT try to pre-generate test rows yourself; the backend will handle row generation and schema validation.
		        - Before calling `create_dataset`, briefly summarize what you are about to create and how many rows (if any) will be generated.

		        Guidelines:
		        - Be concise and helpful
		        - Use emojis to make responses more engaging
		        - Always confirm before performing destructive actions
		        - Provide direct links to resources
		        - Suggest follow-up actions when appropriate#{context_info}
          PROMPT

        Rails.logger.debug("[AssistantChatbot] System prompt length: #{system_prompt.length} chars")
        Rails.logger.debug("[AssistantChatbot] System prompt preview: #{system_prompt[0..400]}...") if system_prompt.length > 400

        system_prompt
    end

    def call_llm(system_prompt, history, message)
      Rails.logger.debug "[AssistantChatbot] ═══ CALL_LLM ═══"

      model_config = @config[:model] || {}
      model = model_config[:model] || "gpt-4o"
      temperature = model_config[:temperature] || 0.7

      Rails.logger.debug "[AssistantChatbot] Model: #{model}, Temperature: #{temperature}"

        # Build conversation-aware prompt
        history_lines = Array(history).map do |msg|
          role = msg[:role]
          content = msg[:content].to_s.strip
          next if content.empty?

          case role
          when "user"
            "User: #{content}"
          when "assistant"
            "Assistant: #{content}"
          else
            nil
          end
        end.compact

      Rails.logger.debug "[AssistantChatbot] Built #{history_lines.length} history lines from #{history.length} history messages"

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

      Rails.logger.debug "[AssistantChatbot] Final prompt length: #{prompt.length} chars"
      Rails.logger.debug "[AssistantChatbot] Final prompt preview: #{prompt[0..200]}..." if prompt.length > 200

        # Build tool config for RubyLlmService + DynamicToolBuilder
        # Convert to string keys as DynamicToolBuilder expects string keys
        tool_defs = build_tool_definitions.map(&:deep_stringify_keys)
        Rails.logger.info "[AssistantChatbot] Built #{tool_defs.length} tool definitions: #{tool_defs.map { |t| t['name'] }.inspect}"
        tool_config = { "functions" => tool_defs }

        # Use unified RubyLlmService so we benefit from existing normalization logic
        # and RubyLLM's native tool handling. We intentionally do NOT pass a
        # function_executor here so that tools are executed with mock outputs
        # only – real side effects happen later via execute_function after
        # explicit user confirmation.
        tools = tool_defs.any? ? [ :functions ] : []

      Rails.logger.info "[AssistantChatbot] Calling RubyLlmService with tools: #{tools.inspect}"

        normalized = LlmClients::RubyLlmService.call(
          model: model,
          prompt: prompt,
          system: system_prompt,
          tools: tools,
          tool_config: tool_config,
          temperature: temperature
        )

      Rails.logger.info "[AssistantChatbot] RubyLlmService returned successfully"
        Rails.logger.info "[AssistantChatbot] Normalized response - text length: #{normalized.text&.length || 0}, tool_calls: #{normalized.tool_calls.length}"

        # If the model issued any tool calls, surface the LAST one as a
        # pending function_call for confirmation. Arguments are returned as a
        # hash and we convert to indifferent access for convenience.
        if normalized.tool_calls.present?
        Rails.logger.info "[AssistantChatbot] Found #{normalized.tool_calls.length} tool call(s), using last one"

          tool_call = normalized.tool_calls.last
        Rails.logger.debug "[AssistantChatbot] Tool call details: #{tool_call.inspect}"

          args = (tool_call[:arguments] || {}).with_indifferent_access

        Rails.logger.info "[AssistantChatbot] Returning function_call: #{tool_call[:function_name]}"

          {
            function_call: {
              name: tool_call[:function_name],
              arguments: args
            }
          }
        else
        Rails.logger.info "[AssistantChatbot] No tool calls - returning text response"
          { text: normalized.text }
        end
      end

    def build_tool_definitions
      [
        {
          name: "create_prompt",
            description: "Create a new prompt from raw user inputs. The backend will enhance the description and system prompt concept with AI.",
          parameters: {
            type: "object",
            properties: {
              name: {
                type: "string",
                description: "Name of the prompt (e.g., 'Customer Support Agent')"
              },
              description: {
                type: "string",
                  description: "Short description of the prompt's purpose (optional - will be enhanced with AI)."
              },
                system_prompt_concept: {
                type: "string",
                  description: "Brief concept of what the AI assistant should do. This is a short description, not the full system prompt. The backend will expand it into a detailed, professional system prompt."
                },
                model: {
                type: "string",
                description: "Model to use (optional, default: gpt-4o)",
                enum: [ "gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022" ]
              },
              temperature: {
                type: "number",
                description: "Temperature (optional, 0.0 to 2.0, default: 0.7)"
              }
            },
              required: [ "name", "system_prompt_concept" ]
          }
        },
          {
            name: "create_dataset",
            description: "Create a new dataset for a prompt version and optionally generate dataset rows with AI.",
            parameters: {
              type: "object",
              properties: {
                prompt_version_id: {
                  type: "integer",
                  description: "ID of the prompt version this dataset belongs to"
                },
                name: {
                  type: "string",
                  description: "Short raw name for the dataset (optional - will be enhanced with AI)."
                },
                description: {
                  type: "string",
                  description: "Short description / purpose for the dataset (optional - will be enhanced with AI)."
                },
                dataset_type: {
                  type: "string",
                  description: "Type of dataset: 'single_turn' or 'conversational' (default: 'single_turn').",
                  enum: [ "single_turn", "conversational" ]
                },
                count: {
                  type: "integer",
                  description: "Number of rows to generate with AI after creating the dataset (optional, 1-100)."
                },
                instructions: {
                  type: "string",
                  description: "Extra instructions for how the AI should generate dataset rows (optional)."
                },
                model: {
                  type: "string",
                  description: "Optional model override for dataset row generation."
                }
              },
              required: [ "prompt_version_id" ]
            }
          },
        {
          name: "generate_tests",
          description: "Generate AI-powered tests for a PromptVersion",
          parameters: {
            type: "object",
            properties: {
              prompt_version_id: {
                type: "integer",
                description: "ID of the prompt version to generate tests for"
              },
              count: {
                type: "integer",
                description: "Number of tests to generate (1-10, default: 5)"
              },
              instructions: {
                type: "string",
                description: "Custom instructions for test generation (optional)"
              }
            },
            required: [ "prompt_version_id" ]
          }
        },
        {
          name: "run_tests",
          description: "Run tests for a PromptVersion",
          parameters: {
            type: "object",
            properties: {
              prompt_version_id: {
                type: "integer",
                description: "ID of the prompt version"
              },
              test_ids: {
                type: "array",
                items: { type: "integer" },
                description: "Specific test IDs to run (optional, runs all if omitted)"
              },
              dataset_id: {
                type: "integer",
                description: "Dataset to run tests against (optional)"
              }
            },
            required: [ "prompt_version_id" ]
          }
        },
        {
          name: "get_prompt_version_info",
          description: "Get detailed information about a PromptVersion including model config, status, and test statistics",
          parameters: {
            type: "object",
            properties: {
              prompt_version_id: {
                type: "integer",
                description: "ID of the prompt version"
              }
            },
            required: [ "prompt_version_id" ]
          }
        },
        {
          name: "get_tests_summary",
          description: "Get a summary of all tests for a PromptVersion, including pass/fail statistics and recent runs",
          parameters: {
            type: "object",
            properties: {
              prompt_version_id: {
                type: "integer",
                description: "ID of the prompt version"
              }
            },
            required: [ "prompt_version_id" ]
          }
        },
        {
          name: "search_prompts",
          description: "Search for prompts by name or description",
          parameters: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Search query string"
              },
              limit: {
                type: "integer",
                description: "Maximum number of results (default: 5, max: 20)"
              }
            },
            required: [ "query" ]
          }
        }
      ]
    end

    def requires_confirmation?(function_name)
        # Action functions require confirmation
        action_functions = %w[create_prompt create_dataset generate_tests run_tests]
      requires = action_functions.include?(function_name)

      Rails.logger.debug "[AssistantChatbot] requires_confirmation?(#{function_name}) => #{requires}"

      requires
    end

      def suggested_models_for_prompt_creation
        model_config = @config[:model] || {}
        provider = (model_config[:provider] || :openai).to_sym
        api = (model_config[:api] || PromptTracker.configuration.default_api_for_provider(provider)).to_sym

        models = PromptTracker.configuration.models_for_api(provider, api)
        models.map { |model| model[:id] }.compact.first(5)
      end

      def build_confirmation_message(function_name, arguments)
      Rails.logger.debug "[AssistantChatbot] Building confirmation message for: #{function_name}"

        "🔧 I'll #{function_name.humanize.downcase} with these parameters:\n" \
          "#{arguments.inspect}\n\n" \
          "Do you want me to proceed?"
      end
  end
end
