# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  module Testing
    module Openai
      RSpec.describe AssistantPlaygroundController, type: :controller do
        routes { PromptTracker::Engine.routes }

        let(:assistant) { create(:openai_assistant, assistant_id: "asst_test123") }
        let(:service) { instance_double(AssistantPlaygroundService) }

        before do
          allow(AssistantPlaygroundService).to receive(:new).and_return(service)
        end

        describe "POST #submit_tool_outputs" do
          before do
            allow(service).to receive(:submit_tool_outputs).and_return({
              success: true,
              status: "completed",
              message: { role: "assistant", content: "Done!", created_at: Time.current },
              usage: { total_tokens: 100 }
            })
          end

          it "submits tool outputs and returns success" do
            post :submit_tool_outputs, params: {
              assistant_id: assistant.id,
              thread_id: "thread_123",
              run_id: "run_123",
              tool_outputs: [
                { tool_call_id: "call_123", output: '{"result": "success"}' }
              ]
            }

            expect(response).to be_successful
            json = JSON.parse(response.body)
            expect(json["success"]).to be true
            expect(json["status"]).to eq("completed")
          end

          it "returns error when thread_id is missing" do
            post :submit_tool_outputs, params: {
              assistant_id: assistant.id,
              run_id: "run_123",
              tool_outputs: []
            }

            expect(response).to have_http_status(:unprocessable_entity)
            json = JSON.parse(response.body)
            expect(json["success"]).to be false
            expect(json["error"]).to include("thread_id")
          end

          it "returns error when run_id is missing" do
            post :submit_tool_outputs, params: {
              assistant_id: assistant.id,
              thread_id: "thread_123",
              tool_outputs: []
            }

            expect(response).to have_http_status(:unprocessable_entity)
            json = JSON.parse(response.body)
            expect(json["success"]).to be false
            expect(json["error"]).to include("run_id")
          end

          it "returns requires_action when more function calls are needed" do
            allow(service).to receive(:submit_tool_outputs).and_return({
              success: true,
              status: "requires_action",
              tool_calls: [
                { id: "call_456", function: { name: "another_func", arguments: "{}" } }
              ]
            })

            post :submit_tool_outputs, params: {
              assistant_id: assistant.id,
              thread_id: "thread_123",
              run_id: "run_123",
              tool_outputs: [
                { tool_call_id: "call_123", output: "result" }
              ]
            }

            expect(response).to be_successful
            json = JSON.parse(response.body)
            expect(json["status"]).to eq("requires_action")
            expect(json["tool_calls"]).to be_an(Array)
          end
        end

        describe "POST #create_assistant" do
          before do
            allow(service).to receive(:create_assistant).and_return({
              success: true,
              assistant: assistant
            })
          end

          context "with functions" do
            it "creates assistant with function definitions" do
              # Note: create_assistant is nested under assistants/:assistant_id/playground
              # For new assistants, we use assistant_id: "new"
              post :create_assistant, params: {
                assistant_id: "new",
                assistant: {
                  name: "Test Assistant",
                  model: "gpt-4o",
                  functions: [
                    {
                      name: "get_weather",
                      description: "Get weather for a location",
                      parameters: { type: "object", properties: { location: { type: "string" } } }
                    }
                  ]
                }
              }

              expect(response).to be_successful
              expect(service).to have_received(:create_assistant).with(
                hash_including(
                  name: "Test Assistant",
                  functions: array_including(
                    hash_including(name: "get_weather")
                  )
                )
              )
            end
          end
        end

        describe "POST #send_message" do
          before do
            allow(service).to receive(:create_thread).and_return({
              success: true,
              thread_id: "thread_123"
            })
          end

          it "returns requires_action when function calls are needed" do
            allow(service).to receive(:send_message).and_return({
              success: true,
              status: "requires_action",
              thread_id: "thread_123",
              run_id: "run_123",
              tool_calls: [
                { id: "call_123", function: { name: "get_weather", arguments: '{"location":"NYC"}' } }
              ]
            })

            post :send_message, params: {
              assistant_id: assistant.id,
              content: "What's the weather?"
            }

            expect(response).to be_successful
          end
        end
      end
    end
  end
end
