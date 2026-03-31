# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_traces
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  input       :text
#  output      :text
#  status      :string           default("running"), not null
#  session_id  :string
#  user_id     :string
#  started_at  :datetime         not null
#  ended_at    :datetime
#  duration_ms :integer
#  metadata    :jsonb
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
module PromptTracker
  # Trace groups related operations (spans and LLM calls) under a single
  # high-level name. It provides a simple, Langfuse-style tracing primitive
  # that can be used to inspect a full flow end-to-end.
  #
  # Traces are intentionally minimal:
  # - name:      short label like "question_1" or "checkout_flow"
  # - session_id:optional string to group multiple traces (e.g. chat session)
  # - status:   simple lifecycle (running/success/error/cancelled)
  # - timing:   started_at / ended_at with derived duration_ms
  #
  # LlmResponses can point back to a Trace (and optionally a Span) so that
  # monitoring views can reconstruct a simple hierarchy.
  class Trace < ApplicationRecord
    STATUSES = %w[running success error cancelled].freeze

    # Associations
    has_many :spans,
             class_name: "PromptTracker::Span",
             inverse_of: :trace,
             dependent: :destroy

    has_many :llm_responses,
             class_name: "PromptTracker::LlmResponse",
             inverse_of: :trace,
             dependent: :nullify

    # Validations
    validates :name, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :started_at, presence: true

    # Scopes
    scope :recent, -> { order(started_at: :desc) }
    scope :for_session, ->(session_id) { where(session_id: session_id) }

    # Prefer the stored duration_ms when present, but fall back to computing it
    # from started_at/ended_at so callers always get a useful value.
    #
    # @return [Integer, nil] duration in milliseconds, or nil if not finished
    def duration_ms
      self[:duration_ms] || computed_duration_ms
    end

    def running?
      status == "running"
    end

    private

    def computed_duration_ms
      return nil unless ended_at && started_at

      ((ended_at - started_at) * 1000).round
    end
  end
end
