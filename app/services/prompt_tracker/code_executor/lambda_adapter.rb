# frozen_string_literal: true

require "aws-sdk-lambda"
require "zip"
require "digest"
require "base64"

module PromptTracker
  class CodeExecutor
    # AWS Lambda-based code execution adapter.
    #
    # This adapter handles:
    # - Creating/updating Lambda functions with user code
    # - Packaging code and dependencies into deployment packages
    # - Invoking Lambda functions with arguments
    # - Parsing responses and handling errors
    #
    # Benefits of using Lambda:
    # - Zero infrastructure management
    # - Built-in sandboxing and security
    # - Automatic scaling
    # - Pay-per-use pricing
    # - Easy to test locally with SAM/LocalStack
    #
    class LambdaAdapter
      TIMEOUT = 30 # seconds
      MEMORY_SIZE = 512 # MB
      RUNTIME = "ruby3.2"

      Result = CodeExecutor::Result

      # Execute user code using AWS Lambda.
      #
      # @param code [String] Ruby source code
      # @param arguments [Hash] function arguments
      # @param environment_variables [Hash] environment variables
      # @param dependencies [Array<String, Hash>] gem dependencies
      # @return [Result] execution result
      def self.execute(code:, arguments:, environment_variables: {}, dependencies: [])
        new(code, arguments, environment_variables, dependencies).execute
      end

      def initialize(code, arguments, environment_variables, dependencies)
        @code = code
        @arguments = arguments
        @environment_variables = environment_variables
        @dependencies = dependencies
        @lambda_client = build_lambda_client
      end

      def execute
        start_time = Time.current

        # Create or update Lambda function with user code
        function_name = ensure_lambda_function

        # Invoke Lambda with arguments
        response = invoke_lambda(function_name)

        execution_time_ms = ((Time.current - start_time) * 1000).to_i

        # Parse response
        parse_lambda_response(response, execution_time_ms)
      rescue Aws::Lambda::Errors::ServiceException => e
        Result.new(
          success?: false,
          result: nil,
          error: "Lambda error: #{e.message}",
          execution_time_ms: 0,
          logs: ""
        )
      rescue StandardError => e
        Result.new(
          success?: false,
          result: nil,
          error: "Execution error: #{e.message}",
          execution_time_ms: 0,
          logs: ""
        )
      end

      private

      def build_lambda_client
        config = PromptTracker.configuration
        lambda_config = config.function_provider_config(:aws_lambda)

        raise "AWS Lambda function provider not configured" unless lambda_config

        Aws::Lambda::Client.new(
          region: lambda_config[:region] || "us-east-1",
          credentials: Aws::Credentials.new(
            lambda_config[:access_key_id],
            lambda_config[:secret_access_key]
          )
        )
      end

      def ensure_lambda_function
        # Generate unique function name based on code hash
        # This allows caching - same code = same Lambda function
        lambda_config = PromptTracker.configuration.function_provider_config(:aws_lambda)
        function_prefix = lambda_config[:function_prefix] || "prompt-tracker"
        code_hash = Digest::SHA256.hexdigest(@code)[0..15]
        function_name = "#{function_prefix}-#{code_hash}"

        begin
          # Check if function exists
          @lambda_client.get_function(function_name: function_name)

          # Function exists - update code if needed
          @lambda_client.update_function_code(
            function_name: function_name,
            zip_file: build_deployment_package
          )

          # Update environment variables
          @lambda_client.update_function_configuration(
            function_name: function_name,
            environment: { variables: @environment_variables }
          )
        rescue Aws::Lambda::Errors::ResourceNotFoundException
          # Function doesn't exist - create it
          lambda_config = PromptTracker.configuration.function_provider_config(:aws_lambda)
          @lambda_client.create_function(
            function_name: function_name,
            runtime: RUNTIME,
            role: lambda_config[:execution_role_arn],
            handler: "function.handler",
            code: { zip_file: build_deployment_package },
            timeout: TIMEOUT,
            memory_size: MEMORY_SIZE,
            environment: { variables: @environment_variables },
            description: "PromptTracker function execution"
          )

          # Wait for function to be active
          @lambda_client.wait_until(:function_active, function_name: function_name)
        end

        function_name
      end

      def invoke_lambda(function_name)
        @lambda_client.invoke(
          function_name: function_name,
          invocation_type: "RequestResponse", # Synchronous
          log_type: "Tail", # Include logs in response
          payload: { arguments: @arguments }.to_json
        )
      end

      def parse_lambda_response(response, execution_time_ms)
        # Decode logs (base64 encoded)
        logs = response.log_result ? Base64.decode64(response.log_result) : ""

        # Parse payload
        payload = JSON.parse(response.payload.read)

        if response.status_code == 200 && !payload["errorMessage"]
          Result.new(
            success?: true,
            result: payload["result"],
            error: nil,
            execution_time_ms: execution_time_ms,
            logs: logs
          )
        else
          Result.new(
            success?: false,
            result: nil,
            error: payload["errorMessage"] || payload["errorType"] || "Unknown error",
            execution_time_ms: execution_time_ms,
            logs: logs
          )
        end
      end

      def build_deployment_package
        # Create ZIP file with Lambda handler and user code
        zip_buffer = Zip::OutputStream.write_buffer do |zip|
          # Add Lambda handler
          zip.put_next_entry("function.rb")
          zip.write(lambda_handler_code)

          # Add user code
          zip.put_next_entry("user_code.rb")
          zip.write(@code)

          # Add Gemfile if dependencies specified
          if @dependencies.any?
            zip.put_next_entry("Gemfile")
            zip.write(gemfile_content)
          end
        end

        zip_buffer.rewind
        zip_buffer.read
      end

      def lambda_handler_code
        # Lambda handler that loads and executes user code
        <<~RUBY
          require 'json'

          def handler(event:, context:)
            # Load user code
            require_relative 'user_code'

            # Extract arguments from event
            arguments = event['arguments'] || {}

            # Execute user function
            result = execute(**arguments.transform_keys(&:to_sym))

            # Return result
            { result: result }
          rescue => e
            # Return error
            {
              errorMessage: e.message,
              errorType: e.class.name,
              stackTrace: e.backtrace
            }
          end
        RUBY
      end

      def gemfile_content
        # Base gems always available
        base_gems = [
          "gem 'http'",
          "gem 'json'"
        ]

        # User-specified gems
        user_gems = @dependencies.map do |dep|
          if dep.is_a?(Hash)
            "gem '#{dep['name']}', '#{dep['version']}'"
          else
            "gem '#{dep}'"
          end
        end

        <<~GEMFILE
          source 'https://rubygems.org'

          #{base_gems.join("\n")}
          #{user_gems.join("\n")}
        GEMFILE
      end
    end
  end
end
