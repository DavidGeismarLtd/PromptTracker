# frozen_string_literal: true

module PromptTracker
  module FunctionExecutors
    # Base class for function executors.
    #
    # Executors are responsible for running function code in different environments:
    # - WebhookExecutor: Calls external HTTP endpoints
    # - LambdaExecutor: Executes code in AWS Lambda
    # - DockerExecutor: Runs code in Docker containers
    # - MockExecutor: Returns mock data for testing
    #
    # @example Execute a function
    #   executor = FunctionExecutors::WebhookExecutor.new(function_definition)
    #   result = executor.execute(arguments: { query: "news" })
    #
    class BaseExecutor
      attr_reader :function_definition

      def initialize(function_definition)
        @function_definition = function_definition
      end

      # Execute the function with given arguments
      #
      # @param arguments [Hash] Function arguments
      # @param context [Hash] Additional context (user_id, session_id, etc.)
      # @return [ExecutionResult] Result with success, data, error, and metadata
      def execute(arguments:, context: {})
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      # Check if this executor can handle the function
      #
      # @return [Boolean]
      def can_execute?
        raise NotImplementedError, "#{self.class} must implement #can_execute?"
      end

      protected

      # Build a successful result
      #
      # @param data [Hash] Result data
      # @param metadata [Hash] Additional metadata
      # @return [ExecutionResult]
      def success_result(data, metadata = {})
        ExecutionResult.new(
          success: true,
          data: data,
          error: nil,
          metadata: metadata
        )
      end

      # Build an error result
      #
      # @param error [String] Error message
      # @param metadata [Hash] Additional metadata
      # @return [ExecutionResult]
      def error_result(error, metadata = {})
        ExecutionResult.new(
          success: false,
          data: nil,
          error: error,
          metadata: metadata
        )
      end
    end

    # Result of a function execution
    ExecutionResult = Struct.new(:success, :data, :error, :metadata, keyword_init: true) do
      def success?
        success
      end

      def failure?
        !success
      end
    end
  end
end
