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
        @assistant_mode = AssistantChatbot::Router.assistant_for(message: message, context: context)
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
            case assistant_mode
            when :test_runner_wizard
              Rails.logger.debug("[AssistantChatbot] Using TestRunnerWizardAssistant system prompt")
              return test_runner_wizard_assistant.system_prompt
            when :test_creator_wizard
              Rails.logger.debug("[AssistantChatbot] Using TestCreatorWizardAssistant system prompt")
              return test_creator_wizard_assistant.system_prompt
            when :dataset_wizard
              Rails.logger.debug("[AssistantChatbot] Using DatasetWizardAssistant system prompt")
              return dataset_wizard_assistant.system_prompt
            when :deployment_wizard
              Rails.logger.debug("[AssistantChatbot] Using DeploymentWizardAssistant system prompt")
              return deployment_wizard_assistant.system_prompt
            when :prompt_creation_wizard
              Rails.logger.debug("[AssistantChatbot] Using PromptCreationWizardAssistant system prompt")
              return prompt_creation_wizard_assistant.system_prompt
            end

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
          model_suggestions_block = if model_suggestions.any?
            bullet_lines = model_suggestions.map { |model| "          • #{model}" }.join("\n")

            <<~BLOCK

		          **Recommended models for this workspace:**
		  #{bullet_lines}

		          When you reach step 4 of the prompt creation wizard, you MUST:
		          - Show these models as a short bullet list
		          - Clearly highlight which one is the default (usually the first)
		          - Ask the user to pick one, or confirm using the default
            BLOCK
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
	        		  2) Short description of what the assistant should do (ask once; keep it short – it will be enhanced with AI later).
	        		  3) Model to use (optional - default gpt-4o if the user does not specify). When you reach this step, you MUST show the recommended models block (if present) and ask the user to choose.
	        		  4) Temperature (optional - default 0.7 if the user does not specify)
			  #{model_suggestions_block}
	        		- Do NOT ask the user explicitly for a separate "system prompt" or "system prompt concept" question. You will derive it yourself.
	        		- Use previous answers from the conversation to avoid repeating questions.
	        		- IMPORTANT: When calling `create_prompt`, you MUST derive a concise `system_prompt_concept` from the prompt name, the short description, and any earlier conversation context. Do NOT ask the user for this field directly – generate it yourself as a short, clear description of the assistant's behavior. The backend will then enhance it into a detailed, professional system prompt using AI.
	        		- Only once you have at least the required fields (name and an internally derived system_prompt_concept), you may call the `create_prompt` function.
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

		        Wizard behavior for running tests:
		        - When the user wants to run tests for a prompt version, act as a STRICT multi-step wizard.
		        - CRITICAL: Ask ONLY ONE clear question at a time in your replies.
		        - Always make sure you know which PromptVersion to use:
		          * If the current page context includes prompt_version_id, you MUST use that value.
		          * Otherwise, ask the user which prompt/version to use or help them find it.
		        - Step 1: Decide which tests to run
		          * First, ask the user whether they want to run ALL enabled tests or ONLY a specific subset.
		          * Your first reply in this wizard MUST present these two options as a short bullet list:
		            - "Run all tests"
		            - "Run a specific test"
		            followed by a question asking them to choose one.
		          * If the user clearly says they want to "run all tests" (or similar), treat that as choosing ALL and move on without listing the tests.
		          * Only if the user chooses to run specific tests, or explicitly asks what tests exist, should you call the `available_tests_for_prompt_version` function to list them.
		          * The question should be explicit, e.g. "Do you want to run all enabled tests, or only specific tests? Reply with 'all' or a list of IDs like 12, 15."
		        - Step 2: Choose data source (dataset vs custom variables)
		          * Call the `available_datasets_for_prompt_version` function to see existing datasets (if any).
		          * Then ask the user whether to run tests against one of these datasets or with a single set of custom variables.
		          * The question should be explicit, e.g. "Do you want to run using a dataset (reply with a dataset ID) or run once with custom variables (reply 'custom')?"
		        - Step 3A: If the user chooses a dataset
		          * Confirm which dataset ID to use.
		          * Once you know the tests to run and the dataset_id, briefly summarize what will happen and THEN call `run_tests` with prompt_version_id, any specific test_ids (if the user chose a subset), and dataset_id.
		        - Step 3B: If the user chooses custom variables (no dataset)
		          * First, ask whether they want a single-turn response or a simulated conversation.
		          * For simulated conversations, remind them to provide an interlocutor_simulation_prompt and optionally max_turns.
		          * Using the variable names from the variables section you saw earlier, ask the user for values for each variable that is relevant. You can collect several variables in a single message, but your question must still be clearly structured.
		          * Once you have all necessary variables, summarize the configuration (tests + custom variables + single vs conversational) and THEN call `run_tests` with prompt_version_id, any specific test_ids, and a custom_variables object.
		        - IMPORTANT: Never call `run_tests` until you have:
		          * Decided which tests to run (all or specific IDs), AND
		          * Chosen between dataset vs custom variables, AND
		          * For custom variables: collected values for each required variable.

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
          raw_tool_defs =
              if test_runner_wizard_mode?
                build_test_runner_wizard_tool_definitions
              elsif test_creator_wizard_mode?
                build_test_creator_wizard_tool_definitions
              elsif dataset_wizard_mode?
                build_dataset_wizard_tool_definitions
              elsif deployment_wizard_mode?
                build_deployment_wizard_tool_definitions
              elsif prompt_creation_wizard_mode?
                build_prompt_creation_wizard_tool_definitions
              else
                build_tool_definitions
              end

          tool_defs = raw_tool_defs.map(&:deep_stringify_keys)
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

            if test_runner_wizard_mode? || test_creator_wizard_mode? || dataset_wizard_mode? || deployment_wizard_mode? || prompt_creation_wizard_mode?
              function_call =
                if test_runner_wizard_mode?
                  extract_run_tests_function_call_from_text(normalized.text)
                elsif test_creator_wizard_mode?
                  extract_generate_tests_function_call_from_text(normalized.text)
                elsif dataset_wizard_mode?
                  extract_create_dataset_function_call_from_text(normalized.text)
                elsif deployment_wizard_mode?
                  extract_deploy_agent_function_call_from_text(normalized.text)
                elsif prompt_creation_wizard_mode?
                  extract_create_prompt_function_call_from_text(normalized.text)
                end

              return function_call if function_call

              Rails.logger.info "[AssistantChatbot] Wizard response without JSON plan - returning text"
              return { text: normalized.text }
            end

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
              description: "Run tests for a PromptVersion using either datasets or custom variables.",
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
                run_mode: {
                  type: "string",
                  description: "How to run the tests: 'dataset' to run against a dataset, or 'custom' to run once with custom variables.",
                  enum: [ "dataset", "custom" ]
                },
              dataset_id: {
                type: "integer",
                    description: "Dataset to run tests against (required when run_mode is 'dataset')."
                  },
                  execution_mode: {
                    type: "string",
                    description: "Execution mode for custom runs: 'single' for a single-turn response or 'conversation' for a multi-turn simulated conversation (default: 'single').",
                    enum: [ "single", "conversation" ]
                  },
                  custom_variables: {
                    type: "object",
                    description: "Custom variables to use for a single run when not using a dataset. Keys should match variable names from the prompt version's variables_schema. For conversational runs, MUST include interlocutor_simulation_prompt and MAY include max_turns."
                }
              },
              required: [ "prompt_version_id", "run_mode" ]
            }
          },
          {
            name: "deploy_agent",
            description: "Deploy a PromptVersion as a conversational or task agent.",
            parameters: {
              type: "object",
              properties: {
                prompt_version_id: {
                  type: "integer",
                  description: "ID of the prompt version to deploy"
                },
                name: {
                  type: "string",
                  description: "Optional name for the deployed agent (e.g., 'Support Agent')"
                },
                agent_type: {
                  type: "string",
                  description: "Type of agent to create: 'conversational' (chat UI + API) or 'task' (background task agent).",
                  enum: [ "conversational", "task" ]
                },
                deployment_config: {
                  type: "object",
                  description: "Configuration for conversational agents.",
                  properties: {
                    conversation_ttl: {
                      type: "integer",
                      description: "How long to keep conversations alive in seconds (e.g., 3600)."
                    },
                    enable_web_ui: {
                      type: "boolean",
                      description: "Whether to enable the public web chat UI."
                    },
                    auth: {
                      type: "object",
                      description: "Authentication configuration (optional).",
                      properties: {
                        type: {
                          type: "string",
                          description: "Auth type identifier (implementation-specific)."
                        }
                      }
                    },
                    rate_limit: {
                      type: "object",
                      description: "Optional rate limiting configuration.",
                      properties: {
                        requests_per_minute: {
                          type: "integer",
                          description: "Maximum number of requests per minute for this agent."
                        }
                      }
                    },
                    cors: {
                      type: "object",
                      description: "Optional CORS configuration for browser clients.",
                      properties: {
                        allowed_origins: {
                          type: "array",
                          items: { type: "string" },
                          description: "List of allowed origins (e.g., ['https://example.com'])."
                        }
                      }
                    }
                  }
                },
                task_config: {
                  type: "object",
                  description: "Configuration for task agents.",
                  properties: {
                    initial_prompt: {
                      type: "string",
                      description: "Instruction describing the task the agent should perform."
                    },
                    variables: {
                      type: "object",
                      description: "Optional default variables object for the task."
                    },
                    execution: {
                      type: "object",
                      description: "Execution configuration (iterations, timeouts, retries).",
                      properties: {
                        max_iterations: {
                          type: "integer",
                          description: "Maximum number of agent iterations (default 5)."
                        },
                        timeout_seconds: {
                          type: "integer",
                          description: "Maximum time allowed for the task in seconds (default 3600)."
                        },
                        retry_on_failure: {
                          type: "boolean",
                          description: "Whether to retry the task on failure (default false)."
                        },
                        max_retries: {
                          type: "integer",
                          description: "Maximum number of retries (default 3)."
                        }
                      }
                    },
                    planning: {
                      type: "object",
                      description: "Optional planning configuration.",
                      properties: {
                        enabled: {
                          type: "boolean",
                          description: "Whether explicit planning is enabled."
                        },
                        max_steps: {
                          type: "integer",
                          description: "Maximum number of planning steps (default 20)."
                        },
                        allow_plan_modifications: {
                          type: "boolean",
                          description: "Whether the agent may modify its plan as it executes."
                        }
                      }
                    },
                    completion_criteria: {
                      type: "object",
                      description: "Optional completion criteria.",
                      properties: {
                        type: {
                          type: "string",
                          description: "Completion criteria type identifier (implementation-specific)."
                        }
                      }
                    }
                  }
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
            name: "available_tests_for_prompt_version",
            description: "List enabled tests for a PromptVersion to help choose which tests to run.",
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
            name: "available_datasets_for_prompt_version",
            description: "List datasets for a PromptVersion to help choose between dataset runs and custom variables.",
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

        def build_test_runner_wizard_tool_definitions
          # Reuse the full tool definitions but restrict to read-only helpers
          # that are useful during the test runner wizard. The run_tests action
          # itself is triggered via a JSON plan, not exposed as a direct
          # tool to the LLM.
          allowed = %w[
            get_prompt_version_info
            get_tests_summary
            available_tests_for_prompt_version
            available_datasets_for_prompt_version
          ]

          build_tool_definitions.select do |tool|
            allowed.include?(tool[:name])
          end
        end

        def build_test_creator_wizard_tool_definitions
          # Test creator wizard needs to understand the prompt to generate
          # appropriate tests. The generate_tests action is triggered via
          # a JSON plan, not exposed as a direct tool to the LLM.
          allowed = %w[
            get_prompt_version_info
          ]

          build_tool_definitions.select do |tool|
            allowed.include?(tool[:name])
          end
        end

        def build_dataset_wizard_tool_definitions
          # Dataset wizard may call read-only helpers for context, but not create_dataset directly.
          allowed = %w[
            get_prompt_version_info
            available_datasets_for_prompt_version
          ]

          build_tool_definitions.select do |tool|
            allowed.include?(tool[:name])
          end
        end

        def build_deployment_wizard_tool_definitions
          # Deployment wizard can inspect prompt and test context but must NOT call deploy_agent directly.
          allowed = %w[
            get_prompt_version_info
            get_tests_summary
            available_tests_for_prompt_version
            available_datasets_for_prompt_version
          ]

          build_tool_definitions.select do |tool|
            allowed.include?(tool[:name])
          end
        end

        def build_prompt_creation_wizard_tool_definitions
          # Prompt creation wizard can inspect existing prompts or prompt versions
          # but must NOT call create_prompt directly.
          allowed = %w[
            get_prompt_version_info
            get_tests_summary
            search_prompts
          ]

          build_tool_definitions.select do |tool|
            allowed.include?(tool[:name])
          end
        end

    def requires_confirmation?(function_name)
          # Action functions require confirmation
          action_functions = %w[create_prompt create_dataset generate_tests run_tests deploy_agent]
      requires = action_functions.include?(function_name)

      Rails.logger.debug "[AssistantChatbot] requires_confirmation?(#{function_name}) => #{requires}"

      requires
    end

          PREFERRED_CHAT_MODELS_FOR_PROMPT_CREATION = {
            openai: %w[gpt-4.1 gpt-4o gpt-4o-mini gpt-4.1-mini]
          }.freeze

          def suggested_models_for_prompt_creation
            providers = PromptTracker.configuration.enabled_providers

            suggestions = providers.each_with_object([]) do |provider, acc|
              api = PromptTracker.configuration.default_api_for_provider(provider)
              next unless api

              models = PromptTracker.configuration.models_for_api(provider, api)
              next if models.empty?

              provider_label = PromptTracker.configuration.provider_name(provider)
              chosen_model = default_model_for_prompt_creation(provider, models)
              next unless chosen_model

              acc << "#{provider_label}: #{chosen_model[:id]}"
            end

            return suggestions if suggestions.any?

            [
              "OpenAI: gpt-4.1 (latest balanced quality & cost)",
              "Anthropic: claude-3.5-sonnet (latest for long, complex tasks)"
            ]
          end

          def default_model_for_prompt_creation(provider, models)
            preferred_ids = PREFERRED_CHAT_MODELS_FOR_PROMPT_CREATION[provider.to_sym] || []

            preferred_ids.each do |model_id|
              model = models.find { |m| m[:id] == model_id }
              return model if model
            end

            # Fallback: keep existing behavior of choosing the last model
            models.last
          end

      def build_confirmation_message(function_name, arguments)
      Rails.logger.debug "[AssistantChatbot] Building confirmation message for: #{function_name}"

        "🔧 I'll #{function_name.humanize.downcase} with these parameters:\n" \
          "#{arguments.inspect}\n\n" \
          "Do you want me to proceed?"
      end

          def assistant_mode
            @assistant_mode || :default
          end

          def test_runner_wizard_mode?
            assistant_mode == :test_runner_wizard
          end

          def test_creator_wizard_mode?
            assistant_mode == :test_creator_wizard
          end

          def dataset_wizard_mode?
            assistant_mode == :dataset_wizard
          end

          def deployment_wizard_mode?
            assistant_mode == :deployment_wizard
          end

          def prompt_creation_wizard_mode?
            assistant_mode == :prompt_creation_wizard
          end

          def test_runner_wizard_assistant
            @test_runner_wizard_assistant ||= AssistantChatbot::Assistants::TestRunnerWizardAssistant.new(context: @context)
          end

          def test_creator_wizard_assistant
            @test_creator_wizard_assistant ||= AssistantChatbot::Assistants::TestCreatorWizardAssistant.new(context: @context)
          end

          def dataset_wizard_assistant
            @dataset_wizard_assistant ||= AssistantChatbot::Assistants::DatasetWizardAssistant.new(context: @context)
          end

          def deployment_wizard_assistant
            @deployment_wizard_assistant ||= AssistantChatbot::Assistants::DeploymentWizardAssistant.new(context: @context)
          end

          def prompt_creation_wizard_assistant
            @prompt_creation_wizard_assistant ||= AssistantChatbot::Assistants::PromptCreationWizardAssistant.new(context: @context)
          end

          def extract_run_tests_function_call_from_text(text)
          return nil if text.blank?

          stripped = text.strip

          begin
            data = JSON.parse(stripped)
          rescue JSON::ParserError
            Rails.logger.debug "[AssistantChatbot] Test wizard response not valid JSON plan"
            return nil
          end

          unless data.is_a?(Hash)
            Rails.logger.debug "[AssistantChatbot] JSON plan is not an object"
            return nil
          end

          # Require at least the core run_tests arguments
          unless data.key?("prompt_version_id") && data.key?("run_mode")
            Rails.logger.debug "[AssistantChatbot] JSON plan missing required keys"
            return nil
          end

          args = data.deep_symbolize_keys.with_indifferent_access

          Rails.logger.info "[AssistantChatbot] Parsed run_tests JSON plan: #{args.inspect}"

          {
            function_call: {
              name: "run_tests",
              arguments: args
            }
          }
        end

          def extract_generate_tests_function_call_from_text(text)
            return nil if text.blank?

            stripped = text.strip

            begin
              data = JSON.parse(stripped)
            rescue JSON::ParserError
              Rails.logger.debug "[AssistantChatbot] Test creator wizard response not valid JSON plan"
              return nil
            end

            unless data.is_a?(Hash)
              Rails.logger.debug "[AssistantChatbot] Test creator JSON plan is not an object"
              return nil
            end

            unless data.key?("prompt_version_id")
              Rails.logger.debug "[AssistantChatbot] Test creator JSON plan missing prompt_version_id"
              return nil
            end

            args = data.deep_symbolize_keys.with_indifferent_access

            Rails.logger.info "[AssistantChatbot] Parsed generate_tests JSON plan: #{args.inspect}"

            {
              function_call: {
                name: "generate_tests",
                arguments: args
              }
            }
          end

          def extract_create_dataset_function_call_from_text(text)
            return nil if text.blank?

            stripped = text.strip

            begin
              data = JSON.parse(stripped)
            rescue JSON::ParserError
              Rails.logger.debug "[AssistantChatbot] Dataset wizard response not valid JSON plan"
              return nil
            end

            unless data.is_a?(Hash)
              Rails.logger.debug "[AssistantChatbot] Dataset wizard JSON plan is not an object"
              return nil
            end

            unless data.key?("prompt_version_id")
              Rails.logger.debug "[AssistantChatbot] Dataset JSON plan missing prompt_version_id"
              return nil
            end

            args = data.deep_symbolize_keys.with_indifferent_access

            Rails.logger.info "[AssistantChatbot] Parsed create_dataset JSON plan: #{args.inspect}"

            {
              function_call: {
                name: "create_dataset",
                arguments: args
              }
            }
          end

          def extract_deploy_agent_function_call_from_text(text)
            return nil if text.blank?

            stripped = text.strip

            begin
              data = JSON.parse(stripped)
            rescue JSON::ParserError
              Rails.logger.debug "[AssistantChatbot] Deployment wizard response not valid JSON plan"
              return nil
            end

            unless data.is_a?(Hash)
              Rails.logger.debug "[AssistantChatbot] Deployment wizard JSON plan is not an object"
              return nil
            end

            unless data.key?("prompt_version_id") && data.key?("agent_type")
              Rails.logger.debug "[AssistantChatbot] Deployment JSON plan missing required keys"
              return nil
            end

            args = data.deep_symbolize_keys.with_indifferent_access

            Rails.logger.info "[AssistantChatbot] Parsed deploy_agent JSON plan: #{args.inspect}"

            {
              function_call: {
                name: "deploy_agent",
                arguments: args
              }
            }
          end

          def extract_create_prompt_function_call_from_text(text)
            return nil if text.blank?

            stripped = text.strip

            begin
              data = JSON.parse(stripped)
            rescue JSON::ParserError
              Rails.logger.debug "[AssistantChatbot] Prompt creation wizard response not valid JSON plan"
              return nil
            end

            unless data.is_a?(Hash)
              Rails.logger.debug "[AssistantChatbot] Prompt creation JSON plan is not an object"
              return nil
            end

            unless data.key?("name") && data.key?("system_prompt_concept")
              Rails.logger.debug "[AssistantChatbot] Prompt creation JSON plan missing required keys"
              return nil
            end

            args = data.deep_symbolize_keys.with_indifferent_access

            Rails.logger.info "[AssistantChatbot] Parsed create_prompt JSON plan: #{args.inspect}"

            {
              function_call: {
                name: "create_prompt",
                arguments: args
              }
            }
          end
  end
end
