# frozen_string_literal: true

class CreatePromptTrackerSpans < ActiveRecord::Migration[7.2]
  def change
    create_table :prompt_tracker_spans do |t|
      t.references :trace, null: false, foreign_key: { to_table: :prompt_tracker_traces }, index: true
      t.references :parent_span, foreign_key: { to_table: :prompt_tracker_spans }, index: true
      t.string :name, null: false
      t.string :span_type
      t.text :input
      t.text :output
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_ms
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :prompt_tracker_spans, [ :status, :created_at ]
    add_index :prompt_tracker_spans, :span_type
  end
end
