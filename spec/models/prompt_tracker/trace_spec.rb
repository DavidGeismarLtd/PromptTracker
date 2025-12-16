# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  RSpec.describe Trace, type: :model do
    describe "validations" do
      it { should validate_presence_of(:name) }
      it { should validate_presence_of(:started_at) }
      it { should validate_inclusion_of(:status).in_array(%w[running completed error]) }
    end

    describe "associations" do
      it { should have_many(:spans).dependent(:destroy) }
      it { should have_many(:llm_responses).dependent(:nullify) }
    end

    describe "scopes" do
      let!(:trace1) { create(:prompt_tracker_trace, session_id: "session_1", user_id: "user_1", status: "running") }
      let!(:trace2) { create(:prompt_tracker_trace, session_id: "session_1", user_id: "user_2", status: "completed") }
      let!(:trace3) { create(:prompt_tracker_trace, session_id: "session_2", user_id: "user_1", status: "error") }

      describe ".in_session" do
        it "returns traces for a specific session" do
          expect(Trace.in_session("session_1")).to contain_exactly(trace1, trace2)
        end
      end

      describe ".for_user" do
        it "returns traces for a specific user" do
          expect(Trace.for_user("user_1")).to contain_exactly(trace1, trace3)
        end
      end

      describe ".running" do
        it "returns only running traces" do
          expect(Trace.running).to contain_exactly(trace1)
        end
      end

      describe ".completed" do
        it "returns only completed traces" do
          expect(Trace.completed).to contain_exactly(trace2)
        end
      end

      describe ".with_errors" do
        it "returns only error traces" do
          expect(Trace.with_errors).to contain_exactly(trace3)
        end
      end
    end

    describe "#complete!" do
      let(:trace) { create(:prompt_tracker_trace, started_at: 2.seconds.ago) }

      it "marks trace as completed" do
        trace.complete!(output: "Final result")

        expect(trace.status).to eq("completed")
        expect(trace.output).to eq("Final result")
        expect(trace.ended_at).to be_present
      end

      it "calculates duration" do
        trace.complete!(output: "Done")

        expect(trace.duration_ms).to be >= 2000
      end
    end

    describe "#mark_error!" do
      let(:trace) { create(:prompt_tracker_trace) }

      it "marks trace as error" do
        trace.mark_error!(error_message: "Something failed")

        expect(trace.status).to eq("error")
        expect(trace.ended_at).to be_present
        expect(trace.metadata["error"]).to eq("Something failed")
      end
    end

    describe "#total_cost" do
      let(:trace) { create(:prompt_tracker_trace) }
      let(:prompt) { create(:prompt) }
      let(:version) { create(:prompt_version, prompt: prompt) }

      it "returns sum of all llm_response costs" do
        create(:llm_response, prompt_version: version, trace: trace, cost_usd: 0.01)
        create(:llm_response, prompt_version: version, trace: trace, cost_usd: 0.02)

        expect(trace.total_cost).to eq(0.03)
      end

      it "returns 0 when no responses" do
        expect(trace.total_cost).to eq(0)
      end
    end

    describe "#total_tokens" do
      let(:trace) { create(:prompt_tracker_trace) }
      let(:prompt) { create(:prompt) }
      let(:version) { create(:prompt_version, prompt: prompt) }

      it "returns sum of all llm_response tokens" do
        create(:llm_response, prompt_version: version, trace: trace, tokens_total: 100)
        create(:llm_response, prompt_version: version, trace: trace, tokens_total: 200)

        expect(trace.total_tokens).to eq(300)
      end

      it "returns 0 when no responses" do
        expect(trace.total_tokens).to eq(0)
      end
    end
  end
end
