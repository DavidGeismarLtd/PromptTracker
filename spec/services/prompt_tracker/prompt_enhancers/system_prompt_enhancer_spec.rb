# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::PromptEnhancers::SystemPromptEnhancer do
  describe ".enhance" do
    let(:generator_result) do
      {
        system_prompt: "You are a customer support triage assistant.",
        variables: %w[customer_name issue_type],
        explanation: "Explains how the prompt works."
      }
    end

    before do
      allow(PromptTracker::PromptGeneratorService)
        .to receive(:generate)
        .and_return(generator_result)
    end

      it "returns system_prompt, variables and explanation from PromptGeneratorService" do
      result = described_class.enhance(
        system_prompt_concept: "Customer support triage assistant",
        description: "Handles billing and technical issues."
      )

      expect(result[:system_prompt]).to eq(generator_result[:system_prompt])
      expect(result[:variables]).to eq(generator_result[:variables])
      expect(result[:explanation]).to eq(generator_result[:explanation])
    end

    it "builds a combined description for PromptGeneratorService" do
      concept = "Customer support triage assistant"
      extra   = "Handles refunds and cancellations."

      described_class.enhance(
        system_prompt_concept: concept,
        description: extra
      )

      expect(PromptTracker::PromptGeneratorService).to have_received(:generate) do |args|
        expect(args[:description]).to include("Prompt concept:\n#{concept}")
        expect(args[:description]).to include("Additional context:\n#{extra}")
      end
    end

    it "falls back to the concept when no extra description is provided" do
      described_class.enhance(
        system_prompt_concept: "Generic assistant",
        description: nil
      )

      expect(PromptTracker::PromptGeneratorService).to have_received(:generate) do |args|
        expect(args[:description]).to include("Generic assistant")
      end
    end
  end
end
