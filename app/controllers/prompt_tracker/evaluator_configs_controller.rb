# frozen_string_literal: true

module PromptTracker
  # Controller for managing evaluator configurations
  class EvaluatorConfigsController < ApplicationController
    before_action :set_prompt_and_version, except: [ :config_form ]
    before_action :set_evaluator_config, only: [ :show, :update, :destroy ]

    # GET /evaluator_configs/config_form
    # Returns the configuration form partial for a specific evaluator
    # Supports both add (new config) and edit (existing config) modes
    def config_form
      evaluator_key = params[:evaluator_key]
      config_id = params[:config_id]

      # Check if evaluator exists in registry
      unless EvaluatorRegistry.exists?(evaluator_key)
        render json: { error: "Evaluator '#{evaluator_key}' not found" }, status: :not_found
        return
      end

      # Fetch existing config if editing
      existing_config = config_id ? EvaluatorConfig.find_by(id: config_id) : nil

      # Try to render the specific form for this evaluator
      template_path = "prompt_tracker/evaluator_configs/forms/#{evaluator_key}"

      # Render the partial with existing_config and namespace available
      partial_content = render_to_string(
        partial: template_path,
        locals: {
          existing_config: existing_config,
          namespace: "evaluator_config[config]"
        }
      )

      # Use different frame ID for edit vs add
      frame_id = config_id ? "edit_evaluator_config_container" : "evaluator_config_container"

      render html: <<~HTML.html_safe, layout: false
        <turbo-frame id="#{frame_id}">
          #{partial_content}
        </turbo-frame>
      HTML
    rescue ActionView::MissingTemplate
      # If no custom form exists, return a message in turbo-frame
      frame_id = config_id ? "edit_evaluator_config_container" : "evaluator_config_container"
      render html: <<~HTML.html_safe, layout: false
        <turbo-frame id="#{frame_id}">
          <div class="alert alert-warning">
            <i class="bi bi-info-circle"></i>
            <strong>No custom configuration form available</strong>
            <p class="mb-0 mt-2">This evaluator will use default configuration values.</p>
          </div>
        </turbo-frame>
      HTML
    end

    # GET /prompts/:prompt_id/evaluators
    # List all evaluator configs for a prompt version (returns JSON for AJAX)
    def index
      @evaluator_configs = @version.evaluator_configs.order(:created_at)
      @available_evaluators = EvaluatorRegistry.all

      respond_to do |format|
        format.html { render partial: "evaluator_configs/list", locals: { prompt: @prompt, version: @version, evaluator_configs: @evaluator_configs } }
        format.json { render json: { configs: @evaluator_configs, available: @available_evaluators } }
      end
    end

    # GET /prompts/:prompt_id/evaluators/:id
    # Get a single evaluator config (for editing)
    def show
      respond_to do |format|
        format.json { render json: @evaluator_config }
      end
    end

    # POST /prompts/:prompt_id/evaluators
    # Create a new evaluator config for the active version
    def create
      # Process config params (convert arrays from form to proper format)
      processed_params = evaluator_config_params
      processed_params[:config] = process_config_params(processed_params[:config]) if processed_params[:config]

      @evaluator_config = @version.evaluator_configs.build(processed_params)

      if @evaluator_config.save
        respond_to do |format|
          format.html { redirect_to monitoring_prompt_prompt_version_path(@prompt, @version, anchor: "auto-evaluators"), notice: "Evaluator configured successfully." }
          format.json { render json: @evaluator_config, status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to monitoring_prompt_prompt_version_path(@prompt, @version, anchor: "auto-evaluators"), alert: "Failed to configure evaluator: #{@evaluator_config.errors.full_messages.join(', ')}" }
          format.json { render json: { errors: @evaluator_config.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /prompts/:prompt_id/evaluators/:id
    # Update an evaluator config
    def update
      # Process config params (convert arrays from form to proper format)
      processed_params = evaluator_config_params
      processed_params[:config] = process_config_params(processed_params[:config]) if processed_params[:config]

      if @evaluator_config.update(processed_params)
        respond_to do |format|
          format.html { redirect_to monitoring_prompt_prompt_version_path(@prompt, @version, anchor: "auto-evaluators"), notice: "Evaluator updated successfully." }
          format.json { render json: @evaluator_config }
        end
      else
        respond_to do |format|
          format.html { redirect_to monitoring_prompt_prompt_version_path(@prompt, @version, anchor: "auto-evaluators"), alert: "Failed to update evaluator: #{@evaluator_config.errors.full_messages.join(', ')}" }
          format.json { render json: { errors: @evaluator_config.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /prompts/:prompt_id/evaluators/:id
    # Delete an evaluator config
    def destroy
      @evaluator_config.destroy

      respond_to do |format|
        format.html { redirect_to monitoring_prompt_prompt_version_path(@prompt, @version, anchor: "auto-evaluators"), notice: "Evaluator removed successfully." }
        format.json { head :no_content }
      end
    end

    private

    def set_prompt_and_version
      @prompt = Prompt.find(params[:prompt_id])
      @version = @prompt.active_version

      unless @version
        respond_to do |format|
          format.json { render json: { error: "No active version" }, status: :unprocessable_entity }
        end
      end
    end

    def set_evaluator_config
      @evaluator_config = @version.evaluator_configs.find(params[:id])
    end

    def evaluator_config_params
      params.require(:evaluator_config).permit(
        :evaluator_key,
        :enabled,
        config: {}
      )
    end

    # this should be scoped
    # Process config params from form (handle arrays, convert types, etc.)
    def process_config_params(config_hash)
      return {} if config_hash.blank?

      processed = {}

      config_hash.each do |key, value|
        case key
        when "required_keywords", "forbidden_keywords", "patterns"
          # Convert textarea input (one per line) to array
          processed[key] = value.is_a?(String) ? value.split("\n").map(&:strip).reject(&:blank?) : value
        when "criteria"
          # Criteria comes as array from checkboxes
          processed[key] = value.is_a?(Array) ? value.reject(&:blank?) : []
        when "case_sensitive", "strict", "match_all"
          # Convert checkbox values to boolean
          processed[key] = value == "true" || value == true || value == "1"
        when "min_length", "max_length", "ideal_min", "ideal_max", "score_min", "score_max", "threshold_score"
          # Convert to integer
          processed[key] = value.to_i
        when "schema"
          # Parse JSON schema if provided
          if value.present? && value.is_a?(String)
            begin
              processed[key] = JSON.parse(value)
            rescue JSON::ParserError => e
              Rails.logger.warn("Failed to parse schema JSON: #{e.message}")
              processed[key] = nil
            end
          else
            processed[key] = value
          end
        else
          # Keep as-is
          processed[key] = value
        end
      end

      processed
    end
  end
end
