# frozen_string_literal: true

module PromptTracker
  module Testing
    # Controller for managing prompt tests in the Testing section
    class PromptTestsController < ApplicationController
    before_action :set_prompt_version
    before_action :set_test, only: [:show, :edit, :update, :destroy, :run]

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests
    def index
      @tests = @version.prompt_tests.order(created_at: :desc)
    end

    # POST /prompts/:prompt_id/versions/:prompt_version_id/tests/run_all
    def run_all
      enabled_tests = @version.prompt_tests.enabled

      if enabled_tests.empty?
        redirect_to testing_prompt_prompt_version_prompt_tests_path(@prompt, @version),
                    alert: "No enabled tests to run."
        return
      end

      # Create test runs and enqueue background jobs for each test
      enabled_tests.each do |test|
        # Create test run immediately with "running" status
        # The after_create_commit callback will broadcast Turbo Stream updates
        test_run = PromptTestRun.create!(
          prompt_test: test,
          prompt_version: @version,
          status: "running",
          metadata: { triggered_by: "run_all", user: "web_ui" }
        )

        # Enqueue background job to execute the test
        RunTestJob.perform_later(
          test_run.id,
          use_real_llm: use_real_llm?
        )
      end

      # Redirect immediately - tests are running in background
      redirect_to testing_prompt_prompt_version_prompt_tests_path(@prompt, @version),
                  notice: "Started #{enabled_tests.count} test#{enabled_tests.count > 1 ? 's' : ''} in the background!"
    end

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests/:id
    def show
      @recent_runs = @test.recent_runs(10)
    end

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests/new
    def new
      @test = @version.prompt_tests.build(
        template_variables: {},
        model_config: { provider: "openai", model: "gpt-4" }
      )
    end

    # POST /prompts/:prompt_id/versions/:prompt_version_id/tests
    def create
      @test = @version.prompt_tests.build(test_params)

      if @test.save
        redirect_to testing_prompt_prompt_version_prompt_test_path(@prompt, @version, @test), notice: "Test created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /prompts/:prompt_id/versions/:prompt_version_id/tests/:id/edit
    def edit
    end

    # PATCH/PUT /prompts/:prompt_id/versions/:prompt_version_id/tests/:id
    def update
      if @test.update(test_params)
        redirect_to testing_prompt_prompt_version_prompt_test_path(@prompt, @version, @test), notice: "Test updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /prompts/:prompt_id/versions/:prompt_version_id/tests/:id
    def destroy
      @test.destroy
      redirect_to testing_prompt_prompt_version_prompt_tests_path(@prompt, @version), notice: "Test deleted successfully."
    end

    # POST /prompts/:prompt_id/versions/:prompt_version_id/tests/:id/run
    def run
      # Create test run immediately with "running" status for instant UI feedback
      test_run = PromptTestRun.create!(
        prompt_test: @test,
        prompt_version: @version,
        status: 'running',
        metadata: { triggered_by: "manual", user: "web_ui" }
      )

      # Enqueue background job to execute the test
      RunTestJob.perform_later(
        test_run.id,
        use_real_llm: use_real_llm?
      )

      respond_to do |format|
        format.turbo_stream do
          # The after_create_commit callback on PromptTestRun already broadcasts the updates
          # Render empty turbo stream to acknowledge the request without redirecting
          render turbo_stream: []
        end
        format.html do
          redirect_to testing_prompt_prompt_version_prompt_test_path(@prompt, @version, @test),
                      notice: "Test started in the background! The page will update automatically when complete."
        end
      end
    end

    private

    def set_prompt_version
      @version = PromptVersion.find(params[:prompt_version_id])
      @prompt = @version.prompt
    end

    def set_test
      @test = @version.prompt_tests.find(params[:id])
    end

    def test_params
      permitted = params.require(:prompt_test).permit(
        :name,
        :description,
        :enabled,
        :template_variables,
        :model_config,
        :metadata,
        :evaluator_configs
      )

      # Parse JSON strings to hashes/arrays
      [ :template_variables, :model_config, :metadata, :evaluator_configs ].each do |key|
        if permitted[key].is_a?(String)
          permitted[key] = JSON.parse(permitted[key])
        end
      end

      permitted
    end

    # Check if real LLM API calls should be used
    #
    # @return [Boolean] true if PROMPT_TRACKER_USE_REAL_LLM is set to 'true'
    def use_real_llm?
      ENV["PROMPT_TRACKER_USE_REAL_LLM"] == "true"
    end

    # Call real LLM API
    #
    # @param rendered_prompt [String] the rendered prompt
    # @param model_config [Hash] the model configuration
    # @return [Hash] LLM API response
    def call_real_llm(rendered_prompt, model_config)
      config = model_config.with_indifferent_access
      provider = config[:provider] || "openai"
      model = config[:model] || "gpt-4"
      temperature = config[:temperature] || 0.7
      max_tokens = config[:max_tokens]

      LlmClientService.call(
        provider: provider,
        model: model,
        prompt: rendered_prompt,
        temperature: temperature,
        max_tokens: max_tokens
      )[:raw] # Return raw response in provider format
    end

    # Generate a mock LLM response for testing
    #
    # @param rendered_prompt [String] the rendered prompt
    # @param model_config [Hash] the model configuration
    # @return [Hash] mock LLM response in OpenAI format
    def generate_mock_llm_response(rendered_prompt, model_config)
      provider = model_config["provider"] || model_config[:provider] || "openai"

      # Generate a realistic mock response based on the prompt
      mock_text = "This is a mock response to: #{rendered_prompt.truncate(100)}\n\n"
      mock_text += "In a production environment, this would be replaced with an actual API call to #{provider}.\n"
      mock_text += "The response would be generated by the configured model and would address the prompt appropriately."

      # Return in OpenAI-like format for compatibility
      {
        "choices" => [
          {
            "message" => {
              "content" => mock_text
            }
          }
        ]
      }
    end
    end
  end
end
