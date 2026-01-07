# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  RSpec.describe OpenaiResponseService do
    let(:model) { "gpt-4o" }
    let(:user_prompt) { "What's the weather in Berlin?" }
    let(:system_prompt) { "You are a helpful assistant." }
    let(:mock_client) { double("OpenAI::Client") }
    let(:mock_responses) { double("responses") }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:responses).and_return(mock_responses)
      allow(PromptTracker.configuration).to receive(:api_key_for).with(:openai).and_return("test-api-key")
    end

    describe ".call" do
      let(:api_response) do
        {
          "id" => "resp_abc123",
          "model" => "gpt-4o-2024-08-06",
          "output" => [
            {
              "type" => "message",
              "content" => [
                { "type" => "output_text", "text" => "I don't have access to real-time weather data." }
              ]
            }
          ],
          "usage" => {
            "input_tokens" => 25,
            "output_tokens" => 15
          }
        }
      end

      it "makes a Response API call and returns normalized response" do
        allow(mock_responses).to receive(:create).and_return(api_response)

        response = described_class.call(
          model: model,
          user_prompt: user_prompt,
          system_prompt: system_prompt
        )

        expect(response[:text]).to eq("I don't have access to real-time weather data.")
        expect(response[:response_id]).to eq("resp_abc123")
        expect(response[:model]).to eq("gpt-4o-2024-08-06")
        expect(response[:usage][:prompt_tokens]).to eq(25)
        expect(response[:usage][:completion_tokens]).to eq(15)
        expect(response[:usage][:total_tokens]).to eq(40)
        expect(response[:raw]).to eq(api_response)
      end

      it "passes correct parameters to the API" do
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(
            model: model,
            input: user_prompt,
            instructions: system_prompt,
            temperature: 0.7
          )
        ).and_return(api_response)

        described_class.call(
          model: model,
          user_prompt: user_prompt,
          system_prompt: system_prompt
        )
      end

      it "includes max_output_tokens when max_tokens is provided" do
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(max_output_tokens: 100)
        ).and_return(api_response)

        described_class.call(
          model: model,
          user_prompt: user_prompt,
          max_tokens: 100
        )
      end

      it "raises error when API key is missing" do
        allow(PromptTracker.configuration).to receive(:api_key_for).with(:openai).and_return(nil)

        expect {
          described_class.call(model: model, user_prompt: user_prompt)
        }.to raise_error(OpenaiResponseService::ResponseApiError, /OpenAI API key not configured/)
      end
    end

    describe ".call with tools" do
      let(:api_response_with_tool) do
        {
          "id" => "resp_xyz789",
          "model" => "gpt-4o-2024-08-06",
          "output" => [
            { "type" => "web_search_call", "id" => "ws_123", "status" => "completed" },
            {
              "type" => "message",
              "content" => [
                { "type" => "output_text", "text" => "Based on my search, the weather in Berlin is sunny." }
              ]
            }
          ],
          "usage" => { "input_tokens" => 50, "output_tokens" => 30 }
        }
      end

      it "formats web_search tool correctly" do
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(
            tools: [ { type: "web_search_preview" } ]
          )
        ).and_return(api_response_with_tool)

        described_class.call(
          model: model,
          user_prompt: user_prompt,
          tools: [ :web_search ]
        )
      end

      it "extracts tool calls from response" do
        allow(mock_responses).to receive(:create).and_return(api_response_with_tool)

        response = described_class.call(
          model: model,
          user_prompt: user_prompt,
          tools: [ :web_search ]
        )

        expect(response[:tool_calls]).to be_an(Array)
        expect(response[:tool_calls].first["type"]).to eq("web_search_call")
      end
    end

    describe ".call_with_context" do
      let(:previous_response_id) { "resp_previous123" }
      let(:api_response) do
        {
          "id" => "resp_followup456",
          "model" => "gpt-4o-2024-08-06",
          "output" => [
            {
              "type" => "message",
              "content" => [
                { "type" => "output_text", "text" => "Your name is Alice." }
              ]
            }
          ],
          "usage" => { "input_tokens" => 30, "output_tokens" => 10 }
        }
      end

      it "includes previous_response_id in the API call" do
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(
            previous_response_id: previous_response_id
          )
        ).and_return(api_response)

        described_class.call_with_context(
          model: model,
          user_prompt: "What's my name?",
          previous_response_id: previous_response_id
        )
      end

      it "returns normalized response for multi-turn conversation" do
        allow(mock_responses).to receive(:create).and_return(api_response)

        response = described_class.call_with_context(
          model: model,
          user_prompt: "What's my name?",
          previous_response_id: previous_response_id
        )

        expect(response[:text]).to eq("Your name is Alice.")
        expect(response[:response_id]).to eq("resp_followup456")
      end
    end

    describe "tool formatting" do
      let(:api_response) do
        {
          "id" => "resp_123",
          "model" => "gpt-4o",
          "output" => [],
          "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
        }
      end

      it "formats file_search tool correctly" do
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(
            tools: [ { type: "file_search" } ]
          )
        ).and_return(api_response)

        described_class.call(model: model, user_prompt: user_prompt, tools: [ :file_search ])
      end

      it "formats code_interpreter tool correctly" do
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(
            tools: [ { type: "code_interpreter" } ]
          )
        ).and_return(api_response)

        described_class.call(model: model, user_prompt: user_prompt, tools: [ :code_interpreter ])
      end

      it "passes through custom tool hashes" do
        custom_tool = { type: "function", name: "get_weather" }
        expect(mock_responses).to receive(:create).with(
          parameters: hash_including(
            tools: [ custom_tool ]
          )
        ).and_return(api_response)

        described_class.call(model: model, user_prompt: user_prompt, tools: [ custom_tool ])
      end
    end
  end
end
