# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Evaluators::BaseAssistantsApiEvaluator do
  describe ".api_type" do
    it "returns :assistants_api" do
      expect(described_class.api_type).to eq(:assistants_api)
    end
  end

  describe ".compatible_with" do
    it "returns an array containing Openai::Assistant" do
      expect(described_class.compatible_with).to eq([ PromptTracker::Openai::Assistant ])
    end
  end

  describe ".compatible_with?" do
    it "returns true for Assistant instances" do
      assistant = build(:openai_assistant)
      expect(described_class.compatible_with?(assistant)).to be true
    end

    it "returns false for PromptVersion instances" do
      prompt_version = build(:prompt_version)
      expect(described_class.compatible_with?(prompt_version)).to be false
    end
  end

  describe "inheritance" do
    it "inherits from BaseConversationalEvaluator" do
      expect(described_class.superclass).to eq(PromptTracker::Evaluators::BaseConversationalEvaluator)
    end
  end

  describe "#messages" do
    it "inherits messages method from BaseConversationalEvaluator" do
      data = { "messages" => [ { "role" => "assistant", "content" => "hello" } ] }
      evaluator = described_class.new(data, {})
      expect(evaluator.messages).to eq([ { "role" => "assistant", "content" => "hello" } ])
    end
  end

  describe "#assistant_messages" do
    it "inherits assistant_messages method from BaseConversationalEvaluator" do
      data = {
        "messages" => [
          { "role" => "user", "content" => "hi" },
          { "role" => "assistant", "content" => "hello" }
        ]
      }
      evaluator = described_class.new(data, {})
      expect(evaluator.assistant_messages.length).to eq(1)
    end
  end
end
