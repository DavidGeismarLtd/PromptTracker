# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Controller for viewing tracing sessions in monitoring context
    class SessionsController < ApplicationController
      # GET /sessions
      # List all unique sessions with summary metrics
      def index
        # Get unique session_ids
        session_ids = Trace.where.not(session_id: nil)
                           .distinct
                           .pluck(:session_id)
                           .compact

        # Filter by user_id if provided
        if params[:user_id].present?
          session_ids = Trace.where(session_id: session_ids, user_id: params[:user_id])
                             .distinct
                             .pluck(:session_id)
        end

        # Filter by date range
        if params[:start_date].present? || params[:end_date].present?
          query = Trace.where(session_id: session_ids)
          query = query.where("created_at >= ?", params[:start_date]) if params[:start_date].present?
          query = query.where("created_at <= ?", params[:end_date]) if params[:end_date].present?
          session_ids = query.distinct.pluck(:session_id)
        end

        # Load all traces for these sessions with nested data
        all_traces = Trace.where(session_id: session_ids)
                          .includes(
                            spans: { llm_responses: :evaluations },
                            llm_responses: [ :prompt_version, :evaluations ]
                          )
                          .order(created_at: :desc)

        # Group traces by session_id and calculate metrics
        @sessions = session_ids.map do |session_id|
          session_traces = all_traces.select { |t| t.session_id == session_id }
          {
            session_id: session_id,
            traces: session_traces,
            trace_count: session_traces.count,
            completed_count: session_traces.count { |t| t.status == "completed" },
            error_count: session_traces.count { |t| t.status == "error" },
            first_activity: session_traces.map(&:started_at).compact.min,
            last_activity: session_traces.map { |t| t.ended_at || t.started_at }.compact.max
          }
        end

        # Sort by last activity
        @sessions.sort_by! { |s| s[:last_activity] || Time.at(0) }
        @sessions.reverse!

        # Pagination
        @sessions = Kaminari.paginate_array(@sessions).page(params[:page]).per(25)

        # Get unique users for filter dropdown
        @users = Trace.where.not(user_id: nil).distinct.pluck(:user_id).compact.sort
      end

      # GET /sessions/:id
      # Show all traces in a session
      def show
        @session_id = params[:id]
        @traces = Trace.where(session_id: @session_id)
                       .includes(:spans, :llm_responses)
                       .order(started_at: :asc)

        # Calculate session metrics
        @total_traces = @traces.count
        @completed_traces = @traces.completed.count
        @error_traces = @traces.with_errors.count
        @total_duration = @traces.sum(:duration_ms)
        @total_cost = @traces.joins(:llm_responses).sum("llm_responses.cost_usd")
        @users = @traces.pluck(:user_id).compact.uniq

        # Get first and last activity
        @first_activity = @traces.minimum(:started_at)
        @last_activity = @traces.maximum(:ended_at) || @traces.maximum(:started_at)

        # Pagination
        @traces = @traces.page(params[:page]).per(20)
      end
    end
  end
end
