# frozen_string_literal: true

module PromptTracker
  # Represents a unit of work within a trace (can be nested).
  #
  # A Span represents a single step or operation within a larger Trace.
  # Spans can be nested (parent-child relationships) to represent sub-operations.
  #
  # @example Creating a span
  #   span = trace.spans.create!(
  #     name: "search_knowledge_base",
  #     span_type: "retrieval",
  #     started_at: Time.current
  #   )
  #   # ... do work ...
  #   span.complete!(output: "Found 5 results")
  #
  # @example Creating nested spans
  #   parent_span = trace.spans.create!(name: "process", span_type: "function", started_at: Time.current)
  #   child_span = parent_span.create_child_span(name: "validate", span_type: "function")
  #   # ... do work ...
  #   child_span.complete!(output: "Valid")
  #   parent_span.complete!(output: "Processed")
  #
  class Span < ApplicationRecord
    # Constants
    STATUSES = %w[running completed error].freeze
    SPAN_TYPES = %w[function tool retrieval database http].freeze

    # Associations
    belongs_to :trace, class_name: "PromptTracker::Trace"
    belongs_to :parent_span, class_name: "PromptTracker::Span", optional: true
    has_many :child_spans, class_name: "PromptTracker::Span", foreign_key: :parent_span_id, dependent: :destroy
    has_many :llm_responses, dependent: :nullify, class_name: "PromptTracker::LlmResponse"

    # Validations
    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :span_type, inclusion: { in: SPAN_TYPES }, allow_nil: true
    validates :started_at, presence: true

    # Scopes
    scope :root_level, -> { where(parent_span_id: nil) }
    scope :running, -> { where(status: "running") }
    scope :completed, -> { where(status: "completed") }
    scope :with_errors, -> { where(status: "error") }

    # Callbacks
    before_save :calculate_duration, if: :ended_at_changed?

    # Marks this span as successfully completed.
    #
    # @param output [String, nil] the output of the span
    # @return [Boolean] true if successful
    def complete!(output: nil)
      update!(
        status: "completed",
        output: output,
        ended_at: Time.current
      )
    end

    # Marks this span as failed with an error.
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

    # Creates a child span under this span.
    #
    # @param name [String] name of the child span
    # @param span_type [String, nil] type of span (function, tool, retrieval, etc.)
    # @param attrs [Hash] additional attributes
    # @return [Span] the created child span
    def create_child_span(name:, span_type: nil, **attrs)
      child_spans.create!(
        trace: trace,
        name: name,
        span_type: span_type,
        started_at: Time.current,
        status: "running",
        **attrs
      )
    end

    private

    def calculate_duration
      return unless started_at && ended_at

      self.duration_ms = ((ended_at - started_at) * 1000).round
    end
  end
end
