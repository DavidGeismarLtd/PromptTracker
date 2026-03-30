# Assistant Chatbot - Links and Context Management

## Overview

The assistant chatbot must provide **clickable links to all resources** it creates or references, and maintain **conversation context** to answer follow-up questions about previously created entities.

---

## Core Principles

### 1. Always Include Links
Every action that creates or references a resource must include clickable links to:
- The resource's show page
- Related pages (playground, tests, runs, etc.)
- Relevant dashboard/list views

### 2. Store Context
The assistant must remember what it created in the conversation:
- Prompt IDs, Version IDs
- Test IDs, Test Run IDs
- Dataset IDs, etc.

This allows users to ask follow-up questions like:
- "What model is running on the prompt you just created?"
- "Show me a summary of the tests for this prompt"
- "How did the tests perform?"

### 3. Two Types of Functions

**Action Functions** (Require Confirmation):
- Modify state (create, update, delete, run)
- Show confirmation modal before execution
- Return success message with links

**Query Functions** (No Confirmation):
- Read-only operations (get info, search, summarize)
- Execute immediately
- Return formatted data with links

---

## Link Display Examples

### After Creating a Prompt

```
✅ Created prompt "Customer Support Bot" successfully!

📝 Prompt ID: 123
🆔 Version ID: 248

🔗 Links:
   • View prompt details
   • Open in playground
   • View all versions
   • Testing section

What would you like to do next?
- Write tests for this prompt
- Configure model settings
- Add to deployment
```

**Technical Format:**
```json
{
  "message": "✅ Created prompt \"Customer Support Bot\" successfully!",
  "links": [
    {
      "text": "View prompt details",
      "url": "/prompt_tracker/testing/prompts/123",
      "icon": "eye"
    },
    {
      "text": "Open in playground",
      "url": "/prompt_tracker/testing/prompts/123/playground",
      "icon": "play-circle"
    }
  ],
  "entities_created": {
    "prompt_id": 123,
    "version_id": 248
  }
}
```

### After Generating Tests

```
✅ Generated 5 tests successfully!

📊 Test Summary:
1. "Happy path: Customer greeting" - Created
2. "Edge case: Empty input" - Created
3. "Error handling: Invalid request" - Created
4. "Response quality: Politeness" - Created
5. "Response time: Under 2s" - Created

🔗 Links:
   • View all tests
   • Run all tests
   • Add more tests
   • View prompt version

Would you like to run all tests now?
[Yes, run tests] [No, thanks]
```

**Technical Format:**
```json
{
  "message": "✅ Generated 5 tests successfully!",
  "tests": [
    {
      "id": 101,
      "name": "Happy path: Customer greeting",
      "status": "created"
    },
    ...
  ],
  "links": [
    {
      "text": "View all tests",
      "url": "/prompt_tracker/testing/prompts/123/versions/248#tests",
      "icon": "list-check"
    }
  ],
  "entities_created": {
    "test_ids": [101, 102, 103, 104, 105]
  }
}
```

### After Running Tests

```
✅ Test run completed!

📊 Results: 4/5 tests passed (80%)
⏱️ Total time: 28.3 seconds

✅ Passing: 4 tests
❌ Failing: 1 test
   - "Edge case: Empty input" - Pattern match failed

🔗 Links:
   • View detailed test results (Run #42)
   • View failing test details
   • Re-run all tests
   • Generate more tests

Top Issues:
1. Test #103: Pattern match failed
   Expected: /greeting/i
   Got: ""
   🔗 View test | 🔗 Edit test

Would you like to:
- Review the failing test
- Generate more tests for edge cases
- Re-run all tests
```

---

## Query Function Examples

### Get Prompt Version Info

**User**: "What model is the prompt you just created using?"

**Assistant Response**:
```
The prompt "Customer Support Bot" (Version 2) is configured with:

🤖 Provider: OpenAI
📊 API: Chat Completions
🧠 Model: gpt-4o
🌡️ Temperature: 0.7
📝 Status: Active
🆔 Version: 2 (latest)
👤 Created by: You (2 minutes ago)

🔗 Links:
   • View full prompt details
   • Open in playground
   • View version history
   • Testing dashboard

Configuration Details:
- Max tokens: 2000
- Top P: 1.0
- Frequency penalty: 0.0
- Presence penalty: 0.0

Would you like to:
- Change the model configuration
- Write tests for this prompt
- Deploy as an agent
```

### Get Tests Summary

**User**: "Can you provide a summary of the tests for this prompt version?"

**Assistant Response**:
```
Test Summary for "Customer Support Bot" (Version 2):

📊 Overall Statistics:
   • Total tests: 10
   • Passing: 8 tests (80%)
   • Failing: 2 tests (20%)
   • Not run: 0 tests

🔗 Links:
   • View all tests
   • View latest test run (#42)
   • Run all tests now
   • Generate more tests

Recent Test Runs:
1. Run #42 (2 min ago): 8/10 passed (80%) 🔗 View
2. Run #41 (1 hour ago): 7/10 passed (70%) 🔗 View
3. Run #40 (2 hours ago): 9/10 passed (90%) 🔗 View

Top Failing Tests:
1. "Edge case: Empty input" - Pattern match failed
   Last failed: 2 min ago (Run #42)
   🔗 View test | 🔗 View run

2. "Performance test" - Response time > 2s
   Last failed: 2 min ago (Run #42)
   Actual: 2.8s, Expected: < 2s
   🔗 View test | 🔗 View run

Would you like to:
- Review the failing tests
- Generate more tests for edge cases
- Re-run all tests
```

---

## Context Storage Implementation

### Conversation Context Structure

```ruby
# Stored in AgentConversation metadata
{
  "context": {
    "current_page": "/prompt_tracker/testing/prompts/123",
    "entities": {
      "prompt_id": 123,
      "version_id": 248,
      "test_ids": [101, 102, 103, 104, 105],
      "last_test_run_id": 42
    },
    "recent_actions": [
      {
        "action": "create_prompt",
        "timestamp": "2026-03-28T10:30:00Z",
        "entities": { "prompt_id": 123, "version_id": 248 }
      },
      {
        "action": "generate_tests",
        "timestamp": "2026-03-28T10:35:00Z",
        "entities": { "test_ids": [101, 102, 103, 104, 105] }
      }
    ]
  }
}
```

### Context Updates

After each action, the service updates conversation context:

```ruby
# app/services/prompt_tracker/assistant_chatbot_service.rb

def update_conversation_context(action, entities)
  conversation.metadata ||= {}
  conversation.metadata["context"] ||= {}
  conversation.metadata["context"]["entities"] ||= {}
  
  # Merge new entities
  conversation.metadata["context"]["entities"].merge!(entities)
  
  # Track action history
  conversation.metadata["context"]["recent_actions"] ||= []
  conversation.metadata["context"]["recent_actions"] << {
    "action" => action,
    "timestamp" => Time.current.iso8601,
    "entities" => entities
  }
  
  # Keep only last 10 actions
  conversation.metadata["context"]["recent_actions"] = 
    conversation.metadata["context"]["recent_actions"].last(10)
  
  conversation.save!
end
```

### Resolving References in Queries

When user asks "What model is the prompt you just created using?":

```ruby
# Extract "the prompt you just created" → resolve to prompt_id from context
def resolve_entity_reference(query, entity_type)
  context = conversation.metadata.dig("context", "entities")
  
  case entity_type
  when :prompt
    context["prompt_id"]
  when :version
    context["version_id"]
  when :tests
    context["test_ids"]
  when :test_run
    context["last_test_run_id"]
  end
end
```

---

## UI Implementation for Links

### Link Rendering in Messages

```erb
<!-- app/views/prompt_tracker/assistant_chatbot/_message.html.erb -->

<div class="message assistant-message">
  <div class="message-content">
    <div class="message-text">
      <%= simple_format(message.content) %>
    </div>
    
    <% if message.links.present? %>
      <div class="message-links mt-2">
        <strong>🔗 Links:</strong>
        <ul class="list-unstyled ms-3 mt-1">
          <% message.links.each do |link| %>
            <li>
              <a href="<%= link['url'] %>" class="text-primary" target="_blank">
                <% if link['icon'] %>
                  <i class="bi bi-<%= link['icon'] %>"></i>
                <% end %>
                <%= link['text'] %>
                <i class="bi bi-box-arrow-up-right ms-1"></i>
              </a>
            </li>
          <% end %>
        </ul>
      </div>
    <% end %>
  </div>
</div>
```

---

## Testing Checklist

- [ ] Links included in all create/update responses
- [ ] Links clickable and open in new tab
- [ ] Context stored after each action
- [ ] Follow-up questions resolve entities correctly
- [ ] Query functions return formatted data with links
- [ ] Links have appropriate icons
- [ ] Mobile-friendly link display

