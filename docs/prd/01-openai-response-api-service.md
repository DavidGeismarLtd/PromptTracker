# PRD: OpenAI Response API Service Integration

## Overview

This document describes the integration of OpenAI's Response API (`/v1/responses`) as a new provider option for PromptTracker. This enables users to leverage Response API-specific features like built-in tools (web search, file search, code interpreter) and stateful conversations.

## Background

### Current State
- **PromptVersions** use `LlmClientService` → RubyLLM → **Chat Completions API** (`/v1/chat/completions`)
- **Assistants** use `OpenaiAssistantService` → ruby-openai → **Assistants API** (threads/runs)

### Problem Statement
The OpenAI Response API offers capabilities not available in Chat Completions:
- Built-in web search tool
- Built-in file search (without pre-creating vector stores)
- Code interpreter
- Stateful conversations via `previous_response_id`
- Simpler multi-turn conversation management

Users want to test prompts using these Response API features without creating full Assistants.

### Goals
1. Add Response API as a provider option for PromptVersions
2. Support both single-turn and multi-turn Response API calls
3. Enable Response API-specific tools (web_search, file_search, code_interpreter)
4. Maintain backward compatibility with existing Chat Completions flow

## Technical Design

### New Service: `OpenaiResponseService`

**Location:** `app/services/prompt_tracker/openai_response_service.rb`

```ruby
module PromptTracker
  class OpenaiResponseService
    # Single-turn call
    def self.call(
      model:,
      system_prompt: nil,
      user_prompt:,
      tools: [],           # [:web_search, :file_search, :code_interpreter]
      temperature: 0.7,
      max_tokens: nil,
      **options
    )
    end

    # Multi-turn call (continues conversation)
    def self.call_with_context(
      model:,
      user_prompt:,
      previous_response_id:,
      tools: [],
      **options
    )
    end
  end
end
```

### API Contract

**Input Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `model` | String | Yes | OpenAI model ID (e.g., `gpt-4o`) |
| `system_prompt` | String | No | System instructions |
| `user_prompt` | String | Yes | User message content |
| `tools` | Array | No | Response API tools to enable |
| `previous_response_id` | String | No | For multi-turn conversations |
| `temperature` | Float | No | 0.0-2.0, default 0.7 |
| `max_tokens` | Integer | No | Max output tokens |

**Output Format:**
```ruby
{
  text: "Response content...",
  response_id: "resp_abc123",      # For conversation continuity
  usage: {
    prompt_tokens: 100,
    completion_tokens: 50,
    total_tokens: 150
  },
  model: "gpt-4o-2024-08-06",
  tool_calls: [...],               # If tools were used
  raw: { ... }                     # Full API response
}
```

### Provider Configuration

**model_config schema for Response API:**
```json
{
  "provider": "openai_responses",
  "model": "gpt-4o",
  "temperature": 0.7,
  "max_tokens": 4096,
  "tools": ["web_search"],
  "tool_config": {
    "web_search": {
      "search_context_size": "medium"
    }
  }
}
```

### Integration with LlmClientService

```ruby
# In LlmClientService.call
def self.call(provider:, model:, prompt:, **options)
  case provider.to_s
  when "openai_responses"
    OpenaiResponseService.call(
      model: model,
      user_prompt: prompt,
      **options
    )
  when "openai_assistants"
    OpenaiAssistantService.call(...)
  else
    # Standard RubyLLM chat completion
    new(...).call
  end
end
```

## Database Changes

**No new tables required.** The existing `model_config` JSONB column on `PromptVersion` accommodates the new provider.

## UI/UX Changes

### PromptVersion Edit Form

Add provider selection to the model configuration panel:

```
┌─────────────────────────────────────────────────────────────┐
│ Model Configuration                                          │
├─────────────────────────────────────────────────────────────┤
│ Provider: [OpenAI ▼]                                         │
│           ├── OpenAI (Chat Completions)                      │
│           ├── OpenAI Response API        ← NEW               │
│           ├── Anthropic                                      │
│           └── ...                                            │
│                                                              │
│ Model: [gpt-4o ▼]                                            │
│                                                              │
│ Temperature: [0.7    ]                                       │
│                                                              │
│ ┌─ Response API Tools (only shown when provider selected) ──┐│
│ │ ☐ Web Search                                              ││
│ │ ☐ File Search                                             ││
│ │ ☐ Code Interpreter                                        ││
│ └───────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Provider Badge Display

Show a badge on PromptVersion cards/lists indicating provider:

```
┌──────────────────────────────────────┐
│ Customer Support Prompt v3           │
│ [Response API] [gpt-4o]              │  ← Provider badge
│ Status: Active                       │
└──────────────────────────────────────┘
```

## Testing Strategy

### Unit Tests

```ruby
# spec/services/prompt_tracker/openai_response_service_spec.rb
RSpec.describe PromptTracker::OpenaiResponseService do
  describe ".call" do
    it "makes a single-turn Response API call"
    it "includes system prompt as system message"
    it "enables requested tools"
    it "returns normalized response format"
  end

  describe ".call_with_context" do
    it "continues conversation with previous_response_id"
    it "maintains tool configuration across turns"
  end
end
```

### Integration Tests

```ruby
# spec/integration/response_api_spec.rb
RSpec.describe "Response API Integration", :vcr do
  it "executes a PromptVersion test with Response API provider"
  it "records LlmResponse with response_id for conversation tracking"
end
```

### Manual Testing Checklist

- [ ] Create PromptVersion with `provider: openai_responses`
- [ ] Run playground with Response API - verify response
- [ ] Enable web_search tool - verify search results appear
- [ ] Run single-turn test - verify test run completes
- [ ] Verify cost calculation works with Response API usage

## Rollout Plan

### Phase 1: Core Service (Week 1)
1. Implement `OpenaiResponseService`
2. Add unit tests with mocked responses
3. Integrate with `LlmClientService`

### Phase 2: UI Integration (Week 2)
1. Add provider dropdown to PromptVersion form
2. Add Response API tools configuration UI
3. Update model_config validation

### Phase 3: Testing Integration (Week 3)
1. Ensure `PromptVersionRunner` works with Response API
2. Verify evaluators work with Response API responses
3. Integration tests with VCR cassettes

## Success Metrics

| Metric | Target |
|--------|--------|
| Response API tests passing | 100% |
| Response time (single-turn) | < 5s avg |
| User adoption (% using Response API) | Track |

## Open Questions

1. **Tool cost tracking**: Response API tools (web_search) have usage-based pricing. How do we track/display this?
2. **File search files**: How do users specify files for file_search without vector stores?
3. **Rate limiting**: Response API may have different rate limits - need to handle gracefully.

## References

- [OpenAI Response API Documentation](https://platform.openai.com/docs/api-reference/responses)
- [Response API Announcement](https://openai.com/index/new-tools-for-building-agents/)
- Internal: `docs/ASSISTANTS_BACKEND_IMPLEMENTATION.md`
