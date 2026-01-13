# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  module Openai
    RSpec.describe ResponseApiConversationRunner, type: :service do
      let(:model) { "gpt-4o" }
      let(:system_prompt) { "You are a helpful customer support agent." }
      let(:interlocutor_simulation_prompt) { "You are a frustrated customer with a billing issue." }
      let(:max_turns) { 3 }
      let(:tools) { [ :web_search ] }

      let(:runner) do
        described_class.new(
          model: model,
          system_prompt: system_prompt,
          interlocutor_simulation_prompt: interlocutor_simulation_prompt,
          max_turns: max_turns,
          tools: tools,
          temperature: 0.7
        )
      end

      describe "#initialize" do
        it "sets instance variables" do
          expect(runner.model).to eq(model)
          expect(runner.system_prompt).to eq(system_prompt)
          expect(runner.interlocutor_simulation_prompt).to eq(interlocutor_simulation_prompt)
          expect(runner.max_turns).to eq(max_turns)
          expect(runner.tools).to eq(tools)
          expect(runner.messages).to eq([])
          expect(runner.previous_response_id).to be_nil
        end

        it "defaults max_turns to 5" do
          runner = described_class.new(
            model: model,
            system_prompt: system_prompt,
            interlocutor_simulation_prompt: interlocutor_simulation_prompt
          )
          expect(runner.max_turns).to eq(5)
        end

        it "defaults tools to empty array" do
          runner = described_class.new(
            model: model,
            system_prompt: system_prompt,
            interlocutor_simulation_prompt: interlocutor_simulation_prompt
          )
          expect(runner.tools).to eq([])
        end
      end

      describe "#run!" do
        before do
          # Mock LLM service for generating user messages
          allow(LlmClientService).to receive(:call).and_return(
            { text: "I've been charged twice for my order!" },
            { text: "[END CONVERSATION]" }
          )

          # Mock Response API service
          allow(OpenaiResponseService).to receive(:call).and_return(
            {
              text: "I'm sorry to hear about the double charge. Let me look into that for you.",
              response_id: "resp_123",
              usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
              tool_calls: []
            }
          )
        end

        it "runs a conversation and returns ConversationResult" do
          result = runner.run!

          expect(result).to be_a(ConversationResult)
          expect(result.status).to eq("completed")
          expect(result.messages.length).to eq(2) # 1 user + 1 assistant
        end

        it "records user messages correctly" do
          result = runner.run!

          user_msg = result.user_messages.first
          expect(user_msg[:role]).to eq("user")
          expect(user_msg[:content]).to eq("I've been charged twice for my order!")
          expect(user_msg[:turn]).to eq(1)
          expect(user_msg[:timestamp]).to be_present
        end

        it "records assistant messages correctly" do
          result = runner.run!

          asst_msg = result.assistant_messages.first
          expect(asst_msg[:role]).to eq("assistant")
          expect(asst_msg[:content]).to include("double charge")
          expect(asst_msg[:turn]).to eq(1)
          expect(asst_msg[:response_id]).to eq("resp_123")
        end

        it "uses call_with_context for subsequent turns" do
          # Allow multiple turns
          allow(LlmClientService).to receive(:call).and_return(
            { text: "I've been charged twice!" },
            { text: "Can you refund me?" },
            { text: "[END]" }
          )

          allow(OpenaiResponseService).to receive(:call).and_return(
            { text: "Let me check.", response_id: "resp_1", usage: {}, tool_calls: [] }
          )

          allow(OpenaiResponseService).to receive(:call_with_context).and_return(
            { text: "I've processed your refund.", response_id: "resp_2", usage: {}, tool_calls: [] }
          )

          result = runner.run!

          expect(OpenaiResponseService).to have_received(:call).once
          expect(OpenaiResponseService).to have_received(:call_with_context).once
        end

        it "stops when conversation ends naturally" do
          result = runner.run!

          # Should only have 1 turn since [END CONVERSATION] was returned
          expect(result.total_turns).to eq(1)
        end

        it "includes metadata in result" do
          result = runner.run!

          expect(result.metadata[:model]).to eq(model)
          expect(result.metadata[:max_turns]).to eq(max_turns)
          expect(result.metadata[:tools]).to eq(tools)
          expect(result.metadata[:completed_at]).to be_present
        end

        it "stores previous_response_id in result" do
          result = runner.run!

          expect(result.previous_response_id).to eq("resp_123")
        end
      end

      describe "private methods" do
        describe "#should_end_conversation?" do
          it "returns true for empty message" do
            expect(runner.send(:should_end_conversation?, "")).to be true
          end

          it "returns true for [END CONVERSATION]" do
            expect(runner.send(:should_end_conversation?, "[END CONVERSATION]")).to be true
          end

          it "returns true for [END]" do
            expect(runner.send(:should_end_conversation?, "Thanks! [END]")).to be true
          end

          it "returns false for normal message" do
            expect(runner.send(:should_end_conversation?, "I have a question")).to be false
          end
        end
      end
    end
  end
end
