# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Controller for viewing hierarchical traces (Trace -> Spans -> LlmResponses)
    # in the monitoring UI.
    class TracesController < BaseController
      # GET /monitoring/traces
      # List recent traces with simple filtering
      def index
        @traces = Trace.order(started_at: :desc)

        if params[:status].present?
          @traces = @traces.where(status: params[:status])
        end

        if params[:session_id].present?
          @traces = @traces.where(session_id: params[:session_id])
        end

        if params[:q].present?
          query = "%#{params[:q]}%"
          @traces = @traces.where("name LIKE ?", query)
        end

        if params[:start_date].present?
          @traces = @traces.where("started_at >= ?", params[:start_date])
        end

        if params[:end_date].present?
          @traces = @traces.where("started_at <= ?", params[:end_date])
        end

        @traces = @traces.page(params[:page]).per(50)

        @statuses = Trace::STATUSES
        @session_ids = Trace.distinct.pluck(:session_id).compact.sort
      end

      # GET /monitoring/traces/:id
      # Show a single trace with its spans and LlmResponses in a simple hierarchy
      def show
        @trace = Trace.find(params[:id])

        @spans = @trace.spans.order(:started_at, :id)
        @responses = @trace.llm_responses.order(:created_at, :id)

        # Pre-group for the view to avoid N+1 lookups
        @spans_by_parent = @spans.group_by(&:parent_span_id)
        @responses_by_span = @responses.group_by(&:span_id)

        @root_spans = @spans_by_parent[nil] || []
        @root_responses = @responses_by_span[nil] || []
      end
    end
  end
end
