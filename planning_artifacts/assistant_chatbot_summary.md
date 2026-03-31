# Assistant Chatbot Feature - Quick Reference

## Overview
AI-powered assistant chatbot accessible throughout PromptTracker that helps users perform common tasks with confirmation prompts.

## Key Features

### 1. Global Accessibility
- **Fixed floating button** in bottom-right corner (all pages)
- **Slide-in panel** (400px wide) from right side
- Modern chat UI with message history
- Context-aware suggestions based on current page

### 2. Core Capabilities

**Action Functions (Require Confirmation):**
1. **Create Prompts**: Generate new prompts with specified parameters
2. **Generate Tests**: Auto-generate tests for prompt versions
3. **Run Tests**: Execute test suites with real-time progress

**Query Functions (No Confirmation):**
1. **Get Prompt Info**: Retrieve model config, status, and details for any prompt version
2. **Get Tests Summary**: View test statistics, pass/fail rates, and recent runs
3. **Search & Navigate**: Find prompts, navigate to pages

### 3. User Experience
- **Suggested Actions**: Context-aware action chips
- **Confirmation Modals**: Review before execution
- **Real-time Progress**: Updates for long-running operations
- **Conversation History**: Persistent within session (24h TTL)
- **Reset Conversation**: Clear and start fresh

## Technical Stack

### Backend
- **Controller**: `AssistantChatbotController` (4 endpoints)
- **Service**: `AssistantChatbotService` (message processing + function routing)
- **Action Functions**: `CreatePromptFunction`, `GenerateTestsFunction`, `RunTestsFunction`
- **Query Functions**: `GetPromptVersionInfoFunction`, `GetTestsSummaryFunction`, `SearchPromptsFunction`
- **Models**: Reuse `AgentConversation` + `ConversationMessage`
- **Context Tracking**: Store created entity IDs for future queries

### Frontend
- **Stimulus Controllers**: `assistant_chatbot_controller.js`, `assistant_confirmation_controller.js`
- **Views**: Panel layout, message partials, confirmation modal
- **Turbo Streams**: Real-time updates

### Configuration
```ruby
PromptTracker.configure do |config|
  config.assistant_chatbot = {
    enabled: true,
    model: {
      provider: :openai,
      api: :chat_completions,
      model: "gpt-4o",
      temperature: 0.7
    },
    ui: { name: "PromptTracker Assistant", position: :bottom_right },
    capabilities: { create_prompts: true, generate_tests: true, run_tests: true }
  }
end
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- Configuration system
- Basic chat (no functions)
- UI: Panel + messages
- Conversation persistence

### Phase 2: Function Execution (Week 3-4)
- Confirmation modal
- Create Prompt function
- Generate Tests function
- Run Tests function

### Phase 3: UX Enhancements (Week 5)
- Suggested actions
- Progress tracking
- Error handling
- Mobile responsive

### Phase 4: Advanced Features (Week 6+)
- Additional functions
- Analytics
- Multi-language support

## Example Workflows

### Create Prompt → Get Info → Generate Tests
```
User: "Create a new prompt called 'CS Bot'"
Assistant: "I'll create... [shows details] [Cancel] [Confirm]"
User: [Clicks Confirm]
Assistant: "✅ Created! [Link to prompt] [Link to playground] Next: Write tests?"

User: "What model is this prompt using?"
Assistant: "CS Bot is using:
           🤖 Provider: OpenAI
           🧠 Model: gpt-4o
           [Link to prompt details]"

User: "Write 5 tests for it"
Assistant: [Confirmation modal] → ✅ "5 tests created! [Links to tests]"
```

### Generate & Run Tests → Get Summary
```
User: "Write 10 tests"
Assistant: "I can generate 10 tests... [Confirm]"
User: [Confirms]
Assistant: "⏳ Generating... ✅ Done! [Links to each test] Run tests now?"
User: "Yes"
Assistant: [Shows progress] "✅ 8/10 passing [Link to run] [Link to failing tests]"

User: "Can you give me a summary of the tests?"
Assistant: "Test Summary:
           📊 8/10 passing (80%)
           ✅ 8 tests passing
           ❌ 2 tests failing:
              - Edge case test [Link]
              - Performance test [Link]
           🔗 View all tests [Link]"
```

## Security & Performance

### Security
- Authenticated users only
- Authorization checks on all functions
- Input sanitization
- Rate limiting (30 msg/min)
- Audit trail for all executions

### Performance
- Response time: < 3s (simple), < 10s (functions)
- Panel animation: < 300ms
- Progress updates: Every 2-5s
- Max 50 messages per conversation

## Testing Strategy
- **Unit Tests**: Service, functions, context detection
- **Integration Tests**: Controller, end-to-end flows
- **System Tests**: UI interactions, confirmations
- **Manual Testing**: All browsers, mobile, accessibility

## Success Criteria (Launch)
- ✅ Accessible from every page
- ✅ Create prompts, generate tests, run tests
- ✅ All actions require confirmation
- ✅ Context-aware suggestions
- ✅ Configuration via initializer
- ✅ Test coverage > 80%

## Open Questions
1. Support multiple models (fast vs. powerful)?
2. Cost control per user/session?
3. Streaming responses token-by-token?
4. Conversation sharing/export?
5. Custom function plugins from host app?

---

**Full PRD**: See `assistant_chatbot_prd.md` for complete details.
