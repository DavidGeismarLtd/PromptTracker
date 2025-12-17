# frozen_string_literal: true

require "rails_helper"
require "prompt_tracker/trackable"

module PromptTracker
  RSpec.describe "Tracing Workflow", type: :integration do
    include PromptTracker::Trackable

    let(:prompt) { create(:prompt, name: "test_prompt") }
    let!(:version) do
      create(:prompt_version,
             :active,
             prompt: prompt,
             template: "Hello {{name}}",
             model_config: { "provider" => "openai", "model" => "gpt-4" })
    end

    describe "with_trace helper" do
      it "creates and completes a trace automatically" do
        result = with_trace("test_workflow", session_id: "session_123", user_id: "user_456") do |trace|
          expect(trace).to be_a(Trace)
          expect(trace.status).to eq("running")
          expect(trace.session_id).to eq("session_123")
          expect(trace.user_id).to eq("user_456")

          "workflow result"
        end

        expect(result).to eq("workflow result")

        trace = Trace.last
        expect(trace.status).to eq("completed")
        expect(trace.output).to eq("workflow result")
        expect(trace.ended_at).to be_present
        expect(trace.duration_ms).to be_present
      end

      it "marks trace as error when block raises" do
        expect do
          with_trace("failing_workflow") do |trace|
            raise StandardError, "Something went wrong"
          end
        end.to raise_error(StandardError, "Something went wrong")

        trace = Trace.last
        expect(trace.status).to eq("error")
        expect(trace.metadata["error"]).to eq("Something went wrong")
        expect(trace.ended_at).to be_present
      end
    end

    describe "with_span helper" do
      it "creates and completes a span automatically" do
        with_trace("workflow_with_spans") do |trace|
          result = with_span(trace, "search_step", type: :retrieval, input: "search query") do |span|
            expect(span).to be_a(Span)
            expect(span.trace).to eq(trace)
            expect(span.status).to eq("running")
            expect(span.span_type).to eq("retrieval")
            expect(span.input).to eq("search query")

            "search results"
          end

          expect(result).to eq("search results")

          span = trace.spans.last
          expect(span.status).to eq("completed")
          expect(span.output).to eq("search results")
          expect(span.ended_at).to be_present
          expect(span.duration_ms).to be_present
        end
      end

      it "marks span as error when block raises" do
        expect do
          with_trace("workflow") do |trace|
            with_span(trace, "failing_step") do |span|
              raise StandardError, "Step failed"
            end
          end
        end.to raise_error(StandardError)

        span = Span.last
        expect(span.status).to eq("error")
        expect(span.metadata["error"]).to eq("Step failed")
      end
    end

    describe "integration with track_llm_call" do
      it "links LLM responses to trace and span" do
        llm_response = nil

        with_trace("llm_workflow", session_id: "chat_123") do |trace|
          with_span(trace, "generation", type: :function) do |span|
            result = track_llm_call(
              "test_prompt",
              variables: { name: "John" },
              trace: trace,
              span: span
            ) do |rendered_prompt|
              expect(rendered_prompt).to eq("Hello John")
              "Hi there!"
            end

            llm_response = result[:llm_response]
          end
        end

        expect(llm_response.trace).to eq(Trace.last)
        expect(llm_response.span).to eq(Span.last)
        expect(llm_response.response_text).to eq("Hi there!")
      end
    end

    describe "complex multi-step workflow" do
      it "handles nested spans and multiple LLM calls" do
        with_trace("rag_qa", session_id: "chat_789", input: "What is Rails?") do |trace|
          # Step 1: Search
          docs = with_span(trace, "search_knowledge_base", type: :retrieval) do
            [ "Doc 1", "Doc 2", "Doc 3" ]
          end

          # Step 2: Generate answer
          answer = with_span(trace, "generate_answer", type: :function) do |span|
            result = track_llm_call(
              "test_prompt",
              variables: { name: "context" },
              trace: trace,
              span: span
            ) { |p| "Rails is a web framework" }

            result[:response_text]
          end

          expect(answer).to eq("Rails is a web framework")
        end

        trace = Trace.last
        expect(trace.status).to eq("completed")
        expect(trace.spans.count).to eq(2)
        expect(trace.llm_responses.count).to eq(1)

        search_span = trace.spans.find_by(name: "search_knowledge_base")
        expect(search_span.status).to eq("completed")
        expect(search_span.span_type).to eq("retrieval")

        gen_span = trace.spans.find_by(name: "generate_answer")
        expect(gen_span.status).to eq("completed")
        expect(gen_span.llm_responses.count).to eq(1)
      end
    end
  end
end
