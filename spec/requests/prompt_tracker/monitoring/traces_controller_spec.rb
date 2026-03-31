# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::Monitoring::TracesController", type: :request do
  let(:prompt) { create(:prompt, :with_active_version) }
  let(:version) { prompt.active_version }

  describe "GET /prompt_tracker/monitoring/traces" do
    it "returns success" do
      get "/prompt_tracker/monitoring/traces"
      expect(response).to have_http_status(:success)
    end

    it "renders created traces" do
      trace = PromptTracker::Trace.create!(
        name: "question_1",
        status: "success",
        started_at: Time.current,
        session_id: "chat_user123"
      )

      get "/prompt_tracker/monitoring/traces"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("question_1")
      expect(response.body).to include("chat_user123")
    end
  end

  describe "GET /prompt_tracker/monitoring/traces/:id" do
    it "returns success and renders hierarchy" do
      trace = PromptTracker::Trace.create!(
        name: "question_1",
        status: "success",
        started_at: Time.current,
        session_id: "chat_user123"
      )

      root_span = PromptTracker::Span.create!(
        trace: trace,
        name: "search_kb",
        status: "success",
        started_at: Time.current
      )

      child_span = PromptTracker::Span.create!(
        trace: trace,
        parent_span: root_span,
        name: "generate_answer",
        status: "success",
        started_at: Time.current
      )

      llm_response = create(
        :llm_response,
        prompt_version: version,
        trace: trace,
        span: child_span,
        provider: "openai",
        model: "gpt-4"
      )

      get "/prompt_tracker/monitoring/traces/#{trace.id}"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("question_1")
      expect(response.body).to include("search_kb")
      expect(response.body).to include("generate_answer")
      expect(response.body).to include("gpt-4")
    end
  end
end
