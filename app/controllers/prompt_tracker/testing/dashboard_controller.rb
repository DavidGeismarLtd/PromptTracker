# frozen_string_literal: true

module PromptTracker
  module Testing
    # Dashboard for the Testing section - pre-deployment validation
    #
    # Shows unified index of all testables:
    # - PromptVersions (with their prompts)
    # - OpenAI Assistants
    #
    # Supports filtering by testable type, provider, and model
    #
    class DashboardController < ApplicationController
      def index
        # Filter by testable type (all, prompts, assistants)
        @filter = params[:filter] || "all"
        @provider_filter = params[:provider].presence
        @model_filter = params[:model].presence

        # Load prompts with their versions and test data
        if @filter.in?([ "all", "prompts" ])
          @prompts = load_filtered_prompts
        else
          @prompts = []
        end

        # Build filter options from all prompt versions
        build_filter_options

        # Assistants are now PromptVersions with api: "assistants"
        # No separate assistant list needed
        @assistants = []

        # Calculate statistics
        calculate_statistics
      end

      # POST /testing/sync_openai_assistants
      # Sync all assistants from OpenAI API
      def sync_openai_assistants
        result = SyncOpenaiAssistantsToPromptVersionsService.new.call

        if result[:success]
          redirect_to testing_root_path,
                      notice: "Synced #{result[:created_count]} assistants from OpenAI."
        else
          redirect_to testing_root_path,
                      alert: "Failed to sync assistants: #{result[:errors].join(', ')}"
        end
      rescue SyncOpenaiAssistantsToPromptVersionsService::SyncError => e
        redirect_to testing_root_path,
                    alert: "Failed to sync assistants: #{e.message}"
      end

      private

      def load_filtered_prompts
        # Start with base query
        prompts_scope = Prompt.includes(
          prompt_versions: [
            :tests,
            { tests: :test_runs }
          ]
        )

        # Apply provider/model filters via prompt versions
        if @provider_filter.present? || @model_filter.present?
          # Get prompt IDs that have matching versions
          version_scope = PromptVersion.all

          if @provider_filter.present?
            version_scope = version_scope.where("model_config->>'provider' = ?", @provider_filter)
          end

          if @model_filter.present?
            version_scope = version_scope.where("model_config->>'model' = ?", @model_filter)
          end

          prompt_ids = version_scope.select(:prompt_id).distinct
          prompts_scope = prompts_scope.where(id: prompt_ids)
        end

        prompts_scope.order(created_at: :desc)
      end

      def build_filter_options
        # Get unique providers and models from all prompt versions
        all_versions = PromptVersion.where.not(model_config: nil)

        @available_providers = all_versions
          .select("DISTINCT model_config->>'provider' as provider")
          .map(&:provider)
          .compact
          .reject(&:blank?)
          .sort

        # Build provider-to-models mapping for linked dropdowns
        @models_by_provider = all_versions
          .select("model_config->>'provider' as provider, model_config->>'model' as model")
          .map { |v| [ v.provider, v.model ] }
          .reject { |p, m| p.blank? || m.blank? }
          .uniq
          .group_by(&:first)
          .transform_values { |pairs| pairs.map(&:last).sort }

        # Available models based on selected provider (or all if no provider selected)
        @available_models = if @provider_filter.present?
          @models_by_provider[@provider_filter] || []
        else
          all_versions
            .select("DISTINCT model_config->>'model' as model")
            .map(&:model)
            .compact
            .reject(&:blank?)
            .sort
        end
      end

      def calculate_statistics
        # Test statistics for summary
        @total_tests = Test.count
        @total_runs_today = TestRun.where("created_at >= ?", Time.current.beginning_of_day).count

        # Pass/fail rates (last 100 runs)
        recent_runs = TestRun.order(created_at: :desc).limit(100)
        @pass_rate = if recent_runs.any?
          (recent_runs.where(status: "passed").count.to_f / recent_runs.count * 100).round(1)
        else
          0
        end

        # Count by testable type
        @prompt_count = Prompt.count
        @assistant_count = 0 # Assistants are now PromptVersions
      end
    end
  end
end
