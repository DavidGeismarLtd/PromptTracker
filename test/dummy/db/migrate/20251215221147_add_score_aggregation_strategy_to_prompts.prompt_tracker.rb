# frozen_string_literal: true

# This migration comes from prompt_tracker (originally 20250112000002)
# Migration to add score aggregation strategy to prompts.
#
# This allows each prompt to define how multiple evaluation scores
# should be combined into an overall score.
#
# Supported strategies:
# - simple_average: Average all evaluation scores equally
# - weighted_average: Use weights from evaluator_configs (default)
# - minimum: Take the lowest score (all must pass)
# - custom: Use custom business logic defined in the application
#
# Example:
#   prompt.update!(score_aggregation_strategy: "weighted_average")
#   # Now response.overall_score uses weighted average based on config weights
class AddScoreAggregationStrategyToPrompts < ActiveRecord::Migration[7.2]
  def change
    add_column :prompt_tracker_prompts,
               :score_aggregation_strategy,
               :string,
               default: "weighted_average"

    # Add index for filtering by strategy
    add_index :prompt_tracker_prompts,
              :score_aggregation_strategy,
              name: "index_prompts_on_aggregation_strategy"
  end
end
