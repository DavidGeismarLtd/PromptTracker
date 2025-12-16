# frozen_string_literal: true

# This migration comes from prompt_tracker (originally 20250116000003)
class AddTracingToLlmResponses < ActiveRecord::Migration[7.2]
  def change
    add_reference :prompt_tracker_llm_responses, :trace, foreign_key: { to_table: :prompt_tracker_traces }, index: true
    add_reference :prompt_tracker_llm_responses, :span, foreign_key: { to_table: :prompt_tracker_spans }, index: true
  end
end
