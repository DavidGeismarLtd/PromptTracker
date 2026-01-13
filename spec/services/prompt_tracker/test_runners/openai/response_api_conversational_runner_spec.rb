# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  module TestRunners
    module Openai
      RSpec.describe ResponseApiConversationalRunner, type: :service do
        let(:prompt) { create(:prompt) }
        let(:prompt_version) do
          create(:prompt_version,
            prompt: prompt,
            system_prompt: "You are a helpful assistant for {{company}}.",
            user_prompt: "Help the customer with their issue.",
            model_config: { "provider" => "openai_responses", "model" => "gpt-4o", "tools" => %w[web_search] },
            # Schema includes only the variable from the prompt; conversational fields are added by dataset
            variables_schema: [
              { "name" => "company", "type" => "string", "required" => true }
            ]
          )
        end
        let(:test) { create(:test, testable: prompt_version) }
        # For conversational datasets, the schema is: prompt variables + conversational fields
        # The Dataset model adds conversational fields when dataset_type: :conversational
        let(:dataset) do
          create(:dataset, testable: prompt_version, dataset_type: :conversational)
        end
        let(:dataset_row) do
          create(:dataset_row, dataset: dataset, row_data: {
            "company" => "Acme Corp",
            "interlocutor_simulation_prompt" => "You are a frustrated customer.",
            "max_turns" => 3
          })
        end
        let(:test_run) do
          create(:test_run, test: test, dataset_row: dataset_row, status: "running")
        end

        let(:runner) do
          described_class.new(
            test_run: test_run,
            test: test,
            testable: prompt_version,
            use_real_llm: false
          )
        end

        let(:mock_conversation_result) do
          PromptTracker::Openai::ConversationResult.new(
            messages: [
              { role: "user", content: "I have a problem!", turn: 1 },
              { role: "assistant", content: "I'm here to help.", turn: 1 }
            ],
            total_turns: 1,
            status: "completed",
            previous_response_id: "resp_123",
            metadata: { model: "gpt-4o" }
          )
        end

        describe "#run" do
          before do
            # Mock the conversation runner
            mock_runner = instance_double(PromptTracker::Openai::ResponseApiConversationRunner)
            allow(PromptTracker::Openai::ResponseApiConversationRunner).to receive(:new).and_return(mock_runner)
            allow(mock_runner).to receive(:run!).and_return(mock_conversation_result)
          end

          it "runs the conversation and updates test_run" do
            runner.run

            test_run.reload
            expect(test_run.conversation_data).to be_present
            expect(test_run.conversation_data["messages"]).to be_an(Array)
            expect(test_run.conversation_data["status"]).to eq("completed")
          end

          it "creates ResponseApiConversationRunner with correct parameters" do
            mock_runner = instance_double(PromptTracker::Openai::ResponseApiConversationRunner)
            allow(mock_runner).to receive(:run!).and_return(mock_conversation_result)

            expect(PromptTracker::Openai::ResponseApiConversationRunner).to receive(:new).with(
              model: "gpt-4o",
              system_prompt: "You are a helpful assistant for Acme Corp.",
              interlocutor_simulation_prompt: "You are a frustrated customer.",
              max_turns: 3,
              tools: [ :web_search ],
              temperature: 0.7
            ).and_return(mock_runner)

            runner.run
          end

          it "runs evaluators on conversation data" do
            create(:evaluator_config, :keyword_evaluator, configurable: test)

            mock_evaluator = instance_double(Evaluators::KeywordEvaluator)
            mock_evaluation = instance_double(PromptTracker::Evaluation, score: 100, passed: true, passed?: true, feedback: "OK")

            allow(EvaluatorRegistry).to receive(:build).and_return(mock_evaluator)
            allow(mock_evaluator).to receive(:evaluate).and_return(mock_evaluation)

            runner.run

            test_run.reload
            expect(test_run.metadata["evaluator_results"]).to be_present
          end

          it "sets passed status when all evaluators pass" do
            runner.run

            test_run.reload
            expect(test_run.status).to eq("passed")
            expect(test_run.passed).to be true
          end

          it "sets failed status when any evaluator fails" do
            create(:evaluator_config, :keyword_evaluator, configurable: test)

            mock_evaluator = instance_double(Evaluators::KeywordEvaluator)
            mock_evaluation = instance_double(PromptTracker::Evaluation, score: 0, passed: false, passed?: false, feedback: "Failed")

            allow(EvaluatorRegistry).to receive(:build).and_return(mock_evaluator)
            allow(mock_evaluator).to receive(:evaluate).and_return(mock_evaluation)

            runner.run

            test_run.reload
            expect(test_run.status).to eq("failed")
            expect(test_run.passed).to be false
          end

          it "records execution time" do
            runner.run

            test_run.reload
            expect(test_run.execution_time_ms).to be > 0
          end

          it "includes model and tools in metadata" do
            runner.run

            test_run.reload
            expect(test_run.metadata["model"]).to eq("gpt-4o")
            expect(test_run.metadata["tools"]).to eq(%w[web_search])
            expect(test_run.metadata["total_turns"]).to eq(1)
          end
        end

        describe "#extract_test_scenario" do
          it "extracts interlocutor_simulation_prompt and max_turns" do
            prompt, turns = runner.send(:extract_test_scenario)

            expect(prompt).to eq("You are a frustrated customer.")
            expect(turns).to eq(3)
          end

          it "raises error when interlocutor_simulation_prompt is missing" do
            # Use custom_variables in metadata to bypass dataset_row validation
            test_run.update!(metadata: { "custom_variables" => { "company" => "Acme" } })
            test_run.update_column(:dataset_row_id, nil)

            expect { runner.send(:extract_test_scenario) }.to raise_error(
              ArgumentError, /interlocutor_simulation_prompt is required/
            )
          end

          it "defaults max_turns to 5" do
            # Update with valid data that includes required fields but no max_turns
            dataset_row.update!(row_data: {
              "company" => "Acme Corp",
              "interlocutor_simulation_prompt" => "Test prompt"
            })

            _, turns = runner.send(:extract_test_scenario)
            expect(turns).to eq(5)
          end
        end
      end
    end
  end
end
