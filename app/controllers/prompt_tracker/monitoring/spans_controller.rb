# frozen_string_literal: true

module PromptTracker
  module Monitoring
    # Controller for viewing individual spans in monitoring context
    class SpansController < ApplicationController
      # GET /spans/:id
      # Show span detail
      def show
        @span = Span.includes(:trace, :parent_span, :child_spans, :llm_responses).find(params[:id])
        @trace = @span.trace

        # Calculate metrics
        @total_child_spans = @span.child_spans.count
        @total_generations = @span.llm_responses.count
        @total_cost = @span.llm_responses.sum(:cost_usd)
        @total_tokens = @span.llm_responses.sum(:tokens_total)
      end
    end
  end
end
