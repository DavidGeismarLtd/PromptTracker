# frozen_string_literal: true

module PromptTracker
  # Controller for managing the Function Library
  # Provides CRUD operations for code-based functions
  class FunctionsController < ApplicationController
    before_action :set_function, only: [ :show, :edit, :update, :destroy, :test ]

    # GET /functions
    # List all functions with search and filtering
    def index
      @functions = FunctionDefinition.includes(:function_executions).order(created_at: :desc)

      # Search by name or description
      if params[:q].present?
        @functions = @functions.search(params[:q])
      end

      # Filter by category
      if params[:category].present?
        @functions = @functions.by_category(params[:category])
      end

      # Filter by language
      if params[:language].present?
        @functions = @functions.by_language(params[:language])
      end

      # Filter by tag
      if params[:tag].present?
        @functions = @functions.where("? = ANY(tags)", params[:tag])
      end

      # Sort
      case params[:sort]
      when "name"
        @functions = @functions.order(name: :asc)
      when "most_used"
        @functions = @functions.order(execution_count: :desc)
      when "recently_executed"
        @functions = @functions.order(Arel.sql("last_executed_at DESC NULLS LAST"))
      else # "newest" or default
        @functions = @functions.order(created_at: :desc)
      end

      # Pagination
      @functions = @functions.page(params[:page]).per(20)

      # Get filter options
      @categories = FunctionDefinition.distinct.pluck(:category).compact.sort
      @languages = FunctionDefinition.distinct.pluck(:language).compact.sort
      @tags = FunctionDefinition.pluck(:tags).flatten.compact.uniq.sort
    end

    # GET /functions/:id
    # Show function details with execution history
    def show
      @executions = @function.function_executions
                             .order(executed_at: :desc)
                             .page(params[:page])
                             .per(20)

      # Calculate stats
      @total_executions = @function.execution_count
      @success_rate = @function.function_executions.success_rate
      @avg_execution_time = @function.average_execution_time_ms
    end

    # GET /functions/new
    # New function form
    def new
      @function = FunctionDefinition.new(
        language: "ruby",
        parameters: {
          "type" => "object",
          "properties" => {},
          "required" => []
        }
      )
    end

    # POST /functions
    # Create a new function
    def create
      @function = FunctionDefinition.new(function_params)
      @function.created_by = "web_ui" # TODO: Replace with current_user when auth is added

      if @function.save
        redirect_to function_path(@function),
                    notice: "Function created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /functions/:id/edit
    # Edit function form
    def edit
    end

    # PATCH/PUT /functions/:id
    # Update a function
    def update
      if @function.update(function_params)
        redirect_to function_path(@function),
                    notice: "Function updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /functions/:id
    # Delete a function
    def destroy
      @function.destroy
      redirect_to functions_path,
                  notice: "Function deleted successfully."
    end

    # POST /functions/:id/test
    # Test a function with sample inputs
    def test
      arguments = JSON.parse(params[:arguments] || "{}")
      result = @function.test(**arguments.symbolize_keys)

      respond_to do |format|
        format.json { render json: result }
        format.html do
          flash[:notice] = "Test executed successfully"
          redirect_to function_path(@function)
        end
      end
    rescue JSON::ParserError => e
      respond_to do |format|
        format.json { render json: { error: "Invalid JSON: #{e.message}" }, status: :unprocessable_entity }
        format.html do
          flash[:alert] = "Invalid JSON: #{e.message}"
          redirect_to function_path(@function)
        end
      end
    end

    private

    def set_function
      @function = FunctionDefinition.find(params[:id])
    end

    def function_params
      params.require(:function_definition).permit(
        :name,
        :description,
        :code,
        :language,
        :category,
        :example_input,
        :example_output,
        :parameters,
        :environment_variables,
        :dependencies,
        tags: []
      )
    end
  end
end
