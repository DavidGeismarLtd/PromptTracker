# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Evaluators::BaseChatCompletionEvaluator do
  describe ".api_type" do
    it "returns :chat_completion" do
      expect(described_class.api_type).to eq(:chat_completion)
    end
  end

  describe ".compatible_with" do
    it "returns an array containing PromptVersion" do
      expect(described_class.compatible_with).to eq([ PromptTracker::PromptVersion ])
    end
  end

  describe ".compatible_with?" do
    it "returns true for PromptVersion instances" do
      prompt_version = build(:prompt_version)
      expect(described_class.compatible_with?(prompt_version)).to be true
    end

    it "returns false for Assistant instances" do
      assistant = build(:openai_assistant)
      expect(described_class.compatible_with?(assistant)).to be false
    end
  end

  describe "#initialize" do
    it "stores response_text" do
      evaluator = described_class.new("test response", {})
      expect(evaluator.response_text).to eq("test response")
    end

    it "stores config" do
      config = { min_length: 10 }
      evaluator = described_class.new("test", config)
      expect(evaluator.config).to eq(config)
    end
  end

  describe "inheritance" do
    it "inherits from BaseEvaluator" do
      expect(described_class.superclass).to eq(PromptTracker::Evaluators::BaseEvaluator)
    end
  end
end
