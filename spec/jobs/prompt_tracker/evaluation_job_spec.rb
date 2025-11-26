# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::EvaluationJob, type: :job do
  include ActiveJob::TestHelper

  let(:prompt) { create(:prompt, :with_active_version) }
  let(:version) { prompt.active_version }
  let(:llm_response) { create(:llm_response, prompt_version: version, response_text: "This is a test response with enough length.") }
  let(:evaluator_config) do
    create(:evaluator_config,
           :disabled,
           configurable: version,
           evaluator_key: "length",
           config: { min_length: 10, max_length: 1000 })
  end

  describe "#perform" do
    it "creates an evaluation for the response" do
      expect {
        described_class.new.perform(llm_response.id, evaluator_config.id)
      }.to change(PromptTracker::Evaluation, :count).by(1)
    end

    it "builds the evaluator from the config" do
      allow(evaluator_config).to receive(:build_evaluator).and_call_original
      allow(PromptTracker::EvaluatorConfig).to receive(:find).and_return(evaluator_config)

      described_class.new.perform(llm_response.id, evaluator_config.id)

      expect(evaluator_config).to have_received(:build_evaluator).with(llm_response)
    end

    it "stores job metadata in the evaluation" do
      described_class.new.perform(llm_response.id, evaluator_config.id)

      evaluation = PromptTracker::Evaluation.last
      expect(evaluation.metadata["evaluator_config_id"]).to eq(evaluator_config.id)
      expect(evaluation.metadata["weight"]).to eq(evaluator_config.weight.to_s)
      expect(evaluation.metadata["priority"]).to eq(evaluator_config.priority)
      expect(evaluation.metadata["executed_at"]).to be_present
    end

    it "logs success message" do
      allow(Rails.logger).to receive(:info)

      described_class.new.perform(llm_response.id, evaluator_config.id)

      expect(Rails.logger).to have_received(:info).with(
        a_string_matching(/Completed evaluation: #{evaluator_config.evaluator_key}/)
      )
    end

    context "with dependency checking" do
      it "skips evaluation when dependency is not met" do
        # Create configs with dependency (disabled to prevent auto-evaluation)
        length_config = create(:evaluator_config,
                               :disabled,
                               configurable: version,
                               evaluator_key: "length",
                               config: { min_length: 10, max_length: 1000 })

        dependency_config = create(:evaluator_config,
                                   :disabled,
                                   configurable: version,
                                   evaluator_key: "keyword",
                                   depends_on: "length",
                                   min_dependency_score: 80,
                                   config: { required_keywords: [ "test" ] })

        # Don't create any dependency evaluation - dependency_met? will return false
        allow(Rails.logger).to receive(:info)

        expect {
          described_class.new.perform(llm_response.id, dependency_config.id, check_dependency: true)
        }.not_to change(PromptTracker::Evaluation, :count)

        expect(Rails.logger).to have_received(:info).with(
          a_string_matching(/Skipping.*dependency not met/)
        )
      end

      it "runs evaluation when dependency is met" do
        # Create configs with dependency (disabled to prevent auto-evaluation)
        length_config = create(:evaluator_config,
                               :disabled,
                               configurable: version,
                               evaluator_key: "length",
                               config: { min_length: 10, max_length: 1000 })

        dependency_config = create(:evaluator_config,
                                   :disabled,
                                   configurable: version,
                                   evaluator_key: "keyword",
                                   depends_on: "length",
                                   min_dependency_score: 80,
                                   config: { required_keywords: [ "test" ] })

        # Create a high-scoring dependency evaluation
        create(:evaluation,
               llm_response: llm_response,
               evaluator_id: "length_evaluator_v1",
               score: 90,
               score_min: 0,
               score_max: 100)

        expect {
          described_class.new.perform(llm_response.id, dependency_config.id, check_dependency: true)
        }.to change(PromptTracker::Evaluation, :count).by(1)
      end

      it "runs evaluation when check_dependency is false" do
        # Create configs with dependency (disabled to prevent auto-evaluation)
        length_config = create(:evaluator_config,
                               :disabled,
                               configurable: version,
                               evaluator_key: "length",
                               config: { min_length: 10, max_length: 1000 })

        dependency_config = create(:evaluator_config,
                                   :disabled,
                                   configurable: version,
                                   evaluator_key: "keyword",
                                   depends_on: "length",
                                   min_dependency_score: 80,
                                   config: { required_keywords: [ "test" ] })

        # Even with no dependency evaluation, should run if check_dependency is false
        expect {
          described_class.new.perform(llm_response.id, dependency_config.id, check_dependency: false)
        }.to change(PromptTracker::Evaluation, :count).by(1)
      end
    end

    context "error handling" do
      it "handles missing response gracefully" do
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.new.perform(999999, evaluator_config.id)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          a_string_matching(/record not found/)
        )
      end

      it "handles missing config gracefully" do
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.new.perform(llm_response.id, 999999)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          a_string_matching(/record not found/)
        )
      end

      it "raises and logs StandardError for retry" do
        allow(Rails.logger).to receive(:error)
        allow(evaluator_config).to receive(:build_evaluator).and_raise(StandardError.new("Test error"))
        allow(PromptTracker::EvaluatorConfig).to receive(:find).and_return(evaluator_config)

        expect {
          described_class.new.perform(llm_response.id, evaluator_config.id)
        }.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end
  end

  describe "job queuing" do
    it "enqueues the job" do
      expect {
        described_class.perform_later(llm_response.id, evaluator_config.id)
      }.to have_enqueued_job(described_class).with(llm_response.id, evaluator_config.id)
    end

    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
