# Assistant Chatbot - Implementation Checklist

This checklist tracks the implementation progress of the Assistant Chatbot feature.

## Phase 1: Foundation (Week 1-2)

### Configuration & Setup
- [ ] Add `assistant_chatbot` configuration to `lib/prompt_tracker/configuration.rb`
- [ ] Add default configuration to generator template `lib/generators/prompt_tracker/install/templates/prompt_tracker.rb`
- [ ] Update `test/dummy/config/initializers/prompt_tracker.rb` with example config
- [ ] Add feature flag support in `PromptTracker.configuration`

### Backend - Controller & Routes
- [ ] Create `app/controllers/prompt_tracker/assistant_chatbot_controller.rb`
  - [ ] `POST /assistant/chat` - Send message, get response
  - [ ] `POST /assistant/execute_action` - Execute confirmed action
  - [ ] `POST /assistant/reset` - Clear conversation
  - [ ] `GET /assistant/suggestions` - Get context-aware suggestions
- [ ] Add routes to `config/routes.rb`
- [ ] Add basic authentication concern (reuse existing pattern)

### Backend - Service Layer
- [ ] Create `app/services/prompt_tracker/assistant_chatbot_service.rb`
  - [ ] Message processing logic
  - [ ] Context extraction from URL/params
  - [ ] LLM call with system prompt
  - [ ] Function call detection
  - [ ] Response formatting
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/context_detector.rb`
  - [ ] Extract current page info (URL, params)
  - [ ] Identify entities (prompt_id, version_id, etc.)
  - [ ] Build context hash for system prompt

### Backend - Conversation Storage
- [ ] Add `assistant_conversations` scope to `AgentConversation` model
- [ ] Add helper methods for loading/creating assistant conversations
- [ ] Test conversation persistence in session/cache

### Backend - System Prompt
- [ ] Create system prompt template
- [ ] Include context variables (page, entities, capabilities)
- [ ] Define function schemas in prompt
- [ ] Add tone/behavior guidelines

### Frontend - UI Components
- [ ] Create `app/views/layouts/prompt_tracker/_assistant_chatbot.html.erb`
  - [ ] Fixed floating button (bottom-right)
  - [ ] Slide-in panel structure
  - [ ] Header with title, close, reset buttons
  - [ ] Messages container
  - [ ] Input area with textarea and send button
- [ ] Create `app/views/prompt_tracker/assistant_chatbot/_message.html.erb`
  - [ ] User message template
  - [ ] Assistant message template
  - [ ] System message template
- [ ] Add chatbot partial to main application layout
- [ ] Style with CSS (slide-in animation, message bubbles, etc.)

### Frontend - Stimulus Controller
- [ ] Create `app/javascript/prompt_tracker/controllers/assistant_chatbot_controller.js`
  - [ ] Panel open/close state management
  - [ ] Send message action
  - [ ] Display messages (user/assistant)
  - [ ] Typing indicator toggle
  - [ ] Auto-scroll to latest message
  - [ ] Reset conversation action
  - [ ] Extract current page context
- [ ] Register controller in `app/javascript/prompt_tracker/controllers/index.js`
- [ ] Add to precompile list in `lib/prompt_tracker/engine.rb`

### Testing - Phase 1
- [ ] RSpec: `AssistantChatbotService` spec
  - [ ] Message processing
  - [ ] Context detection
  - [ ] LLM response handling
- [ ] RSpec: `AssistantChatbotController` spec
  - [ ] POST /chat endpoint
  - [ ] POST /reset endpoint
  - [ ] Authentication
- [ ] System test: Open/close chatbot panel
- [ ] System test: Send message and receive response

---

## Phase 2: Function Execution (Week 3-4)

### Backend - Function Framework
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/functions/base.rb`
  - [ ] Abstract base class for all functions
  - [ ] `call` method signature
  - [ ] `confirmation_message` method
  - [ ] `validate_arguments` method
  - [ ] Result struct (success, data, error)
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/function_executor.rb`
  - [ ] Route function calls to appropriate classes
  - [ ] Handle errors
  - [ ] Track executions

### Backend - Create Prompt Function
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/functions/create_prompt.rb`
  - [ ] Extract name, description from arguments
  - [ ] Validate inputs
  - [ ] Create Prompt + PromptVersion
  - [ ] Return success with entity IDs and URL
- [ ] Add RSpec tests for CreatePromptFunction

### Backend - Generate Tests Function
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/functions/generate_tests.rb`
  - [ ] Extract prompt_version_id, count from arguments
  - [ ] Validate version exists and user has access
  - [ ] Call TestGeneratorService
  - [ ] Return success with test IDs
- [ ] Add RSpec tests for GenerateTestsFunction

### Backend - Run Tests Function
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/functions/run_tests.rb`
  - [ ] Extract prompt_version_id from arguments
  - [ ] Load tests for version
  - [ ] Trigger test run (async job or sync)
  - [ ] Return success with run status
- [ ] Add RSpec tests for RunTestsFunction

### Backend - Get Prompt Version Info Function (Retrieval/Query)
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/functions/get_prompt_version_info.rb`
  - [ ] Extract prompt_version_id from arguments
  - [ ] Load PromptVersion with associations
  - [ ] Format response with model config, status, metadata
  - [ ] Include link to prompt version show page
  - [ ] Return structured data (no confirmation needed)
- [ ] Add RSpec tests for GetPromptVersionInfoFunction

### Backend - Get Tests Summary Function (Retrieval/Query)
- [ ] Create `app/services/prompt_tracker/assistant_chatbot/functions/get_tests_summary.rb`
  - [ ] Extract prompt_version_id from arguments
  - [ ] Load all tests for version
  - [ ] Aggregate test run statistics (passing, failing, not run)
  - [ ] Get recent test runs
  - [ ] Identify top failing tests
  - [ ] Include links to tests page and latest run
  - [ ] Return structured summary (no confirmation needed)
- [ ] Add RSpec tests for GetTestsSummaryFunction

### Frontend - Confirmation Modal
- [ ] Create `app/views/prompt_tracker/assistant_chatbot/_confirmation_modal.html.erb`
  - [ ] Modal structure (Bootstrap)
  - [ ] Dynamic title and description
  - [ ] Parameters display
  - [ ] Cancel and Confirm buttons
- [ ] Create `app/javascript/prompt_tracker/controllers/assistant_confirmation_controller.js`
  - [ ] Show modal with action details
  - [ ] Handle confirm action (call execute endpoint)
  - [ ] Handle cancel action
  - [ ] Close modal after execution
- [ ] Register controller and add to precompile list

### Backend - Update Service for Functions
- [ ] Update `AssistantChatbotService` to detect function calls from LLM
- [ ] Distinguish between action functions (need confirmation) and query functions (no confirmation)
- [ ] Format confirmation message for action functions
- [ ] Execute query functions immediately without confirmation
- [ ] Handle execute_action endpoint (call FunctionExecutor)
- [ ] Return structured response with links and suggestions
- [ ] Store created entity IDs in conversation context for future reference
- [ ] Include resource links in all responses (prompts, tests, runs)

### Testing - Phase 2
- [ ] RSpec: All function classes
- [ ] RSpec: FunctionExecutor routing
- [ ] RSpec: execute_action endpoint
- [ ] Integration test: Full function execution flow
- [ ] System test: Confirmation modal flow

---

## Phase 3: UX Enhancements (Week 5)

### Suggested Actions
- [ ] Add suggested actions to AssistantChatbotService response
- [ ] Context-based suggestion logic (based on current page)
- [ ] Render suggestion buttons/chips in UI
- [ ] Handle suggestion click (send as message or auto-confirm)

### Progress Tracking
- [ ] Add progress updates for long-running operations
- [ ] Stream progress via Turbo Streams (optional)
- [ ] Show spinner/progress bar in UI
- [ ] Update message with final result

### Error Handling
- [ ] Graceful LLM error handling (show user-friendly message)
- [ ] Function execution error handling
- [ ] Network error handling (offline indicator)
- [ ] Retry logic for failed requests

### Mobile Responsive
- [ ] Update CSS for mobile layout (full-screen overlay)
- [ ] Add back button for mobile
- [ ] Touch-friendly button sizes
- [ ] Test on various screen sizes

### Accessibility
- [ ] Add ARIA labels to all interactive elements
- [ ] Keyboard navigation (tab through elements)
- [ ] Focus trap when panel open
- [ ] Escape key to close panel
- [ ] Screen reader testing

---

## Phase 4: Advanced Features (Future)

### Additional Functions
- [ ] NavigateToFunction - Provide navigation suggestions
- [ ] SearchPromptsFunction - Search prompts by name, tag, criteria
- [ ] GenerateDatasetRowsFunction - Generate dataset rows for testing
- [ ] RunABTestFunction - Run A/B test comparisons
- [ ] ExportDataFunction - Export data in various formats
- [ ] UpdatePromptConfigFunction - Modify prompt configuration
- [ ] DeployAgentFunction - Deploy prompt version as agent

### Analytics
- [ ] Track chatbot usage metrics
- [ ] Function execution tracking
- [ ] User satisfaction ratings
- [ ] Dashboard for admin

### Extras
- [ ] Markdown support in messages
- [ ] Code syntax highlighting
- [ ] Conversation export
- [ ] Multi-language support
- [ ] Voice input (optional)

---

## Documentation & Launch

- [ ] Update README with chatbot feature
- [ ] Write user guide for chatbot usage
- [ ] Write developer guide for adding custom functions
- [ ] Update API documentation
- [ ] Migration guide for existing users
- [ ] Release notes
- [ ] Demo video/screenshots

---

**Progress Tracking**: Mark items as complete with `[x]` as you implement them.
