# frozen_string_literal: true

module PromptTracker
  # Represents a complete workflow or operation that may contain multiple steps (spans).
  #
  # A Trace is the top-level container for tracking a multi-step LLM workflow.
  # It can contain multiple Spans (steps) and LlmResponses (generations).
  #
  # @example Simple trace with one LLM call
  #   trace = Trace.create!(
  #     name: "greeting_generation",
  #     session_id: "chat_123",
  #     started_at: Time.current
  #   )
  #   # ... do work ...
  #   trace.complete!(output: "Hello!")
  #
  # @example Trace with multiple spans
  #   trace = Trace.create!(name: "rag_qa", session_id: "chat_123", started_at: Time.current)
  #   search_span = trace.spans.create!(name: "search", span_type: "retrieval", started_at: Time.current)
  #   # ... do search ...
  #   search_span.complete!(output: "Found 5 docs")
  #   trace.complete!(output: "Answer generated")
  #
  class Trace < ApplicationRecord
    # Constants
    STATUSES = %w[running completed error].freeze

    # Associations
    has_many :spans, dependent: :destroy, class_name: "PromptTracker::Span"
    has_many :llm_responses, dependent: :nullify, class_name: "PromptTracker::LlmResponse"

    # Validations
    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :started_at, presence: true

    # Scopes
    scope :in_session, ->(session_id) { where(session_id: session_id) }
    scope :for_user, ->(user_id) { where(user_id: user_id) }
    scope :running, -> { where(status: "running") }
    scope :completed, -> { where(status: "completed") }
    scope :with_errors, -> { where(status: "error") }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_save :calculate_duration, if: :ended_at_changed?

    # Marks this trace as successfully completed.
    #
    # @param output [String, nil] the final output of the trace
    # @return [Boolean] true if successful
    def complete!(output: nil)
      update!(
        status: "completed",
        output: output,
        ended_at: Time.current
      )
    end

    # Marks this trace as failed with an error.
    #
    # @param error_message [String] the error message
    # @return [Boolean] true if successful
    def mark_error!(error_message:)
      update!(
        status: "error",
        ended_at: Time.current,
        metadata: (metadata || {}).merge(error: error_message)
      )
    end

    # Returns the total cost of all LLM responses in this trace.
    #
    # @return [BigDecimal] total cost in USD
    def total_cost
      llm_responses.sum(:cost_usd) || 0
    end

    # Returns the total tokens used across all LLM responses in this trace.
    #
    # @return [Integer] total tokens
    def total_tokens
      llm_responses.sum(:tokens_total) || 0
    end

    private

    def calculate_duration
      return unless started_at && ended_at

      self.duration_ms = ((ended_at - started_at) * 1000).round
    end
  end
end
