# Anthropic Messages API (Claude)

## Endpoint
```
POST https://api.anthropic.com/v1/messages
```

## Headers
```
x-api-key: YOUR_API_KEY
anthropic-version: 2023-06-01
content-type: application/json
```

## Request Body

### Required Parameters

**model** (string)
- Model identifier
- Examples: `claude-3-5-sonnet-20241022`, `claude-3-5-haiku-20241022`, `claude-3-opus-20240229`

**messages** (array)
- Array of message objects
- Each message has:
  - `role`: "user" or "assistant"
  - `content`: string or array of content blocks

**max_tokens** (integer)
- Maximum number of tokens to generate
- Required parameter (no default)

### Optional Parameters

**system** (string or array)
- System prompt(s) to guide Claude's behavior
- Can be a string or array of text/cache control blocks

**temperature** (number, 0-1, default: 1)
- Sampling temperature
- Use 0 for deterministic output

**top_p** (number, 0-1)
- Nucleus sampling parameter
- Recommended to alter either temperature or top_p, not both

**top_k** (integer, default: -1)
- Only sample from top K options
- -1 means disabled

**stop_sequences** (array of strings)
- Custom sequences that will cause the model to stop generating

**stream** (boolean, default: false)
- Whether to stream the response

**metadata** (object)
- Object with `user_id` for tracking/abuse prevention

## Message Content Types

### Text Content
```json
{
  "type": "text",
  "text": "Hello, Claude!"
}
```

### Image Content
```json
{
  "type": "image",
  "source": {
    "type": "base64",
    "media_type": "image/jpeg",
    "data": "/9j/4AAQSkZJRg..."
  }
}
```

Or with URL:
```json
{
  "type": "image",
  "source": {
    "type": "url",
    "url": "https://example.com/image.jpg"
  }
}
```

### Document Content (PDF)
```json
{
  "type": "document",
  "source": {
    "type": "base64",
    "media_type": "application/pdf",
    "data": "JVBERi0xLjQK..."
  }
}
```

## Example Request

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "system": "You are a helpful AI assistant.",
  "messages": [
    {
      "role": "user",
      "content": "Hello, Claude!"
    }
  ]
}
```

## Response Format

```json
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hello! How can I assist you today?"
    }
  ],
  "model": "claude-3-5-sonnet-20241022",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 12,
    "output_tokens": 8
  }
}
```

### stop_reason values
- `end_turn`: Natural stop point
- `max_tokens`: Maximum tokens reached
- `stop_sequence`: Custom stop sequence reached
- `tool_use`: Model wants to use a tool

## Multi-turn Conversations

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "messages": [
    {
      "role": "user",
      "content": "What is the capital of France?"
    },
    {
      "role": "assistant",
      "content": "The capital of France is Paris."
    },
    {
      "role": "user",
      "content": "What is its population?"
    }
  ]
}
```

## Streaming

Set `stream: true` to receive Server-Sent Events (SSE).

Event types:
- `message_start`: Initial message metadata
- `content_block_start`: Start of content block
- `content_block_delta`: Incremental content
- `content_block_stop`: End of content block
- `message_delta`: Message-level changes (usage, stop_reason)
- `message_stop`: End of message

Example event:
```json
event: content_block_delta
data: {
  "type": "content_block_delta",
  "index": 0,
  "delta": {
    "type": "text_delta",
    "text": "Hello"
  }
}
```

## Vision (Multimodal)

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": "/9j/4AAQSkZJRg..."
          }
        },
        {
          "type": "text",
          "text": "What's in this image?"
        }
      ]
    }
  ]
}
```

## Error Responses

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "max_tokens is required"
  }
}
```

Common error types:
- `invalid_request_error`: Invalid request parameters
- `authentication_error`: Invalid API key
- `permission_error`: Insufficient permissions
- `not_found_error`: Resource not found
- `rate_limit_error`: Rate limit exceeded
- `api_error`: Internal server error
- `overloaded_error`: API temporarily overloaded

## Reference
- Official Docs: https://docs.anthropic.com/en/api/messages
- Models: https://docs.anthropic.com/en/docs/about-claude/models

