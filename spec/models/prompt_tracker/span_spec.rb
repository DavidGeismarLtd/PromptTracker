# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  RSpec.describe Span, type: :model do
    describe "validations" do
      it { should validate_presence_of(:name) }
      it { should validate_presence_of(:started_at) }
      it { should validate_inclusion_of(:status).in_array(%w[running completed error]) }
      it { should validate_inclusion_of(:span_type).in_array(%w[function tool retrieval database http]).allow_nil }
    end

    describe "associations" do
      it { should belong_to(:trace) }
      it { should belong_to(:parent_span).optional }
      it { should have_many(:child_spans).dependent(:destroy) }
      it { should have_many(:llm_responses).dependent(:nullify) }
    end

    describe "scopes" do
      let(:trace) { create(:prompt_tracker_trace) }
      let!(:root_span) { create(:prompt_tracker_span, trace: trace, parent_span: nil, status: "running") }
      let!(:child_span) { create(:prompt_tracker_span, trace: trace, parent_span: root_span, status: "completed") }
      let!(:error_span) { create(:prompt_tracker_span, trace: trace, parent_span: nil, status: "error") }

      describe ".root_level" do
        it "returns only root-level spans" do
          expect(Span.root_level).to contain_exactly(root_span, error_span)
        end
      end

      describe ".running" do
        it "returns only running spans" do
          expect(Span.running).to contain_exactly(root_span)
        end
      end

      describe ".completed" do
        it "returns only completed spans" do
          expect(Span.completed).to contain_exactly(child_span)
        end
      end

      describe ".with_errors" do
        it "returns only error spans" do
          expect(Span.with_errors).to contain_exactly(error_span)
        end
      end
    end

    describe "#complete!" do
      let(:span) { create(:prompt_tracker_span, started_at: 1.second.ago) }

      it "marks span as completed" do
        span.complete!(output: "Result")

        expect(span.status).to eq("completed")
        expect(span.output).to eq("Result")
        expect(span.ended_at).to be_present
      end

      it "calculates duration" do
        span.complete!(output: "Done")

        expect(span.duration_ms).to be >= 1000
      end
    end

    describe "#mark_error!" do
      let(:span) { create(:prompt_tracker_span) }

      it "marks span as error" do
        span.mark_error!(error_message: "Failed")

        expect(span.status).to eq("error")
        expect(span.ended_at).to be_present
        expect(span.metadata["error"]).to eq("Failed")
      end
    end

    describe "#create_child_span" do
      let(:trace) { create(:prompt_tracker_trace) }
      let(:parent_span) { create(:prompt_tracker_span, trace: trace) }

      it "creates a child span" do
        child = parent_span.create_child_span(
          name: "child_operation",
          span_type: "function"
        )

        expect(child.parent_span).to eq(parent_span)
        expect(child.trace).to eq(trace)
        expect(child.status).to eq("running")
        expect(child.name).to eq("child_operation")
        expect(child.span_type).to eq("function")
      end

      it "sets started_at automatically" do
        child = parent_span.create_child_span(name: "child")

        expect(child.started_at).to be_present
      end
    end
  end
end
