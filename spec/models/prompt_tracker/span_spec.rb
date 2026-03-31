# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Span, type: :model do
  describe "associations" do
    it { should belong_to(:trace).class_name("PromptTracker::Trace") }
    it { should belong_to(:parent_span).class_name("PromptTracker::Span").optional }
    it { should have_many(:child_spans).class_name("PromptTracker::Span").with_foreign_key(:parent_span_id).dependent(:destroy) }
    it { should have_many(:llm_responses).class_name("PromptTracker::LlmResponse").dependent(:nullify) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { should validate_presence_of(:started_at) }
  end

  describe "#duration_ms" do
    it "returns stored duration_ms when present" do
      span = described_class.new(
        trace: PromptTracker::Trace.new(name: "t", status: "success", started_at: Time.current),
        name: "search_kb",
        status: "success",
        started_at: Time.current,
        duration_ms: 250
      )

      expect(span.duration_ms).to eq(250)
    end

    it "computes duration from timestamps when duration_ms is nil" do
      started_at = Time.current
      ended_at = started_at + 0.5
      trace = PromptTracker::Trace.create!(name: "t", status: "success", started_at: started_at)

      span = described_class.new(
        trace: trace,
        name: "search_kb",
        status: "success",
        started_at: started_at,
        ended_at: ended_at,
        duration_ms: nil
      )

      expect(span.duration_ms).to eq(500)
    end

    it "returns nil when ended_at is missing" do
      trace = PromptTracker::Trace.create!(name: "t", status: "running", started_at: Time.current)

      span = described_class.new(
        trace: trace,
        name: "search_kb",
        status: "running",
        started_at: Time.current,
        ended_at: nil,
        duration_ms: nil
      )

      expect(span.duration_ms).to be_nil
    end
  end

  describe "scopes" do
    it "returns only root spans with .roots" do
      trace = PromptTracker::Trace.create!(name: "t", status: "success", started_at: Time.current)

      root = described_class.create!(trace: trace, name: "root", status: "success", started_at: Time.current)
      _child = described_class.create!(trace: trace, name: "child", status: "success", started_at: Time.current, parent_span: root)

      expect(described_class.roots).to contain_exactly(root)
    end

    it "filters by trace with .for_trace" do
      trace1 = PromptTracker::Trace.create!(name: "t1", status: "success", started_at: Time.current)
      trace2 = PromptTracker::Trace.create!(name: "t2", status: "success", started_at: Time.current)

      span1 = described_class.create!(trace: trace1, name: "s1", status: "success", started_at: Time.current)
      _span2 = described_class.create!(trace: trace2, name: "s2", status: "success", started_at: Time.current)

      expect(described_class.for_trace(trace1)).to contain_exactly(span1)
    end
  end
end
