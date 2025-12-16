# frozen_string_literal: true

module PromptTracker
  # Controller for viewing tracing sessions
  class SessionsController < ApplicationController
    # GET /sessions
    # List all unique sessions with summary metrics
    def index
      # Get unique session_ids with aggregated data
      @sessions = Trace.where.not(session_id: nil)
                       .group(:session_id)
                       .select(
                         "session_id",
                         "COUNT(*) as trace_count",
                         "MAX(created_at) as last_activity",
                         "MIN(created_at) as first_activity",
                         "SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count",
                         "SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) as error_count"
                       )
                       .order("last_activity DESC")

      # Filter by user_id if provided
      if params[:user_id].present?
        @sessions = @sessions.where("user_id = ?", params[:user_id])
      end

      # Filter by date range
      if params[:start_date].present?
        @sessions = @sessions.where("created_at >= ?", params[:start_date])
      end
      if params[:end_date].present?
        @sessions = @sessions.where("created_at <= ?", params[:end_date])
      end

      # Pagination
      @sessions = @sessions.page(params[:page]).per(25)

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
