# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Functions::AvailableTestsForPromptVersion do
  let(:context) { {} }

  describe "#call" do
    let!(:prompt_version) { create(:prompt_version) }

    context "when enabled tests exist" do
      let!(:test1) { create(:test, :for_prompt_version, testable: prompt_version, name: "First test") }
      let!(:test2) { create(:test, :for_prompt_version, testable: prompt_version, name: "Second test") }
      let!(:other_test) { create(:test) }

      let(:arguments) { { prompt_version_id: prompt_version.id } }

      it "returns a success result listing enabled tests for the prompt version" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(result.error).to be_nil

        # Includes tests for this version
        expect(result.message).to include("enabled tests for PromptVersion ##{prompt_version.id}")
        expect(result.message).to include("ID #{test1.id}")
        expect(result.message).to include(test1.name)
        expect(result.message).to include("ID #{test2.id}")
        expect(result.message).to include(test2.name)

        # Does not include tests from other versions
        expect(result.message).not_to include(other_test.id.to_s)

        # Link points to tests tab for this prompt version
        expect(result.links.first[:url]).to eq(
          "/prompt_tracker/testing/prompts/#{prompt_version.prompt_id}/versions/#{prompt_version.id}#tests"
        )
      end
    end

    context "when no enabled tests exist" do
      let(:arguments) { { prompt_version_id: prompt_version.id } }

      it "returns an informative success result with no tests" do
        result = described_class.new(arguments, context).call

        expect(result.success?).to be true
        expect(result.message).to include("no enabled tests")
        expect(result.links.first[:url]).to eq(
          "/prompt_tracker/testing/prompts/#{prompt_version.prompt_id}/versions/#{prompt_version.id}#tests"
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
