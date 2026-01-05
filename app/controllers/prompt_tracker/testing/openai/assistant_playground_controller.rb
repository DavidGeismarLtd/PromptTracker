# frozen_string_literal: true

module PromptTracker
  module Testing
    module Openai
      # Controller for the OpenAI Assistant Playground.
      #
      # Provides an interactive interface for creating, editing, and testing
      # OpenAI Assistants with a split-screen layout:
      # - Left: Thread chat interface for testing
      # - Right: Configuration sidebar for assistant settings
      #
      class AssistantPlaygroundController < ApplicationController
        before_action :set_assistant, only: [
          :show, :update_assistant, :send_message, :load_messages,
          :upload_file, :list_files, :delete_file,
          :create_vector_store, :list_vector_stores, :attach_vector_store, :add_file_to_vector_store, :submit_tool_outputs
        ]


        before_action :initialize_service

        # GET /testing/openai/assistants/playground/new
        #
        # Renders the playground interface for creating a new assistant
        def new
          @assistant = PromptTracker::Openai::Assistant.new
          @is_new = true
          load_available_models

          render :show
        end

        # GET /testing/openai/assistants/:assistant_id/playground
        #
        # Renders the playground interface for editing an existing assistant
        def show
          @assistant ||= PromptTracker::Openai::Assistant.new
          @is_new = @assistant.new_record?
          load_available_models
        end

        # POST /testing/openai/assistants/playground/create_assistant
        #
        # Creates a new assistant via OpenAI API
        def create_assistant
          result = @service.create_assistant(assistant_params)

          if result[:success]
            render json: {
              success: true,
              assistant_id: result[:assistant].assistant_id,
              message: "Assistant created successfully",
              redirect_url: testing_openai_assistant_playground_path(result[:assistant])
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # POST /testing/openai/assistants/:assistant_id/playground/update_assistant
        #
        # Updates an existing assistant via OpenAI API
        def update_assistant
          result = @service.update_assistant(@assistant.assistant_id, assistant_params)

          if result[:success]
            render json: {
              success: true,
              message: "Assistant updated successfully",
              last_saved_at: Time.current.strftime("%I:%M %p")
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # POST /testing/openai/assistants/:assistant_id/playground/create_thread
        #
        # Creates a new conversation thread
        def create_thread
          result = @service.create_thread

          if result[:success]
            session[:playground_thread_id] = result[:thread_id]
            render json: {
              success: true,
              thread_id: result[:thread_id]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # POST /testing/openai/assistants/:assistant_id/playground/send_message
        #
        # Sends a message in the thread and runs the assistant
        def send_message
          thread_id = params[:thread_id] || session[:playground_thread_id]

          # Auto-create thread if needed
          if thread_id.blank?
            thread_result = @service.create_thread
            return render json: { success: false, error: "Failed to create thread" },
                          status: :unprocessable_entity unless thread_result[:success]
            thread_id = thread_result[:thread_id]
            session[:playground_thread_id] = thread_id
          end

          result = @service.send_message(
            thread_id: thread_id,
            assistant_id: @assistant.assistant_id,
            content: params[:content]
          )

          if result[:success]
            render json: {
              success: true,
              thread_id: thread_id,
              message: result[:message],
              usage: result[:usage]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # GET /testing/openai/assistants/:assistant_id/playground/load_messages
        #
        # Loads message history for a thread
        def load_messages
          thread_id = params[:thread_id] || session[:playground_thread_id]

          if thread_id.blank?
            return render json: { success: true, messages: [] }
          end

          result = @service.load_messages(thread_id: thread_id)

          if result[:success]
            render json: {
              success: true,
              messages: result[:messages]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # POST /testing/openai/assistants/:assistant_id/playground/upload_file
        #
        # Uploads a file to OpenAI for use with file_search
        def upload_file
          unless params[:file].present?
            return render json: { success: false, error: "No file provided" }, status: :unprocessable_entity
          end

          result = @service.upload_file(params[:file])

          if result[:success]
            render json: {
              success: true,
              file: result[:file]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # GET /testing/openai/assistants/:assistant_id/playground/list_files
        #
        # Lists files uploaded for assistants
        def list_files
          result = @service.list_files

          if result[:success]
            render json: {
              success: true,
              files: result[:files]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # DELETE /testing/openai/assistants/:assistant_id/playground/delete_file
        #
        # Deletes a file from OpenAI
        def delete_file
          result = @service.delete_file(params[:file_id])

          if result[:success]
            render json: { success: true }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end
        # Create a vector store
        #
        # @param name [String] the vector store name
        # @param file_ids [Array<String>] optional file IDs to add immediately
        # @return [Hash] result with :success, :vector_store_id, :vector_store keys
        def create_vector_store(name:, file_ids: [])
          params = { name: name }
          params[:file_ids] = file_ids if file_ids.present?

          response = client.vector_stores.create(parameters: params)

          {
            success: true,
            vector_store_id: response["id"],
            vector_store: {
              id: response["id"],
              name: response["name"],
              status: response["status"],
              file_counts: response["file_counts"],
              created_at: response["created_at"] ? Time.at(response["created_at"]) : nil
            }
          }
        rescue => e
          Rails.logger.error "Failed to create vector store: #{e.message}"
          { success: false, error: e.message }
        end
        # POST /testing/openai/assistants/:assistant_id/playground/generate_instructions
        # POST /testing/openai/assistants/playground/generate_instructions (for new assistants)
        #
        # Generates assistant instructions from a natural language description using AI
        def generate_instructions
          description = params[:description]

          if description.blank?
            return render json: {
              success: false,
              error: "Description is required"
            }, status: :unprocessable_entity
          end

          result = AssistantInstructionsGeneratorService.generate(description: description)

          render json: {
            success: true,
            instructions: result[:instructions],
            name: result[:name],
            description: result[:description],
            explanation: result[:explanation]
          }
        end

        # POST /testing/openai/assistants/:assistant_id/playground/submit_tool_outputs
        #

        # POST /testing/openai/assistants/:assistant_id/playground/submit_tool_outputs
        #
        # Submits function call results back to OpenAI when a run is waiting for tool outputs.
        #
        # == OpenAI Assistants Function Calling Flow
        #
        # When an assistant has tools/functions defined, the following flow occurs:
        #
        # 1. User sends a message to the assistant
        # 2. Assistant decides to call one or more functions → run status becomes "requires_action"
        # 3. The run returns tool_calls: [{ id: "call_abc", function: { name: "get_weather", arguments: '{"city": "Paris"}' } }]
        # 4. Client executes the function(s) locally or mocks the response (in playground mode)
        # 5. Client calls this endpoint with the results → submit_tool_outputs
        # 6. OpenAI continues the run with the function results
        # 7. Assistant formulates its final response incorporating the function outputs
        #
        # == Parameters
        #
        # - thread_id [String] The conversation thread ID where the run is executing
        # - run_id [String] The run ID that is in "requires_action" status waiting for tool outputs
        # - tool_outputs [Array<Hash>] Array of function results to submit back to OpenAI:
        #   - tool_call_id [String] Must match the "id" from the original tool_call
        #   - output [String] The function's return value (what the assistant will see)
        #
        # == Response
        #
        # Returns one of two possible statuses:
        # - "completed": The assistant has finished and includes its final message
        # - "requires_action": The assistant wants to call MORE functions (parallel/sequential calls)
        #
        # @example Request body
        #   {
        #     "thread_id": "thread_abc123",
        #     "run_id": "run_xyz789",
        #     "tool_outputs": [
        #       { "tool_call_id": "call_abc", "output": "Sunny, 22°C" }
        #     ]
        #   }
        #
        def submit_tool_outputs
          thread_id = params[:thread_id]
          run_id = params[:run_id]
          tool_outputs = params[:tool_outputs]

          if thread_id.blank? || run_id.blank?
            return render json: {
              success: false,
              error: "thread_id and run_id are required"
            }, status: :unprocessable_entity
          end

          # Submit the tool outputs to OpenAI and wait for the run to complete (or require more actions)
          result = @service.submit_tool_outputs(
            thread_id: thread_id,
            run_id: run_id,
            tool_outputs: tool_outputs
          )

          if result[:success]
            # Response may include:
            # - status: "completed" with message and usage, OR
            # - status: "requires_action" with more tool_calls for sequential/parallel function calling
            render json: {
              success: true,
              status: result[:status],
              message: result[:message],
              usage: result[:usage],
              tool_calls: result[:tool_calls]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end
        # GET /testing/openai/assistants/:assistant_id/playground/list_vector_stores
        #
        # Lists vector stores
        def list_vector_stores
          result = @service.list_vector_stores

          if result[:success]
            render json: {
              success: true,
              vector_stores: result[:vector_stores]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # POST /testing/openai/assistants/:assistant_id/playground/add_file_to_vector_store
        #
        # Adds a file to a vector store
        def add_file_to_vector_store
          result = @service.add_file_to_vector_store(
            vector_store_id: params[:vector_store_id],
            file_id: params[:file_id]
          )

          if result[:success]
            render json: {
              success: true,
              vector_store_file: result[:vector_store_file]
            }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        # POST /testing/openai/assistants/:assistant_id/playground/attach_vector_store
        #
        # Attaches a vector store to an assistant
        def attach_vector_store
          result = @service.attach_vector_store_to_assistant(
            assistant_id: @assistant.assistant_id,
            vector_store_ids: Array(params[:vector_store_ids])
          )

          if result[:success]
            render json: { success: true }
          else
            render json: {
              success: false,
              error: result[:error]
            }, status: :unprocessable_entity
          end
        end

        private

        def set_assistant
          @assistant = PromptTracker::Openai::Assistant.find(params[:assistant_id]) if params[:assistant_id] != "new"
        end

        def initialize_service
          @service = AssistantPlaygroundService.new
        end

        def assistant_params
          params.require(:assistant).permit(
            :name,
            :description,
            :instructions,
            :model,
            :temperature,
            :top_p,
            :response_format,
            tools: [],
            functions: [ :name, :description, :strict, { parameters: {} } ],
            metadata: {}
          )
        end

        def load_available_models
          # Get OpenAI models from configuration for assistant playground context
          @available_models = PromptTracker.configuration.models_for(:assistant_playground, provider: :openai)

          # Fallback to default models if none configured
          if @available_models.blank?
            @available_models = [
              { id: "gpt-4o", name: "GPT-4o" },
              { id: "gpt-4-turbo", name: "GPT-4 Turbo" },
              { id: "gpt-4", name: "GPT-4" },
              { id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo" }
            ]
          end
        end
      end
    end
  end
end
