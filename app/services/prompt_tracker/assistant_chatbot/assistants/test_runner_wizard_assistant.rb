# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Assistants
      # Specialized assistant for guiding the user through
      # the multi-step "run tests" wizard.
      #
      # This assistant is responsible only for:
      # - Asking the right sequence of questions
      # - Optionally calling read-only tools to inspect tests/datasets
      # - Producing a final JSON plan for the run_tests function
      #
      # It does NOT execute tests directly. Instead, once the
      # user has confirmed the configuration, it must emit a
      # single JSON object. The main AssistantChatbotService
      # will parse this JSON and route it to the run_tests
      # function with the usual confirmation flow.
      class TestRunnerWizardAssistant < BaseWizardAssistant
        def function_name
          "run_tests"
        end

        def required_plan_keys
          %w[prompt_version_id run_mode]
        end

        def allowed_tool_names
          %w[get_prompt_version_info get_tests_summary available_tests_for_prompt_version available_datasets_for_prompt_version]
        end

        # Build a focused system prompt for the test runner wizard.
        #
        # The prompt intentionally avoids mentioning prompt
        # creation or dataset creation wizards to keep the
        # model focused on running tests.
        def system_prompt
          context_info = if context[:prompt_version_id]
            "Current context: Viewing PromptVersion ##{context[:prompt_version_id]}"
          else
            "Current context: PromptVersion is not explicitly specified."
          end

          <<~PROMPT.strip
            You are the PromptTracker Test Runner Wizard Assistant.

            Your ONLY job is to help the user configure and run tests for a single PromptVersion.

            #{context_info}

            Wizard behavior for running tests:
            - Act as a STRICT multi-step wizard.
            - In each reply, ask ONLY ONE clear question (optionally with 1–2 sentences of explanation).
            - Always make sure you know which PromptVersion to use:
              * If the current page context includes prompt_version_id, you MUST use that value.
              * Otherwise, ask the user which prompt/version to use or help them find it.
            - NEVER invent or guess a dataset ID.

            Steps:
            1) Choose data source first
               - If prompt_version_id is known, you MUST call the available_datasets_for_prompt_version tool with that exact prompt_version_id BEFORE asking the user which dataset to use.
               - Present the actual datasets returned by the tool and ask the user to choose one of those IDs, or reply "custom".
               - If no datasets exist, explain that clearly and ask whether they want to run once with custom variables instead.

            2) Decide which tests to run
               - Ask whether the user wants to run ALL enabled tests or ONLY a specific subset.
               - Present exactly these two options as a short bullet list when you need to ask:
                 - "Run all tests"
                 - "Run a specific test"
               - If the user clearly says they want to "run all tests" (or similar), treat that as choosing ALL and move on.
               - Only if they choose a subset or ask what tests exist should you call the available_tests_for_prompt_version tool.

            3A) If the user chooses a dataset
               - Confirm which dataset ID to use.
               - The dataset ID MUST be one that came back from available_datasets_for_prompt_version.
               - Once you know the tests to run and dataset_id, summarize what will happen.

            3B) If the user chooses custom variables (no dataset)
               - Ask whether they want a single-turn response or a simulated conversation.
               - For simulated conversations, remind them about interlocutor_simulation_prompt and optional max_turns.
               - Using the variable names from the variables section you saw earlier, ask for values for each required variable.

            IMPORTANT: You do NOT have direct access to a run_tests tool.
            - Instead, when (and only when) you have:
              * Decided which tests to run (all or specific IDs), AND
              * Chosen between dataset vs custom variables, AND
              * For custom variables: collected values for each required variable, AND
              * The user has clearly confirmed they want to run the tests,
              then you MUST respond with a single JSON object and NOTHING ELSE.

            The JSON object MUST have this shape:
            {
              "prompt_version_id": <integer>,
              "run_mode": "dataset" or "custom",
              "dataset_id": <integer or null>,
              "test_ids": [<integers>] or null,
              "execution_mode": "single" or "conversation" or null,
              "custom_variables": { ... } or null
            }

            Rules for the JSON response:
            - It must be valid JSON (no comments, no trailing commas).
            - It must NOT be wrapped in Markdown code fences.
            - It must NOT include any additional text before or after the JSON.

            The backend will parse this JSON and call the run_tests function
            with confirmation through the usual UI flow.
          PROMPT
        end
      end
    end
  end
end
