# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AgentRuntimeService, type: :service do
  let(:agent_version) do
    create(:agent_version,
           system_prompt: "You are a helpful customer support assistant.",
           model_config: {
             "provider" => "openai",
             "api" => "chat_completions",
             "model" => "gpt-4",
             "temperature" => 0.7
           })
  end

  let(:deployed_agent) do
    create(:deployed_agent,
           agent_version: agent_version,
           deployment_config: {
             auth: { type: "api_key" },
             rate_limit: { requests_per_minute: 60 },
             conversation_ttl: 3600
           })
  end

  let(:message) { "Hello, how are you?" }
  let(:conversation_id) { "conv_#{SecureRandom.uuid}" }
  let(:metadata) { { user_id: "user_123" } }

  describe ".call" do
    context "with successful execution (no function calls)" do
      it "returns successful result with response text" do
        # Mock LLM service
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "I'm doing well, thank you! How can I help you today?",
            model: "gpt-4",
            usage: { prompt_tokens: 50, completion_tokens: 20, total_tokens: 70 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        result = described_class.call(
          deployed_agent: deployed_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be true
        expect(result.response).to eq("I'm doing well, thank you! How can I help you today?")
        expect(result.conversation_id).to eq(conversation_id)
        expect(result.function_calls).to eq([])
      end

      it "creates conversation record" do
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Hello!",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        expect {
          described_class.call(
            deployed_agent: deployed_agent,
            message: message,
            conversation_id: conversation_id,
            metadata: metadata
          )
        }.to change(PromptTracker::AgentConversation, :count).by(1)

        conversation = PromptTracker::AgentConversation.last
        expect(conversation.conversation_id).to eq(conversation_id)
        expect(conversation.deployed_agent).to eq(deployed_agent)
        expect(conversation.metadata).to eq(metadata.stringify_keys)
      end

      it "adds user and assistant messages to conversation" do
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Response text",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        described_class.call(
          deployed_agent: deployed_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        conversation = PromptTracker::AgentConversation.last
        expect(conversation.messages.length).to eq(2)
        expect(conversation.messages[0]["role"]).to eq("user")
        expect(conversation.messages[0]["content"]).to eq(message)
        expect(conversation.messages[1]["role"]).to eq("assistant")
        expect(conversation.messages[1]["content"]).to eq("Response text")
      end

      it "creates LlmResponse record for tracking" do
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Response",
            model: "gpt-4",
            usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        expect {
          described_class.call(
            deployed_agent: deployed_agent,
            message: message,
            conversation_id: conversation_id,
            metadata: metadata
          )
        }.to change(PromptTracker::LlmResponse, :count).by(1)

        llm_response = PromptTracker::LlmResponse.last
        expect(llm_response.agent_version).to eq(agent_version)
        expect(llm_response.model).to eq("gpt-4")
        expect(llm_response.tokens_prompt).to eq(100)
        expect(llm_response.tokens_completion).to eq(50)
        expect(llm_response.tokens_total).to eq(150)
      end

      it "updates agent stats" do
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Response",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        expect {
          described_class.call(
            deployed_agent: deployed_agent,
            message: message,
            conversation_id: conversation_id,
            metadata: metadata
          )
        }.to change { deployed_agent.reload.request_count }.by(1)
          .and change { deployed_agent.reload.last_request_at }
      end
    end

    context "when conversation_id is not provided" do
      it "generates a new conversation_id" do
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Response",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        result = described_class.call(
          deployed_agent: deployed_agent,
          message: message,
          metadata: metadata
        )

        expect(result.success?).to be true
        expect(result.conversation_id).to be_present
        expect(result.conversation_id).to match(/\A[a-f0-9\-]+\z/)
      end
    end

    context "with existing conversation" do
      it "reuses existing conversation and appends messages" do
        # Create existing conversation with one message
        conversation = create(:agent_conversation,
                            deployed_agent: deployed_agent,
                            conversation_id: conversation_id)
        conversation.add_message(role: "user", content: "First message")
        conversation.add_message(role: "assistant", content: "First response")

        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Second response",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        expect {
          described_class.call(
            deployed_agent: deployed_agent,
            message: "Second message",
            conversation_id: conversation_id,
            metadata: metadata
          )
        }.not_to change(PromptTracker::AgentConversation, :count)

        conversation.reload
        expect(conversation.messages.length).to eq(4)
        expect(conversation.messages[2]["content"]).to eq("Second message")
        expect(conversation.messages[3]["content"]).to eq("Second response")
      end

      it "extends conversation TTL" do
        conversation = create(:agent_conversation,
                            deployed_agent: deployed_agent,
                            conversation_id: conversation_id,
                            expires_at: 10.minutes.from_now)

        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Response",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        described_class.call(
          deployed_agent: deployed_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        conversation.reload
        expect(conversation.expires_at).to be > 50.minutes.from_now
      end
    end

    context "with function calls" do
      let(:function_def) do
        create(:function_definition,
               :deployed,
               name: "get_weather",
               description: "Get weather for a city",
               parameters: {
                 "type" => "object",
                 "properties" => {
                   "city" => { "type" => "string", "description" => "City name" }
                 },
                 "required" => [ "city" ]
               })
      end

      before do
        deployed_agent.function_definitions << function_def
      end

      it "executes functions and tracks function calls" do
        # Mock CodeExecutor to return function result
        executor_result = PromptTracker::CodeExecutor::Result.new(
          success?: true,
          result: { temperature: 22, conditions: "sunny" },
          error: nil,
          execution_time_ms: 150
        )
        allow(PromptTracker::CodeExecutor).to receive(:execute).and_return(executor_result)

        # Mock LLM service
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new) do |**args|
          # Simulate RubyLLM calling the executor
          if args[:function_executor]
            args[:function_executor].call("get_weather", { "city" => "Berlin" })
          end
          mock_service
        end

        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "The weather in Berlin is 22°C and sunny.",
            model: "gpt-4",
            usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
            tool_calls: [
              {
                id: "call_123",
                function_name: "get_weather",
                arguments: { "city" => "Berlin" }
              }
            ],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        result = described_class.call(
          deployed_agent: deployed_agent,
          message: "What's the weather in Berlin?",
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be true
        expect(result.function_calls.length).to eq(1)
        expect(result.function_calls[0][:name]).to eq("get_weather")
        expect(result.function_calls[0][:arguments]).to eq({ "city" => "Berlin" })
      end

      it "creates FunctionExecution record" do
        executor_result = PromptTracker::CodeExecutor::Result.new(
          success?: true,
          result: { temperature: 22 },
          error: nil,
          execution_time_ms: 150
        )
        allow(PromptTracker::CodeExecutor).to receive(:execute).and_return(executor_result)

        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new) do |**args|
          args[:function_executor]&.call("get_weather", { "city" => "Berlin" })
          mock_service
        end

        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "The weather is sunny",
            model: "gpt-4",
            usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
            tool_calls: [
              {
                id: "call_123",
                function_name: "get_weather",
                arguments: { "city" => "Berlin" }
              }
            ],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        expect {
          described_class.call(
            deployed_agent: deployed_agent,
            message: "What's the weather?",
            conversation_id: conversation_id,
            metadata: metadata
          )
        }.to change(PromptTracker::FunctionExecution, :count).by(1)

        execution = PromptTracker::FunctionExecution.last
        expect(execution.function_definition).to eq(function_def)
        expect(execution.deployed_agent).to eq(deployed_agent)
        expect(execution.success).to be true
        expect(execution.result).to eq({ "temperature" => 22 })
      end

      it "handles function execution errors gracefully" do
        executor_result = PromptTracker::CodeExecutor::Result.new(
          success?: false,
          result: nil,
          error: "Connection timeout",
          execution_time_ms: 5000
        )
        allow(PromptTracker::CodeExecutor).to receive(:execute).and_return(executor_result)

        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new) do |**args|
          args[:function_executor]&.call("get_weather", { "city" => "Berlin" })
          mock_service
        end

        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "I'm sorry, I couldn't fetch the weather data.",
            model: "gpt-4",
            usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        result = described_class.call(
          deployed_agent: deployed_agent,
          message: "What's the weather?",
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be true
        execution = PromptTracker::FunctionExecution.last
        expect(execution.success).to be false
        expect(execution.error_message).to eq("Connection timeout")
      end
    end

    context "validation" do
      it "returns error when message is blank" do
        result = described_class.call(
          deployed_agent: deployed_agent,
          message: "",
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be false
        expect(result.error).to eq("Message is required")
      end

      it "returns error when message is too long" do
        long_message = "a" * 10_001

        result = described_class.call(
          deployed_agent: deployed_agent,
          message: long_message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be false
        expect(result.error).to eq("Message too long (max 10,000 characters)")
      end

      it "returns error when conversation_id format is invalid" do
        result = described_class.call(
          deployed_agent: deployed_agent,
          message: message,
          conversation_id: "invalid conversation id with spaces!",
          metadata: metadata
        )

        expect(result.success?).to be false
        expect(result.error).to eq("Conversation ID format invalid")
      end

      it "accepts valid conversation_id formats" do
        mock_service = instance_double(PromptTracker::LlmClients::RubyLlmService)
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return(
          PromptTracker::NormalizedLlmResponse.new(
            text: "Response",
            model: "gpt-4",
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
            tool_calls: [],
            file_search_results: [],
            web_search_results: [],
            code_interpreter_results: [],
            api_metadata: {},
            raw_response: nil
          )
        )

        valid_ids = [
          "conv_123",
          "abc-def-ghi",
          "user_session_456",
          SecureRandom.uuid
        ]

        valid_ids.each do |conv_id|
          result = described_class.call(
            deployed_agent: deployed_agent,
            message: message,
            conversation_id: conv_id,
            metadata: metadata
          )

          expect(result.success?).to be true
        end
      end
    end

    context "error handling" do
      it "handles LLM service errors and updates agent status" do
        allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new)
          .and_raise(StandardError, "API connection failed")

        result = described_class.call(
          deployed_agent: deployed_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be false
        expect(result.error).to eq("Internal error: API connection failed")
        expect(deployed_agent.reload.status).to eq("error")
        expect(deployed_agent.error_message).to eq("API connection failed")
      end

      it "handles RuntimeError and updates agent status" do
        service_instance = described_class.new(deployed_agent, message, conversation_id, metadata)
        allow(service_instance).to receive(:validate_input!)
          .and_raise(PromptTracker::AgentRuntimeService::RuntimeError, "Custom runtime error")

        result = service_instance.execute

        expect(result.success?).to be false
        expect(result.error).to eq("Custom runtime error")
        expect(deployed_agent.reload.status).to eq("error")
      end
    end

    context "with OpenAI Assistants API" do
      let(:assistant_agent_version) do
        create(:agent_version,
               system_prompt: "Assistant system prompt",
               model_config: {
                 "provider" => "openai",
                 "api" => "assistants",
                 "model" => "gpt-4",
                 "temperature" => 0.7,
                 "metadata" => {
                   "assistant_id" => "asst_123"
                 }
               })
      end

      let(:assistant_agent) do
        create(:deployed_agent, agent_version: assistant_agent_version)
      end

      it "calls OpenaiAssistantService" do
        allow(PromptTracker::LlmClients::OpenaiAssistantService).to receive(:call)
          .with(assistant_id: "asst_123", user_message: message)
          .and_return(
            PromptTracker::NormalizedLlmResponse.new(
              text: "Assistant response",
              model: "gpt-4",
              usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
              tool_calls: [],
              file_search_results: [],
              web_search_results: [],
              code_interpreter_results: [],
              api_metadata: {},
              raw_response: nil
            )
          )

        result = described_class.call(
          deployed_agent: assistant_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be true
        expect(result.response).to eq("Assistant response")
        expect(PromptTracker::LlmClients::OpenaiAssistantService).to have_received(:call)
          .with(assistant_id: "asst_123", user_message: message)
      end

      it "raises error when assistant_id is missing" do
        bad_config = assistant_agent_version.model_config.dup
        bad_config["metadata"] = {}
        assistant_agent_version.update!(model_config: bad_config)

        result = described_class.call(
          deployed_agent: assistant_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be false
        expect(result.error).to eq("Assistant ID not configured")
      end
    end

    context "with OpenAI Responses API" do
      let(:responses_agent_version) do
        create(:agent_version,
               model_config: {
                 "provider" => "openai",
                 "api" => "responses",
                 "model" => "gpt-4"
               })
      end

      let(:responses_agent) do
        create(:deployed_agent, agent_version: responses_agent_version)
      end

      it "raises not supported error" do
        result = described_class.call(
          deployed_agent: responses_agent,
          message: message,
          conversation_id: conversation_id,
          metadata: metadata
        )

        expect(result.success?).to be false
        expect(result.error).to eq("OpenAI Responses API not yet supported for deployed agents")
      end
    end
  end
end
