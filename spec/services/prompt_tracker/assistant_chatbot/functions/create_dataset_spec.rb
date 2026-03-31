# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Functions::CreateDataset do
  let(:prompt_version) { create(:prompt_version) }
  let(:context) { {} }

  let(:arguments) do
    {
      prompt_version_id: prompt_version.id,
      name: "raw dataset name",
      description: "raw description",
      dataset_type: "single_turn",
      count: 10,
      instructions: "Focus on edge cases",
      model: "gpt-4o"
    }
  end

  subject(:function) { described_class.new(arguments, context) }

  before do
    allow(PromptTracker::DatasetEnhancers::NameEnhancer).to receive(:enhance).and_return(
      name: "Enhanced Dataset Name"
    )

    allow(PromptTracker::DatasetEnhancers::DescriptionEnhancer).to receive(:enhance).and_return(
      description: "Enhanced dataset description"
    )

    allow(PromptTracker::GenerateDatasetRowsJob).to receive(:perform_later)
  end

  describe "#call" do
    it "creates a dataset and enqueues row generation when count is provided" do
      result = function.call

      expect(result.success?).to be true

      dataset = PromptTracker::Dataset.last
      expect(dataset).to be_present
      expect(dataset.testable).to eq(prompt_version)
      expect(dataset.name).to eq("Enhanced Dataset Name")
      expect(dataset.description).to eq("Enhanced dataset description")
      expect(dataset.dataset_type).to eq("single_turn")

      expect(PromptTracker::GenerateDatasetRowsJob).to have_received(:perform_later).with(
        dataset.id,
        count: 10,
        instructions: "Focus on edge cases",
        model: "gpt-4o"
      )

      expect(result.entities_created[:dataset_id]).to eq(dataset.id)
      expect(result.entities_created[:prompt_version_id]).to eq(prompt_version.id)
    end

    it "does not enqueue row generation when count is nil" do
      arguments.delete(:count)

      function.call

      expect(PromptTracker::GenerateDatasetRowsJob).not_to have_received(:perform_later)
    end

    it "returns a failure result when prompt_version_id is missing" do
      arguments.delete(:prompt_version_id)

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("prompt_version_id is required")
    end

    it "returns a failure result for invalid dataset_type" do
      arguments[:dataset_type] = "invalid"

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("dataset_type must be 'single_turn' or 'conversational'")
    end

    it "returns a failure result for non-positive count" do
      arguments[:count] = 0

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("count must be a positive integer")
    end

    it "returns a failure result when prompt version is not found" do
      arguments[:prompt_version_id] = -1

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("PromptVersion -1 not found")
    end
  end
end
