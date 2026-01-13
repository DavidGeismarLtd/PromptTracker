# PRD: Response API Conversation Runner

## Overview

This document describes a new conversation runner that enables multi-turn testing of PromptVersions using the OpenAI Response API. This allows simulating realistic conversations with an interlocutor (simulated user) to evaluate prompt performance across multiple exchanges.

## Background

### Current State

| Testable | Runner | Conversation Support |
|----------|--------|---------------------|
| `PromptVersion` | `PromptVersionRunner` | Single-turn only |
| `Assistant` | `AssistantRunner` | Multi-turn via Assistants API threads |

### Problem Statement

Users want to test PromptVersions in conversational scenarios without creating full OpenAI Assistants. The Response API's `previous_response_id` feature enables stateful conversations without server-side thread management.

### Goals

1. Enable multi-turn testing for Response API-backed PromptVersions
2. Reuse the interlocutor simulation pattern from Assistant testing
3. Support conversation evaluation (e.g., `ConversationJudgeEvaluator`)
4. Maintain conversation history in `LlmResponse` records

## Technical Design

### New Service: `ResponseApiConversationRunner`

**Location:** `app/services/prompt_tracker/openai/response_api_conversation_runner.rb`

```ruby
module PromptTracker
  module Openai
    class ResponseApiConversationRunner
      attr_reader :prompt_version, :interlocutor_prompt, :max_turns, :variables

      def initialize(prompt_version:, interlocutor_prompt:, max_turns: 5, variables: {})
        @prompt_version = prompt_version
        @interlocutor_prompt = interlocutor_prompt
        @max_turns = max_turns
        @variables = variables
      end

      # Run the full conversation
      # @return [ConversationResult] containing messages, llm_responses, final status
      def run
        conversation = Conversation.new
        previous_response_id = nil

        max_turns.times do |turn|
          # Get user message (from interlocutor or initial)
          user_message = turn.zero? ? initial_message : simulate_interlocutor(conversation)

          break if conversation_complete?(user_message)

          conversation.add_user_message(user_message)

          # Call Response API with context
          response = call_response_api(user_message, previous_response_id)
          previous_response_id = response[:response_id]

          conversation.add_assistant_message(response[:text])
        end

        ConversationResult.new(
          messages: conversation.messages,
          turn_count: conversation.turn_count,
          completed: true
        )
      end

      private

      def call_response_api(message, previous_response_id)
        if previous_response_id
          OpenaiResponseService.call_with_context(
            model: model_config[:model],
            user_prompt: message,
            previous_response_id: previous_response_id,
            tools: model_config[:tools] || []
          )
        else
          OpenaiResponseService.call(
            model: model_config[:model],
            system_prompt: rendered_system_prompt,
            user_prompt: message,
            tools: model_config[:tools] || []
          )
        end
      end

      def simulate_interlocutor(conversation)
        InterlocutorSimulationService.call(
          simulation_prompt: interlocutor_prompt,
          conversation_history: conversation.messages
        )
      end

      def model_config
        @model_config ||= prompt_version.model_config.with_indifferent_access
      end

      def rendered_system_prompt
        return nil if prompt_version.system_prompt.blank?
        TemplateRenderer.new(prompt_version.system_prompt).render(variables)
      end
    end
  end
end
```

### Conversation State Management

Unlike the Assistants API (which stores state server-side), the Response API uses `previous_response_id` for continuity:

```
Turn 1:
  Request:  { input: [...], model: "gpt-4o" }
  Response: { id: "resp_001", output: [...] }

Turn 2:
  Request:  { input: [...], previous_response_id: "resp_001" }
  Response: { id: "resp_002", output: [...] }

Turn 3:
  Request:  { input: [...], previous_response_id: "resp_002" }
  Response: { id: "resp_003", output: [...] }
```

### ConversationResult Value Object

```ruby
module PromptTracker
  module Openai
    class ConversationResult
      attr_reader :messages, :turn_count, :completed, :error

      def initialize(messages:, turn_count:, completed:, error: nil)
        @messages = messages
        @turn_count = turn_count
        @completed = completed
        @error = error
      end

      def success?
        completed && error.nil?
      end

      def to_h
        {
          messages: messages,
          turn_count: turn_count,
          completed: completed,
          error: error
        }
      end
    end
  end
end
```

### Integration with Test Runner

**New Runner:** `ResponseApiConversationalRunner`

**Location:** `app/services/prompt_tracker/test_runners/openai/response_api_conversational_runner.rb`

```ruby
module PromptTracker
  module TestRunners
    module Openai
      class ResponseApiConversationalRunner < Base
        def run
          start_time = Time.current

          # Get conversation parameters from dataset row
          interlocutor_prompt = variables["interlocutor_simulation_prompt"]
          max_turns = variables["max_turns"] || 5

          # Run conversation
          conversation_runner = PromptTracker::Openai::ResponseApiConversationRunner.new(
            prompt_version: testable,
            interlocutor_prompt: interlocutor_prompt,
            max_turns: max_turns,
            variables: template_variables
          )

          result = conversation_runner.run

          # Create LlmResponse with conversation data
          llm_response = create_llm_response(result)

          # Run evaluators (ConversationJudgeEvaluator, etc.)
          evaluator_results = run_evaluators(llm_response)

          # Update test run
          update_test_run_with_evaluators(
            llm_response: llm_response,
            evaluator_results: evaluator_results,
            passed: evaluator_results.all? { |r| r[:passed] },
            execution_time_ms: ((Time.current - start_time) * 1000).to_i
          )
        end

        private

        def template_variables
          # Filter out conversation-specific fields
          variables.except("interlocutor_simulation_prompt", "max_turns")
        end
      end
    end
  end
end
```

## Database Changes

### LlmResponse Extensions

The existing `LlmResponse` model needs to store conversation data:

```ruby
# Already exists in schema:
# - response_text: string (stores final assistant message or full transcript)
# - metadata: jsonb (can store conversation_messages array)
# - raw_response: jsonb (stores raw API responses)

# Proposed metadata structure for conversations:
{
  "conversation_messages": [
    { "role": "user", "content": "Hello, I need help..." },
    { "role": "assistant", "content": "Hi! I'd be happy to help..." },
    { "role": "user", "content": "Can you explain..." },
    { "role": "assistant", "content": "Of course! Let me..." }
  ],
  "turn_count": 2,
  "response_ids": ["resp_001", "resp_002"],
  "conversation_mode": "response_api"
}
```

## UI/UX Design

### Dataset Row Schema for Conversational Tests

When a dataset is used for conversational testing, rows need additional fields:

```
┌────────────────────────────────────────────────────────────────────┐
│ Dataset Row #1                                                      │
├────────────────────────────────────────────────────────────────────┤
│ Template Variables:                                                 │
│   customer_name: "John Smith"                                       │
│   issue_type: "billing"                                             │
│                                                                     │
│ Conversation Settings:                                              │
│   interlocutor_simulation_prompt:                                   │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │ You are a frustrated customer who has been charged twice     │ │
│   │ for the same order. You want a refund and an apology.        │ │
│   │ Start by saying "I've been double-charged!"                  │ │
│   └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│   max_turns: [5 ▼]                                                  │
└────────────────────────────────────────────────────────────────────┘
```

### Conversation Viewer in Test Results

```
┌────────────────────────────────────────────────────────────────────┐
│ Test Run #42 - Conversation View                                    │
├────────────────────────────────────────────────────────────────────┤
│ Turn 1/3                                                            │
│ ┌──────────────────────────────────────────────────────────────────┐
│ │ 👤 User (Simulated)                                              │
│ │ I've been double-charged for my order #12345!                    │
│ └──────────────────────────────────────────────────────────────────┘
│ ┌──────────────────────────────────────────────────────────────────┐
│ │ 🤖 Assistant (Response API)                                      │
│ │ I'm so sorry to hear about that, John. Let me look into your    │
│ │ order #12345 right away and get this resolved for you.          │
│ └──────────────────────────────────────────────────────────────────┘
│                                                                     │
│ Turn 2/3                                                            │
│ ┌──────────────────────────────────────────────────────────────────┐
│ │ 👤 User (Simulated)                                              │
│ │ This is unacceptable! I want my money back now.                  │
│ └──────────────────────────────────────────────────────────────────┘
│ ┌──────────────────────────────────────────────────────────────────┐
│ │ 🤖 Assistant (Response API)                                      │
│ │ I completely understand your frustration. I've initiated a      │
│ │ refund for the duplicate charge. You should see it in 3-5 days. │
│ └──────────────────────────────────────────────────────────────────┘
│                                                                     │
│ ── Evaluations ──────────────────────────────────────────────────── │
│ ✅ ConversationJudge: Passed (Score: 4.5/5)                         │
│    "The assistant handled the escalation professionally..."        │
└────────────────────────────────────────────────────────────────────┘
```

## Testing Strategy

### Unit Tests

```ruby
# spec/services/prompt_tracker/openai/response_api_conversation_runner_spec.rb
RSpec.describe PromptTracker::Openai::ResponseApiConversationRunner do
  describe "#run" do
    it "executes multi-turn conversation with Response API"
    it "passes previous_response_id between turns"
    it "stops at max_turns limit"
    it "handles conversation completion signal"
    it "returns ConversationResult with all messages"
  end
end

# spec/services/prompt_tracker/test_runners/openai/response_api_conversational_runner_spec.rb
RSpec.describe PromptTracker::TestRunners::Openai::ResponseApiConversationalRunner do
  describe "#run" do
    it "extracts interlocutor_prompt from dataset row"
    it "creates LlmResponse with conversation metadata"
    it "runs evaluators on conversation result"
    it "updates test_run with pass/fail status"
  end
end
```

### Integration Tests

```ruby
RSpec.describe "Response API Conversational Testing", :vcr do
  let(:prompt_version) { create(:prompt_version, model_config: { provider: "openai_responses", model: "gpt-4o" }) }
  let(:dataset_row) do
    create(:dataset_row, variables: {
      "customer_name" => "John",
      "interlocutor_simulation_prompt" => "You are a confused customer...",
      "max_turns" => 3
    })
  end

  it "runs a complete conversational test" do
    runner = described_class.new(test_run: test_run, test: test, testable: prompt_version)
    runner.run

    expect(test_run.reload.status).to eq("completed")
    expect(test_run.llm_response.metadata["turn_count"]).to eq(3)
  end
end
```

## Dependencies

This feature depends on:
- **PRD-01**: `OpenaiResponseService` with `call_with_context`
- Existing: `InterlocutorSimulationService` (used by Assistant testing)
- Existing: `ConversationJudgeEvaluator`

## Rollout Plan

### Phase 1: Core Runner (Week 1)
1. Implement `ResponseApiConversationRunner`
2. Implement `ConversationResult` value object
3. Unit tests with mocked API calls

### Phase 2: Test Integration (Week 2)
1. Implement `ResponseApiConversationalRunner` (test runner)
2. Integrate with RunTestJob
3. Store conversation in LlmResponse metadata

### Phase 3: UI (Week 3)
1. Conversation viewer component
2. Dataset row form with conversation fields

## Success Metrics

| Metric | Target |
|--------|--------|
| Multi-turn tests completing successfully | 95% |
| Average conversation latency (5 turns) | < 30s |
| Evaluator compatibility | All existing evaluators work |

## Open Questions

1. **Conversation termination**: How does the interlocutor signal "conversation complete"? Use a special marker?
2. **Error recovery**: If a turn fails, do we retry or fail the whole test?
3. **Cost implications**: Multi-turn tests cost more. Should we show estimated cost before running?

## References

- PRD-01: OpenAI Response API Service Integration
- `docs/plans/assistant-testing-architecture.md`
- `app/services/prompt_tracker/test_runners/openai/assistant_runner.rb`
