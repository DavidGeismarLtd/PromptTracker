# frozen_string_literal: true

module PromptTracker
  module Analytics
    # Controller for analytics dashboard and reports
    class DashboardController < ApplicationController
      # GET /analytics
      # Main analytics dashboard
      def index
        # Overall metrics
        @total_prompts = Prompt.count
        @active_prompts = Prompt.joins(:prompt_versions).where(prompt_tracker_prompt_versions: { status: "active" }).distinct.count
        @total_responses = LlmResponse.count
        @successful_responses = LlmResponse.where(status: "success").count

        # Cost metrics
        @total_cost = LlmResponse.sum(:cost_usd) || 0
        @cost_last_30_days = LlmResponse.where("created_at >= ?", 30.days.ago).sum(:cost_usd) || 0

        # Performance metrics
        @avg_response_time = LlmResponse.average(:response_time_ms) || 0

        # Activity over time (last 30 days)
        @activity_by_day = LlmResponse.where("created_at >= ?", 30.days.ago)
                                      .group_by_day(:created_at)
                                      .count

        # Provider distribution
        @responses_by_provider = LlmResponse.group(:provider).count

        # Recent activity
        @recent_responses = LlmResponse.includes(prompt_version: :prompt).order(created_at: :desc).limit(10)

        # Top prompts by usage
        prompt_usage = LlmResponse.joins(prompt_version: :prompt)
                                  .group("prompt_tracker_prompts.id")
                                  .count
        @top_prompts_by_usage = prompt_usage.sort_by { |_, count| -count }
                                            .first(5)
                                            .map { |prompt_id, count| [Prompt.find(prompt_id), count] }

        # Top prompts by cost
        prompt_costs = LlmResponse.joins(prompt_version: :prompt)
                                  .group("prompt_tracker_prompts.id")
                                  .sum(:cost_usd)
        @top_prompts_by_cost = prompt_costs.sort_by { |_, cost| -cost }
                                           .first(5)
                                           .map { |prompt_id, cost| [Prompt.find(prompt_id), cost] }
      end

      # GET /analytics/costs
      # Cost analysis
      def costs
        # Summary metrics
        @total_cost = LlmResponse.sum(:cost_usd) || 0
        @cost_last_30_days = LlmResponse.where("created_at >= ?", 30.days.ago).sum(:cost_usd) || 0
        @cost_previous_30_days = LlmResponse.where("created_at >= ? AND created_at < ?", 60.days.ago, 30.days.ago).sum(:cost_usd) || 0
        @cost_today = LlmResponse.where("created_at >= ?", Time.current.beginning_of_day).sum(:cost_usd) || 0
        @avg_cost_per_call = LlmResponse.count > 0 ? @total_cost / LlmResponse.count : 0

        # Cost over time (last 30 days)
        @cost_by_day = LlmResponse.where("created_at >= ?", 30.days.ago)
                                  .group_by_day(:created_at)
                                  .sum(:cost_usd)

        # Cost by provider
        @cost_by_provider = LlmResponse.group(:provider).sum(:cost_usd)
        @responses_by_provider = LlmResponse.group(:provider).count

        # Cost by model
        @cost_by_model = LlmResponse.group(:model).sum(:cost_usd)
        @responses_by_model = LlmResponse.group(:model).count

        # Top prompts by cost
        prompt_costs = LlmResponse.joins(prompt_version: :prompt)
                                  .group("prompt_tracker_prompts.id")
                                  .sum(:cost_usd)
        @top_prompts_by_cost = prompt_costs.sort_by { |_, cost| -cost }
                                           .first(10)
                                           .map { |prompt_id, cost| [Prompt.find(prompt_id), cost] }
      end

      # GET /analytics/performance
      # Performance analysis
      def performance
        # Summary metrics
        @avg_response_time = LlmResponse.average(:response_time_ms) || 0
        @min_response_time = LlmResponse.minimum(:response_time_ms) || 0
        @max_response_time = LlmResponse.maximum(:response_time_ms) || 0

        # Calculate P95 (95th percentile)
        response_times = LlmResponse.where.not(response_time_ms: nil).pluck(:response_time_ms).sort
        @p95_response_time = if response_times.any?
                               index = (response_times.length * 0.95).ceil - 1
                               response_times[index]
                             else
                               0
                             end

        # Response time over time (last 30 days)
        @response_time_by_day = LlmResponse.where("created_at >= ?", 30.days.ago)
                                           .group_by_day(:created_at)
                                           .average(:response_time_ms)

        # Response time by provider
        @response_time_by_provider = LlmResponse.group(:provider).average(:response_time_ms).reject { |_, time| time.nil? }
        @responses_by_provider = LlmResponse.group(:provider).count

        # Success rate by provider
        @success_rate_by_provider = {}
        LlmResponse.group(:provider).count.each do |provider, total|
          success_count = LlmResponse.where(provider: provider, status: "success").count
          @success_rate_by_provider[provider] = (success_count.to_f / total * 100)
        end

        # Response time by model
        @response_time_by_model = LlmResponse.group(:model).average(:response_time_ms).reject { |_, time| time.nil? }
        @responses_by_model = LlmResponse.group(:model).count

        # Fastest and slowest prompts
        prompt_times = LlmResponse.joins(prompt_version: :prompt)
                                  .group("prompt_tracker_prompts.id")
                                  .average(:response_time_ms)
                                  .reject { |_, time| time.nil? }  # Filter out nil values

        @fastest_prompts = prompt_times.sort_by { |_, time| time }
                                       .first(5)
                                       .map { |prompt_id, time| [Prompt.find(prompt_id), time] }

        @slowest_prompts = prompt_times.sort_by { |_, time| -time }
                                       .first(5)
                                       .map { |prompt_id, time| [Prompt.find(prompt_id), time] }
      end

      # GET /analytics/quality
      # Quality analysis
      def quality
        # Summary metrics
        @total_evaluations = Evaluation.count
        @total_responses = LlmResponse.count
        @evaluation_rate = @total_responses > 0 ? (@total_evaluations.to_f / @total_responses * 100) : 0
        @evaluations_last_30_days = Evaluation.joins(:llm_response)
                                              .where("prompt_tracker_llm_responses.created_at >= ?", 30.days.ago)
                                              .count

        # Calculate average quality score
        if @total_evaluations > 0
          all_evaluations = Evaluation.all
          normalized_scores = all_evaluations.map do |eval|
            PromptTracker::EvaluationHelpers.normalize_score(eval.score, min: eval.score_min, max: eval.score_max)
          end
          @avg_quality_score = (normalized_scores.sum / normalized_scores.length.to_f * 100)
          @high_quality_count = normalized_scores.count { |score| score >= 0.8 }
        else
          @avg_quality_score = 0
          @high_quality_count = 0
        end

        # Quality scores over time (last 30 days)
        evaluations_30_days = Evaluation.joins(:llm_response)
                                        .where("prompt_tracker_llm_responses.created_at >= ?", 30.days.ago)
                                        .includes(:llm_response)

        @quality_by_day = {}
        evaluations_30_days.group_by { |e| e.llm_response.created_at.to_date }.each do |date, evals|
          normalized_scores = evals.map do |eval|
            PromptTracker::EvaluationHelpers.normalize_score(eval.score, min: eval.score_min, max: eval.score_max)
          end
          @quality_by_day[date.to_s] = (normalized_scores.sum / normalized_scores.length.to_f * 100).round(1)
        end

        # Evaluation type breakdown
        evaluations_by_class = Evaluation.group(:evaluator_type).count

        # Convert class names to registry keys for display
        @evaluations_by_type = {}
        evaluations_by_class.each do |class_name, count|
          # Convert "PromptTracker::Evaluators::LlmJudgeEvaluator" -> "llm_judge"
          key = class_name.demodulize.underscore.gsub('_evaluator', '')
          @evaluations_by_type[key] = count
        end

        # Average score by type (using keys)
        @avg_score_by_type = {}
        evaluations_by_class.each do |class_name, _count|
          key = class_name.demodulize.underscore.gsub('_evaluator', '')
          evals = Evaluation.where(evaluator_type: class_name)
          normalized_scores = evals.map do |eval|
            PromptTracker::EvaluationHelpers.normalize_score(eval.score, min: eval.score_min, max: eval.score_max)
          end
          @avg_score_by_type[key] = (normalized_scores.sum / normalized_scores.length.to_f * 100).round(1) if normalized_scores.any?
        end

        # Score distribution (buckets: 0-20, 20-40, 40-60, 60-80, 80-100)
        @score_distribution = {
          "0-20%" => 0,
          "20-40%" => 0,
          "40-60%" => 0,
          "60-80%" => 0,
          "80-100%" => 0
        }

        Evaluation.all.each do |eval|
          normalized = PromptTracker::EvaluationHelpers.normalize_score(eval.score, min: eval.score_min, max: eval.score_max) * 100
          case normalized
          when 0...20 then @score_distribution["0-20%"] += 1
          when 20...40 then @score_distribution["20-40%"] += 1
          when 40...60 then @score_distribution["40-60%"] += 1
          when 60...80 then @score_distribution["60-80%"] += 1
          else @score_distribution["80-100%"] += 1
          end
        end

        # Top and bottom prompts by quality
        prompts_with_evals = Prompt.joins(prompt_versions: { llm_responses: :evaluations })
                                   .distinct

        prompt_scores = prompts_with_evals.map do |prompt|
          evaluations = prompt.evaluations
          if evaluations.any?
            normalized_scores = evaluations.map do |eval|
              PromptTracker::EvaluationHelpers.normalize_score(eval.score, min: eval.score_min, max: eval.score_max)
            end
            avg_score = (normalized_scores.sum / normalized_scores.length.to_f * 100).round(1)
            { prompt: prompt, avg_score: avg_score }
          end
        end.compact

        @top_prompts_by_quality = prompt_scores.sort_by { |h| -h[:avg_score] }.first(5)
        @bottom_prompts_by_quality = prompt_scores.sort_by { |h| h[:avg_score] }.first(5)
      end
    end
  end
end
