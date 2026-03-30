# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Functions::AvailableDatasetsForPromptVersion do
  let(:context) { {} }

  describe "#call" do
    let!(:prompt_version) { create(:prompt_version) }

    context "when datasets exist" do
      let!(:single_dataset) do
        create(:dataset, testable: prompt_version, dataset_type: :single_turn).tap do |dataset|
          create_list(:dataset_row, 2, dataset: dataset)
        end
      end

      let!(:conversational_dataset) do
        create(:dataset, testable: prompt_version, dataset_type: :conversational).tap do |dataset|
          create_list(:dataset_row, 1, dataset: dataset)
        end
      end

      let!(:other_dataset) { create(:dataset, :for_prompt_version) }

      let(:arguments) { { prompt_version_id: prompt_version.id } }

      it "returns a success result listing datasets for the prompt version" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(result.error).to be_nil

        expect(result.message).to include("datasets for PromptVersion ##{prompt_version.id}")

        # Includes this prompt version's datasets with IDs, names, types, and row counts
        expect(result.message).to include("ID #{single_dataset.id}")
        expect(result.message).to include(single_dataset.name)
        expect(result.message).to include("single_turn")
        expect(result.message).to include("rows: 2")

        expect(result.message).to include("ID #{conversational_dataset.id}")
        expect(result.message).to include(conversational_dataset.name)
        expect(result.message).to include("conversational")
        expect(result.message).to include("rows: 1")

          # Does not include datasets from other prompt versions
          expect(result.message).not_to include("ID #{other_dataset.id}:")

        # Link points to datasets tab for this prompt version
        expect(result.links.first[:url]).to eq(
          "/prompt_tracker/testing/prompts/#{prompt_version.prompt_id}/versions/#{prompt_version.id}#datasets"
        )
      end
    end

    context "when no datasets exist" do
      let(:arguments) { { prompt_version_id: prompt_version.id } }

      it "returns an informative success result with no datasets" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(result.message).to include("does not have any datasets yet")
        expect(result.links.first[:url]).to eq(
          "/prompt_tracker/testing/prompts/#{prompt_version.prompt_id}/versions/#{prompt_version.id}#datasets"
        )
      end
    end

    context "when prompt_version_id is missing" do
      it "returns a failure result" do
        result = described_class.new({}, context).call

        expect(result.success?).to be false
        expect(result.error).to include("prompt_version_id is required")
      end
    end
  end
end
