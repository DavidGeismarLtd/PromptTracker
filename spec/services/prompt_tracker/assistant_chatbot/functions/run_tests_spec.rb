# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Functions::RunTests do
  let(:context) { {} }

  describe "#call" do
    before do
      allow(PromptTracker::RunTestJob).to receive(:perform_later)
    end

    context "when running with a dataset" do
      let!(:prompt_version) { create(:prompt_version) }
      let!(:test1) { create(:test, testable: prompt_version, name: "First test") }
      let!(:test2) { create(:test, testable: prompt_version, name: "Second test") }

      let!(:dataset) do
        create(:dataset, testable: prompt_version, dataset_type: :single_turn).tap do |ds|
          create_list(:dataset_row, 2, dataset: ds)
        end
      end

      let(:arguments) do
        {
          prompt_version_id: prompt_version.id,
          run_mode: "dataset",
          dataset_id: dataset.id
        }
      end

      it "creates a TestRun for each test × dataset row with dataset metadata" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(result.entities_created[:test_ids]).to match_array([ test1.id, test2.id ])

        # 2 tests × 2 rows
        expect(PromptTracker::TestRun.count).to eq(4)

        PromptTracker::TestRun.all.each do |run|
          expect(run.dataset).to eq(dataset)
          expect(run.dataset_row).to be_present
          expect(run.metadata["triggered_by"]).to eq("assistant_chatbot")
          expect(run.metadata["run_mode"]).to eq("dataset")
          expect(run.metadata["execution_mode"]).to eq("single")
        end

        expect(PromptTracker::RunTestJob).to have_received(:perform_later).exactly(4).times
      end
    end

      context "when running with custom variables in single mode" do
        let!(:prompt_version) do
          create(:prompt_version).tap do |version|
            version.update!(
              variables_schema: [
                { "name" => "name", "type" => "string", "required" => true }
              ]
            )
          end
        end
      let!(:test1) { create(:test, testable: prompt_version) }
      let!(:test2) { create(:test, testable: prompt_version) }

      let(:arguments) do
        {
          prompt_version_id: prompt_version.id,
          run_mode: "custom",
          execution_mode: "single",
          custom_variables: {
            "name" => "Alice"
          }
        }
      end

      it "creates one TestRun per test with custom metadata and variables" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(result.entities_created[:test_ids]).to match_array([ test1.id, test2.id ])
        expect(PromptTracker::TestRun.count).to eq(2)

        PromptTracker::TestRun.all.each do |run|
          expect(run.dataset).to be_nil
          expect(run.metadata["run_mode"]).to eq("custom")
          expect(run.metadata["execution_mode"]).to eq("single")
          expect(run.metadata["custom_variables"]).to include("name" => "Alice")
          expect(run.variables_used).to include("name" => "Alice")
        end

        expect(PromptTracker::RunTestJob).to have_received(:perform_later).exactly(2).times
      end
    end

      context "when running with custom variables in conversation mode" do
        let!(:prompt_version) do
          create(:prompt_version).tap do |version|
            version.update!(
              variables_schema: [
                { "name" => "name", "type" => "string", "required" => true }
              ]
            )
          end
        end
      let!(:test) { create(:test, testable: prompt_version) }

      let(:arguments) do
        {
          prompt_version_id: prompt_version.id,
          run_mode: "custom",
          execution_mode: "conversation",
          custom_variables: {
            "name" => "Alice",
            "interlocutor_simulation_prompt" => "You are a worried user.",
            "max_turns" => 3
          }
        }
      end

      it "requires conversational fields and stores execution_mode=conversation" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(PromptTracker::TestRun.count).to eq(1)

        run = PromptTracker::TestRun.last
        expect(run.metadata["run_mode"]).to eq("custom")
        expect(run.metadata["execution_mode"]).to eq("conversation")
        expect(run.metadata["custom_variables"]).to include(
          "name" => "Alice",
          "interlocutor_simulation_prompt" => "You are a worried user.",
          "max_turns" => 3
        )
      end
    end

      context "when required custom variables are missing" do
        let!(:prompt_version) do
          create(:prompt_version).tap do |version|
            version.update!(
              variables_schema: [
                { "name" => "name", "type" => "string", "required" => true }
              ]
            )
          end
        end
      let!(:test) { create(:test, testable: prompt_version) }

      let(:arguments) do
        {
          prompt_version_id: prompt_version.id,
          run_mode: "custom",
          execution_mode: "single",
          custom_variables: {} # missing required "name"
        }
      end

      it "returns a failure result with a helpful error" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be false
        expect(result.error).to include("Missing required custom variables")
      end
    end
  end
end
