# OpenAI Assistants API

## Overview
The Assistants API allows you to build AI assistants with:
- Instructions and model selection
- Access to tools (Code Interpreter, File Search, Function calling)
- Persistent threads for conversations
- File handling capabilities

## Core Concepts

### Assistant
A configured AI with instructions, model, and tools.

### Thread
A conversation session between user and assistant.

### Message
A message within a thread (user or assistant).

### Run
An invocation of an assistant on a thread.

### Run Step
Detailed steps the assistant took during a run.

## Create Assistant

```
POST https://api.openai.com/v1/assistants
```

### Request Body
```json
{
  "model": "gpt-4o",
  "name": "Math Tutor",
  "instructions": "You are a personal math tutor. Help students with math problems.",
  "tools": [
    {"type": "code_interpreter"},
    {"type": "file_search"}
  ],
  "tool_resources": {
    "file_search": {
      "vector_store_ids": ["vs_abc123"]
    }
  },
  "metadata": {
    "user_id": "user_123"
  }
}
```

### Parameters
- **model** (required): Model ID (e.g., `gpt-4o`, `gpt-4-turbo`)
- **name**: Name of the assistant (max 256 chars)
- **description**: Description (max 512 chars)
- **instructions**: System instructions (max 256,000 chars)
- **tools**: Array of tools (`code_interpreter`, `file_search`, `function`)
- **tool_resources**: Resources for tools (vector stores, code interpreter files)
- **metadata**: Key-value pairs (max 16 pairs)
- **temperature**: 0-2 (default: 1)
- **top_p**: 0-1 (default: 1)
- **response_format**: `auto` or `{"type": "json_object"}`

## Create Thread

```
POST https://api.openai.com/v1/threads
```

### Request Body
```json
{
  "messages": [
    {
      "role": "user",
      "content": "Solve this equation: 3x + 11 = 14"
    }
  ],
  "metadata": {
    "session_id": "session_123"
  }
}
```

## Add Message to Thread

```
POST https://api.openai.com/v1/threads/{thread_id}/messages
```

### Request Body
```json
{
  "role": "user",
  "content": "What is the solution?",
  "attachments": [
    {
      "file_id": "file-abc123",
      "tools": [{"type": "file_search"}]
    }
  ]
}
```

## Create Run

```
POST https://api.openai.com/v1/threads/{thread_id}/runs
```

### Request Body
```json
{
  "assistant_id": "asst_abc123",
  "instructions": "Please address the user as Jane Doe.",
  "additional_instructions": "Be concise.",
  "additional_messages": [
    {
      "role": "user",
      "content": "Extra context here"
    }
  ],
  "tools": [{"type": "code_interpreter"}],
  "metadata": {
    "run_type": "test"
  }
}
```

### Parameters
- **assistant_id** (required): ID of assistant to use
- **model**: Override assistant's model
- **instructions**: Override assistant's instructions
- **additional_instructions**: Append to instructions
- **additional_messages**: Add messages before run
- **tools**: Override assistant's tools
- **stream**: Enable streaming
- **temperature**, **top_p**, **max_prompt_tokens**, **max_completion_tokens**

## Run Status

A run can have these statuses:
- `queued`: Waiting to be processed
- `in_progress`: Currently running
- `requires_action`: Waiting for function call results
- `cancelling`: Being cancelled
- `cancelled`: Cancelled
- `failed`: Failed
- `completed`: Successfully completed
- `incomplete`: Incomplete (max tokens/time reached)
- `expired`: Expired before completion

## Retrieve Run

```
GET https://api.openai.com/v1/threads/{thread_id}/runs/{run_id}
```

### Response
```json
{
  "id": "run_abc123",
  "object": "thread.run",
  "created_at": 1699063290,
  "assistant_id": "asst_abc123",
  "thread_id": "thread_abc123",
  "status": "completed",
  "started_at": 1699063290,
  "completed_at": 1699063291,
  "model": "gpt-4o",
  "instructions": "You are a helpful assistant.",
  "tools": [{"type": "code_interpreter"}],
  "metadata": {},
  "usage": {
    "prompt_tokens": 123,
    "completion_tokens": 456,
    "total_tokens": 579
  }
}
```

## List Messages

```
GET https://api.openai.com/v1/threads/{thread_id}/messages
```

### Response
```json
{
  "object": "list",
  "data": [
    {
      "id": "msg_abc123",
      "object": "thread.message",
      "created_at": 1699017614,
      "thread_id": "thread_abc123",
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": {
            "value": "The solution is x = 1",
            "annotations": []
          }
        }
      ],
      "assistant_id": "asst_abc123",
      "run_id": "run_abc123",
      "metadata": {}
    }
  ]
}
```

## Reference
- Official Docs: https://platform.openai.com/docs/assistants
- API Reference: https://platform.openai.com/docs/api-reference/assistants

