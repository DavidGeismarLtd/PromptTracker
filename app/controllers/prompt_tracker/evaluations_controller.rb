# frozen_string_literal: true

module PromptTracker
  # Controller for viewing evaluations
  class EvaluationsController < ApplicationController
    # GET /evaluations
    # List all evaluations with filtering
    def index
      @evaluations = Evaluation.includes(llm_response: { prompt_version: :prompt })

      # Filter by evaluator_type
      @evaluations = @evaluations.where(evaluator_type: params[:evaluator_type]) if params[:evaluator_type].present?

      # Filter by normalized score range (need to calculate normalized scores)
      # For simplicity, we'll filter on raw scores for now
      # TODO: Implement proper normalized score filtering
      if params[:min_score].present?
        min_normalized = params[:min_score].to_f / 100.0
        # This is a simplified filter - ideally we'd calculate normalized scores
        @evaluations = @evaluations.where("(score - score_min) / NULLIF((score_max - score_min), 0) >= ?", min_normalized)
      end
      if params[:max_score].present?
        max_normalized = params[:max_score].to_f / 100.0
        @evaluations = @evaluations.where("(score - score_min) / NULLIF((score_max - score_min), 0) <= ?", max_normalized)
      end

      # Sorting
      case params[:sort]
      when "oldest"
        @evaluations = @evaluations.order(created_at: :asc)
      when "highest_score"
        @evaluations = @evaluations.order(Arel.sql("(score - score_min) / NULLIF((score_max - score_min), 0) DESC"))
      when "lowest_score"
        @evaluations = @evaluations.order(Arel.sql("(score - score_min) / NULLIF((score_max - score_min), 0) ASC"))
      else # "newest" or default
        @evaluations = @evaluations.order(created_at: :desc)
      end

      # Calculate summary stats before pagination
      all_evaluations = @evaluations.to_a
      if all_evaluations.any?
        normalized_scores = all_evaluations.map do |eval|
          PromptTracker::EvaluationHelpers.normalize_score(eval.score, min: eval.score_min, max: eval.score_max) * 100
        end
        @avg_score = normalized_scores.sum / normalized_scores.length.to_f
        @high_quality_count = normalized_scores.count { |score| score >= 80 }
        @low_quality_count = normalized_scores.count { |score| score < 50 }
      else
        @avg_score = 0
        @high_quality_count = 0
        @low_quality_count = 0
      end

      # Pagination
      @evaluations = @evaluations.page(params[:page]).per(20)

      # Get filter options
      @evaluator_types = Evaluation.distinct.pluck(:evaluator_type).compact.sort
    end

    # GET /evaluations/:id
    # Show evaluation details
    def show
      @evaluation = Evaluation.includes(llm_response: { prompt_version: :prompt }).find(params[:id])
      @response = @evaluation.llm_response
      @version = @response.prompt_version
      @prompt = @version.prompt
    end

    # GET /evaluations/form_template
    # Returns the form partial for a specific evaluator type
    def form_template
      evaluator_key = params[:evaluator_key]

      # Get the response for form context
      @response = LlmResponse.find(params[:llm_response_id]) if params[:llm_response_id].present?

      # Get evaluator metadata from registry
      metadata = EvaluatorRegistry.get(evaluator_key&.to_sym)

      # Determine template path
      # 1. Try custom form template from registry metadata
      # 2. Fall back to evaluator_key-based template (e.g., _length.html.erb)
      # 3. Fall back to evaluator_type-based template (e.g., _human.html.erb)
      template_path = metadata&.dig(:form_template) ||
                      "prompt_tracker/evaluators/forms/#{evaluator_key}" ||
                      "prompt_tracker/evaluators/forms/#{params[:evaluator_type]}"

      # Render the partial wrapped in a turbo-frame tag
      partial_content = render_to_string(partial: template_path, locals: { f: nil, response: @response })

      render html: <<~HTML.html_safe, layout: false
        <turbo-frame id="evaluator_form_container">
          #{partial_content}
        </turbo-frame>
      HTML
    rescue ActionView::MissingTemplate => e
      render html: <<~HTML.html_safe, layout: false
        <turbo-frame id="evaluator_form_container">
          <div class="alert alert-danger">
            <i class="bi bi-exclamation-triangle"></i>
            <strong>Form template not found</strong>
            <p class="mb-0">Could not find form template for evaluator: #{evaluator_key}</p>
          </div>
        </turbo-frame>
      HTML
    rescue ActiveRecord::RecordNotFound
      render html: <<~HTML.html_safe, layout: false
        <turbo-frame id="evaluator_form_container">
          <div class="alert alert-danger">
            <i class="bi bi-exclamation-triangle"></i>
            <strong>Response not found</strong>
          </div>
        </turbo-frame>
      HTML
    end

    # POST /evaluations
    # Create a new evaluation
    def create
      @response = LlmResponse.find(params[:evaluation][:llm_response_id])

      # Determine evaluation type and route accordingly
      if params[:llm_judge].present?
        create_llm_judge_evaluation
      else
        # This is a manual human evaluation
        create_manual_evaluation
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to llm_responses_path, alert: "Response not found"
    end

    private

    # Creates a manual evaluation (human with manual scores)
    def create_manual_evaluation
      @evaluation = @response.evaluations.build(evaluation_params)

      if @evaluation.save
        redirect_to llm_response_path(@response), notice: "Evaluation created successfully!"
      else
        redirect_to llm_response_path(@response), alert: "Error creating evaluation: #{@evaluation.errors.full_messages.join(', ')}"
      end
    end

    # Runs a registry evaluator and creates evaluation automatically
    def create_registry_evaluation
      evaluator_key = params[:evaluation][:evaluator_id]&.to_sym

      # Get evaluator from registry
      metadata = EvaluatorRegistry.get(evaluator_key)

      unless metadata
        redirect_to llm_response_path(@response), alert: "Evaluator not found: #{evaluator_key}"
        return
      end

      # Get configuration from form params or use defaults
      config = if params[evaluator_key].present?
        process_evaluator_config_params(params[evaluator_key])
      else
        metadata[:default_config] || {}
      end

      # Build and run the evaluator
      evaluator = EvaluatorRegistry.build(evaluator_key, @response, config)
      evaluation = evaluator.evaluate

      redirect_to llm_response_path(@response),
                  notice: "#{metadata[:name]} evaluation completed! Score: #{evaluation.score}"
    end

    # Creates an LLM judge evaluation (runs evaluator directly)
    def create_llm_judge_evaluation
      judge_params = params[:llm_judge]

      # Build configuration for the LLM judge
      config = {
        judge_model: judge_params[:judge_model],
        criteria: judge_params[:criteria] || [],
        custom_instructions: judge_params[:custom_instructions],
        score_min: judge_params[:score_min]&.to_i || 0,
        score_max: judge_params[:score_max]&.to_i || 100
      }

      evaluator_key = :gpt4_judge

      # Build and run the evaluator directly (without saving a config)
      evaluator = EvaluatorRegistry.build(evaluator_key, @response, config)

      # Run evaluation in background job
      LlmJudgeEvaluationJob.perform_later(@response.id, config)

      redirect_to llm_response_path(@response),
                  notice: "LLM Judge evaluation started! The results will appear shortly."
    end

    # Process configuration parameters from form
    # Converts form data to proper format for evaluators
    def process_evaluator_config_params(config_hash)
      return {} if config_hash.blank?

      processed = {}

      config_hash.each do |key, value|
        case key
        when "required_keywords", "forbidden_keywords"
          # Convert textarea input (one per line) to array
          processed[key.to_sym] = value.is_a?(String) ? value.split("\n").map(&:strip).reject(&:blank?) : value
        when "case_sensitive", "strict"
          # Convert checkbox values to boolean
          processed[key.to_sym] = value == "true" || value == true || value == "1"
        when "min_length", "max_length", "ideal_min", "ideal_max"
          # Convert to integer
          processed[key.to_sym] = value.to_i
        when "schema"
          # Parse JSON schema if provided
          if value.present? && value.is_a?(String)
            begin
              processed[key.to_sym] = JSON.parse(value)
            rescue JSON::ParserError => e
              Rails.logger.warn("Failed to parse schema JSON: #{e.message}")
              processed[key.to_sym] = nil
            end
          else
            processed[key.to_sym] = value
          end
        else
          # Keep as-is
          processed[key.to_sym] = value
        end
      end

      processed
    end

    def evaluation_params
      params.require(:evaluation).permit(
        :evaluator_type,
        :evaluator_id,
        :evaluation_context,
        :score,
        :score_min,
        :score_max,
        :feedback
      )
    end
  end
end
