# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Deploys a PromptVersion as a conversational or task agent.
      #
      # Arguments (JSON plan collected by the deployment wizard):
      # - prompt_version_id: (required) ID of the prompt version to deploy
      # - name: (optional) Agent name, defaults to "<prompt name> Agent"
      # - agent_type: (required) "conversational" or "task"
      # - deployment_config: (optional) Hash for conversational agents
      # - task_config: (optional) Hash for task agents
      #
      # The shape of deployment_config and task_config mirrors
      # PromptTracker::DeployedAgent#deployment_config and #task_config.
      class DeployAgent < Base
        def self.tool_definition
          {
            name: "deploy_agent",
            description: "Deploy a PromptVersion as a conversational or task agent.",
            parameters: {
              type: "object",
              properties: {
                prompt_version_id: { type: "integer", description: "ID of the prompt version to deploy" },
                name: { type: "string", description: "Optional name for the deployed agent (e.g., 'Support Agent')" },
                agent_type: { type: "string", description: "Type of agent to create: 'conversational' (chat UI + API) or 'task' (background task agent).", enum: %w[conversational task] },
                deployment_config: {
                  type: "object",
                  description: "Configuration for conversational agents.",
                  properties: {
                    conversation_ttl: { type: "integer", description: "How long to keep conversations alive in seconds (e.g., 3600)." },
                    enable_web_ui: { type: "boolean", description: "Whether to enable the public web chat UI." },
                    auth: { type: "object", description: "Authentication configuration (optional).", properties: { type: { type: "string", description: "Auth type identifier." } } },
                    rate_limit: { type: "object", description: "Optional rate limiting configuration.", properties: { requests_per_minute: { type: "integer", description: "Maximum requests per minute." } } },
                    cors: { type: "object", description: "Optional CORS configuration.", properties: { allowed_origins: { type: "array", items: { type: "string" }, description: "List of allowed origins." } } }
                  }
                },
                task_config: {
                  type: "object",
                  description: "Configuration for task agents.",
                  properties: {
                    initial_prompt: { type: "string", description: "Instruction describing the task the agent should perform." },
                    variables: { type: "object", description: "Optional default variables object for the task." },
                    execution: {
                      type: "object", description: "Execution configuration.",
                      properties: {
                        max_iterations: { type: "integer", description: "Maximum number of agent iterations (default 5)." },
                        timeout_seconds: { type: "integer", description: "Maximum time allowed for the task in seconds (default 3600)." },
                        retry_on_failure: { type: "boolean", description: "Whether to retry the task on failure (default false)." },
                        max_retries: { type: "integer", description: "Maximum number of retries (default 3)." }
                      }
                    },
                    planning: {
                      type: "object", description: "Optional planning configuration.",
                      properties: {
                        enabled: { type: "boolean", description: "Whether explicit planning is enabled." },
                        max_steps: { type: "integer", description: "Maximum number of planning steps (default 20)." },
                        allow_plan_modifications: { type: "boolean", description: "Whether the agent may modify its plan as it executes." }
                      }
                    },
                    completion_criteria: { type: "object", description: "Optional completion criteria.", properties: { type: { type: "string", description: "Completion criteria type identifier." } } }
                  }
                }
              },
              required: %w[prompt_version_id]
            }
          }
        end

        protected

        def execute
          version = find_prompt_version
          type = normalized_agent_type
          name = arg(:name).presence || default_name_for(version)

          attributes = {
            prompt_version: version,
            name: name,
            agent_type: type
          }

          if type == "conversational"
            attributes[:deployment_config] = normalized_deployment_config
          else
            attributes[:task_config] = normalized_task_config
          end

          agent = PromptTracker::DeployedAgent.new(attributes)

          if agent.save
            success(
              build_success_message(version, agent),
              links: build_links(agent),
              entities: { deployed_agent_id: agent.id, prompt_version_id: version.id }
            )
          else
            failure(format_errors(agent))
          end
        end

        def validate_arguments!
          raise ArgumentError, "prompt_version_id is required" if arg(:prompt_version_id).blank?

          type = (arg(:agent_type).presence || "conversational").to_s
          unless %w[conversational task].include?(type)
            raise ArgumentError, "agent_type must be 'conversational' or 'task'"
          end

          return unless type == "task"

          cfg = arg(:task_config)
          cfg_hash = cfg.is_a?(Hash) ? cfg.deep_symbolize_keys : {}
          initial_prompt = cfg_hash[:initial_prompt]

          if initial_prompt.blank?
            raise ArgumentError, "task_config.initial_prompt is required for task agents"
          end
        end

        private

        def find_prompt_version
          version_id = arg(:prompt_version_id)
          version = PromptVersion.find_by(id: version_id)
          raise ArgumentError, "PromptVersion #{version_id} not found" unless version
          version
        end

        def normalized_agent_type
          (arg(:agent_type).presence || "conversational").to_s
        end

        def default_name_for(version)
          "#{version.prompt.name} Agent"
        end

        def normalized_deployment_config
          raw = arg(:deployment_config)
          return {} unless raw.is_a?(Hash)

          raw.deep_symbolize_keys
        end

        def normalized_task_config
          raw = arg(:task_config)
          return {} unless raw.is_a?(Hash)

          cfg = raw.deep_symbolize_keys

          {
            initial_prompt: cfg[:initial_prompt],
            variables: cfg[:variables].is_a?(Hash) ? cfg[:variables] : {},
            execution: normalized_execution_config(cfg[:execution]),
            planning: normalized_planning_config(cfg[:planning]),
            completion_criteria: normalized_completion_config(cfg[:completion_criteria])
          }
        end

        def normalized_execution_config(raw)
          conf = raw.is_a?(Hash) ? raw.deep_symbolize_keys : {}

          {
            max_iterations: (conf[:max_iterations] || 5).to_i,
            timeout_seconds: (conf[:timeout_seconds] || 3600).to_i,
            retry_on_failure: conf.key?(:retry_on_failure) ? !!conf[:retry_on_failure] : false,
            max_retries: (conf[:max_retries] || 3).to_i
          }
        end

        def normalized_planning_config(raw)
          conf = raw.is_a?(Hash) ? raw.deep_symbolize_keys : {}

          {
            enabled: conf.key?(:enabled) ? !!conf[:enabled] : false,
            max_steps: (conf[:max_steps] || 20).to_i,
            allow_plan_modifications: conf.key?(:allow_plan_modifications) ? !!conf[:allow_plan_modifications] : true
          }
        end

        def normalized_completion_config(raw)
          conf = raw.is_a?(Hash) ? raw.deep_symbolize_keys : {}

          {
            type: conf[:type].presence || "auto"
          }
        end

        def build_success_message(version, agent)
          <<~MSG.strip
            ✅ Deployed agent "#{agent.name}" for prompt "#{version.prompt.name}" (version #{version.name}).

            🤖 Agent type: #{agent.agent_type}
            🔗 Public URL: #{agent.public_url}
          MSG
        end

        def build_links(agent)
          [
            link("View agent", "/prompt_tracker/agents/#{agent.slug}", icon: "robot")
          ]
        end

        def format_errors(agent)
          errors = agent.errors.full_messages
          "Failed to deploy agent: #{errors.join(', ')}"
        end
      end
    end
  end
end
