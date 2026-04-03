# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AbTestAnalyzer do
  let(:prompt) { create(:agent) }
  let(:version_a) { create(:agent_version, agent: prompt, version_number: 1) }
  let(:version_b) { create(:agent_version, agent: prompt, version_number: 2) }
  let(:ab_test) do
    create(:ab_test, :running,
           agent: prompt,
           version_a: version_a,
           version_b: version_b,
           metric_to_optimize: "response_time",
           optimization_direction: "minimize",
           minimum_sample_size: 20)
  end

  describe "#ready_for_analysis?" do
    context "when test is not running" do
      it "returns false" do
        ab_test.update!(status: "draft")
        analyzer = described_class.new(ab_test)

        expect(analyzer.ready_for_analysis?).to be false
      end
    end

    context "when test has fewer than 10 responses" do
      it "returns false" do
        create_list(:llm_response, 5, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
        analyzer = described_class.new(ab_test)

        expect(analyzer.ready_for_analysis?).to be false
      end
    end

    context "when test is running and has 10+ responses" do
      it "returns true" do
        create_list(:llm_response, 6, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
        create_list(:llm_response, 5, agent_version: version_b, ab_test: ab_test, ab_variant: "B")
        analyzer = described_class.new(ab_test)

        expect(analyzer.ready_for_analysis?).to be true
      end
    end
  end

  describe "#sample_size_met?" do
    context "when minimum_sample_size is not set" do
      it "returns false" do
        ab_test.update!(minimum_sample_size: nil)
        analyzer = described_class.new(ab_test)

        expect(analyzer.sample_size_met?).to be false
      end
    end

    context "when total responses is less than minimum" do
      it "returns false" do
        create_list(:llm_response, 10, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
        analyzer = described_class.new(ab_test)

        expect(analyzer.sample_size_met?).to be false
      end
    end

    context "when total responses meets minimum" do
      it "returns true" do
        create_list(:llm_response, 12, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
        create_list(:llm_response, 10, agent_version: version_b, ab_test: ab_test, ab_variant: "B")
        analyzer = described_class.new(ab_test)

        expect(analyzer.sample_size_met?).to be true
      end
    end
  end

  describe "#analyze" do
    context "when not ready for analysis" do
      it "returns nil" do
        analyzer = described_class.new(ab_test)
        expect(analyzer.analyze).to be_nil
      end
    end

    context "when ready for analysis" do
      before do
        # Create responses for variant A (slower)
        create_list(:llm_response, 10,
                    agent_version: version_a,
                    ab_test: ab_test,
                    ab_variant: "A",
                    response_time_ms: 1500)

        # Create responses for variant B (faster)
        create_list(:llm_response, 10,
                    agent_version: version_b,
                    ab_test: ab_test,
                    ab_variant: "B",
                    response_time_ms: 1000)
      end

      it "returns analysis results" do
        analyzer = described_class.new(ab_test)
        results = analyzer.analyze

        expect(results).to be_a(Hash)
        expect(results).to have_key(:variants)
        expect(results).to have_key(:winner)
        expect(results).to have_key(:p_value)
        expect(results).to have_key(:confidence)
        expect(results).to have_key(:improvement)
        expect(results).to have_key(:significant)
        expect(results).to have_key(:sample_size_met)
        expect(results).to have_key(:analyzed_at)
      end

      it "calculates variant statistics correctly" do
        analyzer = described_class.new(ab_test)
        results = analyzer.analyze

        expect(results[:variants]["A"][:mean]).to eq(1500)
        expect(results[:variants]["A"][:count]).to eq(10)
        expect(results[:variants]["B"][:mean]).to eq(1000)
        expect(results[:variants]["B"][:count]).to eq(10)
      end

      it "identifies the winner correctly for minimize optimization" do
        analyzer = described_class.new(ab_test)
        results = analyzer.analyze

        # B has lower response time, so it should win for minimize
        expect(results[:winner]).to eq("B")
      end

      it "calculates improvement percentage" do
        analyzer = described_class.new(ab_test)
        results = analyzer.analyze

        # B is 33.3% faster than A: (1500 - 1000) / 1500 = 0.333
        expect(results[:improvement]).to be_within(1).of(33.3)
      end
    end

    context "when optimizing for maximize" do
      before do
        ab_test.update!(metric_to_optimize: "quality_score", optimization_direction: "maximize")

        # Create responses with evaluations for variant A (lower quality)
        10.times do
          response = create(:llm_response, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
          create(:evaluation, llm_response: response, score: 3.0, score_max: 5)
        end

        # Create responses with evaluations for variant B (higher quality)
        10.times do
          response = create(:llm_response, agent_version: version_b, ab_test: ab_test, ab_variant: "B")
          create(:evaluation, llm_response: response, score: 4.5, score_max: 5)
        end
      end

      it "identifies the winner correctly for maximize optimization" do
        analyzer = described_class.new(ab_test)
        results = analyzer.analyze

        # B has higher quality score, so it should win for maximize
        expect(results[:winner]).to eq("B")
      end
    end
  end

  describe "#current_leader" do
    context "when no responses exist" do
      it "returns nil" do
        analyzer = described_class.new(ab_test)
        expect(analyzer.current_leader).to be_nil
      end
    end

    context "when responses exist" do
      before do
        create_list(:llm_response, 5,
                    agent_version: version_a,
                    ab_test: ab_test,
                    ab_variant: "A",
                    response_time_ms: 1500)
        create_list(:llm_response, 5,
                    agent_version: version_b,
                    ab_test: ab_test,
                    ab_variant: "B",
                    response_time_ms: 1000)
      end

      it "returns the current leader" do
        analyzer = described_class.new(ab_test)
        # B has lower response time for minimize optimization
        expect(analyzer.current_leader).to eq("B")
      end
    end
  end
end
