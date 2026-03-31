# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Trace, type: :model do
  describe "associations" do
    it { should have_many(:spans).class_name("PromptTracker::Span").dependent(:destroy) }
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
      trace = described_class.new(
        name: "checkout_flow",
        status: "success",
        started_at: Time.current,
        duration_ms: 123
      )

      expect(trace.duration_ms).to eq(123)
    end

    it "computes duration from timestamps when duration_ms is nil" do
      started_at = Time.current
      ended_at = started_at + 1.234

      trace = described_class.new(
        name: "checkout_flow",
        status: "success",
        started_at: started_at,
        ended_at: ended_at,
        duration_ms: nil
      )

      expect(trace.duration_ms).to eq(1234)
    end

    it "returns nil when ended_at is missing" do
      trace = described_class.new(
        name: "checkout_flow",
        status: "running",
        started_at: Time.current,
        ended_at: nil,
        duration_ms: nil
      )

      expect(trace.duration_ms).to be_nil
    end
  end

  describe "scopes" do
    it "filters by session with .for_session" do
      matching = described_class.create!(
        name: "t1",
        status: "success",
        started_at: Time.current,
        session_id: "session-1"
      )
      _other = described_class.create!(
        name: "t2",
        status: "success",
        started_at: Time.current,
        session_id: "session-2"
      )

      expect(described_class.for_session("session-1")).to contain_exactly(matching)
    end

    it "orders by started_at desc with .recent" do
      older = described_class.create!(
        name: "old",
        status: "success",
        started_at: 2.hours.ago
      )
      newer = described_class.create!(
        name: "new",
        status: "success",
        started_at: 1.hour.ago
      )

      expect(described_class.recent.first).to eq(newer)
      expect(described_class.recent.last).to eq(older)
    end
  end
end
