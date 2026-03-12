# frozen_string_literal: true

module PromptTracker
  # Execute user-written Ruby code using AWS Lambda.
  #
  # This service provides a simple interface for executing code in a sandboxed environment.
  # The actual execution is delegated to LambdaAdapter, which handles AWS Lambda integration.
  #
  # @example Execute a simple function
  #   result = CodeExecutor.execute(
  #     code: "def execute(name:)\n  { greeting: \"Hello, #{name}!\" }\nend",
  #     arguments: { name: "World" }
  #   )
  #   result.success? # => true
  #   result.result   # => { "greeting" => "Hello, World!" }
  #
  # @example Execute with environment variables
  #   result = CodeExecutor.execute(
  #     code: "def execute\n  { api_key: ENV['API_KEY'] }\nend",
  #     arguments: {},
  #     environment_variables: { "API_KEY" => "secret" }
  #   )
  #
  class CodeExecutor
    # Result object returned by execute.
    # @!attribute [r] success?
    #   @return [Boolean] whether execution succeeded
    # @!attribute [r] result
    #   @return [Hash, nil] execution result (if successful)
    # @!attribute [r] error
    #   @return [String, nil] error message (if failed)
    # @!attribute [r] execution_time_ms
    #   @return [Integer] execution time in milliseconds
    # @!attribute [r] logs
    #   @return [String] execution logs
    Result = Struct.new(:success?, :result, :error, :execution_time_ms, :logs, keyword_init: true)

    # Execute user code using AWS Lambda.
    #
    # @param code [String] Ruby source code containing an `execute` method
    # @param arguments [Hash] arguments to pass to the execute method
    # @param environment_variables [Hash] environment variables to set
    # @param dependencies [Array<String, Hash>] gem dependencies
    # @return [Result] execution result
    def self.execute(code:, arguments:, environment_variables: {}, dependencies: [])
      LambdaAdapter.execute(
        code: code,
        arguments: arguments,
        environment_variables: environment_variables,
        dependencies: dependencies
      )
    end
  end
end
