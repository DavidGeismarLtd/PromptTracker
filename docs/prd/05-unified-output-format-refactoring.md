# Unified Output Format Refactoring

## Overview

This document outlines a potential refactoring to unify the output format across all test execution modes (single-turn and conversational) while preserving the necessary distinction in execution logic.

## Current State

### The Problem: Two Separate Output Paths

Currently, test runs store output differently based on execution mode:

| Mode | Output Storage | Format |
|------|----------------|--------|
| Single-turn | `llm_response.response_text` | String |
| Conversational | `test_run.conversation_data` | Hash with `messages` array |

This creates inconsistency in:
- How evaluators receive data
- How the UI displays results
- How normalizers structure their output

### Current Normalizer Interface

Each normalizer has two methods:

```ruby
class BaseNormalizer
  def normalize_single_response(raw_response)
    { text: "...", tool_calls: [...], metadata: {...} }
  end

  def normalize_conversation(raw_data)
    { messages: [...], tool_usage: [...], file_search_results: [...] }
  end
end
```

## Proposed Refactoring

### Core Insight

**Execution mode** and **output format** are orthogonal concerns:

- **Execution mode** (single-turn vs conversational) determines HOW we run the test
- **Output format** can be unified regardless of execution mode

A single response is simply an array of one message.

### What Stays Separate (Execution Layer)

These distinctions are fundamental and must remain:

| Component | Why It Stays Separate |
|-----------|----------------------|
| `Test.conversational?` | Determines which runner to use |
| `Dataset.dataset_type` | Conversational datasets need `interlocutor_simulation_prompt` and `max_turns` |
| `SingleTurnRunner` | 1 LLM call, uses template variables |
| `ConversationalRunner` | N LLM calls with interlocutor simulation loop |
| `AssistantRunner` | OpenAI Assistants API with threads |

### What Gets Unified (Output Layer)

```
┌─────────────────────────────────────────────────────────────────┐
│                      EXECUTION LAYER                             │
│            (Stays separate - different runners)                  │
├─────────────────────────────────────────────────────────────────┤
│  SingleTurnRunner          │  ConversationalRunner              │
│  - 1 LLM call              │  - N LLM calls                     │
│  - Template + variables    │  - interlocutor_prompt + max_turns │
└────────────┬───────────────┴────────────────┬───────────────────┘
             │                                │
             ▼                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                 UNIFIED NORMALIZATION LAYER                      │
├─────────────────────────────────────────────────────────────────┤
│  Both normalize to:                                              │
│  {                                                               │
│    messages: [                                                   │
│      { role: "assistant", content: "...", tool_calls: [], ... } │
│    ],                                                            │
│    tool_usage: [...],                                            │
│    file_search_results: [...],                                   │
│    metadata: {...}                                               │
│  }                                                               │
│                                                                  │
│  Single-turn: messages.length == 1                               │
│  Conversational: messages.length >= 2                            │
└────────────┬────────────────────────────────┬───────────────────┘
             │                                │
             ▼                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  UNIFIED STORAGE LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│  test_run.output_messages (JSONB array)                          │
│  - Always an array of message objects                            │
│  - Replaces llm_response.response_text + conversation_data       │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Unified Normalizer Interface

**File:** `app/services/prompt_tracker/evaluators/normalizers/base_normalizer.rb`

Replace two methods with one:

```ruby
class BaseNormalizer
  # BEFORE: normalize_single_response + normalize_conversation
  # AFTER: Single unified method

  def normalize(raw_data)
    {
      messages: extract_messages(raw_data),      # Always an array
      tool_usage: extract_tool_usage(raw_data),
      file_search_results: extract_file_search_results(raw_data),
      metadata: extract_metadata(raw_data)
    }
  end

  private

  def extract_messages(raw_data)
    raise NotImplementedError
  end
end
```

**Changes to each normalizer:**

| Normalizer | Change |
|------------|--------|
| `ChatCompletionNormalizer` | Wrap single response in array: `[{ role: "assistant", ... }]` |
| `ResponseApiNormalizer` | Already returns array via `output_to_messages` |
| `AssistantsApiNormalizer` | Already returns array from thread messages |
| `AnthropicNormalizer` | Wrap single response in array |

### Phase 2: Unified Storage Field

**Migration:**

```ruby
class AddOutputMessagesToTestRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :prompt_tracker_test_runs, :output_messages, :jsonb, default: []
  end
end
```

**Data migration strategy:**

```ruby
# Migrate existing data
TestRun.find_each do |run|
  if run.conversation_data.present?
    # Conversational: already has messages array
    run.update_column(:output_messages, run.conversation_data["messages"] || [])
  elsif run.llm_response&.response_text.present?
    # Single-turn: wrap in array
    run.update_column(:output_messages, [{
      role: "assistant",
      content: run.llm_response.response_text,
      turn: 1
    }])
  end
end
```

### Phase 3: Update Runners to Use Unified Format

**SingleTurnRunner changes:**

```ruby
# BEFORE
llm_response = call_llm(...)
test_run.update!(llm_response: llm_response_record)
evaluator_results = run_evaluators(llm_response[:text])

# AFTER
llm_response = call_llm(...)
normalized = normalizer.normalize(llm_response[:raw])
test_run.update!(
  llm_response: llm_response_record,
  output_messages: normalized[:messages]
)
evaluator_results = run_evaluators(normalized)
```

**ConversationalRunner changes:**

```ruby
# BEFORE
conversation_result = conversation_runner.run!
test_run.update!(conversation_data: conversation_result.to_h)
evaluator_results = run_evaluators(conversation_result.to_h)

# AFTER
conversation_result = conversation_runner.run!
normalized = normalizer.normalize(conversation_result.to_h)
test_run.update!(output_messages: normalized[:messages])
evaluator_results = run_evaluators(normalized)
```

### Phase 4: Update Evaluator Interface

Evaluators receive the same normalized structure regardless of test mode:

```ruby
class BaseEvaluator
  def evaluate(normalized_output)
    # normalized_output is always:
    # {
    #   messages: [...],
    #   tool_usage: [...],
    #   file_search_results: [...],
    #   metadata: {...}
    # }
  end
end
```

**Helper methods for evaluators:**

```ruby
module EvaluatorHelpers
  # Get the last assistant message (most common use case)
  def last_assistant_message(normalized)
    normalized[:messages]
      .reverse
      .find { |m| m[:role] == "assistant" }
  end

  # Get all assistant messages
  def assistant_messages(normalized)
    normalized[:messages].select { |m| m[:role] == "assistant" }
  end

  # Get concatenated assistant text
  def all_assistant_text(normalized)
    assistant_messages(normalized).map { |m| m[:content] }.join("\n")
  end
end
```

### Phase 5: Update UI Views

**Unified partial for displaying output:**

```erb
<%# app/views/prompt_tracker/testing/test_runs/cells/_output_messages.html.erb %>
<% if run.output_messages.length == 1 %>
  <%# Single message display %>
  <div class="single-response">
    <%= run.output_messages.first["content"] %>
  </div>
<% else %>
  <%# Conversation display %>
  <div class="conversation">
    <% run.output_messages.each do |message| %>
      <div class="message message-<%= message['role'] %>">
        <strong><%= message['role'].titleize %></strong>
        <p><%= message['content'] %></p>
      </div>
    <% end %>
  </div>
<% end %>
```

## Message Schema

Standardized message object structure:

```ruby
{
  role: String,           # "user" | "assistant" | "system" | "tool"
  content: String,        # The message text content
  tool_calls: Array,      # Tool/function calls made (if any)
  turn: Integer,          # Turn number in conversation (1-indexed)
  timestamp: String,      # ISO8601 timestamp (optional)
  metadata: Hash          # Provider-specific metadata (optional)
}
```

## Benefits

1. **Simplified mental model**: Output is always an array of messages
2. **Unified evaluator interface**: All evaluators work with same structure
3. **Consistent storage**: One field (`output_messages`) instead of two
4. **Easier UI**: Same rendering logic for all test types
5. **Future-proof**: Easy to add new execution modes without changing output format

## Backward Compatibility

### Deprecation Strategy

1. Keep `conversation_data` and `llm_response.response_text` readable
2. Add `output_messages` as the new canonical field
3. Add helper methods that read from new field with fallback to old:

```ruby
class TestRun
  def output_messages
    # New field takes precedence
    return self[:output_messages] if self[:output_messages].present?

    # Fallback to old fields
    if conversation_data.present?
      conversation_data["messages"] || []
    elsif llm_response&.response_text.present?
      [{ "role" => "assistant", "content" => llm_response.response_text, "turn" => 1 }]
    else
      []
    end
  end
end
```

4. After migration is complete, deprecate old fields

## Files to Modify

| File | Changes |
|------|---------|
| `app/services/prompt_tracker/evaluators/normalizers/base_normalizer.rb` | Unified `normalize` method |
| `app/services/prompt_tracker/evaluators/normalizers/*_normalizer.rb` | Implement unified interface |
| `app/models/prompt_tracker/test_run.rb` | Add `output_messages` accessor |
| `app/services/prompt_tracker/test_runners/single_turn_runner.rb` | Use unified output format |
| `app/services/prompt_tracker/test_runners/openai/*_runner.rb` | Use unified output format |
| `app/views/prompt_tracker/testing/test_runs/cells/*` | Update to use `output_messages` |
| Migration | Add `output_messages` column |

## Non-Goals

This refactoring does NOT change:

- How tests are classified (single-turn vs conversational)
- How datasets are structured (conversational still needs `interlocutor_simulation_prompt`)
- Which runner is selected for which test type
- The fundamental execution logic of each runner

## Timeline Estimate

| Phase | Effort | Risk |
|-------|--------|------|
| Phase 1: Normalizer interface | 2-3 hours | Low |
| Phase 2: Storage migration | 1-2 hours | Medium (data migration) |
| Phase 3: Runner updates | 2-3 hours | Low |
| Phase 4: Evaluator interface | 1-2 hours | Low |
| Phase 5: UI updates | 2-3 hours | Low |
| Testing & validation | 3-4 hours | - |

**Total: ~2-3 days of focused work**
