# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  module Openai
    RSpec.describe ConversationResult, type: :service do
      let(:messages) do
        [
          { role: "user", content: "Hello", turn: 1, timestamp: "2024-01-01T10:00:00Z" },
          { role: "assistant", content: "Hi there!", turn: 1, timestamp: "2024-01-01T10:00:01Z" },
          { role: "user", content: "How are you?", turn: 2, timestamp: "2024-01-01T10:00:02Z" },
          { role: "assistant", content: "I'm doing well!", turn: 2, timestamp: "2024-01-01T10:00:03Z" }
        ]
      end

      let(:result) do
        described_class.new(
          messages: messages,
          total_turns: 2,
          status: "completed",
          metadata: { model: "gpt-4o" },
          previous_response_id: "resp_123"
        )
      end

      describe "#initialize" do
        it "sets all attributes" do
          expect(result.messages).to eq(messages)
          expect(result.total_turns).to eq(2)
          expect(result.status).to eq("completed")
          expect(result.metadata).to eq({ model: "gpt-4o" })
          expect(result.previous_response_id).to eq("resp_123")
        end

        it "freezes messages and metadata" do
          expect(result.messages).to be_frozen
          expect(result.metadata).to be_frozen
        end

        it "defaults optional attributes" do
          simple_result = described_class.new(
            messages: [],
            total_turns: 0,
            status: "completed"
          )

          expect(simple_result.metadata).to eq({})
          expect(simple_result.run_steps).to eq([])
          expect(simple_result.thread_id).to be_nil
          expect(simple_result.previous_response_id).to be_nil
        end
      end

      describe "#completed?" do
        it "returns true when status is completed" do
          expect(result.completed?).to be true
        end

        it "returns false when status is not completed" do
          error_result = described_class.new(messages: [], total_turns: 0, status: "error")
          expect(error_result.completed?).to be false
        end
      end

      describe "#error?" do
        it "returns true when status is error" do
          error_result = described_class.new(messages: [], total_turns: 0, status: "error")
          expect(error_result.error?).to be true
        end

        it "returns false when status is not error" do
          expect(result.error?).to be false
        end
      end

      describe "#max_turns_reached?" do
        it "returns true when status is max_turns_reached" do
          max_result = described_class.new(messages: [], total_turns: 5, status: "max_turns_reached")
          expect(max_result.max_turns_reached?).to be true
        end
      end

      describe "#user_messages" do
        it "returns only user messages" do
          user_msgs = result.user_messages
          expect(user_msgs.length).to eq(2)
          expect(user_msgs.all? { |m| m[:role] == "user" }).to be true
        end
      end

      describe "#assistant_messages" do
        it "returns only assistant messages" do
          asst_msgs = result.assistant_messages
          expect(asst_msgs.length).to eq(2)
          expect(asst_msgs.all? { |m| m[:role] == "assistant" }).to be true
        end
      end

      describe "#last_assistant_message" do
        it "returns the last assistant message" do
          expect(result.last_assistant_message[:content]).to eq("I'm doing well!")
        end
      end

      describe "#last_user_message" do
        it "returns the last user message" do
          expect(result.last_user_message[:content]).to eq("How are you?")
        end
      end

      describe "#messages_for_turn" do
        it "returns messages for a specific turn" do
          turn_1_msgs = result.messages_for_turn(1)
          expect(turn_1_msgs.length).to eq(2)
          expect(turn_1_msgs.map { |m| m[:content] }).to eq(%w[Hello Hi\ there!])
        end
      end

      describe "#to_h" do
        it "converts to hash" do
          hash = result.to_h
          expect(hash[:messages]).to eq(messages)
          expect(hash[:total_turns]).to eq(2)
          expect(hash[:status]).to eq("completed")
          expect(hash[:previous_response_id]).to eq("resp_123")
        end

        it "excludes nil values" do
          simple_result = described_class.new(messages: [], total_turns: 0, status: "completed")
          hash = simple_result.to_h
          expect(hash).not_to have_key(:thread_id)
          expect(hash).not_to have_key(:previous_response_id)
        end
      end

      describe ".from_h" do
        it "creates from hash" do
          hash = {
            messages: messages,
            total_turns: 2,
            status: "completed",
            previous_response_id: "resp_456"
          }

          restored = described_class.from_h(hash)
          # Messages may have string keys after round-trip through hash
          expect(restored.messages.length).to eq(messages.length)
          expect(restored.messages.first["role"] || restored.messages.first[:role]).to eq("user")
          expect(restored.total_turns).to eq(2)
          expect(restored.status).to eq("completed")
          expect(restored.previous_response_id).to eq("resp_456")
        end

        it "handles missing keys with defaults" do
          hash = {}
          restored = described_class.from_h(hash)
          expect(restored.messages).to eq([])
          expect(restored.total_turns).to eq(0)
          expect(restored.status).to eq("unknown")
        end
      end
    end
  end
end
