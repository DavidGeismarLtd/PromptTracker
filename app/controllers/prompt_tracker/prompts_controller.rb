# frozen_string_literal: true

module PromptTracker
  # Controller for browsing and viewing prompts
  class PromptsController < ApplicationController
    # GET /prompts
    # List all prompts with search and filtering
    def index
      @prompts = Prompt.includes(:prompt_versions).order(created_at: :desc)

      # Search by name or description
      if params[:q].present?
        query = "%#{params[:q]}%"
        @prompts = @prompts.where("name LIKE ? OR description LIKE ?", query, query)
      end

      # Filter by category
      @prompts = @prompts.in_category(params[:category]) if params[:category].present?

      # Filter by tag
      @prompts = @prompts.with_tag(params[:tag]) if params[:tag].present?

      # Filter by status
      case params[:status]
      when "active"
        @prompts = @prompts.active
      when "archived"
        @prompts = @prompts.archived
      end

      # Sort
      case params[:sort]
      when "name"
        @prompts = @prompts.order(name: :asc)
      when "calls"
        @prompts = @prompts.left_joins(prompt_versions: :llm_responses)
                          .group("prompt_tracker_prompts.id")
                          .order("COUNT(prompt_tracker_llm_responses.id) DESC")
      when "cost"
        @prompts = @prompts.left_joins(prompt_versions: :llm_responses)
                          .group("prompt_tracker_prompts.id")
                          .order("SUM(prompt_tracker_llm_responses.cost_usd) DESC")
      end

      # Pagination
      @prompts = @prompts.page(params[:page]).per(20)

      # Get all categories and tags for filters
      @categories = Prompt.distinct.pluck(:category).compact.sort
      @tags = Prompt.pluck(:tags).flatten.compact.uniq.sort
    end

    # GET /prompts/:id
    # Show prompt details with all versions
    def show
      @prompt = Prompt.includes(prompt_versions: :llm_responses).find(params[:id])
      @versions = @prompt.prompt_versions.order(version_number: :desc)
      @active_version = @prompt.active_version
      @latest_version = @prompt.latest_version
    end

    # GET /prompts/:id/analytics
    # Show analytics for a specific prompt
    def analytics
      @prompt = Prompt.includes(prompt_versions: :llm_responses).find(params[:id])
      @versions = @prompt.prompt_versions.order(version_number: :asc)
      @active_version = @prompt.active_version

      # Calculate metrics per version
      @version_stats = @versions.map do |version|
        {
          version: version,
          calls: version.llm_responses.count,
          avg_response_time: version.average_response_time_ms,
          total_cost: version.total_cost_usd,
          has_evaluations: version.evaluations.any?
        }
      end

      # Get responses over time (last 30 days)
      @responses_by_day = @prompt.llm_responses
                                 .where("prompt_tracker_llm_responses.created_at >= ?", 30.days.ago)
                                 .group_by_day("prompt_tracker_llm_responses.created_at")
                                 .count

      # Get cost over time (last 30 days)
      @cost_by_day = @prompt.llm_responses
                            .where("prompt_tracker_llm_responses.created_at >= ?", 30.days.ago)
                            .group_by_day("prompt_tracker_llm_responses.created_at")
                            .sum(:cost_usd)

      # Provider breakdown
      @responses_by_provider = @prompt.llm_responses.group(:provider).count
      @cost_by_provider = @prompt.llm_responses.group(:provider).sum(:cost_usd)
    end
  end
end
