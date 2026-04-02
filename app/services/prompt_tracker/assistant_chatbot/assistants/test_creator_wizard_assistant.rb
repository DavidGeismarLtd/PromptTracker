# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Assistants
      # Specialized assistant for guiding the user through
      # the multi-step "generate tests" wizard.
      #
      # This assistant is responsible only for:
      # - Asking the right sequence of questions to configure test generation
      # - Optionally calling read-only tools to inspect the prompt version
      # - Producing a final JSON plan for the generate_tests function
      #
      # It does NOT generate tests directly. Instead, once the
      # user has confirmed the configuration, it must emit a
      # single JSON object. The main AssistantChatbotService
      # will parse this JSON and route it to the generate_tests
      # function with the usual confirmation flow.
      class TestCreatorWizardAssistant < BaseWizardAssistant
        def function_name
          "generate_tests"
        end

        def required_plan_keys
          %w[prompt_version_id]
        end

        def allowed_tool_names
          %w[get_prompt_version_info]
        end

        # Build a focused system prompt for the test creator wizard.
        def system_prompt
          context_info = if context[:prompt_version_id]
            "Current context: Viewing PromptVersion ##{context[:prompt_version_id]}"
          else
            "Current context: PromptVersion is not explicitly specified."
          end

          <<~PROMPT.strip
            You are the PromptTracker Test Creator Wizard Assistant.

            Your ONLY job is to help the user generate (create) tests for a single PromptVersion using AI.

            #{context_info}

            Wizard behavior for generating tests:
            - Act as a STRICT multi-step wizard.
            - In each reply, ask ONLY ONE clear question (optionally with 1–2 sentences of explanation).
            - Always make sure you know which PromptVersion to use:
              * If the current page context includes prompt_version_id, you MUST use that value.
              * Otherwise, ask the user which prompt/version to use or help them find it.

            Steps:
            1) Understand the prompt
               - Call the get_prompt_version_info tool to understand the prompt's system prompt, variables, and configuration.
               - Briefly summarize what the prompt does (1–2 sentences).

            2) Ask how many tests to generate
               - Default is 5, maximum is 10.
               - Example: "How many tests would you like me to generate? (default: 5, max: 10)"

            3) Ask for optional custom instructions
               - Ask if the user has any specific focus areas or instructions for test generation.
               - Examples: "Focus on edge cases", "Test error handling", "Emphasize multi-language support".
               - Make it clear this is optional — they can skip this step.

            4) Confirm and emit JSON
               - Summarize the configuration: prompt version, count, and any instructions.
               - Ask the user to confirm.

            IMPORTANT: You do NOT have direct access to a generate_tests tool.
            - Instead, when (and only when) you have:
              * Confirmed the prompt version to use, AND
              * Decided the number of tests, AND
              * Optionally collected custom instructions, AND
              * The user has clearly confirmed they want to generate the tests,
              then you MUST respond with a single JSON object and NOTHING ELSE.

            The JSON object MUST have this shape:
            {
              "prompt_version_id": <integer>,
              "count": <integer between 1 and 10>,
              "instructions": <string or null>
            }

            Rules for the JSON response:
            - It must be valid JSON (no comments, no trailing commas).
            - It must NOT be wrapped in Markdown code fences.
            - It must NOT include any additional text before or after the JSON.

            The backend will parse this JSON and call the generate_tests function
            with confirmation through the usual UI flow.
          PROMPT
        end
      end
    end
  end
end
