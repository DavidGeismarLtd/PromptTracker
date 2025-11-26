# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::EvaluationsController", type: :request do
  let(:prompt) { create(:prompt, :with_active_version) }
  let(:version) { prompt.active_version }
  let(:llm_response) { create(:llm_response, prompt_version: version) }
  let!(:evaluation) { create(:evaluation, llm_response: llm_response) }

  describe "GET /evaluations" do
    it "returns success" do
      get "/prompt_tracker/evaluations"
      expect(response).to have_http_status(:success)
    end

    it "filters by evaluator_type" do
      human_eval = create(:evaluation, llm_response: llm_response, evaluator_type: "human")
      automated_eval = create(:evaluation, llm_response: llm_response, evaluator_type: "automated")

      get "/prompt_tracker/evaluations", params: { evaluator_type: "human" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by newest (default)" do
      get "/prompt_tracker/evaluations"
      expect(response).to have_http_status(:success)
    end

    it "sorts by oldest" do
      get "/prompt_tracker/evaluations", params: { sort: "oldest" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by highest_score" do
      get "/prompt_tracker/evaluations", params: { sort: "highest_score" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by lowest_score" do
      get "/prompt_tracker/evaluations", params: { sort: "lowest_score" }
      expect(response).to have_http_status(:success)
    end

    it "calculates summary stats" do
      create(:evaluation, llm_response: llm_response, score: 4.0, score_min: 0, score_max: 5)
      create(:evaluation, llm_response: llm_response, score: 5.0, score_min: 0, score_max: 5)

      get "/prompt_tracker/evaluations"
      expect(response).to have_http_status(:success)
    end

    it "paginates evaluations" do
      create_list(:evaluation, 25, llm_response: llm_response)

      get "/prompt_tracker/evaluations"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /evaluations/:id" do
    it "shows evaluation details" do
      get "/prompt_tracker/evaluations/#{evaluation.id}"
      expect(response).to have_http_status(:success)
    end

    it "includes response and prompt details" do
      get "/prompt_tracker/evaluations/#{evaluation.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(prompt.name)
    end

    it "returns 404 for non-existent evaluation" do
      get "/prompt_tracker/evaluations/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /evaluations" do
    it "creates manual evaluation" do
      expect {
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: llm_response.id,
            evaluator_type: "human",
            evaluator_id: "manual",
            score: 4.5,
            score_min: 0,
            score_max: 5,
            feedback: "Great response!"
          }
        }
      }.to change(PromptTracker::Evaluation, :count).by(1)

      expect(response).to redirect_to("/prompt_tracker/responses/#{llm_response.id}")
      follow_redirect!
      expect(response.body).to include("Evaluation created successfully")
    end

    it "handles invalid evaluation" do
      expect {
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: llm_response.id,
            evaluator_type: "human",
            score: 10, # Invalid - exceeds max
            score_min: 0,
            score_max: 5
          }
        }
      }.not_to change(PromptTracker::Evaluation, :count)

      expect(response).to redirect_to("/prompt_tracker/responses/#{llm_response.id}")
      follow_redirect!
      expect(response.body).to include("Error creating evaluation")
    end

    it "handles non-existent response" do
      post "/prompt_tracker/evaluations", params: {
        evaluation: {
          llm_response_id: 999999,
          evaluator_type: "human",
          score: 4.5
        }
      }

      expect(response).to redirect_to("/prompt_tracker/responses")
      follow_redirect!
      expect(response.body).to include("Response not found")
    end
  end

  describe "GET /evaluations/form_template" do
    it "returns form template for human evaluator" do
      get "/prompt_tracker/evaluations/form_template", params: {
        evaluator_type: "human",
        llm_response_id: llm_response.id
      }
      expect(response).to have_http_status(:success)
    end

    it "returns form template for registry evaluator" do
      get "/prompt_tracker/evaluations/form_template", params: {
        evaluator_type: "registry",
        evaluator_key: "keyword",
        llm_response_id: llm_response.id
      }
      expect(response).to have_http_status(:success)
    end
  end
end
