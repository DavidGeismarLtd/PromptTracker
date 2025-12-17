# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Controller for viewing execution traces in monitoring context
    class TracesController < ApplicationController
      # GET /traces
      # List all traces with filtering
      def index
        @traces = Trace.includes(:spans, :llm_responses)
                       .order(created_at: :desc)

        # Filter by status
        @traces = @traces.where(status: params[:status]) if params[:status].present?

        # Filter by user_id
        @traces = @traces.for_user(params[:user_id]) if params[:user_id].present?

        # Filter by session_id
        @traces = @traces.in_session(params[:session_id]) if params[:session_id].present?

        # Search by name
        if params[:q].present?
          @traces = @traces.where("name LIKE ?", "%#{params[:q]}%")
        end

        # Date range filter
        if params[:start_date].present?
          @traces = @traces.where("started_at >= ?", params[:start_date])
        end
        if params[:end_date].present?
          @traces = @traces.where("started_at <= ?", params[:end_date])
        end

        # Pagination
        @traces = @traces.page(params[:page]).per(25)

        # Get filter options
        @statuses = Trace::STATUSES
        @users = Trace.where.not(user_id: nil).distinct.pluck(:user_id).compact.sort
        @sessions = Trace.where.not(session_id: nil).distinct.pluck(:session_id).compact.sort
      end

      # GET /traces/:id
      # Show trace detail with timeline
      def show
        @trace = Trace.includes(
          spans: [ :child_spans, :llm_responses ],
          llm_responses: [ :prompt_version, :evaluations ]
        ).find(params[:id])

        # Get root-level spans (no parent)
        @root_spans = @trace.spans.root_level.order(:started_at)

        # Get orphan generations (LLM responses not in any span)
        @orphan_generations = @trace.llm_responses.where(span_id: nil).order(:created_at)

        # Calculate metrics
        @total_spans = @trace.spans.count
        @total_generations = @trace.llm_responses.count
        @total_cost = @trace.llm_responses.sum(:cost_usd)
        @total_tokens = @trace.llm_responses.sum(:tokens_total)
      end
    end
  end
end
