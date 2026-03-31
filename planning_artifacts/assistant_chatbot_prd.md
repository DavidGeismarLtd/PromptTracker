# Assistant Chatbot Feature - Product Requirements Document

## Executive Summary

Add an AI-powered assistant chatbot that is accessible throughout the PromptTracker application. The chatbot will help users perform common tasks, answer questions, and execute actions with confirmation prompts. This enhances user productivity by providing contextual assistance without leaving their current workflow.

---

## Problem Statement

**Current State:**
- Users need to navigate through multiple pages to perform common tasks
- Creating prompts, writing tests, and running tests requires manual navigation
- No contextual help or guidance available within the application
- Repetitive tasks require multiple clicks and form submissions

**Desired State:**
- Users can access an AI assistant from anywhere in the application
- The assistant can perform actions like creating prompts, writing tests, and running tests
- Users receive contextual suggestions based on their current page/context
- All actions require explicit user confirmation before execution
- The assistant provides a great UX with a modern, accessible chat interface

---

## Goals and Success Metrics

### Goals
1. **Accessibility**: Chatbot accessible from every page via a fixed UI element
2. **Capability**: Support key workflows (create prompts, write tests, run tests)
3. **Safety**: Always ask for confirmation before executing actions
4. **UX Excellence**: Modern, responsive chat UI with suggested actions
5. **Configurability**: Model and provider configurable via initializer

### Success Metrics
- Adoption: % of users who interact with the chatbot within first week
- Engagement: Average number of chatbot interactions per user session
- Completion Rate: % of suggested actions that users confirm and execute
- User Satisfaction: NPS score or feedback rating for chatbot feature

---

## User Stories

### As a User
1. **Access Anywhere**: I want to access the chatbot from any page in the application via a fixed button/icon
2. **Get Suggestions**: I want the chatbot to suggest relevant actions based on my current page context
3. **Create Prompts**: I want to ask the chatbot to create a new prompt with specific parameters
4. **Write Tests**: I want the chatbot to generate tests for a prompt version
5. **Run Tests**: I want the chatbot to execute tests and show me the results
6. **Confirm Actions**: I want to review and confirm any action before the chatbot executes it
7. **See Progress**: I want to see real-time feedback as the chatbot performs actions
8. **Chat History**: I want to see my conversation history within a session
9. **Reset Conversation**: I want to clear the chat and start fresh

### As an Admin/Developer
1. **Configure Model**: I want to configure which LLM provider and model powers the chatbot
2. **Control Access**: I want to enable/disable the chatbot feature via configuration
3. **Monitor Usage**: I want to track chatbot usage and function executions
4. **Custom Functions**: I want to add custom assistant functions for domain-specific actions

---

## Functional Requirements

### 1. UI/UX Requirements

#### 1.1 Global Access
- **Fixed Chat Button**: Floating button in bottom-right corner of all pages
  - Icon: Speech bubble or bot icon
  - Badge: Show unread message count (if applicable)
  - Click: Opens chat panel with slide-in animation

#### 1.2 Chat Panel
- **Slide-in Panel**: 400px wide panel that slides in from right side
- **Header**:
  - Title: "Assistant" or custom name
  - Close button (X)
  - Minimize button (-)
  - Reset conversation button
- **Messages Area**:
  - Scrollable container (max-height: 70vh)
  - User messages: Right-aligned, blue background
  - Assistant messages: Left-aligned, gray background
  - System messages: Centered, subtle background
  - Typing indicator when assistant is thinking
  - Timestamp for each message
  - Auto-scroll to latest message
- **Suggested Actions**:
  - Display action buttons/chips for suggested next steps
  - Context-aware suggestions based on current page
  - Example: On prompt detail page → "Write tests for this prompt"
  - Click on suggestion → Adds it to input field or sends directly
- **Input Area**:
  - Multi-line textarea (auto-resize, max 150px)
  - Send button (enabled only when text present)
  - Shift+Enter for new line, Enter to send
  - Placeholder: "Ask me anything or try a suggestion..."
- **Confirmation Modal**:
  - Shows action details before execution
  - Clear description of what will happen
  - "Cancel" and "Confirm" buttons
  - Display parameters in readable format

#### 1.3 Responsive Behavior
- **Desktop**: 400px panel slides in from right
- **Tablet**: 350px panel
- **Mobile**: Full-screen overlay with back button

#### 1.4 Accessibility
- **Keyboard Navigation**: Tab through all interactive elements
- **Screen Reader Support**: ARIA labels for all elements
- **Focus Management**: Trap focus within panel when open
- **Escape Key**: Closes panel

---

### 2. Conversation Management

#### 2.1 Session Persistence
- Store conversation history in Rails session (cache_store)
- Conversation tied to user session (auto-expires after 24h inactivity)
- Reset button clears conversation immediately

#### 2.2 Context Awareness
- Track current page URL and key identifiers (prompt_id, version_id, etc.)
- Pass context to assistant in system prompt or metadata
- Assistant can reference current page in responses

---

### 3. Action Capabilities

The chatbot must support the following actions with confirmation:

#### 3.1 Create Prompt
**User Request**: "Create a new prompt called 'Customer Support Bot'"
**Assistant Response**:
```
I can create a new prompt with these details:
- Name: Customer Support Bot
- Type: Standard
- Provider: openai (default)
- Model: gpt-4o (default)

Would you like me to proceed?
[Cancel] [Confirm & Create]
```
**On Confirm**:
- Create Prompt and PromptVersion via service
- Show success message:
  ```
  ✅ Created prompt "Customer Support Bot" successfully!

  📝 Prompt ID: 123
  🔗 View prompt: [Link to /prompts/123]
  🔗 Open in playground: [Link to /prompts/123/playground]

  What would you like to do next?
  - Write tests for this prompt
  - Configure model settings
  - Add to deployment
  ```
- Store created entity IDs in conversation context for future reference

#### 3.2 Write Tests for Prompt
**User Request**: "Write 5 tests for this prompt"
**Assistant Response**:
```
I can generate 5 tests for the prompt "Customer Support Bot" using AI.

Test generation will:
- Analyze the prompt's purpose
- Create diverse test scenarios
- Set up assertions

Would you like me to proceed?
[Cancel] [Confirm & Generate]
```
**On Confirm**:
- Call TestGeneratorService
- Show progress indicator
- Display created tests with details:
  ```
  ✅ Generated 5 tests successfully!

  📊 Test Summary:
  1. "Happy path: Customer greeting" - Created
  2. "Edge case: Empty input" - Created
  3. "Error handling: Invalid request" - Created
  4. "Response quality: Politeness" - Created
  5. "Response time: Under 2s" - Created

  🔗 View all tests: [Link to /prompts/123/versions/248#tests]

  Would you like to run all tests now?
  [Yes, run tests] [No, thanks]
  ```
- Store test IDs in conversation context for future queries

#### 3.3 Run Tests
**User Request**: "Run all tests"
**Assistant Response**:
```
I can run all 5 tests for this prompt version.

This will:
- Execute each test against the current model
- Track results and metrics
- Show pass/fail status

Estimated time: ~30 seconds

Would you like me to proceed?
[Cancel] [Confirm & Run]
```
**On Confirm**:
- Trigger test run (async job)
- Show real-time progress updates:
  ```
  ⏳ Running tests... (this may take 30 seconds)

  Progress:
  ✅ Test 1/5: Passed (1.2s)
  ✅ Test 2/5: Passed (0.9s)
  ❌ Test 3/5: Failed - Pattern match error
  ✅ Test 4/5: Passed (1.5s)
  ⏳ Test 5/5: Running...
  ```
- Display final results summary with links:
  ```
  ✅ Test run completed!

  📊 Results: 4/5 tests passed (80%)
  ⏱️ Total time: 28.3 seconds

  ✅ Passing: 4 tests
  ❌ Failing: 1 test
     - "Edge case: Empty input" - Pattern match failed

  🔗 View detailed results: [Link to test run #42]
  🔗 View failing test: [Link to test #3]

  Would you like to:
  - Review the failing test
  - Generate more tests for edge cases
  - Re-run all tests
  ```
- Store test run ID in conversation context

#### 3.4 Get Prompt Version Info
**User Request**: "What model is running on the prompt you just created?" or "Show me details about this prompt"
**Assistant Response**:
```
The prompt "CS Bot v1" (Version 2) is configured with:

🤖 Provider: OpenAI
📊 API: Chat Completions
🧠 Model: gpt-4o
🌡️ Temperature: 0.7
📝 Status: Active

🔗 View full details: [Link to /prompts/123/versions/248]

Would you like to:
- Write tests for this prompt
- Open in playground
- Change the model configuration
```

**On Execution**:
- Query PromptVersion model for details
- Format response with key information
- Provide direct link to prompt version page
- Suggest relevant next actions

#### 3.5 Get Tests Summary
**User Request**: "Can you provide a summary of the tests for this prompt version?" or "How are the tests performing?"
**Assistant Response**:
```
Test Summary for "CS Bot v1" (Version 2):

📊 Overall: 8/10 tests passing (80%)
✅ Passing: 8 tests
❌ Failing: 2 tests
⏳ Not run: 0 tests

Recent Test Runs:
- Run #5 (2 min ago): 8/10 passed (80%)
- Run #4 (1 hour ago): 7/10 passed (70%)

Top Failing Tests:
1. "Edge case: Empty input" - Pattern match failed
2. "Performance test" - Response time > 2s

🔗 View all tests: [Link to tests section]
🔗 View latest run: [Link to test run #5]

Would you like to:
- Run all tests again
- Generate more tests
- View failing test details
```

**On Execution**:
- Query Test model for prompt version
- Aggregate test run statistics
- Identify failing tests
- Provide links to tests page and latest run
- Suggest actionable next steps

#### 3.6 Navigate & Search
**User Request**: "Take me to the monitoring dashboard" or "Find prompts with tag 'production'"
**Assistant Response**:
```
I can help you navigate!

🔗 Monitoring Dashboard: [Link to /monitoring]

Or would you like to:
- View all prompts
- See active deployments
- Check recent evaluations
```

**For Search**:
```
Found 5 prompts with tag "production":

1. Customer Support Bot v3 (Active)
   🔗 View prompt
2. Email Classifier v2 (Active)
   🔗 View prompt
3. Sentiment Analyzer v1 (Paused)
   🔗 View prompt

Show more results? [Yes] [No]
```

#### 3.7 Additional Capabilities (Future)
- Generate dataset rows
- Run A/B test comparison
- Analyze test results in detail
- Export data
- Modify prompt configuration
- Deploy as agent

---

### 4. Technical Architecture

#### 4.1 Backend Components

**Models:**
- Reuse existing `AgentConversation` model for session storage
- Reuse existing `ConversationMessage` model for message history
- New scope: `assistant_conversations` to distinguish from deployed agent conversations

**Service:**
- `AssistantChatbotService` - Main service for processing user messages
  - Input: user message, current context (URL, page params)
  - Output: assistant response, suggested actions, function calls
  - Uses `AgentRuntimeService` pattern with custom function executor

**Functions:**
- `CreatePromptFunction` - Creates new prompt and version
- `GenerateTestsFunction` - Generates tests for a prompt version
- `RunTestsFunction` - Executes test suite
- `GetPromptVersionInfoFunction` - Retrieves prompt version details (model, config, status)
- `GetTestsSummaryFunction` - Retrieves test statistics and results
- `NavigateToFunction` - Provides navigation link/suggestion
- `SearchPromptsFunction` - Searches prompts by name, tag, or criteria
- Each function returns structured data with links to relevant pages

**Controller:**
- `PromptTracker::AssistantChatbotController`
  - `POST /assistant/chat` - Send message, get response
  - `POST /assistant/execute_action` - Execute confirmed action
  - `POST /assistant/reset` - Clear conversation
  - `GET /assistant/suggestions` - Get context-aware suggestions

#### 4.2 Frontend Components

**Stimulus Controllers:**
- `assistant_chatbot_controller.js` - Main controller
  - Manages panel open/close state
  - Sends messages to backend
  - Displays messages in chat UI
  - Handles typing indicators
  - Auto-scrolls to latest message
  - Manages suggested actions

- `assistant_confirmation_controller.js` - Confirmation modal
  - Shows action details
  - Handles confirm/cancel actions
  - Executes confirmed actions via API

**Views:**
- `app/views/layouts/prompt_tracker/_assistant_chatbot.html.erb` - Global chatbot UI
  - Rendered in main application layout
  - Includes floating button + slide-in panel
  - Controlled by Stimulus

- `app/views/prompt_tracker/assistant_chatbot/_message.html.erb` - Message partial
  - User message template
  - Assistant message template
  - System message template

- `app/views/prompt_tracker/assistant_chatbot/_confirmation_modal.html.erb` - Confirmation UI
  - Generic modal for all action confirmations
  - Dynamically populated with action details

**Turbo Streams:**
- Real-time message updates
- Typing indicator toggles
- Suggested actions updates
- Progress updates during long-running actions

#### 4.3 System Prompt Design

The assistant needs a comprehensive system prompt that:

1. **Defines Role**: "You are a helpful assistant for PromptTracker..."
2. **Lists Capabilities**: Available functions and their purposes
3. **Provides Context**: Current page, user state, relevant entities
4. **Sets Tone**: Friendly, concise, action-oriented
5. **Instructs Behavior**:
   - Always suggest actions using available functions
   - Provide clear, structured responses
   - Ask clarifying questions when needed
   - Confirm understanding before calling functions

**Example System Prompt Structure:**
```
You are a helpful AI assistant for PromptTracker, a prompt engineering and testing platform.

CURRENT CONTEXT:
- Page: Prompt Details
- Prompt ID: 123
- Prompt Name: "Customer Support Bot"
- Version: 2 (active)
- Status: 5 tests created, 3 passing

AVAILABLE ACTIONS:
1. create_prompt(name, description) - Create a new prompt
2. generate_tests(prompt_version_id, count) - Generate tests for a prompt version
3. run_tests(prompt_version_id) - Run all tests for a prompt version
4. get_prompt_version_info(prompt_version_id) - Get details about a prompt version (model, config, status)
5. get_tests_summary(prompt_version_id) - Get test statistics and results summary
6. navigate_to(page, entity_id) - Suggest navigation to a page
7. search_prompts(query, filters) - Search for prompts by name, tag, or other criteria

GUIDELINES:
- Be concise and helpful
- Suggest relevant actions based on context
- Always call functions to perform actions (don't just describe them)
- Ask clarifying questions if user request is ambiguous
- Confirm you understand before calling functions

USER PREFERENCES:
- Provider: OpenAI
- Default Model: gpt-4o

Reply to the user's message below.
```

---

### 5. Configuration

#### 5.1 Initializer Configuration

**File**: `config/initializers/prompt_tracker.rb`

```ruby
PromptTracker.configure do |config|
  # ... existing configuration ...

  # ===================================================================
  # ASSISTANT CHATBOT CONFIGURATION
  # ===================================================================

  # Enable/disable the assistant chatbot feature
  config.assistant_chatbot = {
    enabled: true,

    # Model configuration for the assistant
    model: {
      provider: :openai,
      api: :chat_completions,
      model: "gpt-4o",
      temperature: 0.7
    },

    # UI customization
    ui: {
      name: "PromptTracker Assistant",
      position: :bottom_right, # :bottom_right, :bottom_left
      theme: :light # :light, :dark, :auto
    },

    # Conversation settings
    conversation: {
      max_messages: 50, # Limit conversation history
      ttl: 24.hours # Auto-expire conversations
    },

    # Feature flags for capabilities
    capabilities: {
      create_prompts: true,
      generate_tests: true,
      run_tests: true,
      navigate: true
    }
  }
end
```

#### 5.2 Feature Flag

Allow users to disable the chatbot entirely:

```ruby
# Disable chatbot
config.assistant_chatbot = { enabled: false }

# OR
config.features[:assistant_chatbot] = false
```

---

### 6. User Flows

#### 6.1 Flow: Create Prompt via Chatbot

1. User clicks floating chatbot button
2. Panel slides in from right
3. User types: "Create a prompt for customer support"
4. Assistant responds:
   ```
   I can help you create a new prompt!

   To create a customer support prompt, I need:
   - A name for the prompt
   - A brief description (optional)

   What would you like to name it?
   ```
5. User: "Call it 'CS Bot v1'"
6. Assistant calls `create_prompt` function with confirmation:
   ```
   I'll create a new prompt with these details:

   📝 Name: CS Bot v1
   📋 Description: Customer support prompt
   🤖 Provider: OpenAI (default)
   🧠 Model: gpt-4o (default)

   This will create a new prompt with an empty first version.

   [Cancel] [Confirm & Create]
   ```
7. User clicks "Confirm & Create"
8. Assistant executes function → Creates Prompt + PromptVersion
9. Success message with suggestions:
   ```
   ✅ Created prompt "CS Bot v1" successfully!

   🔗 View prompt: [Link to /prompts/124]

   What would you like to do next?
   - Write tests for this prompt
   - Open in playground
   - Create another prompt
   ```

#### 6.2 Flow: Generate and Run Tests

1. User on prompt version detail page
2. Opens chatbot (context: prompt_version_id = 42)
3. User: "Write 10 tests for this prompt"
4. Assistant (with context awareness):
   ```
   I can generate 10 tests for "CS Bot v1" (Version 2).

   Test generation will:
   - Analyze the prompt's system instructions
   - Create diverse scenarios
   - Set up appropriate assertions

   Estimated time: ~20 seconds

   [Cancel] [Confirm & Generate]
   ```
5. User confirms
6. Assistant shows progress:
   ```
   ⏳ Generating tests... (this may take 20-30 seconds)
   ```
7. On completion:
   ```
   ✅ Generated 10 tests successfully!

   📊 Test Summary:
   - 10 tests created
   - 0 run yet

   🔗 View tests: [Link to tests section]

   Would you like to run all tests now?
   [Yes, run tests] [No, thanks]
   ```
8. If user clicks "Yes, run tests":
   - Show confirmation modal for run_tests function
   - Execute test run
   - Show real-time progress
   - Display final results

---

### 7. Non-Functional Requirements

#### 7.1 Performance
- **Message Response Time**: < 3s for simple queries, < 10s for function calls
- **UI Responsiveness**: Panel open/close animations < 300ms
- **Function Execution**: Progress updates every 2-5 seconds for long operations
- **Session Storage**: Efficient conversation storage (limit to 50 messages)

#### 7.2 Security
- **Authentication**: Chatbot only accessible to authenticated users
- **Authorization**: Function execution respects user permissions
- **Input Validation**: Sanitize all user inputs before processing
- **Rate Limiting**: Max 30 messages per minute per user
- **Audit Trail**: Log all function executions with user, timestamp, parameters

#### 7.3 Error Handling
- **LLM Failures**: Show friendly error message, suggest retry
- **Function Failures**: Display specific error, suggest alternative actions
- **Network Errors**: Offline indicator, queue messages for retry
- **Validation Errors**: Clear feedback on what went wrong

#### 7.4 Browser Compatibility
- Modern browsers: Chrome 90+, Firefox 88+, Safari 14+, Edge 90+
- Graceful degradation for older browsers (hide chatbot if JS disabled)

---

### 8. Implementation Phases

#### Phase 1: Foundation (Week 1-2)
- [ ] Configuration system in initializer
- [ ] Backend: AssistantChatbotController + routes
- [ ] Backend: AssistantChatbotService (basic chat, no functions)
- [ ] Frontend: Stimulus controller + UI components
- [ ] Frontend: Slide-in panel with messages
- [ ] Conversation persistence using session/cache
- [ ] Basic system prompt with context awareness

**Deliverable**: Working chatbot that can answer questions but not execute actions

#### Phase 2: Function Execution (Week 3-4)
- [ ] Function framework: Base class + executor pattern
- [ ] Confirmation modal UI + controller
- [ ] Create Prompt function
- [ ] Generate Tests function
- [ ] Run Tests function
- [ ] Function execution tracking and audit

**Deliverable**: Chatbot can create prompts, generate tests, run tests with confirmation

#### Phase 3: UX Enhancements (Week 5)
- [ ] Suggested actions system
- [ ] Context-aware suggestions based on current page
- [ ] Real-time progress updates for long operations
- [ ] Improved message formatting (markdown support)
- [ ] Error handling and recovery flows
- [ ] Mobile responsive design

**Deliverable**: Polished UX with suggestions and progress tracking

#### Phase 4: Advanced Features (Week 6+)
- [ ] Additional functions (datasets, A/B tests, navigation)
- [ ] Conversation analytics and insights
- [ ] Multi-language support
- [ ] Voice input (optional)
- [ ] Export conversation history
- [ ] Custom function plugins

**Deliverable**: Full-featured assistant with extensibility

---

### 9. Testing Strategy

#### 9.1 Unit Tests (RSpec)
- `AssistantChatbotService` - Message processing, function routing
- Function classes - Create prompt, generate tests, run tests
- Context detection - URL parsing, entity extraction
- Confirmation logic - Action validation, parameter extraction

#### 9.2 Integration Tests (RSpec)
- Controller actions - Chat, execute_action, reset
- End-to-end flows - User message → Function execution → Response
- Session management - Conversation persistence, expiry

#### 9.3 System Tests (RSpec + Capybara)
- UI interactions - Open/close panel, send messages
- Confirmation flow - Function call → Modal → Execution
- Real-time updates - Progress indicators, result display

#### 9.4 Manual Testing Checklist
- [ ] Chatbot accessible from all pages
- [ ] Panel animations smooth on all browsers
- [ ] Message formatting correct (user/assistant/system)
- [ ] Suggested actions appear based on context
- [ ] Confirmation modal shows correct details
- [ ] Function execution succeeds and provides feedback
- [ ] Error scenarios handled gracefully
- [ ] Mobile responsive layout works
- [ ] Keyboard navigation works
- [ ] Screen reader compatibility

---

### 10. Dependencies and Risks

#### Dependencies
- **LLM Provider**: Requires valid API key for configured provider
- **RubyLLM Gem**: Function calling support
- **Turbo/Stimulus**: Frontend framework
- **Redis**: Session storage (already used)
- **Existing Services**: TestGeneratorService, test runners

#### Risks
| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| LLM API failures | High | Medium | Graceful error handling, retry logic |
| Function execution errors | Medium | Medium | Comprehensive validation, rollback support |
| Poor UX adoption | High | Low | User testing, iteration based on feedback |
| Performance issues | Medium | Low | Caching, debouncing, async processing |
| Security vulnerabilities | High | Low | Input sanitization, authorization checks |

---

### 11. Open Questions

1. **Model Selection**: Should we support multiple models (fast vs. powerful)?
2. **Cost Control**: How to limit LLM usage per user/session?
3. **Multi-tenancy**: If app becomes multi-tenant, how to isolate conversations?
4. **Streaming Responses**: Should assistant responses stream token-by-token?
5. **Conversation Sharing**: Should users be able to share/export conversations?
6. **Function Plugins**: How to allow custom functions from host app?

---

### 12. Success Criteria for Launch

**Must Have (Phase 1-2):**
- ✅ Chatbot accessible from every page
- ✅ Create prompts via chatbot
- ✅ Generate tests via chatbot
- ✅ Run tests via chatbot
- ✅ All actions require confirmation
- ✅ Context-aware suggestions
- ✅ Basic error handling
- ✅ Configuration via initializer
- ✅ Test coverage > 80%

**Nice to Have (Phase 3-4):**
- ⭐ Real-time progress for long operations
- ⭐ Markdown support in messages
- ⭐ Mobile-optimized UI
- ⭐ Additional functions (datasets, A/B tests)
- ⭐ Conversation analytics

**Launch Checklist:**
- [ ] All Phase 1-2 features complete and tested
- [ ] Documentation updated (README, guides)
- [ ] User feedback collected from beta testers
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] Migration guide for existing users

---

## Appendix

### A. Example API Responses

#### Chat Response (No Action)
```json
{
  "role": "assistant",
  "content": "I can help you create a new prompt! What would you like to name it?",
  "suggestions": [
    "Create a new prompt",
    "Generate tests for current prompt",
    "View all prompts"
  ]
}
```

#### Chat Response (With Function Call)
```json
{
  "role": "assistant",
  "content": "I'll create a new prompt with these details...",
  "function_call": {
    "name": "create_prompt",
    "arguments": {
      "name": "CS Bot v1",
      "description": "Customer support prompt"
    },
    "confirmation_required": true,
    "confirmation_message": "I'll create a new prompt with these details:\n\n📝 Name: CS Bot v1\n..."
  },
  "suggestions": []
}
```

#### Execute Action Response
```json
{
  "success": true,
  "message": "✅ Created prompt 'CS Bot v1' successfully!",
  "data": {
    "prompt_id": 124,
    "version_id": 248,
    "url": "/prompt_tracker/testing/prompts/124"
  },
  "suggestions": [
    "Write tests for this prompt",
    "Open in playground"
  ]
}
```

### B. System Prompt Template

See Section 4.3 for detailed system prompt structure.

### C. UI Wireframes

**Chatbot Button:**
```
┌─────────────────┐
│                 │
│   [💬 Chat]     │  ← Fixed bottom-right
└─────────────────┘
```

**Chatbot Panel:**
```
┌────────────────────────────────┐
│ PromptTracker Assistant    ✕ - │
├────────────────────────────────┤
│                                │
│  🤖 How can I help?            │
│                                │
│  You: Create a new prompt      │
│                                │
│  🤖 I can help you create...   │
│      [Suggested Actions]       │
│      - Create new prompt       │
│      - Generate tests          │
│                                │
├────────────────────────────────┤
│ Type a message...        [Send]│
└────────────────────────────────┘
```
