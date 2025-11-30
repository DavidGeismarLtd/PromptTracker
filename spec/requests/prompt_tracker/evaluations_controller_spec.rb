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
      keyword_eval = create(:evaluation, llm_response: llm_response, evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator")
      length_eval = create(:evaluation, llm_response: llm_response, evaluator_type: "PromptTracker::Evaluators::LengthEvaluator")

      get "/prompt_tracker/evaluations", params: { evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator" }
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
      # Verify evaluation details are shown
      expect(response.body).to include("Evaluation ##{evaluation.id}")
      expect(response.body).to include("Response ##{llm_response.id}")
    end

    it "returns 404 for non-existent evaluation" do
      get "/prompt_tracker/evaluations/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /evaluations" do
    context "with llm_judge evaluator" do
      it "creates llm_judge evaluation using config params" do
        # Use mock mode to avoid real API calls
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("PROMPT_TRACKER_LLM_JUDGE_MOCK_MODE").and_return("true")

        expect {
          post "/prompt_tracker/evaluations", params: {
            evaluation: {
              llm_response_id: llm_response.id,
              evaluator_id: "llm_judge"
            },
            config: {
              judge_model: "gpt-4o",
              criteria: [ "accuracy", "helpfulness", "tone" ]
            }
          }
        }.to change(PromptTracker::Evaluation, :count).by(1)

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::LlmJudgeEvaluator")
        expect(evaluation.score).to be_between(0, 5)
        expect(evaluation.feedback).to be_present

        expect(response).to redirect_to("/prompt_tracker/responses/#{llm_response.id}")
        follow_redirect!
        expect(response.body).to include("evaluation completed")
      end
    end

    context "with length evaluator" do
      let(:llm_response) { create(:llm_response, prompt_version: version, response_text: "This is a test response") }

      it "creates automated evaluation using length evaluator" do
        expect {
          post "/prompt_tracker/evaluations", params: {
            evaluation: {
              llm_response_id: llm_response.id,
              evaluator_id: "length"
            },
            config: {
              min_length: 10,
              max_length: 100
            }
          }
        }.to change(PromptTracker::Evaluation, :count).by(1)

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::LengthEvaluator")
        expect(evaluation.passed).to eq(true) # Response is within range
      end

      it "fails when response is too short" do
        short_response = create(:llm_response, prompt_version: version, response_text: "Hi")

        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: short_response.id,
            evaluator_id: "length"
          },
          config: {
            min_length: 10,
            max_length: 100
          }
        }

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.passed).to eq(false)
      end
    end

    context "with keyword evaluator" do
      let(:llm_response) { create(:llm_response, prompt_version: version, response_text: "Hello world, welcome to our service!") }

      it "creates automated evaluation using keyword evaluator" do
        expect {
          post "/prompt_tracker/evaluations", params: {
            evaluation: {
              llm_response_id: llm_response.id,
              evaluator_id: "keyword"
            },
            config: {
              required_keywords: "hello\nwelcome",
              case_sensitive: "false"
            }
          }
        }.to change(PromptTracker::Evaluation, :count).by(1)

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::KeywordEvaluator")
        expect(evaluation.passed).to eq(true)
      end

      it "fails when required keywords are missing" do
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: llm_response.id,
            evaluator_id: "keyword"
          },
          config: {
            required_keywords: "missing\nkeyword",
            case_sensitive: "false"
          }
        }

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.passed).to eq(false)
      end

      it "fails when forbidden keywords are present" do
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: llm_response.id,
            evaluator_id: "keyword"
          },
          config: {
            forbidden_keywords: "hello",
            case_sensitive: "false"
          }
        }

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.passed).to eq(false)
      end
    end

    context "with format evaluator" do
      it "creates automated evaluation using format evaluator for JSON" do
        json_response = create(:llm_response, prompt_version: version, response_text: '{"key": "value"}')

        expect {
          post "/prompt_tracker/evaluations", params: {
            evaluation: {
              llm_response_id: json_response.id,
              evaluator_id: "format"
            },
            config: {
              expected_format: "json"
            }
          }
        }.to change(PromptTracker::Evaluation, :count).by(1)

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::FormatEvaluator")
        expect(evaluation.passed).to eq(true)
      end
    end

    context "with pattern match evaluator" do
      it "creates automated evaluation using pattern match evaluator" do
        response_with_pattern = create(:llm_response, prompt_version: version, response_text: "Error: Something went wrong")

        expect {
          post "/prompt_tracker/evaluations", params: {
            evaluation: {
              llm_response_id: response_with_pattern.id,
              evaluator_id: "pattern_match"
            },
            config: {
              patterns: "/Error:.*/"
            }
          }
        }.to change(PromptTracker::Evaluation, :count).by(1)

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::PatternMatchEvaluator")
        expect(evaluation.passed).to eq(true)
      end
    end

    context "with exact match evaluator" do
      it "creates automated evaluation using exact match evaluator" do
        exact_response = create(:llm_response, prompt_version: version, response_text: "Expected output")

        expect {
          post "/prompt_tracker/evaluations", params: {
            evaluation: {
              llm_response_id: exact_response.id,
              evaluator_id: "exact_match"
            },
            config: {
              expected_text: "Expected output"
            }
          }
        }.to change(PromptTracker::Evaluation, :count).by(1)

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::ExactMatchEvaluator")
        expect(evaluation.passed).to eq(true)
      end

      it "fails when output doesn't match exactly" do
        different_response = create(:llm_response, prompt_version: version, response_text: "Different output")

        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: different_response.id,
            evaluator_id: "exact_match"
          },
          config: {
            expected_text: "Expected output"
          }
        }

        evaluation = PromptTracker::Evaluation.last
        expect(evaluation.passed).to eq(false)
      end
    end

    context "error handling" do
      it "handles invalid evaluator" do
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: llm_response.id,
            evaluator_id: "nonexistent_evaluator"
          }
        }

        expect(response).to redirect_to("/prompt_tracker/responses/#{llm_response.id}")
        follow_redirect!
        expect(response.body).to include("Evaluator not found")
      end

      it "handles non-existent response" do
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: 999999,
            evaluator_id: "keyword"
          }
        }

        expect(response).to redirect_to("/prompt_tracker/responses")
        follow_redirect!
        expect(response.body).to include("Response not found")
      end

      it "handles missing evaluator_id" do
        post "/prompt_tracker/evaluations", params: {
          evaluation: {
            llm_response_id: llm_response.id
          }
        }

        expect(response).to redirect_to("/prompt_tracker/responses/#{llm_response.id}")
        follow_redirect!
        expect(response.body).to include("Evaluator ID is required")
      end
    end
  end

  describe "GET /evaluations/form_template" do
    it "returns form template for llm_judge evaluator" do
      get "/prompt_tracker/evaluations/form_template", params: {
        evaluator_type: "registry",
        evaluator_key: "llm_judge",
        llm_response_id: llm_response.id
      }
      expect(response).to have_http_status(:success)
    end

    it "returns form template for keyword evaluator" do
      get "/prompt_tracker/evaluations/form_template", params: {
        evaluator_type: "registry",
        evaluator_key: "keyword",
        llm_response_id: llm_response.id
      }
      expect(response).to have_http_status(:success)
    end
  end
end
