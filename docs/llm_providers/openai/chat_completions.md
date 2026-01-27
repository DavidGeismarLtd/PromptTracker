# OpenAI Chat Completions API

The Chat Completions API is OpenAI's primary interface for conversational AI. It powers ChatGPT and enables developers to build chat-based applications with GPT models.

**Source**: Official OpenAI OpenAPI Specification (fetched 2026-01-27)

## Endpoint

```
POST https://api.openai.com/v1/chat/completions
```

## Headers

```
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY
```

## Request Parameters

### Required Parameters

**model** (string)
- Model ID used to generate the response
- Examples: `gpt-4o`, `gpt-4o-mini`, `o1`, `o3`, `gpt-4.1`
- See [Models documentation](https://platform.openai.com/docs/models) for all available models

**messages** (array, minimum 1 item)
- Array of message objects comprising the conversation
- Supports different modalities: text, images, and audio (depending on model)
- Each message has:
  - `role`: One of `system`, `user`, `assistant`, `developer`, `tool`, or `function`
  - `content`: The message content (string or array for multimodal)
  - `name` (optional): Name of the message author

### Optional Parameters

**temperature** (number, 0-2, default: 1, nullable)
- Controls randomness. Higher values (0.8) make output more random, lower values (0.2) more focused and deterministic
- Recommend altering this OR `top_p`, not both

**max_completion_tokens** (integer, nullable)
- Upper bound for tokens that can be generated for a completion
- Includes visible output tokens and reasoning tokens

**top_p** (number, 0-1, default: 1, nullable)
- Nucleus sampling: model considers tokens with top_p probability mass
- 0.1 means only tokens in top 10% probability mass are considered
- Recommend altering this OR `temperature`, not both

**stream** (boolean, default: false, nullable)
- If true, model response data streamed as server-sent events (SSE)
- See [Streaming section](https://platform.openai.com/docs/api-reference/chat/streaming)

**stop** (string, array, or object, nullable)
- Sequences where the API will stop generating tokens
- Can be up to 4 stop sequences

**presence_penalty** (number, -2.0 to 2.0, default: 0, nullable)
- Positive values penalize new tokens based on whether they appear in the text so far
- Increases likelihood to talk about new topics

**frequency_penalty** (number, -2.0 to 2.0, default: 0, nullable)
- Positive values penalize new tokens based on their existing frequency
- Decreases likelihood to repeat the same line verbatim

**logit_bias** (object/map, default: null, nullable)
- Modify likelihood of specified tokens appearing
- Maps token IDs (integers) to bias values from -100 to 100
- Values between -1 and 1 decrease/increase likelihood; -100 or 100 ban/exclusively select tokens

**logprobs** (boolean, default: false, nullable)
- Whether to return log probabilities of output tokens
- Returns log probabilities of each output token in the `content` of `message`

**top_logprobs** (integer, 0-20, nullable)
- Number of most likely tokens to return at each position with associated log probability
- Requires `logprobs: true`

**response_format** (object)
- Specify output format
- `{ "type": "text" }`: Regular text (default)
- `{ "type": "json_object" }`: JSON mode (older, ensures valid JSON)
- `{ "type": "json_schema", "json_schema": {...} }`: Structured Outputs (preferred, ensures model matches your JSON schema)

**modalities** (array)
- Output modalities for the response
- Can include `text` and/or `audio`

**audio** (object, nullable)
- Parameters for audio output
- Required when audio output requested with `modalities: ["audio"]`
- Properties:
  - `voice`: Voice to use (`alloy`, `ash`, `ballad`, `coral`, `echo`, `fable`, `nova`, `onyx`, `sage`, `shimmer`, `marin`, `cedar`)
  - `format`: Output audio format (`wav`, `aac`, `mp3`, `flac`, `opus`, `pcm16`)

**store** (boolean, default: false, nullable)
- Whether to store output for model distillation or evals products
- Supports text and image inputs (images over 8MB dropped)

**metadata** (object, nullable)
- Set of 16 key-value pairs for storing additional information
- Keys: max 64 characters, Values: max 512 characters

**reasoning_effort** (string)
- Amount of reasoning effort for reasoning models
- Options: `low`, `medium`, `high`

**verbosity** (string)
- Controls verbosity of reasoning model outputs

**web_search_options** (object)
- Options for web search tool
- Properties:
  - `user_location`: Approximate location for search
  - `search_context_size`: Size of search context

**user** (string, deprecated)
- Being replaced by `safety_identifier` and `prompt_cache_key`
- Use `prompt_cache_key` for caching optimizations

**safety_identifier** (string)
- Stable identifier to help detect policy violations
- Should uniquely identify each user (recommend hashing username/email)

**prompt_cache_key** (string)
- Used by OpenAI to cache responses for similar requests
- Replaces the `user` field for caching optimization

**service_tier** (string)
- Service tier to use (`auto` or `default`)

**prompt_cache_retention** (string, nullable)
- Retention policy for prompt cache
- `in-memory`: Standard caching
- `24h`: Extended prompt caching (keeps cached prefixes active up to 24 hours)

## Response Format

```json
{
  "id": "chatcmpl-B9MBs8CjcvOU2jLn4n570S5qMJKcT",
  "object": "chat.completion",
  "created": 1741569952,
  "model": "gpt-4.1-2025-04-14",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello! How can I assist you today?",
      "refusal": null,
      "annotations": []
    },
    "logprobs": null,
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 19,
    "completion_tokens": 10,
    "total_tokens": 29,
    "prompt_tokens_details": {
      "cached_tokens": 0,
      "audio_tokens": 0
    },
    "completion_tokens_details": {
      "reasoning_tokens": 0,
      "audio_tokens": 0,
      "accepted_prediction_tokens": 0,
      "rejected_prediction_tokens": 0
    }
  },
  "service_tier": "default"
}
```

### Response Fields

- **id**: Unique identifier for the chat completion
- **object**: Object type, always `chat.completion`
- **created**: Unix timestamp of when the completion was created
- **model**: The model used for completion
- **service_tier**: Service tier used for the request
- **choices**: Array of completion choices
  - **index**: Choice index
  - **message**: The generated message
    - **role**: Always `assistant`
    - **content**: The content of the message
    - **refusal**: Refusal message if model refused to respond
    - **annotations**: Array of annotations
    - **tool_calls** (optional): Tool calls generated by the model
  - **logprobs**: Log probability information (if requested)
  - **finish_reason**: Why the model stopped
    - `stop`: Natural stop point or provided stop sequence
    - `length`: Max tokens reached
    - `tool_calls`: Model called a tool
    - `content_filter`: Content filtered by moderation
- **usage**: Token usage statistics
  - **prompt_tokens**: Tokens in the prompt
  - **completion_tokens**: Tokens in the completion
  - **total_tokens**: Total tokens used
  - **prompt_tokens_details**: Breakdown of prompt tokens (cached, audio)
  - **completion_tokens_details**: Breakdown of completion tokens (reasoning, audio, prediction)

## Streaming

Set `stream: true` to receive partial message deltas via Server-Sent Events (SSE).

### Streaming Response Format

Each chunk:
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion.chunk",
  "created": 1694268190,
  "model": "gpt-4o",
  "choices": [{
    "index": 0,
    "delta": {
      "role": "assistant",
      "content": "Hello"
    },
    "logprobs": null,
    "finish_reason": null
  }]
}
```

The last chunk has `finish_reason` set and `delta` is empty or contains final fields.

## Tool/Function Calling

### Request with Tools

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "What's the weather in Boston?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "get_weather",
      "description": "Get the current weather in a location",
      "parameters": {
        "type": "object",
        "properties": {
          "location": {"type": "string", "description": "City and state, e.g. San Francisco, CA"},
          "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
        },
        "required": ["location"]
      }
    }
  }]
}
```

### Response with Tool Call

```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": null,
      "tool_calls": [{
        "id": "call_abc123",
        "type": "function",
        "function": {
          "name": "get_weather",
          "arguments": "{\"location\": \"Boston, MA\", \"unit\": \"fahrenheit\"}"
        }
      }]
    },
    "finish_reason": "tool_calls"
  }]
}
```

### Submitting Tool Results

After executing the function, submit the result back:

```json
{
  "model": "gpt-4o",
  "messages": [
    {"role": "user", "content": "What's the weather in Boston?"},
    {
      "role": "assistant",
      "content": null,
      "tool_calls": [{
        "id": "call_abc123",
        "type": "function",
        "function": {"name": "get_weather", "arguments": "{\"location\": \"Boston, MA\"}"}
      }]
    },
    {
      "role": "tool",
      "tool_call_id": "call_abc123",
      "content": "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }
  ]
}
```

## Vision (Image Inputs)

Include images in messages using the multimodal content format:

```json
{
  "model": "gpt-4o",
  "messages": [{
    "role": "user",
    "content": [
      {"type": "text", "text": "What's in this image?"},
      {
        "type": "image_url",
        "image_url": {
          "url": "https://example.com/image.jpg",
          "detail": "high"
        }
      }
    ]
  }]
}
```

The `detail` parameter can be `low`, `high`, or `auto`.

## JSON Mode and Structured Outputs

### JSON Mode (Legacy)

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "Generate a person's profile"}],
  "response_format": {"type": "json_object"}
}
```

### Structured Outputs (Recommended)

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "Generate a person's profile"}],
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "person_profile",
      "strict": true,
      "schema": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "number"},
          "email": {"type": "string"}
        },
        "required": ["name", "age", "email"],
        "additionalProperties": false
      }
    }
  }
}
```

## Reference

- **Official Documentation**: https://platform.openai.com/docs/api-reference/chat
- **Models List**: https://platform.openai.com/docs/models
- **Streaming Guide**: https://platform.openai.com/docs/api-reference/chat/streaming
- **Function Calling**: https://platform.openai.com/docs/guides/function-calling
- **Vision Guide**: https://platform.openai.com/docs/guides/vision
- **Structured Outputs**: https://platform.openai.com/docs/guides/structured-outputs
