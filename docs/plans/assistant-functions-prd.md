# PRD: OpenAI Assistant Function Calling

## Overview

### Problem Statement
Currently, when creating or editing an OpenAI Assistant in the playground, users cannot define custom functions. The "Functions" option is disabled with a "coming soon" label. This limits the ability to test assistants that need to interact with external systems or perform custom actions.

### Goal
Enable users to define, manage, and test custom functions on OpenAI Assistants, allowing them to build more powerful AI agents that can call external tools and APIs.

### Value to Users
1. **Complete Assistant Configuration**: Users can fully configure assistants without leaving the playground
2. **Rapid Prototyping**: Test function-calling behavior before implementing actual backend integrations
3. **Mock Testing**: Validate assistant behavior with mock function responses
4. **Documentation**: Function definitions serve as documentation for API integrations
5. **Iterative Development**: Quickly adjust function schemas and test responses

---

## User Stories

### US-1: Define a New Function
**As a** developer building an AI assistant
**I want to** define custom functions with name, description, and parameters
**So that** my assistant can request specific actions during conversations

**Acceptance Criteria:**
- User can add a new function with required fields (name, description)
- User can define parameters using JSON Schema format
- User can optionally enable "strict" mode for structured outputs
- Function is saved when assistant is saved/updated
- Validation prevents invalid function definitions

### US-2: Edit Existing Functions
**As a** developer iterating on my assistant
**I want to** edit functions I've already defined
**So that** I can refine my assistant's capabilities

**Acceptance Criteria:**
- User can see list of all defined functions
- User can click to edit any function
- Changes are preserved when saving
- User can cancel edits without saving

### US-3: Delete Functions
**As a** developer
**I want to** remove functions I no longer need
**So that** my assistant only has relevant tools

**Acceptance Criteria:**
- User can delete individual functions
- Confirmation is required before deletion
- Deletion is reflected immediately in UI
- Changes are saved when assistant is updated

### US-4: Test Functions in Conversation
**As a** developer testing my assistant
**I want to** see when my assistant calls functions and provide mock responses
**So that** I can validate the function-calling behavior

**Acceptance Criteria:**
- When assistant requests a function call, UI shows the function name and arguments
- User can input a mock response for the function
- Conversation continues after submitting the response
- Function calls are visually distinct from regular messages

---

## Functional Requirements

### FR-1: Function Definition UI
The function definition interface must support:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Function identifier (alphanumeric + underscore) |
| `description` | string | Yes | What the function does (helps LLM decide when to call) |
| `parameters` | JSON Schema | No | Input parameters schema |
| `strict` | boolean | No | Enable structured outputs (default: false) |

### FR-2: Parameter Schema Builder
Two modes for defining parameters:
1. **JSON Mode**: Raw JSON Schema text editor with syntax highlighting
2. **Visual Mode** (future): Form-based parameter builder

Initial implementation will use JSON Mode only.

### FR-3: Function List Display
- Show all functions in a collapsible card section
- Display function name and description summary
- Show parameter count badge
- Provide edit/delete action buttons

### FR-4: Function Call Handling in Chat
When a run enters `requires_action` status:
1. Pause the conversation
2. Display function call details (name, arguments)
3. Provide input field for mock response
4. Submit response and continue run

---

## Technical Design

### Backend Changes

#### 1. Controller Updates (`assistant_playground_controller.rb`)

```ruby
# Update assistant_params to permit functions
def assistant_params
  params.require(:assistant).permit(
    :name, :description, :instructions, :model,
    :temperature, :top_p, :response_format,
    tools: [],
    functions: [:name, :description, :strict, parameters: {}],
    metadata: {}
  )
end
```

New endpoints needed:
- `POST /submit_tool_outputs` - Submit mock function responses during a run

#### 2. Service Updates (`assistant_playground_service.rb`)

```ruby
# Update build_tools_array to include functions
def build_tools_array(tools_param, functions_param = [])
  tools = []
  tools << { type: "file_search" } if tools_param&.include?("file_search")
  tools << { type: "code_interpreter" } if tools_param&.include?("code_interpreter")

  # Add function definitions
  functions_param&.each do |func|
    tools << {
      type: "function",
      function: {
        name: func[:name],
        description: func[:description],
        strict: func[:strict] || false,
        parameters: func[:parameters] || { type: "object", properties: {} }
      }
    }
  end

  tools
end
```

New methods needed:
- `submit_tool_outputs(thread_id, run_id, tool_outputs)` - Submit function responses

#### 3. Run Status Handling

The existing `send_message` action needs to handle the `requires_action` status:

```ruby
def wait_for_completion(thread_id, run_id)
  # ... existing polling logic ...

  case run["status"]
  when "completed"
    { status: "completed", run: run }
  when "requires_action"
    # Return the required action details to frontend
    {
      status: "requires_action",
      run_id: run_id,
      thread_id: thread_id,
      tool_calls: run.dig("required_action", "submit_tool_outputs", "tool_calls")
    }
  when "failed", "cancelled", "expired"
    { status: run["status"], error: run["last_error"] }
  end
end
```

### Frontend Changes

#### 1. View Updates (`show.html.erb`)

Add new sections to the Tools card:

```erb
<!-- Functions Section -->
<div class="mt-3" data-assistant-playground-target="functionsSection">
  <div class="d-flex justify-content-between align-items-center mb-2">
    <strong><i class="bi bi-gear"></i> Functions</strong>
    <button type="button" class="btn btn-sm btn-outline-primary"
            data-action="click->assistant-playground#addFunction">
      <i class="bi bi-plus"></i> Add
    </button>
  </div>

  <!-- Function List -->
  <div data-assistant-playground-target="functionList">
    <!-- Dynamically populated -->
  </div>
</div>

<!-- Function Editor Modal -->
<div class="modal" id="functionEditorModal" data-assistant-playground-target="functionModal">
  <!-- Modal content for editing functions -->
</div>
```

#### 2. Stimulus Controller Updates (`assistant_playground_controller.js`)

New targets:
```javascript
static targets = [
  // ... existing targets ...
  "functionsSection",
  "functionList",
  "functionModal",
  "functionName",
  "functionDescription",
  "functionParameters",
  "functionStrict",
  "toolCallsContainer"
]
```

New methods:
```javascript
// Function management
addFunction() { }
editFunction(event) { }
deleteFunction(event) { }
saveFunction() { }
renderFunctionList() { }

// Function call handling
handleRequiresAction(toolCalls) { }
submitToolOutputs(toolCallId, output) { }
renderToolCallUI(toolCall) { }
```

#### 3. Function Call UI in Chat

When a function call is required, display:
```
┌─────────────────────────────────────────────┐
│ 🔧 Function Call: get_weather              │
├─────────────────────────────────────────────┤
│ Arguments:                                  │
│ {                                           │
│   "location": "San Francisco, CA",          │
│   "unit": "Celsius"                         │
│ }                                           │
├─────────────────────────────────────────────┤
│ Mock Response:                              │
│ ┌─────────────────────────────────────────┐ │
│ │ {"temperature": 18, "conditions": ...   │ │
│ └─────────────────────────────────────────┘ │
│                              [Submit]       │
└─────────────────────────────────────────────┘
```

---

## UI/UX Design

### Functions Card Section

```
┌─────────────────────────────────────────────┐
│ 🛠️ Tools                                    │
├─────────────────────────────────────────────┤
│ ☑ File Search                              │
│   Enables searching through uploaded files  │
│                                             │
│ ☑ Code Interpreter                         │
│   Enables Python code execution             │
├─────────────────────────────────────────────┤
│ ⚙️ Functions                    [+ Add]     │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ get_weather              [Edit][Delete] │ │
│ │ Get current weather for a location      │ │
│ │ 📦 2 parameters                         │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ search_products          [Edit][Delete] │ │
│ │ Search product catalog                  │ │
│ │ 📦 3 parameters                         │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Function Editor Modal

```
┌─────────────────────────────────────────────────────┐
│ Add Function                               [×]      │
├─────────────────────────────────────────────────────┤
│ Name *                                              │
│ ┌─────────────────────────────────────────────────┐ │
│ │ get_weather                                     │ │
│ └─────────────────────────────────────────────────┘ │
│                                                     │
│ Description *                                       │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Get current weather for a specific location    │ │
│ └─────────────────────────────────────────────────┘ │
│                                                     │
│ Parameters (JSON Schema)                            │
│ ┌─────────────────────────────────────────────────┐ │
│ │ {                                               │ │
│ │   "type": "object",                             │ │
│ │   "properties": {                               │ │
│ │     "location": {                               │ │
│ │       "type": "string",                         │ │
│ │       "description": "City name"                │ │
│ │     }                                           │ │
│ │   },                                            │ │
│ │   "required": ["location"]                      │ │
│ │ }                                               │ │
│ └─────────────────────────────────────────────────┘ │
│                                                     │
│ ☐ Strict mode (structured outputs)                 │
│                                                     │
│                        [Cancel]  [Save Function]    │
└─────────────────────────────────────────────────────┘
```

### Interaction Flow

```
User Action                    System Response
─────────────────────────────────────────────────────
1. Click "+ Add"           →   Open function editor modal
2. Fill in function details
3. Click "Save Function"   →   Validate & add to list
4. Save Assistant          →   Sync functions to OpenAI
5. Send message in chat    →   Assistant may call function
6. Function call detected  →   Show function call UI
7. Enter mock response
8. Click "Submit"          →   Continue conversation
```

---

## Data Model

### Function Storage

Functions are stored in the assistant's `metadata` field:

```json
{
  "instructions": "...",
  "model": "gpt-4o",
  "tools": [
    { "type": "file_search" },
    { "type": "code_interpreter" },
    { "type": "function", "function": { "name": "get_weather", ... } }
  ],
  "functions": [
    {
      "name": "get_weather",
      "description": "Get current weather for a location",
      "strict": false,
      "parameters": {
        "type": "object",
        "properties": {
          "location": { "type": "string", "description": "City name" }
        },
        "required": ["location"]
      }
    }
  ],
  "temperature": 1.0,
  "top_p": 1.0
}
```

---

## Testing Requirements

### Unit Tests (RSpec)

#### Service Tests (`spec/services/prompt_tracker/assistant_playground_service_spec.rb`)

```ruby
describe AssistantPlaygroundService do
  describe "#build_tools_array" do
    context "with functions" do
      it "includes function definitions in tools array"
      it "formats function parameters correctly"
      it "handles strict mode"
      it "handles functions without parameters"
    end
  end

  describe "#submit_tool_outputs" do
    it "submits tool outputs to OpenAI"
    it "handles multiple tool calls"
    it "raises error on API failure"
  end
end
```

#### Controller Tests (`spec/controllers/.../assistant_playground_controller_spec.rb`)

```ruby
describe AssistantPlaygroundController do
  describe "POST #create_assistant" do
    context "with functions" do
      it "creates assistant with function definitions"
      it "validates function name format"
      it "validates parameters JSON schema"
    end
  end

  describe "POST #submit_tool_outputs" do
    it "submits tool outputs and returns updated run"
    it "handles missing thread_id"
    it "handles missing run_id"
  end
end
```

### Integration Tests

```ruby
describe "Function calling flow", type: :system do
  it "allows user to add a function to an assistant"
  it "allows user to edit an existing function"
  it "allows user to delete a function"
  it "displays function call when assistant requires action"
  it "allows user to submit mock response"
  it "continues conversation after tool output submission"
end
```

### JavaScript Tests (if using Jest/Vitest)

```javascript
describe("AssistantPlaygroundController", () => {
  describe("function management", () => {
    it("adds a new function to the list")
    it("validates function name")
    it("validates JSON parameters")
    it("removes function from list on delete")
  })

  describe("function call handling", () => {
    it("renders tool call UI when requires_action")
    it("submits tool outputs correctly")
    it("handles multiple parallel function calls")
  })
})
```

---

## Implementation Plan

### Phase 1: Backend Foundation (1-2 days)
1. Update `assistant_params` to accept functions
2. Update `build_tools_array` to include function definitions
3. Add `submit_tool_outputs` method to service
4. Update `send_message` to handle `requires_action` status
5. Add controller endpoint for submitting tool outputs
6. Write unit tests

### Phase 2: Frontend - Function Management (1-2 days)
1. Add Functions section to Tools card
2. Create function editor modal
3. Implement add/edit/delete in Stimulus controller
4. Store functions in assistant data
5. Update save flow to include functions

### Phase 3: Frontend - Function Call Handling (1 day)
1. Detect `requires_action` response
2. Render function call UI in chat
3. Implement mock response submission
4. Handle conversation continuation

### Phase 4: Polish & Testing (1 day)
1. Add validation and error handling
2. Improve UX (loading states, confirmations)
3. Write integration tests
4. Manual QA testing

---

## Success Metrics

1. **Functionality**: Users can define, edit, and delete functions
2. **Reliability**: Function calls are properly handled in 100% of cases
3. **Usability**: Users can complete the flow without documentation
4. **Performance**: No noticeable lag when saving assistants with functions

---

## Out of Scope (Future Enhancements)

1. Visual parameter builder (drag-and-drop schema creation)
2. Function templates library
3. Actual function execution (webhooks)
4. Function testing sandbox
5. Import/export function definitions
6. Function versioning

---

## Dependencies

- OpenAI API: Assistants v2 with function calling support
- ruby-openai gem: Already installed, supports function calling
- Bootstrap: For modal and UI components
- Stimulus: For frontend interactivity

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Complex JSON Schema validation | Medium | Start with basic validation, iterate |
| Run timeout during function calls | High | Add timeout handling and user feedback |
| Large function definitions | Low | Add character limits and warnings |
| OpenAI API changes | Medium | Abstract API calls behind service layer |
