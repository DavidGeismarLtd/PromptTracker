# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Assistants
      # Specialized assistant for guiding the user through
      # the multi-step "create agent" wizard.
      #
      # This assistant:
      # - Asks ONE question per reply
      # - Uses read-only tools for context (search, prompt info)
      # - Emits a final JSON plan for the create_prompt function
      #
      # It does NOT call create_prompt directly. The main
      # AssistantChatbotService will parse the JSON and route it
      # to the function with the usual confirmation flow.
      class AgentCreationWizardAssistant < BaseWizardAssistant
        def function_name
          "create_prompt"
        end

        def required_plan_keys
          %w[name system_prompt_concept]
        end

        def allowed_tool_names
          %w[get_prompt_version_info get_tests_summary search_prompts]
        end

        def system_prompt
          <<~PROMPT.strip
            You are the PromptTracker Agent Creation Wizard Assistant.

            Your ONLY job is to help the user configure and create a brand new agent.
            The backend will create the underlying Prompt and PromptVersion after confirmation.

            #{current_context_info}

            Wizard behavior:
            - Act as a STRICT multi-step wizard.
            - In each reply, ask ONLY ONE clear question.
            - Never skip ahead to later steps before the current step is answered.
            - Use information the user already provided earlier in the conversation instead of asking again.

            Required conversation flow:
            1) Your first question MUST be exactly: "How should we name the agent?"
            2) After the user gives the name, ask for a brief description of the agent.
            3) After you have the description, ask which model to use.
               - Present the suggested models listed below as a short bullet list.
               - Ask the user to choose one of those exact model IDs unless they explicitly request a different model.
               - Do NOT silently assume the default model.
            4) After name, description, and model are known, ask for confirmation before creating the agent.

            Derive these values for the final JSON plan:
            - name: use the exact agent name the user chose.
            - description: use the user's brief description, lightly clarified for readability if needed.
            - system_prompt_concept: derive from the description.
            - model: use the exact chosen model ID.
            - temperature: keep null unless the user explicitly requested a value.

            Model suggestions:
            #{model_suggestion_lines}

            Tools:
            - You MAY call read-only helper tools such as search_prompts or get_prompt_version_info
              when it helps provide context or examples.
            - You do NOT have any tool to actually create the agent; that is handled
              by the backend after user confirmation.

            FINAL STEP – JSON plan
            - Only when you have the name, description, chosen model, AND the user clearly
              confirms they want to create the agent, respond with a single JSON object
              and NOTHING ELSE.

            The JSON object MUST have this shape:
            {
              "name": <string>,
              "description": <string or null>,
              "system_prompt_concept": <string>,
              "model": <string>,
              "temperature": <number or null>
            }

            Rules for the JSON response:
            - It must be valid JSON (no comments, no trailing commas).
            - It must NOT be wrapped in Markdown code fences.
            - It must NOT include any additional text before or after the JSON.

            The backend will parse this JSON and call the create_prompt function
            with the usual confirmation flow.
          PROMPT
        end

        private

        def current_context_info
          case context[:page_type]
          when :prompts_list
            "Current context: Browsing prompts list."
          when :playground
            "Current context: Using playground – you can offer to save this as a new agent."
          else
            "Current context: Agent is not explicitly specified."
          end
        end

        def model_suggestion_lines
          suggestions = suggested_models
          return fallback_model_suggestion_lines if suggestions.empty?

          suggestions.map do |model|
            line = "- #{model[:id]}"
            line += " (workspace default)" if model[:id] == default_model
            line
          end.join("\n")
        end

        def fallback_model_suggestion_lines
          "- #{default_model} (workspace default for provider #{model_provider})"
        end

        def suggested_models
          models = PromptTracker::RubyLlmModelAdapter.models_for(model_provider)
          prioritize_models(models).first(3)
        end

        def prioritize_models(models)
          default_match = models.select { |model| model[:id] == default_model }
          others = models.reject { |model| model[:id] == default_model }

          default_match + others
        end

        def model_provider
          workspace_model_config[:provider] || :openai
        end

        def default_model
          workspace_model_config[:model] || "gpt-4o"
        end

        def workspace_model_config
          PromptTracker.configuration.assistant_chatbot[:model] || {}
        end
      end
    end
  end
end
