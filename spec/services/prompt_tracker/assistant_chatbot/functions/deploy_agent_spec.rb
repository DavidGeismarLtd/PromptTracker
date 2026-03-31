# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Functions::DeployAgent do
  let(:prompt_version) { create(:prompt_version) }
  let(:context) { {} }

  let(:arguments) do
    {
      prompt_version_id: prompt_version.id,
      name: "Support Agent",
      agent_type: "conversational",
      deployment_config: {
        conversation_ttl: 1800,
        enable_web_ui: true
      }
    }
  end

  subject(:function) { described_class.new(arguments, context) }

  describe "#call" do
    it "creates a conversational deployed agent with the given config" do
      result = function.call

      expect(result.success?).to be true

      agent = PromptTracker::DeployedAgent.last
      expect(agent).to be_present
      expect(agent.prompt_version).to eq(prompt_version)
      expect(agent.agent_type_conversational?).to be true
      expect(agent.name).to eq("Support Agent")
      expect(agent.deployment_config["conversation_ttl"]).to eq(1800)

      expect(result.entities_created[:deployed_agent_id]).to eq(agent.id)
      expect(result.entities_created[:prompt_version_id]).to eq(prompt_version.id)
    end

    it "creates a task agent when agent_type is task" do
      arguments[:agent_type] = "task"
      arguments[:task_config] = {
        initial_prompt: "Do something important",
        variables: { "foo" => "bar" },
        execution: { max_iterations: 7 }
      }
      arguments.delete(:deployment_config)

      result = function.call

      expect(result.success?).to be true

      agent = PromptTracker::DeployedAgent.last
      expect(agent.agent_type_task?).to be true
      expect(agent.task_config["initial_prompt"]).to eq("Do something important")
    end

    it "returns a failure result when prompt_version_id is missing" do
      arguments.delete(:prompt_version_id)

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("prompt_version_id is required")
    end

    it "returns a failure result for invalid agent_type" do
      arguments[:agent_type] = "invalid"

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("agent_type must be 'conversational' or 'task'")
    end

    it "returns a failure result when task agent is missing initial_prompt" do
      arguments[:agent_type] = "task"
      arguments[:task_config] = {}
      arguments.delete(:deployment_config)

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("task_config.initial_prompt is required")
    end

    it "returns a failure result when prompt version is not found" do
      arguments[:prompt_version_id] = -1

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("PromptVersion -1 not found")
    end
  end
end
