# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class AbTestTest < ActiveSupport::TestCase
    # Setup
    def setup
      @prompt = prompts(:greeting)
      @version_1 = prompt_versions(:greeting_v1)
      @version_2 = prompt_versions(:greeting_v2)

      @valid_attributes = {
        prompt: @prompt,
        name: "Test A/B Test",
        description: "Testing shorter greeting",
        hypothesis: "Version 2 will reduce response time by 20%",
        metric_to_optimize: "response_time",
        optimization_direction: "minimize",
        traffic_split: { "A" => 50, "B" => 50 },
        variants: [
          { "name" => "A", "version_id" => @version_1.id, "description" => "Current version" },
          { "name" => "B", "version_id" => @version_2.id, "description" => "Shorter version" }
        ],
        confidence_level: 0.95,
        minimum_sample_size: 100
      }
    end

    # Validation Tests

    test "should be valid with valid attributes" do
      ab_test = AbTest.new(@valid_attributes)
      assert ab_test.valid?, "AbTest should be valid with valid attributes"
    end

    test "should require name" do
      ab_test = AbTest.new(@valid_attributes.except(:name))
      assert_not ab_test.valid?, "AbTest should not be valid without name"
      assert_includes ab_test.errors[:name], "can't be blank"
    end

    test "should require status" do
      ab_test = AbTest.new(@valid_attributes.merge(status: nil))
      assert_not ab_test.valid?, "AbTest should not be valid without status"
      assert_includes ab_test.errors[:status], "can't be blank"
    end

    test "should validate status inclusion" do
      valid_statuses = %w[draft running paused completed cancelled]
      valid_statuses.each do |status|
        ab_test = AbTest.new(@valid_attributes.merge(status: status))
        assert ab_test.valid?, "Status '#{status}' should be valid"
      end

      ab_test = AbTest.new(@valid_attributes.merge(status: "invalid"))
      assert_not ab_test.valid?, "Invalid status should not be valid"
      assert_includes ab_test.errors[:status], "is not included in the list"
    end

    test "should require metric_to_optimize" do
      ab_test = AbTest.new(@valid_attributes.except(:metric_to_optimize))
      assert_not ab_test.valid?, "AbTest should not be valid without metric_to_optimize"
      assert_includes ab_test.errors[:metric_to_optimize], "can't be blank"
    end

    test "should validate metric_to_optimize inclusion" do
      valid_metrics = %w[cost response_time quality_score success_rate custom]
      valid_metrics.each do |metric|
        ab_test = AbTest.new(@valid_attributes.merge(metric_to_optimize: metric))
        assert ab_test.valid?, "Metric '#{metric}' should be valid"
      end

      ab_test = AbTest.new(@valid_attributes.merge(metric_to_optimize: "invalid"))
      assert_not ab_test.valid?, "Invalid metric should not be valid"
    end

    test "should require optimization_direction" do
      ab_test = AbTest.new(@valid_attributes.merge(optimization_direction: nil))
      assert_not ab_test.valid?, "AbTest should not be valid without optimization_direction"
    end

    test "should validate optimization_direction inclusion" do
      %w[minimize maximize].each do |direction|
        ab_test = AbTest.new(@valid_attributes.merge(optimization_direction: direction))
        assert ab_test.valid?, "Direction '#{direction}' should be valid"
      end

      ab_test = AbTest.new(@valid_attributes.merge(optimization_direction: "invalid"))
      assert_not ab_test.valid?, "Invalid direction should not be valid"
    end

    test "should require traffic_split" do
      ab_test = AbTest.new(@valid_attributes.merge(traffic_split: nil))
      assert_not ab_test.valid?, "AbTest should not be valid without traffic_split"
    end

    test "should validate traffic_split sums to 100" do
      ab_test = AbTest.new(@valid_attributes.merge(traffic_split: { "A" => 50, "B" => 50 }))
      assert ab_test.valid?, "Traffic split summing to 100 should be valid"

      ab_test = AbTest.new(@valid_attributes.merge(traffic_split: { "A" => 60, "B" => 30 }))
      assert_not ab_test.valid?, "Traffic split not summing to 100 should be invalid"
      assert_includes ab_test.errors[:traffic_split], "percentages must sum to 100 (currently 90)"
    end

    test "should require variants" do
      ab_test = AbTest.new(@valid_attributes.merge(variants: nil))
      assert_not ab_test.valid?, "AbTest should not be valid without variants"
    end

    test "should validate variants structure" do
      # Valid variants
      ab_test = AbTest.new(@valid_attributes)
      assert ab_test.valid?, "Valid variants should be valid"

      # Missing name
      ab_test = AbTest.new(@valid_attributes.merge(
        variants: [{ "version_id" => @version_1.id }]
      ))
      assert_not ab_test.valid?, "Variant without name should be invalid"

      # Missing version_id
      ab_test = AbTest.new(@valid_attributes.merge(
        variants: [{ "name" => "A" }]
      ))
      assert_not ab_test.valid?, "Variant without version_id should be invalid"
    end

    test "should validate variants reference valid versions" do
      ab_test = AbTest.new(@valid_attributes.merge(
        variants: [
          { "name" => "A", "version_id" => 99999, "description" => "Invalid" }
        ]
      ))
      assert_not ab_test.valid?, "Variant with invalid version_id should be invalid"
      assert_match(/non-existent version/, ab_test.errors[:variants].first)
    end

    test "should not allow duplicate variant names" do
      ab_test = AbTest.new(@valid_attributes.merge(
        variants: [
          { "name" => "A", "version_id" => @version_1.id },
          { "name" => "A", "version_id" => @version_2.id }
        ]
      ))
      assert_not ab_test.valid?, "Duplicate variant names should be invalid"
      assert_match(/duplicate names/, ab_test.errors[:variants].first)
    end

    test "should validate confidence_level range" do
      ab_test = AbTest.new(@valid_attributes.merge(confidence_level: 0.95))
      assert ab_test.valid?, "Confidence level 0.95 should be valid"

      ab_test = AbTest.new(@valid_attributes.merge(confidence_level: 0))
      assert_not ab_test.valid?, "Confidence level 0 should be invalid"

      ab_test = AbTest.new(@valid_attributes.merge(confidence_level: 1))
      assert_not ab_test.valid?, "Confidence level 1 should be invalid"
    end

    test "should validate minimum_sample_size is positive integer" do
      ab_test = AbTest.new(@valid_attributes.merge(minimum_sample_size: 100))
      assert ab_test.valid?, "Positive sample size should be valid"

      ab_test = AbTest.new(@valid_attributes.merge(minimum_sample_size: 0))
      assert_not ab_test.valid?, "Zero sample size should be invalid"

      ab_test = AbTest.new(@valid_attributes.merge(minimum_sample_size: -10))
      assert_not ab_test.valid?, "Negative sample size should be invalid"
    end

    test "should only allow one running test per prompt" do
      # Create first running test
      AbTest.create!(@valid_attributes.merge(status: "running"))

      # Try to create second running test
      ab_test = AbTest.new(@valid_attributes.merge(
        name: "Another test",
        status: "running"
      ))
      assert_not ab_test.valid?, "Second running test should be invalid"
      assert_includes ab_test.errors[:base], "Only one running test allowed per prompt"
    end

    test "should allow multiple draft tests per prompt" do
      AbTest.create!(@valid_attributes.merge(status: "draft"))
      ab_test = AbTest.new(@valid_attributes.merge(name: "Another test", status: "draft"))
      assert ab_test.valid?, "Multiple draft tests should be allowed"
    end

    # Association Tests

    test "should belong to prompt" do
      ab_test = AbTest.create!(@valid_attributes)
      assert_equal @prompt, ab_test.prompt
    end

    test "should have many llm_responses" do
      ab_test = AbTest.create!(@valid_attributes)
      assert_respond_to ab_test, :llm_responses
    end

    # Scope Tests

    test "draft scope should return only draft tests" do
      AbTest.create!(@valid_attributes.merge(status: "draft"))
      AbTest.create!(@valid_attributes.merge(name: "Running test", status: "running"))

      assert_equal 1, AbTest.draft.count
      assert_equal "draft", AbTest.draft.first.status
    end

    test "running scope should return only running tests" do
      AbTest.create!(@valid_attributes.merge(status: "draft"))
      AbTest.create!(@valid_attributes.merge(name: "Running test", status: "running"))

      assert_equal 1, AbTest.running.count
      assert_equal "running", AbTest.running.first.status
    end

    test "completed scope should return only completed tests" do
      AbTest.create!(@valid_attributes.merge(status: "completed"))
      AbTest.create!(@valid_attributes.merge(name: "Running test", status: "running"))

      assert_equal 1, AbTest.completed.count
      assert_equal "completed", AbTest.completed.first.status
    end

    test "for_prompt scope should return tests for specific prompt" do
      other_prompt = Prompt.create!(name: "other_prompt", description: "Other")
      AbTest.create!(@valid_attributes)
      AbTest.create!(@valid_attributes.merge(prompt: other_prompt, name: "Other test"))

      assert_equal 1, AbTest.for_prompt(@prompt.id).count
      assert_equal @prompt, AbTest.for_prompt(@prompt.id).first.prompt
    end

    # State Management Tests

    test "start! should set status to running and set started_at" do
      ab_test = AbTest.create!(@valid_attributes)
      assert_nil ab_test.started_at

      ab_test.start!

      assert_equal "running", ab_test.status
      assert_not_nil ab_test.started_at
    end

    test "pause! should set status to paused" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))
      ab_test.pause!

      assert_equal "paused", ab_test.status
    end

    test "resume! should set status back to running" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "paused"))
      ab_test.resume!

      assert_equal "running", ab_test.status
    end

    test "complete! should set status to completed and set completed_at" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))
      ab_test.complete!(winner: "A")

      assert_equal "completed", ab_test.status
      assert_not_nil ab_test.completed_at
      assert_equal "A", ab_test.results["winner"]
    end

    test "cancel! should set status to cancelled and set cancelled_at" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))
      ab_test.cancel!

      assert_equal "cancelled", ab_test.status
      assert_not_nil ab_test.cancelled_at
    end

    # Variant Selection Tests

    test "select_variant should return a variant name" do
      ab_test = AbTest.create!(@valid_attributes)
      variant = ab_test.select_variant

      assert_includes ["A", "B"], variant
    end

    test "select_variant should respect traffic split distribution" do
      ab_test = AbTest.create!(@valid_attributes.merge(
        traffic_split: { "A" => 100, "B" => 0 }
      ))

      # Should always return A with 100% traffic
      10.times do
        assert_equal "A", ab_test.select_variant
      end
    end

    test "version_for_variant should return correct version" do
      ab_test = AbTest.create!(@valid_attributes)

      assert_equal @version_1, ab_test.version_for_variant("A")
      assert_equal @version_2, ab_test.version_for_variant("B")
    end

    test "version_for_variant should return nil for invalid variant" do
      ab_test = AbTest.create!(@valid_attributes)

      assert_nil ab_test.version_for_variant("Z")
    end

    test "variant_names should return all variant names" do
      ab_test = AbTest.create!(@valid_attributes)

      assert_equal ["A", "B"], ab_test.variant_names
    end

    # Status Check Tests

    test "running? should return true when status is running" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))
      assert ab_test.running?

      ab_test.update!(status: "draft")
      assert_not ab_test.running?
    end

    test "completed? should return true when status is completed" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "completed"))
      assert ab_test.completed?

      ab_test.update!(status: "running")
      assert_not ab_test.completed?
    end

    test "paused? should return true when status is paused" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "paused"))
      assert ab_test.paused?
    end

    test "cancelled? should return true when status is cancelled" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "cancelled"))
      assert ab_test.cancelled?
    end

    test "draft? should return true when status is draft" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "draft"))
      assert ab_test.draft?
    end

    # Duration Tests

    test "duration_days should return nil if not started" do
      ab_test = AbTest.create!(@valid_attributes)
      assert_nil ab_test.duration_days
    end

    test "duration_days should calculate duration for running test" do
      ab_test = AbTest.create!(@valid_attributes.merge(
        status: "running",
        started_at: 5.days.ago
      ))

      assert_in_delta 5.0, ab_test.duration_days, 0.1
    end

    test "duration_days should use completed_at for completed test" do
      ab_test = AbTest.create!(@valid_attributes.merge(
        status: "completed",
        started_at: 10.days.ago,
        completed_at: 3.days.ago
      ))

      assert_in_delta 7.0, ab_test.duration_days, 0.1
    end

    # Response Counting Tests

    test "total_responses should return count of all responses" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))

      # Create some responses (would need fixtures or factory)
      # For now, just test the method exists
      assert_equal 0, ab_test.total_responses
    end

    test "responses_for_variant should return count for specific variant" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))

      assert_equal 0, ab_test.responses_for_variant("A")
      assert_equal 0, ab_test.responses_for_variant("B")
    end

    # Winner Promotion Tests

    test "promote_winner! should raise error if test not completed" do
      ab_test = AbTest.create!(@valid_attributes.merge(status: "running"))

      assert_raises(StandardError, "Test must be completed") do
        ab_test.promote_winner!
      end
    end

    test "promote_winner! should raise error if no winner declared" do
      ab_test = AbTest.create!(@valid_attributes.merge(
        status: "completed",
        results: {}
      ))

      assert_raises(StandardError, "No winner declared") do
        ab_test.promote_winner!
      end
    end

    test "promote_winner! should activate winning version" do
      ab_test = AbTest.create!(@valid_attributes.merge(
        status: "completed",
        results: { "winner" => "B" }
      ))

      ab_test.promote_winner!

      @version_2.reload
      assert @version_2.active?, "Winning version should be activated"

      @version_1.reload
      assert @version_1.deprecated?, "Losing version should be deprecated"
    end

    # Multi-variant Tests

    test "should support more than 2 variants" do
      version_3 = @prompt.prompt_versions.create!(
        template: "Version 3",
        version_number: 3,
        status: "draft",
        source: "web_ui"
      )

      ab_test = AbTest.new(@valid_attributes.merge(
        traffic_split: { "A" => 33, "B" => 33, "C" => 34 },
        variants: [
          { "name" => "A", "version_id" => @version_1.id },
          { "name" => "B", "version_id" => @version_2.id },
          { "name" => "C", "version_id" => version_3.id }
        ]
      ))

      assert ab_test.valid?, "Multi-variant test should be valid"
      assert_equal 3, ab_test.variant_names.length
    end

    test "should support uneven traffic splits" do
      ab_test = AbTest.new(@valid_attributes.merge(
        traffic_split: { "A" => 80, "B" => 20 }
      ))

      assert ab_test.valid?, "Uneven traffic split should be valid"
    end
  end
end
