# Anthropic Tool Use (Function Calling)

## Overview
Claude can use external tools and functions to extend its capabilities. The tool use workflow involves:
1. Provide tools in your API request
2. Claude decides whether to use a tool
3. Extract tool input from Claude's response
4. Execute the tool on your end
5. Return results to Claude
6. Claude provides final response

## Request with Tools

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "tools": [
    {
      "name": "get_weather",
      "description": "Get the current weather in a given location",
      "input_schema": {
        "type": "object",
        "properties": {
          "location": {
            "type": "string",
            "description": "The city and state, e.g. San Francisco, CA"
          },
          "unit": {
            "type": "string",
            "enum": ["celsius", "fahrenheit"],
            "description": "The unit of temperature"
          }
        },
        "required": ["location"]
      }
    }
  ],
  "messages": [
    {
      "role": "user",
      "content": "What's the weather like in San Francisco?"
    }
  ]
}
```

## Tool Definition

Each tool must have:
- **name**: Function name (alphanumeric, underscores, hyphens)
- **description**: What the tool does (helps Claude decide when to use it)
- **input_schema**: JSON Schema for the tool's parameters

## Response with Tool Use

```json
{
  "id": "msg_01Aq9w938a90dw8q",
  "model": "claude-3-5-sonnet-20241022",
  "stop_reason": "tool_use",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "I'll check the weather for you."
    },
    {
      "type": "tool_use",
      "id": "toolu_01A09q90qw90lq917835lq9",
      "name": "get_weather",
      "input": {
        "location": "San Francisco, CA",
        "unit": "fahrenheit"
      }
    }
  ]
}
```

## Continuing the Conversation with Tool Results

After executing the tool, send the results back:

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "tools": [...],  // Same tools as before
  "messages": [
    {
      "role": "user",
      "content": "What's the weather like in San Francisco?"
    },
    {
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": "I'll check the weather for you."
        },
        {
          "type": "tool_use",
          "id": "toolu_01A09q90qw90lq917835lq9",
          "name": "get_weather",
          "input": {
            "location": "San Francisco, CA",
            "unit": "fahrenheit"
          }
        }
      ]
    },
    {
      "role": "user",
      "content": [
        {
          "type": "tool_result",
          "tool_use_id": "toolu_01A09q90qw90lq917835lq9",
          "content": "65°F and sunny"
        }
      ]
    }
  ]
}
```

## Tool Result Content Types

### Text Result
```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_123",
  "content": "The result is 42"
}
```

### Structured Result
```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_123",
  "content": [
    {
      "type": "text",
      "text": "Here are the search results:"
    },
    {
      "type": "text",
      "text": "1. Result one\n2. Result two"
    }
  ]
}
```

### Error Result
```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_123",
  "content": "Error: API rate limit exceeded",
  "is_error": true
}
```

## Tool Choice

Control whether Claude uses tools:

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "tools": [...],
  "tool_choice": {
    "type": "auto"  // or "any" or "tool"
  },
  "messages": [...]
}
```

### Tool Choice Types

**auto** (default)
- Claude decides whether to use tools

**any**
- Claude must use one of the provided tools

**tool**
- Claude must use a specific tool
```json
{
  "type": "tool",
  "name": "get_weather"
}
```

## Multiple Tool Calls

Claude can use multiple tools in a single response:

```json
{
  "content": [
    {
      "type": "text",
      "text": "I'll check both cities."
    },
    {
      "type": "tool_use",
      "id": "toolu_01",
      "name": "get_weather",
      "input": {"location": "San Francisco, CA"}
    },
    {
      "type": "tool_use",
      "id": "toolu_02",
      "name": "get_weather",
      "input": {"location": "New York, NY"}
    }
  ]
}
```

Return all results:
```json
{
  "role": "user",
  "content": [
    {
      "type": "tool_result",
      "tool_use_id": "toolu_01",
      "content": "65°F and sunny"
    },
    {
      "type": "tool_result",
      "tool_use_id": "toolu_02",
      "content": "45°F and cloudy"
    }
  ]
}
```

## Best Practices

1. **Clear descriptions**: Help Claude understand when to use each tool
2. **Detailed schemas**: Provide comprehensive input_schema with descriptions
3. **Handle errors**: Use `is_error: true` for tool execution failures
4. **Validate inputs**: Check tool inputs before execution
5. **Timeout handling**: Set reasonable timeouts for tool execution
6. **Sequential tools**: For dependent operations, use multiple turns

## Reference
- Official Docs: https://docs.anthropic.com/en/docs/build-with-claude/tool-use
- Examples: https://github.com/anthropics/anthropic-cookbook/tree/main/tool_use

