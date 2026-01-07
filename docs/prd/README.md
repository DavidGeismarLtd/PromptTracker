# OpenAI Response API Integration - PRD Index

This directory contains Product Requirements Documents (PRDs) for integrating OpenAI's Response API into PromptTracker. The Response API enables stateful multi-turn conversations and built-in tools (web_search, file_search, code_interpreter) without requiring OpenAI Assistants.

## PRD Overview

| PRD | Title | Status | Priority |
|-----|-------|--------|----------|
| [01](./01-openai-response-api-service.md) | OpenAI Response API Service Integration | Draft | P0 |
| [02](./02-response-api-conversation-runner.md) | Response API Conversation Runner | Draft | P0 |
| [03](./03-playground-response-api-support.md) | Playground Response API Support | Draft | P1 |
| [04](./04-test-mode-single-turn-vs-conversational.md) | Test Mode - Single-Turn vs Conversational | Draft | P1 |
| [05](./05-llm-response-schema-changes.md) | LlmResponse Schema Changes | Draft | P0 |

## Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ┌─────────────┐                                                    │
│  │   PRD-01    │ ◄─────────────────────────────────────────────┐    │
│  │  Response   │                                               │    │
│  │ API Service │                                               │    │
│  └──────┬──────┘                                               │    │
│         │                                                      │    │
│         ▼                                                      │    │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐     │    │
│  │   PRD-05    │      │   PRD-02    │      │   PRD-03    │     │    │
│  │ LlmResponse │◄─────│ Conversation│      │ Playground  │     │    │
│  │   Schema    │      │   Runner    │      │   Support   │     │    │
│  └─────────────┘      └──────┬──────┘      └─────────────┘     │    │
│                              │                                 │    │
│                              ▼                                 │    │
│                       ┌─────────────┐                          │    │
│                       │   PRD-04    │──────────────────────────┘    │
│                       │  Test Mode  │                               │
│                       │ Single/Conv │                               │
│                       └─────────────┘                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Implementation Order

### Phase 1: Foundation (Week 1-2)
1. **PRD-05**: LlmResponse Schema Changes
   - Add database columns for Response API data
   - No dependencies, can start immediately

2. **PRD-01**: OpenAI Response API Service
   - Core service for making Response API calls
   - Depends on: PRD-05 (for storing responses)

### Phase 2: Testing Infrastructure (Week 3-4)
3. **PRD-02**: Response API Conversation Runner
   - Multi-turn conversation testing
   - Depends on: PRD-01

4. **PRD-04**: Test Mode - Single-Turn vs Conversational
   - Dataset and test model changes
   - Depends on: PRD-02

### Phase 3: User Experience (Week 5-6)
5. **PRD-03**: Playground Response API Support
   - Interactive conversation UI
   - Depends on: PRD-01

## Key Decisions

### Why Response API?

The Response API provides:
- **Stateful conversations** via `previous_response_id` - no need to resend full history
- **Built-in tools** (web_search, file_search, code_interpreter) - no custom implementation
- **Simpler than Assistants** - no thread/run management, just request/response

### Provider Strategy

PromptVersions can now specify a `provider` in their `model_config`:

| Provider | API Used | Features |
|----------|----------|----------|
| `openai` (default) | Chat Completions | Standard chat, function calling |
| `openai_responses` | Response API | Stateful conversations, built-in tools |
| `openai_assistants` | Assistants API | Full assistant features, file storage |

### Backward Compatibility

All changes are additive:
- Existing PromptVersions continue using Chat Completions
- Existing tests continue as single-turn
- Existing LlmResponses retain all data

## Success Criteria

| Metric | Target |
|--------|--------|
| Response API calls working | 100% |
| Multi-turn conversations working | 100% |
| Built-in tools (web_search, etc.) working | 100% |
| Existing functionality unaffected | 100% |
| Test coverage for new code | >90% |

## Open Questions (Cross-PRD)

1. **Rate limiting**: How do we handle Response API rate limits differently from Chat Completions?

2. **Cost tracking**: Response API with tools may have different pricing. How do we track costs?

3. **Error handling**: Should we fall back to Chat Completions if Response API fails?

4. **Migration path**: Should we provide a tool to migrate existing Assistants to Response API?

## References

- [OpenAI Response API Documentation](https://platform.openai.com/docs/api-reference/responses)
- [OpenAI Responses vs Assistants](https://platform.openai.com/docs/guides/responses-vs-assistants)
- Existing: `docs/plans/assistant-testing-architecture.md`
- Existing: `docs/features/assistant-playground.md`

