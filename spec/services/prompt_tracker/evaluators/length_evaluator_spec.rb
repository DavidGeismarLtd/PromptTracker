# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  module Evaluators
    RSpec.describe LengthEvaluator do
      let(:prompt) do
        Prompt.create!(
          name: "test_prompt",
          description: "Test",
          category: "test"
        )
      end

      let(:version) do
        prompt.prompt_versions.create!(
          template: "Test",
          status: "active",
        )
      end

      def create_response(text)
        version.llm_responses.create!(
          rendered_prompt: "Test",
          provider: "openai",
          model: "gpt-4",
          response_text: text,
          status: "success"
        )
      end

      describe "#evaluate_score" do
        it "scores perfect for ideal length" do
          response = create_response("a" * 100) # Within ideal range (50-500)
          evaluator = LengthEvaluator.new(response)

          expect(evaluator.evaluate_score).to eq(100)
        end

        it "scores low for too short response" do
          response = create_response("hi") # 2 chars, below min (10)
          evaluator = LengthEvaluator.new(response)

          expect(evaluator.evaluate_score).to eq(20)
        end

        it "scores low for too long response" do
          response = create_response("a" * 3000) # Above max (2000)
          evaluator = LengthEvaluator.new(response)

          expect(evaluator.evaluate_score).to eq(30)
        end

        it "scores medium for acceptable but not ideal length" do
          response = create_response("a" * 30) # Between min (10) and ideal_min (50)
          evaluator = LengthEvaluator.new(response)

          score = evaluator.evaluate_score
          expect(score).to be > 50
          expect(score).to be < 100
        end

        it "uses custom config" do
          response = create_response("a" * 20)
          evaluator = LengthEvaluator.new(response, {
            min_length: 10,
            max_length: 100,
            ideal_min: 15,
            ideal_max: 25
          })

          expect(evaluator.evaluate_score).to eq(100) # Within custom ideal range
        end

        it "handles empty response" do
          response = create_response("")
          evaluator = LengthEvaluator.new(response)

          expect(evaluator.evaluate_score).to eq(20) # Too short
        end

        it "scales score correctly between min and ideal_min" do
          response1 = create_response("a" * 10) # At min_length
          response2 = create_response("a" * 30) # Between min and ideal_min
          response3 = create_response("a" * 50) # At ideal_min

          evaluator1 = LengthEvaluator.new(response1)
          evaluator2 = LengthEvaluator.new(response2)
          evaluator3 = LengthEvaluator.new(response3)

          score1 = evaluator1.evaluate_score
          score2 = evaluator2.evaluate_score
          score3 = evaluator3.evaluate_score

          expect(score1).to be < score2
          expect(score2).to be < score3
          expect(score3).to eq(100)
        end
      end

      describe "#generate_feedback" do
        it "generates appropriate feedback for too short" do
          response = create_response("hi")
          evaluator = LengthEvaluator.new(response)

          feedback = evaluator.generate_feedback
          expect(feedback).to match(/too short/i)
          expect(feedback).to match(/2 chars/)
        end

        it "generates appropriate feedback for too long" do
          response = create_response("a" * 3000)
          evaluator = LengthEvaluator.new(response)

          feedback = evaluator.generate_feedback
          expect(feedback).to match(/too long/i)
        end

        it "generates appropriate feedback for ideal length" do
          response = create_response("a" * 100)
          evaluator = LengthEvaluator.new(response)

          feedback = evaluator.generate_feedback
          expect(feedback).to match(/ideal/i)
        end
      end

      describe "#evaluate" do
        it "creates evaluation record" do
          response = create_response("a" * 100)
          evaluator = LengthEvaluator.new(response)

          evaluation = evaluator.evaluate

          expect(evaluation).to be_persisted
          expect(evaluation.evaluator_type).to eq("PromptTracker::Evaluators::LengthEvaluator")
          expect(evaluation.score).to eq(100)
          expect(evaluation.score_min).to eq(0)
          expect(evaluation.score_max).to eq(100)
          expect(evaluation.feedback).not_to be_nil
        end

        it "associates evaluation with prompt_test_run when provided in config" do
          response = create_response("a" * 100)
          test_run = create(:prompt_test_run)
          evaluator = LengthEvaluator.new(response, { prompt_test_run_id: test_run.id })

          evaluation = evaluator.evaluate

          expect(evaluation.prompt_test_run_id).to eq(test_run.id)
          expect(evaluation.prompt_test_run).to eq(test_run)
        end
      end

      describe "#metadata" do
        it "includes metadata" do
          response = create_response("a" * 100)
          evaluator = LengthEvaluator.new(response)

          metadata = evaluator.metadata
          expect(metadata[:response_length]).to eq(100)
          expect(metadata[:min_length]).to eq(10)
          expect(metadata[:max_length]).to eq(2000)
          expect(metadata[:ideal_min]).to eq(50)
          expect(metadata[:ideal_max]).to eq(500)
        end
      end
    end
  end
end
