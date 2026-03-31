# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_spans
#
#  id             :bigint           not null, primary key
#  trace_id       :bigint           not null
#  parent_span_id :bigint
#  name           :string           not null
#  span_type      :string
#  input          :text
#  output         :text
#  status         :string           default("running"), not null
#  started_at     :datetime         not null
#  ended_at       :datetime
#  duration_ms    :integer
#  metadata       :jsonb
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
module PromptTracker
  # Span represents a single step within a Trace. Spans can be nested
  # (parent_span/child_spans) to capture hierarchical workflows, and
  # LlmResponses can attach to a Span for precise context.
  class Span < ApplicationRecord
    STATUSES = %w[running success error cancelled].freeze

    # Associations
    belongs_to :trace,
               class_name: "PromptTracker::Trace",
               inverse_of: :spans

    belongs_to :parent_span,
               class_name: "PromptTracker::Span",
               optional: true,
               inverse_of: :child_spans

    has_many :child_spans,
             class_name: "PromptTracker::Span",
             foreign_key: :parent_span_id,
             inverse_of: :parent_span,
             dependent: :destroy

    has_many :llm_responses,
             class_name: "PromptTracker::LlmResponse",
             inverse_of: :span,
             dependent: :nullify

    # Validations
    validates :name, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :started_at, presence: true

    # Scopes
    scope :roots, -> { where(parent_span_id: nil) }
    scope :for_trace, ->(trace) { where(trace_id: trace.id) }

    # Prefer stored duration_ms when present, but compute from timestamps when
    # it is nil so callers always get a useful value.
    #
    # @return [Integer, nil] duration in milliseconds, or nil if not finished
    def duration_ms
      self[:duration_ms] || computed_duration_ms
    end

    private

    def computed_duration_ms
      return nil unless ended_at && started_at

      ((ended_at - started_at) * 1000).round
    end
  end
end
