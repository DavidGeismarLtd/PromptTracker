# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::LlmResponse, type: :model do
  describe "associations" do
    it { should belong_to(:prompt_version) }
    it { should have_many(:evaluations).dependent(:destroy) }
  end

  describe "scopes" do
    let!(:prompt) { create(:prompt) }
    let!(:version) { create(:prompt_version, prompt: prompt) }

    let!(:production_response) do
      create(:llm_response,
             prompt_version: version,
             environment: "production")
    end

    let!(:staging_response) do
      create(:llm_response,
             prompt_version: version,
             environment: "staging")
    end

    describe ".tracked_calls" do
      it "returns all LlmResponses (all are tracked calls)" do
        expect(described_class.tracked_calls).to contain_exactly(production_response, staging_response)
      end
    end
  end

  describe "callbacks" do
    let(:prompt) { create(:prompt) }
    let(:version) { create(:prompt_version, prompt: prompt) }

    it "triggers auto-evaluation after create" do
      expect(PromptTracker::AutoEvaluationService).to receive(:evaluate)
        .with(instance_of(described_class), context: "tracked_call")

      described_class.create!(
        prompt_version: version,
        rendered_prompt: "Test prompt",
        provider: "openai",
        model: "gpt-4",
        response_text: "Test response",
        status: "success"
      )
    end
  end

  describe "#trigger_auto_evaluation" do
    let(:prompt) { create(:prompt) }
    let(:version) { create(:prompt_version, prompt: prompt) }
    let(:response) do
      described_class.new(
        prompt_version: version,
        rendered_prompt: "Test prompt",
        provider: "openai",
        model: "gpt-4",
        response_text: "Test response",
        status: "success"
      )
    end

    it "calls AutoEvaluationService with tracked_call context" do
      expect(PromptTracker::AutoEvaluationService).to receive(:evaluate)
        .with(response, context: "tracked_call")

      response.save!
    end
  end

  describe "Response API features" do
    let!(:prompt) { create(:prompt) }
    let!(:version) { create(:prompt_version, prompt: prompt) }

    describe "validations" do
      it "validates turn_number is a positive integer" do
        response = build(:llm_response, prompt_version: version, turn_number: 0)
        expect(response).not_to be_valid
        expect(response.errors[:turn_number]).to include("must be greater than or equal to 1")
      end

      it "validates tools_used is an array" do
        response = build(:llm_response, prompt_version: version)
        response.tools_used = "not an array"
        expect(response).not_to be_valid
        expect(response.errors[:tools_used]).to include("must be an array")
      end

      it "validates tool_outputs is a hash" do
        response = build(:llm_response, prompt_version: version)
        response.tool_outputs = "not a hash"
        expect(response).not_to be_valid
        expect(response.errors[:tool_outputs]).to include("must be a hash")
      end
    end

    describe "scopes" do
      let!(:response_with_tools) do
        create(:llm_response,
               prompt_version: version,
               tools_used: %w[web_search file_search],
               tool_outputs: { "web_search" => { results: [] } })
      end

      let!(:response_without_tools) do
        create(:llm_response, prompt_version: version, tools_used: [])
      end

      let!(:conversation_response_1) do
        create(:llm_response,
               prompt_version: version,
               conversation_id: "conv_123",
               turn_number: 1,
               response_id: "resp_001")
      end

      let!(:conversation_response_2) do
        create(:llm_response,
               prompt_version: version,
               conversation_id: "conv_123",
               turn_number: 2,
               response_id: "resp_002",
               previous_response_id: "resp_001")
      end

      let!(:single_response) do
        create(:llm_response, prompt_version: version, conversation_id: nil)
      end

      describe ".with_tools" do
        it "returns only responses that used tools" do
          expect(described_class.with_tools).to contain_exactly(response_with_tools)
        end
      end

      describe ".with_tool" do
        it "returns responses that used a specific tool" do
          expect(described_class.with_tool("web_search")).to contain_exactly(response_with_tools)
        end

        it "returns empty when tool was not used" do
          expect(described_class.with_tool("code_interpreter")).to be_empty
        end
      end

      describe ".for_conversation" do
        it "returns all responses for a conversation ordered by turn" do
          results = described_class.for_conversation("conv_123")
          expect(results).to eq([ conversation_response_1, conversation_response_2 ])
        end
      end

      describe ".multi_turn" do
        it "returns only responses in conversations" do
          expect(described_class.multi_turn).to contain_exactly(
            conversation_response_1, conversation_response_2
          )
        end
      end

      describe ".single_turn" do
        it "returns only responses not in conversations" do
          expect(described_class.single_turn).to include(single_response)
          expect(described_class.single_turn).not_to include(conversation_response_1)
        end
      end

      describe ".conversation_starts" do
        it "returns only the first turn of each conversation" do
          expect(described_class.conversation_starts).to contain_exactly(conversation_response_1)
        end
      end
    end

    describe "instance methods" do
      let!(:response_with_tools) do
        create(:llm_response,
               prompt_version: version,
               tools_used: %w[web_search file_search],
               tool_outputs: {
                 "web_search" => { results: [ { title: "Result 1" } ] },
                 "file_search" => { files: [] }
               })
      end

      let!(:response_without_tools) do
        create(:llm_response, prompt_version: version, tools_used: [])
      end

      describe "#used_tools?" do
        it "returns true when tools were used" do
          expect(response_with_tools.used_tools?).to be true
        end

        it "returns false when no tools were used" do
          expect(response_without_tools.used_tools?).to be false
        end
      end

      describe "#used_tool?" do
        it "returns true when specific tool was used" do
          expect(response_with_tools.used_tool?("web_search")).to be true
        end

        it "returns false when specific tool was not used" do
          expect(response_with_tools.used_tool?("code_interpreter")).to be false
        end
      end

      describe "#tool_output_for" do
        it "returns the output for a specific tool" do
          output = response_with_tools.tool_output_for("web_search")
          expect(output).to eq({ "results" => [ { "title" => "Result 1" } ] })
        end

        it "returns nil for a tool that wasn't used" do
          expect(response_with_tools.tool_output_for("unknown")).to be_nil
        end
      end

      describe "#tools_summary" do
        it "returns comma-separated list of tools" do
          expect(response_with_tools.tools_summary).to eq("web_search, file_search")
        end

        it "returns 'None' when no tools were used" do
          expect(response_without_tools.tools_summary).to eq("None")
        end
      end
    end

    describe "conversation navigation" do
      let!(:response_1) do
        create(:llm_response,
               prompt_version: version,
               conversation_id: "conv_nav",
               turn_number: 1,
               response_id: "resp_nav_001")
      end

      let!(:response_2) do
        create(:llm_response,
               prompt_version: version,
               conversation_id: "conv_nav",
               turn_number: 2,
               response_id: "resp_nav_002",
               previous_response_id: "resp_nav_001")
      end

      let!(:response_3) do
        create(:llm_response,
               prompt_version: version,
               conversation_id: "conv_nav",
               turn_number: 3,
               response_id: "resp_nav_003",
               previous_response_id: "resp_nav_002")
      end

      describe "#multi_turn?" do
        it "returns true for responses in a conversation" do
          expect(response_1.multi_turn?).to be true
        end

        it "returns false for single responses" do
          single = create(:llm_response, prompt_version: version, conversation_id: nil)
          expect(single.multi_turn?).to be false
        end
      end

      describe "#first_turn?" do
        it "returns true for the first turn" do
          expect(response_1.first_turn?).to be true
        end

        it "returns false for subsequent turns" do
          expect(response_2.first_turn?).to be false
        end
      end

      describe "#conversation_responses" do
        it "returns all responses in the conversation ordered by turn" do
          expect(response_2.conversation_responses).to eq([ response_1, response_2, response_3 ])
        end

        it "returns empty relation for single responses" do
          single = create(:llm_response, prompt_version: version, conversation_id: nil)
          expect(single.conversation_responses).to be_empty
        end
      end

      describe "#previous_response" do
        it "returns the previous response in the conversation" do
          expect(response_2.previous_response).to eq(response_1)
        end

        it "returns nil for the first turn" do
          expect(response_1.previous_response).to be_nil
        end
      end

      describe "#next_response" do
        it "returns the next response in the conversation" do
          expect(response_2.next_response).to eq(response_3)
        end

        it "returns nil for the last turn" do
          expect(response_3.next_response).to be_nil
        end
      end
    end

    describe "auto turn_number assignment" do
      it "auto-increments turn_number when conversation_id is set" do
        response_1 = create(:llm_response,
                            prompt_version: version,
                            conversation_id: "conv_auto",
                            turn_number: nil)
        expect(response_1.turn_number).to eq(1)

        response_2 = create(:llm_response,
                            prompt_version: version,
                            conversation_id: "conv_auto",
                            turn_number: nil)
        expect(response_2.turn_number).to eq(2)

        response_3 = create(:llm_response,
                            prompt_version: version,
                            conversation_id: "conv_auto",
                            turn_number: nil)
        expect(response_3.turn_number).to eq(3)
      end

      it "respects explicitly set turn_number" do
        response = create(:llm_response,
                          prompt_version: version,
                          conversation_id: "conv_explicit",
                          turn_number: 5)
        expect(response.turn_number).to eq(5)
      end

      it "does not set turn_number for single responses" do
        response = create(:llm_response,
                          prompt_version: version,
                          conversation_id: nil,
                          turn_number: nil)
        expect(response.turn_number).to be_nil
      end
    end
  end
end
