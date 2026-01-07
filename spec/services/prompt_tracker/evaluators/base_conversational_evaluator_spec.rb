# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Evaluators::BaseConversationalEvaluator do
  describe ".api_type" do
    it "returns :conversational" do
      expect(described_class.api_type).to eq(:conversational)
    end
  end

  describe "#initialize" do
    it "stores conversation_data" do
      data = { "messages" => [] }
      evaluator = described_class.new(data, {})
      expect(evaluator.conversation_data).to eq(data)
    end

    it "handles nil conversation_data" do
      evaluator = described_class.new(nil, {})
      expect(evaluator.conversation_data).to eq({})
    end

    it "stores config" do
      config = { threshold: 80 }
      evaluator = described_class.new({}, config)
      expect(evaluator.config).to eq(config)
    end
  end

  describe "#messages" do
    it "returns messages from conversation_data with string keys" do
      data = { "messages" => [ { "role" => "user", "content" => "hello" } ] }
      evaluator = described_class.new(data, {})
      expect(evaluator.messages).to eq([ { "role" => "user", "content" => "hello" } ])
    end

    it "returns messages from conversation_data with symbol keys" do
      data = { messages: [ { role: "user", content: "hello" } ] }
      evaluator = described_class.new(data, {})
      expect(evaluator.messages).to eq([ { role: "user", content: "hello" } ])
    end

    it "returns empty array when no messages" do
      evaluator = described_class.new({}, {})
      expect(evaluator.messages).to eq([])
    end
  end

  describe "#assistant_messages" do
    it "filters to only assistant messages" do
      data = {
        "messages" => [
          { "role" => "user", "content" => "hello" },
          { "role" => "assistant", "content" => "hi there" },
          { "role" => "user", "content" => "bye" },
          { "role" => "assistant", "content" => "goodbye" }
        ]
      }
      evaluator = described_class.new(data, {})
      expect(evaluator.assistant_messages.length).to eq(2)
      expect(evaluator.assistant_messages.all? { |m| m["role"] == "assistant" }).to be true
    end
  end

  describe "inheritance" do
    it "inherits from BaseEvaluator" do
      expect(described_class.superclass).to eq(PromptTracker::Evaluators::BaseEvaluator)
    end
  end
end
