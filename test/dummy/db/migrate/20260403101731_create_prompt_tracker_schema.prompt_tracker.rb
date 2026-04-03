# frozen_string_literal: true

# This migration comes from prompt_tracker (originally 20251216000001)
# Consolidated migration that creates the complete PromptTracker schema.
#
# This migration replaces 38+ individual migrations with a single comprehensive
# schema definition. It creates all tables, indexes, and foreign keys needed
# for the PromptTracker Rails engine.
#
# Tables created (in dependency order):
# 1. prompts - Container for prompt versions
# 2. agent_versions - Individual versions of prompts
# 3. assistants - OpenAI assistants for conversation testing
# 4. llm_responses - Responses from LLM API calls
# 5. evaluations - Quality ratings for responses
# 6. ab_tests - A/B testing experiments
# 7. evaluator_configs - Configuration for auto-evaluators
# 8. tests - Test cases for prompts/assistants (polymorphic)
# 9. prompt_test_suites - Collections of tests
# 10. test_runs - Individual test executions (polymorphic)
# 11. prompt_test_suite_runs - Suite execution results
# 12. traces - Distributed tracing for LLM calls
# 13. spans - Individual spans within traces
# 14. datasets - Reusable test data collections (polymorphic)
# 15. dataset_rows - Individual rows of test data
# 16. human_evaluations - Human review of evaluations/responses
# 17. function_definitions - Reusable executable functions for agents
# 18. function_executions - Individual function execution logs
class CreatePromptTrackerSchema < ActiveRecord::Migration[7.2]
  def change
    # Enable PostgreSQL extension
    enable_extension "plpgsql"

    # ============================================================================
    # TABLE 1: agents
    # Container for different versions of an agent template
    # ============================================================================
    create_table :prompt_tracker_agents do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :category
      t.jsonb :tags, default: []
      t.string :created_by
      t.datetime :archived_at
      t.string :score_aggregation_strategy, default: "weighted_average"
      t.timestamps
    end

    add_index :prompt_tracker_agents, :name, unique: true
    add_index :prompt_tracker_agents, :slug, unique: true
    add_index :prompt_tracker_agents, :category
    add_index :prompt_tracker_agents, :archived_at
    add_index :prompt_tracker_agents, :score_aggregation_strategy, name: "index_prompts_on_aggregation_strategy"

    # ============================================================================
    # TABLE 2: agent_versions
    # Individual versions of a prompt with template and configuration
    # ============================================================================
    create_table :prompt_tracker_agent_versions do |t|
      t.bigint :agent_id, null: false
      t.text :user_prompt
      t.text :system_prompt
      t.integer :version_number, null: false
      t.string :status, default: "draft", null: false
      t.jsonb :variables_schema, default: []
      t.jsonb :model_config, default: {}
      t.jsonb :response_schema  # JSON Schema for structured output (OpenAI Structured Outputs)
      t.text :notes
      t.string :created_by
      t.datetime :archived_at  # Soft delete timestamp
      t.timestamps
    end

    add_index :prompt_tracker_agent_versions, :agent_id
    add_index :prompt_tracker_agent_versions, [ :agent_id, :status ], name: "index_agent_versions_on_prompt_and_status"
    add_index :prompt_tracker_agent_versions, [ :agent_id, :version_number ], unique: true, name: "index_agent_versions_on_prompt_and_version_number"
    add_index :prompt_tracker_agent_versions, :status
    add_index :prompt_tracker_agent_versions, :archived_at

    # ============================================================================
    # TABLE 3: llm_responses
    # Responses from LLM API calls with metadata and performance metrics
    # ============================================================================
    create_table :prompt_tracker_llm_responses do |t|
      t.bigint :agent_version_id, null: false
      t.text :rendered_prompt, null: false
      t.text :rendered_system_prompt
      t.jsonb :variables_used, default: {}
      t.text :response_text
      t.jsonb :response_metadata, default: {}
      t.string :status, default: "pending", null: false
      t.string :error_type
      t.text :error_message
      t.integer :response_time_ms
      t.integer :tokens_prompt
      t.integer :tokens_completion
      t.integer :tokens_total
      t.decimal :cost_usd, precision: 10, scale: 6
      t.string :provider, null: false
      t.string :model, null: false
      t.string :user_id
      t.string :session_id
      t.string :environment
      t.jsonb :context, default: {}
      t.bigint :ab_test_id
      t.string :ab_variant
      t.bigint :trace_id
      t.bigint :span_id

      # Multi-turn conversation tracking
      t.string :conversation_id  # Groups related responses in a multi-turn conversation
      t.integer :turn_number     # Order of this response in the conversation (1-indexed)

      # OpenAI Response API support
      t.string :response_id          # OpenAI Response API response ID (e.g., resp_abc123)
      t.string :previous_response_id # References the response_id of the previous turn

      # Tool usage tracking
      t.jsonb :tools_used, default: []   # Array of tool names used in this call
      t.jsonb :tool_outputs, default: {} # Hash of tool name => output data

      # Task Agent Timeline: Store LLM's intent to call tools (before execution)
      t.jsonb :tool_calls, default: []   # Array of tool call objects from LLM response

      # Deployed agent context (for both conversational and task agents)
      t.bigint :deployed_agent_id
      t.bigint :agent_conversation_id
      t.bigint :task_run_id

      t.timestamps
    end

    add_index :prompt_tracker_llm_responses, :agent_version_id
    add_index :prompt_tracker_llm_responses, :status
    add_index :prompt_tracker_llm_responses, :provider
    add_index :prompt_tracker_llm_responses, :model
    add_index :prompt_tracker_llm_responses, :environment
    add_index :prompt_tracker_llm_responses, :user_id
    add_index :prompt_tracker_llm_responses, :session_id
    add_index :prompt_tracker_llm_responses, :ab_test_id
    add_index :prompt_tracker_llm_responses, :trace_id
    add_index :prompt_tracker_llm_responses, :span_id
    add_index :prompt_tracker_llm_responses, :conversation_id
    add_index :prompt_tracker_llm_responses, [ :conversation_id, :turn_number ], name: "index_llm_responses_on_conversation_turn"
    add_index :prompt_tracker_llm_responses, :tools_used, using: :gin
    add_index :prompt_tracker_llm_responses, [ :status, :created_at ], name: "index_llm_responses_on_status_and_created_at"
    add_index :prompt_tracker_llm_responses, [ :provider, :model, :created_at ], name: "index_llm_responses_on_provider_model_created_at"
    add_index :prompt_tracker_llm_responses, [ :ab_test_id, :ab_variant ], name: "index_llm_responses_on_ab_test_and_variant"
    add_index :prompt_tracker_llm_responses, :response_id, unique: true, where: "response_id IS NOT NULL"
    add_index :prompt_tracker_llm_responses, :previous_response_id
    add_index :prompt_tracker_llm_responses, :deployed_agent_id
    add_index :prompt_tracker_llm_responses, :agent_conversation_id
    add_index :prompt_tracker_llm_responses, :task_run_id

    # ============================================================================
    # TABLE 4: evaluations
    # Quality ratings for LLM responses (human, automated, or LLM-as-judge)
    # ============================================================================
    create_table :prompt_tracker_evaluations do |t|
      t.bigint :llm_response_id
      t.decimal :score, precision: 10, scale: 2, null: false
      t.decimal :score_min, precision: 10, scale: 2, default: "0.0"
      t.decimal :score_max, precision: 10, scale: 2, default: "5.0"
      t.string :evaluator_type, null: false
      t.string :evaluator_id
      t.text :feedback
      t.jsonb :metadata, default: {}
      t.boolean :passed
      t.bigint :test_run_id
      t.string :evaluation_context, null: false, default: "tracked_call"
      t.bigint :evaluator_config_id
      t.timestamps
    end

    add_index :prompt_tracker_evaluations, :llm_response_id
    add_index :prompt_tracker_evaluations, :evaluator_type
    add_index :prompt_tracker_evaluations, :score, name: "index_evaluations_on_score"
    add_index :prompt_tracker_evaluations, [ :evaluator_type, :created_at ], name: "index_evaluations_on_type_and_created_at"
    add_index :prompt_tracker_evaluations, :test_run_id
    add_index :prompt_tracker_evaluations, :evaluation_context
    add_index :prompt_tracker_evaluations, :evaluator_config_id

    # ============================================================================
    # TABLE 6: ab_tests
    # A/B testing experiments for comparing prompt versions
    # ============================================================================
    create_table :prompt_tracker_ab_tests do |t|
      t.bigint :agent_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :hypothesis
      t.string :status, default: "draft", null: false
      t.string :metric_to_optimize, null: false
      t.string :optimization_direction, default: "minimize", null: false
      t.jsonb :traffic_split, default: {}, null: false
      t.jsonb :variants, default: [], null: false
      t.float :confidence_level, default: 0.95
      t.float :minimum_detectable_effect, default: 0.05
      t.integer :minimum_sample_size, default: 100
      t.jsonb :results, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.string :created_by
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :prompt_tracker_ab_tests, :agent_id
    add_index :prompt_tracker_ab_tests, :status
    add_index :prompt_tracker_ab_tests, :metric_to_optimize
    add_index :prompt_tracker_ab_tests, :started_at
    add_index :prompt_tracker_ab_tests, :completed_at
    add_index :prompt_tracker_ab_tests, [ :agent_id, :status ], name: "index_prompt_tracker_ab_tests_on_agent_id_and_status"

    # ============================================================================
    # TABLE 5: evaluator_configs
    # Configuration for automatic evaluators
    # ============================================================================
    create_table :prompt_tracker_evaluator_configs do |t|
      t.string :configurable_type, null: false
      t.bigint :configurable_id, null: false
      t.string :evaluator_type, null: false
      t.string :evaluator_key
      t.boolean :enabled, default: true, null: false
      t.integer :priority
      t.decimal :threshold_score, precision: 10, scale: 2
      t.string :depends_on
      t.jsonb :config, default: {}, null: false
      t.timestamps
    end

    add_index :prompt_tracker_evaluator_configs, [ :configurable_type, :configurable_id ], name: "index_evaluator_configs_on_configurable"
    add_index :prompt_tracker_evaluator_configs, :enabled
    add_index :prompt_tracker_evaluator_configs, :depends_on

    # ============================================================================
    # TABLE 6: tests (polymorphic - for prompts and assistants)
    # Test cases for validating prompt/assistant behavior
    # ============================================================================
    create_table :prompt_tracker_tests do |t|
      # Polymorphic association to testable (AgentVersion or Assistant)
      t.string :testable_type
      t.bigint :testable_id

      t.string :name, null: false
      t.text :description
      t.boolean :enabled, default: true, null: false
      t.jsonb :tags, default: [], null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :prompt_tracker_tests, [ :testable_type, :testable_id ]
    add_index :prompt_tracker_tests, :name
    add_index :prompt_tracker_tests, :enabled
    add_index :prompt_tracker_tests, :tags, using: :gin

    # ============================================================================
    # TABLE 7: prompt_test_suites
    # Collections of related tests
    # ============================================================================
    create_table :prompt_tracker_prompt_test_suites do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :agent_id
      t.boolean :enabled, default: true, null: false
      t.jsonb :tags, default: [], null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :prompt_tracker_prompt_test_suites, :name, unique: true
    add_index :prompt_tracker_prompt_test_suites, :agent_id
    add_index :prompt_tracker_prompt_test_suites, :enabled
    add_index :prompt_tracker_prompt_test_suites, :tags, using: :gin

    # ============================================================================
    # TABLE 8: test_runs
    # Individual test execution results (for both prompts and assistants)
    # ============================================================================
    create_table :prompt_tracker_test_runs do |t|
      t.bigint :test_id, null: false
      t.bigint :dataset_id
      t.bigint :dataset_row_id
      t.string :status, default: "pending", null: false
      t.boolean :passed
      t.text :error_message
      t.jsonb :assertion_results, default: {}, null: false
      t.integer :passed_evaluators, default: 0, null: false
      t.integer :failed_evaluators, default: 0, null: false
      t.integer :total_evaluators, default: 0, null: false
      t.jsonb :evaluator_results, default: [], null: false
      t.integer :execution_time_ms
      t.decimal :cost_usd, precision: 10, scale: 6
      t.jsonb :metadata, default: {}, null: false

      # Unified output storage for all test types (single-turn and conversational)
      # Structure: { rendered_prompt, model, provider, messages, tokens, status, ... }
      t.jsonb :output_data

      t.timestamps
    end

    add_index :prompt_tracker_test_runs, :test_id
    add_index :prompt_tracker_test_runs, :status
    add_index :prompt_tracker_test_runs, :passed
    add_index :prompt_tracker_test_runs, :created_at
    add_index :prompt_tracker_test_runs, :output_data, using: :gin

    # ============================================================================
    # TABLE 9: prompt_test_suite_runs
    # Test suite execution results
    # ============================================================================
    create_table :prompt_tracker_prompt_test_suite_runs do |t|
      t.bigint :prompt_test_suite_id, null: false
      t.string :status, default: "pending", null: false
      t.integer :total_tests, default: 0, null: false
      t.integer :passed_tests, default: 0, null: false
      t.integer :failed_tests, default: 0, null: false
      t.integer :skipped_tests, default: 0, null: false
      t.integer :error_tests, default: 0, null: false
      t.integer :total_duration_ms
      t.decimal :total_cost_usd, precision: 10, scale: 6
      t.string :triggered_by
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :prompt_tracker_prompt_test_suite_runs, :prompt_test_suite_id, name: "idx_on_prompt_test_suite_id_4251a091be"
    add_index :prompt_tracker_prompt_test_suite_runs, :status
    add_index :prompt_tracker_prompt_test_suite_runs, :created_at
    add_index :prompt_tracker_prompt_test_suite_runs, [ :prompt_test_suite_id, :created_at ], name: "idx_on_prompt_test_suite_id_created_at_00b03ff2b9"

    # ============================================================================
    # TABLE 10: traces
    # Distributed tracing for LLM calls
    # ============================================================================
    create_table :prompt_tracker_traces do |t|
      t.string :name, null: false
      t.text :input
      t.text :output
      t.string :status, default: "running", null: false
      t.string :session_id
      t.string :user_id
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_ms
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :prompt_tracker_traces, :session_id
    add_index :prompt_tracker_traces, :user_id
    add_index :prompt_tracker_traces, :started_at
    add_index :prompt_tracker_traces, [ :status, :created_at ], name: "index_prompt_tracker_traces_on_status_and_created_at"

    # ============================================================================
    # TABLE 11: spans
    # Individual spans within traces
    # ============================================================================
    create_table :prompt_tracker_spans do |t|
      t.bigint :trace_id, null: false
      t.bigint :parent_span_id
      t.string :name, null: false
      t.string :span_type
      t.text :input
      t.text :output
      t.string :status, default: "running", null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_ms
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :prompt_tracker_spans, :trace_id
    add_index :prompt_tracker_spans, :parent_span_id
    add_index :prompt_tracker_spans, :span_type
    add_index :prompt_tracker_spans, [ :status, :created_at ], name: "index_prompt_tracker_spans_on_status_and_created_at"

    # ============================================================================
    # TABLE 12: datasets (polymorphic - for prompts and assistants)
    # Reusable test data collections
    # ============================================================================
    create_table :prompt_tracker_datasets do |t|
      # Polymorphic association to testable (AgentVersion or Assistant)
      t.string :testable_type
      t.bigint :testable_id

      t.string :name, null: false
      t.text :description
      t.jsonb :schema, null: false, default: []
      t.string :created_by
      t.jsonb :metadata, null: false, default: {}

      # Dataset type: single_turn (0) or conversational (1)
      t.integer :dataset_type, default: 0, null: false

      t.timestamps
    end

    add_index :prompt_tracker_datasets, [ :testable_type, :testable_id ]
    add_index :prompt_tracker_datasets, :created_at
    add_index :prompt_tracker_datasets, :dataset_type

    # ============================================================================
    # TABLE 13: dataset_rows
    # Individual rows of test data
    # ============================================================================
    create_table :prompt_tracker_dataset_rows do |t|
      t.bigint :dataset_id, null: false
      t.jsonb :row_data, null: false, default: {}
      t.string :source, null: false, default: "manual"
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :prompt_tracker_dataset_rows, :dataset_id
    add_index :prompt_tracker_dataset_rows, :created_at
    add_index :prompt_tracker_dataset_rows, :source

    # ============================================================================
    # TABLE 14: human_evaluations
    # Human review of evaluations or responses
    # ============================================================================
    create_table :prompt_tracker_human_evaluations do |t|
      t.bigint :evaluation_id
      t.bigint :llm_response_id
      t.bigint :test_run_id
      t.decimal :score, precision: 10, scale: 2, null: false
      t.text :feedback
      t.timestamps
    end

    add_index :prompt_tracker_human_evaluations, :evaluation_id
    add_index :prompt_tracker_human_evaluations, :llm_response_id
    add_index :prompt_tracker_human_evaluations, :test_run_id

    # Add check constraint for human_evaluations
    # Exactly one of evaluation_id, llm_response_id, or test_run_id must be set
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE prompt_tracker_human_evaluations
          ADD CONSTRAINT human_evaluation_belongs_to_one
          CHECK (
            (evaluation_id IS NOT NULL AND llm_response_id IS NULL AND test_run_id IS NULL) OR
            (evaluation_id IS NULL AND llm_response_id IS NOT NULL AND test_run_id IS NULL) OR
            (evaluation_id IS NULL AND llm_response_id IS NULL AND test_run_id IS NOT NULL)
          )
        SQL
      end

      dir.down do
        execute <<-SQL
          ALTER TABLE prompt_tracker_human_evaluations
          DROP CONSTRAINT IF EXISTS human_evaluation_belongs_to_one
        SQL
      end
    end

    # ============================================================================
    # TABLE 15: function_definitions
    # Reusable executable functions for agents
    # ============================================================================
    create_table :prompt_tracker_function_definitions do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :parameters, default: {}, null: false  # JSON Schema
      t.text :code, null: false  # Ruby source code
      t.string :language, null: false, default: "ruby"
      t.string :category
      t.jsonb :tags, default: []
      t.text :environment_variables  # Encrypted by Rails
      t.jsonb :dependencies, default: []  # Array of gem names/versions
      t.jsonb :example_input, default: {}
      t.jsonb :example_output, default: {}
      t.integer :version, default: 1, null: false
      t.string :created_by
      t.integer :usage_count, default: 0, null: false
      t.datetime :last_executed_at
      t.integer :execution_count, default: 0, null: false
      t.integer :average_execution_time_ms
      t.string :lambda_function_name
      t.string :deployment_status, default: "not_deployed", null: false
      t.datetime :deployed_at
      t.text :deployment_error
      t.timestamps
    end

    add_index :prompt_tracker_function_definitions, :name, unique: true
    add_index :prompt_tracker_function_definitions, :category
    add_index :prompt_tracker_function_definitions, :language
    add_index :prompt_tracker_function_definitions, :last_executed_at
    add_index :prompt_tracker_function_definitions, :created_at
    add_index :prompt_tracker_function_definitions, :lambda_function_name
    add_index :prompt_tracker_function_definitions, :deployment_status

    # ============================================================================
    # TABLE: environment_variables
    # Shared environment variables (API keys, secrets) reused across functions
    # ============================================================================
    create_table :prompt_tracker_environment_variables do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :value, null: false
      t.text :description

      t.timestamps
    end

    add_index :prompt_tracker_environment_variables, :key, unique: true
    add_index :prompt_tracker_environment_variables, :name

    # ============================================================================
    # JOIN TABLE: function_definition_environment_variables
    # Many-to-many relationship between functions and shared environment variables
    # ============================================================================
    create_table :prompt_tracker_function_definition_environment_variables do |t|
      t.references :function_definition,
                   null: false,
                   index: { name: "index_func_def_env_vars_on_func_def_id" }
      t.references :environment_variable,
                   null: false,
                   index: { name: "index_func_def_env_vars_on_env_var_id" }

      t.timestamps
    end

    add_index :prompt_tracker_function_definition_environment_variables,
              [ :function_definition_id, :environment_variable_id ],
              unique: true,
              name: "index_func_def_env_vars_unique"

    # ============================================================================
    # TABLE: deployed_agents
    # Deployed agent versions accessible via unique URLs
    # ============================================================================
    create_table :prompt_tracker_deployed_agents do |t|
      t.references :agent_version,
                   null: false,
                   index: true

      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "active"
      t.jsonb :deployment_config, default: {}, null: false
      t.datetime :deployed_at
      t.datetime :paused_at
      t.text :error_message
      t.integer :request_count, default: 0, null: false
      t.datetime :last_request_at
      t.string :created_by
      t.text :api_key
      t.string :agent_type, default: "conversational", null: false
      t.jsonb :task_config, default: {}, null: false

      t.timestamps
    end

    add_index :prompt_tracker_deployed_agents, :slug, unique: true
    add_index :prompt_tracker_deployed_agents, :status
    add_index :prompt_tracker_deployed_agents, :created_at
    add_index :prompt_tracker_deployed_agents, :agent_type

    # ============================================================================
    # TABLE: agent_conversations
    # Conversation state for deployed agents
    # ============================================================================
    create_table :prompt_tracker_agent_conversations do |t|
      t.references :deployed_agent,
                   null: false,
                   index: true

      t.string :conversation_id, null: false
      t.jsonb :messages, default: [], null: false
      t.jsonb :metadata, default: {}, null: false
      t.datetime :last_message_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :prompt_tracker_agent_conversations,
              [ :deployed_agent_id, :conversation_id ],
              unique: true,
              name: "index_agent_conversations_on_agent_and_conversation"
    add_index :prompt_tracker_agent_conversations, :expires_at
    add_index :prompt_tracker_agent_conversations, :last_message_at

    # ============================================================================
    # JOIN TABLE: deployed_agent_functions
    # Many-to-many relationship between deployed agents and function definitions
    # ============================================================================
    create_table :prompt_tracker_deployed_agent_functions do |t|
      t.references :deployed_agent,
                   null: false,
                   index: { name: "index_deployed_agent_funcs_on_agent_id" }
      t.references :function_definition,
                   null: false,
                   index: { name: "index_deployed_agent_funcs_on_func_def_id" }

      t.timestamps
    end

    add_index :prompt_tracker_deployed_agent_functions,
              [ :deployed_agent_id, :function_definition_id ],
              unique: true,
              name: "index_deployed_agent_functions_unique"

    # ============================================================================
    # TABLE: task_runs
    # Individual task agent executions
    # ============================================================================
    create_table :prompt_tracker_task_runs do |t|
      t.references :deployed_agent,
                   null: false,
                   index: true

      t.string :status, null: false, default: "queued"
      t.string :trigger_type, null: false

      t.datetime :started_at
      t.datetime :completed_at

      t.jsonb :variables_used, default: {}, null: false
      t.text :output_summary
      t.text :error_message
      t.jsonb :metadata, default: {}, null: false

      t.integer :llm_calls_count, default: 0, null: false
      t.integer :function_calls_count, default: 0, null: false
      t.integer :iterations_count, default: 0, null: false
      t.decimal :total_cost_usd, precision: 10, scale: 6

      t.timestamps
    end

    add_index :prompt_tracker_task_runs, :status
    add_index :prompt_tracker_task_runs, :trigger_type
    add_index :prompt_tracker_task_runs, :started_at
    add_index :prompt_tracker_task_runs, [ :deployed_agent_id, :created_at ],
              name: "index_task_runs_on_agent_and_created"

    # ============================================================================
    # TABLE: task_schedules
    # Scheduled task execution configuration for deployed task agents
    # ============================================================================
    create_table :prompt_tracker_task_schedules do |t|
      t.references :deployed_agent,
                   null: false,
                   index: { unique: true }

      t.string :schedule_type, null: false
      t.string :cron_expression
      t.integer :interval_value
      t.string :interval_unit

      t.string :timezone, default: "UTC", null: false
      t.boolean :enabled, default: true, null: false

      t.datetime :last_run_at
      t.datetime :next_run_at
      t.integer :run_count, default: 0, null: false

      t.timestamps
    end

    add_index :prompt_tracker_task_schedules, :enabled
    add_index :prompt_tracker_task_schedules, :next_run_at
    add_index :prompt_tracker_task_schedules, [ :enabled, :next_run_at ],
              name: "index_task_schedules_on_enabled_and_next_run"

    # ============================================================================
    # TABLE 16: function_executions
    # Individual function execution logs for analytics and debugging
    # ============================================================================
    create_table :prompt_tracker_function_executions do |t|
      t.bigint :function_definition_id
      t.jsonb :arguments, default: {}, null: false
      t.jsonb :result
      t.boolean :success, null: false, default: true
      t.text :error_message
      t.integer :execution_time_ms
      t.datetime :executed_at, null: false

      # Task Agent Timeline: Link to planning step that triggered this execution
      t.string :planning_step_id

      t.bigint :deployed_agent_id
      t.bigint :agent_conversation_id
      t.bigint :task_run_id

      t.timestamps
    end

    add_index :prompt_tracker_function_executions, :function_definition_id
    add_index :prompt_tracker_function_executions, :executed_at
    add_index :prompt_tracker_function_executions, :planning_step_id
    add_index :prompt_tracker_function_executions, :success
    add_index :prompt_tracker_function_executions, [ :function_definition_id, :executed_at ],
              name: "index_function_executions_on_definition_and_executed_at"
    add_index :prompt_tracker_function_executions, :deployed_agent_id
    add_index :prompt_tracker_function_executions, :agent_conversation_id, name: "idx_on_agent_conversation_id_74963468f2"
    add_index :prompt_tracker_function_executions, :task_run_id

    # ============================================================================
    # FOREIGN KEYS
    # Add all foreign key constraints
    # ============================================================================
    add_foreign_key :prompt_tracker_ab_tests, :prompt_tracker_agents, column: :agent_id
    add_foreign_key :prompt_tracker_agent_conversations, :prompt_tracker_deployed_agents, column: :deployed_agent_id
    add_foreign_key :prompt_tracker_agent_versions, :prompt_tracker_agents, column: :agent_id
    add_foreign_key :prompt_tracker_dataset_rows, :prompt_tracker_datasets, column: :dataset_id
    # llm_response_id is optional - evaluations can be for test_runs (no llm_response) or tracked_calls (has llm_response)
    # Don't add foreign key constraint to allow NULL values
    add_foreign_key :prompt_tracker_evaluations, :prompt_tracker_test_runs, column: :test_run_id
    add_foreign_key :prompt_tracker_function_definition_environment_variables, :prompt_tracker_environment_variables, column: :environment_variable_id
    add_foreign_key :prompt_tracker_function_definition_environment_variables, :prompt_tracker_function_definitions, column: :function_definition_id
    add_foreign_key :prompt_tracker_function_executions, :prompt_tracker_agent_conversations, column: :agent_conversation_id
    add_foreign_key :prompt_tracker_function_executions, :prompt_tracker_deployed_agents, column: :deployed_agent_id
    add_foreign_key :prompt_tracker_function_executions, :prompt_tracker_function_definitions, column: :function_definition_id
    add_foreign_key :prompt_tracker_function_executions, :prompt_tracker_task_runs, column: :task_run_id
    add_foreign_key :prompt_tracker_human_evaluations, :prompt_tracker_evaluations, column: :evaluation_id
    add_foreign_key :prompt_tracker_human_evaluations, :prompt_tracker_llm_responses, column: :llm_response_id
    add_foreign_key :prompt_tracker_human_evaluations, :prompt_tracker_test_runs, column: :test_run_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_ab_tests, column: :ab_test_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_agent_conversations, column: :agent_conversation_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_agent_versions, column: :agent_version_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_deployed_agents, column: :deployed_agent_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_spans, column: :span_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_task_runs, column: :task_run_id
    add_foreign_key :prompt_tracker_llm_responses, :prompt_tracker_traces, column: :trace_id
    add_foreign_key :prompt_tracker_task_runs, :prompt_tracker_deployed_agents, column: :deployed_agent_id
    add_foreign_key :prompt_tracker_task_schedules, :prompt_tracker_deployed_agents, column: :deployed_agent_id
    add_foreign_key :prompt_tracker_test_runs, :prompt_tracker_tests, column: :test_id
    add_foreign_key :prompt_tracker_test_runs, :prompt_tracker_datasets, column: :dataset_id
    add_foreign_key :prompt_tracker_test_runs, :prompt_tracker_dataset_rows, column: :dataset_row_id
    add_foreign_key :prompt_tracker_spans, :prompt_tracker_spans, column: :parent_span_id
    add_foreign_key :prompt_tracker_spans, :prompt_tracker_traces, column: :trace_id
  end
end
