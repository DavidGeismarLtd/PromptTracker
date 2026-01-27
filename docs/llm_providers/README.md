# LLM Provider API Documentation

This directory contains comprehensive API documentation for various LLM providers integrated with PromptTracker. These docs are stored locally for quick reference without needing to browse the web.

## 📚 Available Documentation

### OpenAI

#### [Chat Completions API](openai/chat_completions.md)
The standard OpenAI API for conversational AI.
- Request/response formats
- Parameters (temperature, max_tokens, etc.)
- Tool/function calling
- Streaming responses
- JSON mode and structured outputs

**Use cases**: Most general-purpose LLM interactions, chatbots, Q&A systems

#### [Assistants API](openai/assistants_api.md)
Stateful assistant with persistent threads and built-in tools.
- Creating and managing assistants
- Thread-based conversations
- Code Interpreter tool
- File Search tool
- Function calling
- Run management

**Use cases**: Multi-turn conversations, file analysis, code execution, RAG applications

#### [Responses API](openai/responses_api.md)
OpenAI's newer stateful conversation API (successor to Assistants API).
- Stateful conversations with server-side state
- Web search integration
- Code interpreter
- File search
- Conversation compaction
- Include parameters for additional data

**Use cases**: Advanced conversational AI, web-grounded responses, multi-modal interactions

### Anthropic (Claude)

#### [Messages API](anthropic/messages_api.md)
The primary API for interacting with Claude models.
- Request/response formats
- System prompts
- Multi-turn conversations
- Vision (image inputs)
- Document processing (PDF)
- Streaming responses
- Error handling

**Use cases**: General-purpose Claude interactions, vision tasks, document analysis

#### [Tool Use](anthropic/tool_use.md)
Function calling with Claude (Anthropic's approach to tools).
- Tool definition format
- Tool use workflow
- Returning tool results
- Multiple tool calls
- Tool choice control
- Error handling

**Use cases**: Extending Claude with external APIs, database queries, calculations

### Google (Coming Soon)

#### Gemini API
Documentation for Google's Gemini models.
- Coming soon

## 🔍 Quick Reference

### When to Use Which API

| Use Case | Recommended API |
|----------|----------------|
| Simple chat completion | OpenAI Chat Completions |
| Multi-turn conversation with state | OpenAI Responses API or Assistants API |
| Function calling (OpenAI) | Chat Completions with tools |
| Function calling (Anthropic) | Messages API with tools |
| Code execution | OpenAI Assistants/Responses (Code Interpreter) |
| File/document search | OpenAI Assistants/Responses (File Search) |
| Web search | OpenAI Responses API (web_search tool) |
| Vision/image analysis | Claude Messages API or OpenAI Chat Completions |
| Long context | Claude (200K tokens) or GPT-4 Turbo (128K) |

### Model Comparison

| Provider | Model | Context | Strengths |
|----------|-------|---------|-----------|
| OpenAI | gpt-4o | 128K | Best all-around, fast, multimodal |
| OpenAI | gpt-4o-mini | 128K | Cost-effective, fast |
| OpenAI | gpt-4-turbo | 128K | High capability, vision |
| OpenAI | o1 | 200K | Advanced reasoning |
| Anthropic | claude-3-5-sonnet | 200K | Excellent reasoning, coding |
| Anthropic | claude-3-5-haiku | 200K | Fast, cost-effective |
| Anthropic | claude-3-opus | 200K | Highest capability |

## 📖 How to Use These Docs

1. **During Development**: Reference these docs when implementing new LLM integrations
2. **For Debugging**: Check exact API formats when troubleshooting issues
3. **For Testing**: Understand response structures when writing tests
4. **For Evaluators**: Know what fields are available when building custom evaluators

## 🔗 Official Documentation Links

- [OpenAI Platform Docs](https://platform.openai.com/docs)
- [Anthropic Claude Docs](https://docs.anthropic.com)
- [Google AI Studio](https://ai.google.dev)

## 📝 Contributing

When adding new provider documentation:

1. Create a new directory: `docs/llm_providers/{provider_name}/`
2. Add markdown files for each API endpoint/feature
3. Update this README with links and descriptions
4. Include:
   - Request/response formats
   - All parameters with descriptions
   - Example requests and responses
   - Common use cases
   - Error handling
   - Links to official docs

## 🎯 PromptTracker Integration

These APIs are integrated into PromptTracker through:

- **Services**: `app/services/prompt_tracker/` (e.g., `OpenaiResponseService`, `LlmClientService`)
- **Normalizers**: `app/services/prompt_tracker/evaluators/normalizers/` (convert API responses to common format)
- **Test Executors**: `app/services/prompt_tracker/test_runners/api_executors/`

See the codebase for implementation details.

## 📅 Last Updated

- OpenAI Chat Completions: 2026-01-26
- OpenAI Assistants API: 2026-01-26
- OpenAI Responses API: 2026-01-26
- Anthropic Messages API: 2026-01-26
- Anthropic Tool Use: 2026-01-26

