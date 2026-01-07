# PRD: Playground Response API Support

## Overview

This document describes how the existing PromptVersion Playground will support the OpenAI Response API provider. The playground enables interactive prompt testing and iteration, and will now support Response API-specific features including multi-turn conversations and built-in tools.

**Key Decision**: Rather than creating a separate playground, we will extend the existing playground with mode-aware UI that adapts based on the provider. This leverages significant component reuse from the Assistant Playground.

## Background

### Current State

**PromptVersion Playground (`PlaygroundController`)** provides:
- Prompt template rendering with variables (Liquid/Mustache)
- Single-turn preview execution
- Template editing with live preview
- Response saving to `LlmResponse`

```ruby
# Current flow
PlaygroundController#show → Template editor + preview
PlaygroundController#preview → Renders template with variables
PlaygroundController#save → Saves version/creates prompt
```

**Assistant Playground (`AssistantPlaygroundController`)** provides:
- Full multi-turn conversation UI
- Thread-based state management via OpenAI Threads API
- Function editor with modal UI
- File upload + vector store management
- Tool checkboxes (file_search, code_interpreter)
- Real-time message rendering with typing indicators

### Shared Components Analysis

| Component | Assistant Playground | Response API Needs | Reusable? |
|-----------|---------------------|-------------------|-----------|
| **Conversation UI** | Thread-based chat messages | Session-based chat messages | ✅ Extract shared partial |
| **Message Rendering** | CSS + JS for user/assistant | Same styling | ✅ Reuse directly |
| **Function Editor** | Modal for function definitions | Same function format | ✅ Extract as component |
| **File Management** | Vector stores + uploads | file_search tool support | ✅ Reuse partial |
| **Tool Selection** | file_search, code_interpreter | + web_search | ✅ Extend existing |
| **Typing Indicator** | CSS animation | Same UX | ✅ Reuse directly |
| **Tool Output Display** | Shows function calls | + web_search, code_interpreter | ✅ Extract & extend |

### Problem Statement

When a PromptVersion uses `provider: "openai_responses"`, the playground should:
1. Use the Response API instead of Chat Completions
2. Support multi-turn conversations within a session
3. Enable Response API tools (web_search, file_search, code_interpreter)
4. Maintain conversation state via `previous_response_id`
5. **Reuse existing Assistant Playground components** to avoid duplication

### Goals

1. Seamless provider detection - playground auto-selects API based on `model_config`
2. Interactive multi-turn conversations in the playground
3. Tool execution visibility (show when web_search was used, etc.)
4. Maintain existing UX patterns for Chat Completions provider
5. **Maximize component reuse** from Assistant Playground (target: 70%+ shared code)
6. **Single unified codebase** for prompt playground regardless of provider

## Architecture Decision

### Option A: Separate Playgrounds ❌ (Rejected)

Create a dedicated `ResponseApiPlaygroundController` with its own views.

**Pros:**
- Clean separation of concerns
- No conditional logic in views

**Cons:**
- Duplicates 70%+ of UI code
- Double maintenance burden
- Inconsistent UX evolution

### Option B: Unified Playground with Mode Detection ✅ (Chosen)

Extend the existing `PlaygroundController` with provider-aware behavior and shared components.

**Pros:**
- DRY: Single codebase for all providers
- Consistent UX across providers
- Easier maintenance
- Progressive enhancement (simple → complex)

**Cons:**
- Slightly more complex controller logic
- Conditional rendering in some views

### Rationale

The Assistant Playground already implements the exact conversation UI, function editing, and file management we need. Rather than rebuilding, we extract shared components and adapt the Prompt Playground to use them when Response API is selected.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SHARED COMPONENT LIBRARY                         │
├─────────────────────────────────────────────────────────────────────┤
│ _conversation_messages.html.erb  (extracted from assistant)        │
│ _tool_output_display.html.erb    (new, shared)                      │
│ _function_editor.html.erb        (extracted from assistant)        │
│ _file_management.html.erb        (reuse from assistant)            │
│ conversation_controller.js       (extracted from assistant)         │
│ function_editor_controller.js    (already exists, reuse)           │
│ file_management_controller.js    (already exists, reuse)           │
│ assistant_playground.css         (reuse message styles)            │
└─────────────────────────────────────────────────────────────────────┘
           ↓                                    ↓
┌─────────────────────────┐      ┌─────────────────────────────────┐
│  Assistant Playground   │      │  Prompt Version Playground      │
│  (full assistant mgmt)  │      │  (template + provider modes)    │
├─────────────────────────┤      ├─────────────────────────────────┤
│ - Create/edit assistant │      │ Chat Completions Mode:          │
│ - Thread management     │      │ - Single response preview       │
│ - Full tool config      │      │ - No conversation state         │
│                         │      │                                 │
│                         │      │ Response API Mode:              │
│                         │      │ - Conversation UI (shared)      │
│                         │      │ - Tool selection panel          │
│                         │      │ - Session-based state           │
└─────────────────────────┘      └─────────────────────────────────┘
```

## Technical Design

### Mode Detection & UI Adaptation

The playground UI adapts based on `model_config.provider`:

| Provider | Conversation UI | Tools Panel | State Management |
|----------|----------------|-------------|------------------|
| `openai` (default) | Hidden | Hidden | None (stateless) |
| `openai_responses` | Shown | Shown | Session-based |
| `anthropic` | Hidden | Hidden | None (stateless) |

```ruby
# app/helpers/playground_helper.rb
module PlaygroundHelper
  def response_api_provider?
    @version&.model_config&.dig("provider") == "openai_responses"
  end

  def supports_conversation?
    response_api_provider?
  end

  def available_tools_for_provider
    return [] unless response_api_provider?
    %w[web_search file_search code_interpreter]
  end
end
```

### Provider Detection

```ruby
# app/controllers/prompt_tracker/testing/playground_controller.rb
class PlaygroundController < ApplicationController
  def execute
    case provider
    when "openai_responses"
      execute_response_api
    when "openai_assistants"
      execute_assistant_api
    else
      execute_chat_completion
    end
  end

  private

  def provider
    @version.model_config&.dig("provider") || "openai"
  end

  def execute_response_api
    # Use session or params to track conversation state
    previous_response_id = session[:playground_response_id]

    result = if previous_response_id && continuing_conversation?
      OpenaiResponseService.call_with_context(
        model: model_config[:model],
        user_prompt: rendered_prompt,
        previous_response_id: previous_response_id,
        tools: model_config[:tools] || []
      )
    else
      OpenaiResponseService.call(
        model: model_config[:model],
        system_prompt: rendered_system_prompt,
        user_prompt: rendered_prompt,
        tools: model_config[:tools] || []
      )
    end

    # Store for next turn
    session[:playground_response_id] = result[:response_id]
    session[:playground_messages] ||= []
    session[:playground_messages] << { role: "user", content: rendered_prompt }
    session[:playground_messages] << { role: "assistant", content: result[:text] }

    render_response(result)
  end
end
```

### Conversation State Management

**Session-based state for playground:**

```ruby
# Stored in session per version
session[:playground_state] = {
  version_id: @version.id,
  response_id: "resp_abc123",        # For continuing conversation
  messages: [                         # For display
    { role: "user", content: "Hello" },
    { role: "assistant", content: "Hi there!" }
  ],
  tools_used: ["web_search"]          # Track tool usage
}
```

**API endpoints:**

| Endpoint | Purpose |
|----------|---------|
| `POST /playground/:id/execute` | Send message (new or continuing) |
| `POST /playground/:id/reset` | Clear conversation state |
| `GET /playground/:id/conversation` | Get current conversation history |

### Frontend Conversation UI

The playground will show a conversation interface when using Response API. The UI adapts based on provider:

**Chat Completions Mode (default):**
```
┌─────────────────────────────────────────────────────────────────────┐
│ Playground - Customer Support v3                  [Chat Completions] │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌─────────────────────────────────────┐   │
│  │ Template Editors    │  │ Preview / Response                  │   │
│  │ (system + user)     │  │ Single response display             │   │
│  │ + Variables         │  │ [Generate] [Save]                   │   │
│  └─────────────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

**Response API Mode:**
```
┌─────────────────────────────────────────────────────────────────────┐
│ Playground - Customer Support v3                    [Response API]  │
│ Tools: [✓ web_search] [✓ file_search] [○ code_interpreter]         │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌─────────────────────────────────────┐   │
│  │ Template Editors    │  │ Conversation             [🔄 Reset] │   │
│  │ ─────────────────── │  │ ─────────────────────────────────── │   │
│  │ System Prompt       │  │  👤 You: What's your return policy? │   │
│  │ ┌─────────────────┐ │  │                                     │   │
│  │ │ You are...      │ │  │  🤖 Assistant: Our return policy... │   │
│  │ └─────────────────┘ │  │     [🔍 web_search used]            │   │
│  │                     │  │                                     │   │
│  │ User Prompt         │  │  👤 You: What about receipts?       │   │
│  │ ┌─────────────────┐ │  │                                     │   │
│  │ │ {{question}}    │ │  │  🤖 Assistant: Without a receipt... │   │
│  │ └─────────────────┘ │  │                                     │   │
│  │                     │  ├─────────────────────────────────────┤   │
│  │ Variables           │  │ ┌─────────────────────────────────┐ │   │
│  │ question: [_______] │  │ │ Next message...                 │ │   │
│  │                     │  │ └─────────────────────────────────┘ │   │
│  │ [⚙️ Functions (2)]  │  │ [Send] [Save Conversation]          │   │
│  │ [📁 Manage Files]   │  │                                     │   │
│  └─────────────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Shared Components (Extracted from Assistant Playground)

These components are extracted/reused from the existing Assistant Playground:

| Component | Source | New Location |
|-----------|--------|--------------|
| Message rendering CSS | `assistant_playground.css` | `shared/conversation.css` |
| Message JS (add, scroll, typing) | `assistant_playground_controller.js` | `conversation_controller.js` |
| Function editor modal | `assistant_playground/show.html.erb` | `shared/_function_editor.html.erb` |
| Function editor JS | `function_editor_controller.js` | Reuse directly |
| File management partial | `assistant_playground/_file_management.html.erb` | Reuse directly |
| File management JS | `file_management_controller.js` | Reuse directly |

```erb
<%# app/views/prompt_tracker/shared/_conversation_messages.html.erb %>
<%# Shared between Assistant Playground and Prompt Playground (Response API mode) %>

<div class="messages-container" data-conversation-target="messagesContainer">
  <% messages.each do |message| %>
    <div class="message <%= message[:role] %>-message">
      <div class="message-avatar">
        <i class="bi bi-<%= message[:role] == 'user' ? 'person' : 'robot' %>"></i>
      </div>
      <div class="message-content">
        <div class="message-text"><%= message[:content] %></div>
        <% if message[:tools_used]&.any? %>
          <%= render "prompt_tracker/shared/tool_output_display", tools: message[:tools_used] %>
        <% end %>
        <div class="message-meta">
          <small class="text-muted"><%= message[:timestamp] %></small>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

### Tool Usage Display

When Response API tools are used, show inline indicators (shared partial):

```erb
<%# app/views/prompt_tracker/shared/_tool_output_display.html.erb %>

<div class="tools-used mt-2">
  <% tools.each do |tool| %>
    <div class="tool-badge d-inline-flex align-items-center gap-1 px-2 py-1 rounded bg-light">
      <% case tool[:type] %>
      <% when "web_search" %>
        <i class="bi bi-globe"></i>
        <span>web_search</span>
        <% if tool[:query] %>
          <small class="text-muted">- "<%= tool[:query].truncate(30) %>"</small>
        <% end %>
      <% when "file_search" %>
        <i class="bi bi-file-earmark-search"></i>
        <span>file_search</span>
      <% when "code_interpreter" %>
        <i class="bi bi-code-slash"></i>
        <span>code_interpreter</span>
      <% when "function" %>
        <i class="bi bi-gear"></i>
        <span><%= tool[:name] %></span>
      <% end %>
    </div>
  <% end %>
</div>
```

### Response API Tools Configuration

The tools panel appears only when Response API provider is selected:

```erb
<%# app/views/prompt_tracker/testing/playground/_response_api_tools.html.erb %>

<% if response_api_provider? %>
  <div class="card mb-3">
    <div class="card-header">
      <i class="bi bi-tools"></i> Response API Tools
    </div>
    <div class="card-body">
      <% available_tools_for_provider.each do |tool| %>
        <div class="form-check mb-2">
          <input class="form-check-input" type="checkbox"
                 id="tool_<%= tool %>" value="<%= tool %>"
                 data-playground-target="toolCheckbox"
                 <%= 'checked' if enabled_tools.include?(tool) %>>
          <label class="form-check-label" for="tool_<%= tool %>">
            <%= tool_icon(tool) %> <strong><%= tool.humanize %></strong>
          </label>
        </div>
      <% end %>

      <hr class="my-3">

      <%# Reuse function editor from assistant playground %>
      <%= render "prompt_tracker/shared/function_editor",
                 functions: @version.model_config&.dig("functions") || [] %>

      <% if enabled_tools.include?("file_search") %>
        <hr class="my-3">
        <%# Reuse file management from assistant playground %>
        <%= render "prompt_tracker/testing/openai/assistant_playground/file_management",
                   vector_store_ids: @version.model_config&.dig("vector_store_ids") || [] %>
      <% end %>
    </div>
  </div>
<% end %>
```

## Controller Changes

### Updated PlaygroundController

```ruby
# app/controllers/prompt_tracker/testing/playground_controller.rb
module PromptTracker
  module Testing
    class PlaygroundController < ApplicationController
      before_action :set_version
      before_action :init_conversation_state, only: [:show]

      def show
        # Existing - render playground view
      end

      def execute
        @response = case provider
        when "openai_responses"
          execute_response_api
        else
          execute_standard
        end

        respond_to do |format|
          format.turbo_stream
          format.json { render json: @response }
        end
      end

      def reset_conversation
        clear_conversation_state
        redirect_to playground_path(@version), notice: "Conversation reset"
      end

      def save_conversation
        # Save entire conversation to LlmResponse
        llm_response = create_conversation_response
        redirect_to llm_response_path(llm_response), notice: "Conversation saved"
      end

      private

      def provider
        @version.model_config&.dig("provider") || "openai"
      end

      def response_api?
        provider == "openai_responses"
      end

      def conversation_state
        @conversation_state ||= session[:playground_conversations]&.dig(@version.id.to_s) || {
          "response_id" => nil,
          "messages" => [],
          "tools_used" => []
        }
      end

      def update_conversation_state(response)
        state = conversation_state
        state["response_id"] = response[:response_id]
        state["messages"] << { "role" => "user", "content" => rendered_prompt }
        state["messages"] << { "role" => "assistant", "content" => response[:text] }
        state["tools_used"].concat(response[:tools_used] || [])

        session[:playground_conversations] ||= {}
        session[:playground_conversations][@version.id.to_s] = state
      end

      def clear_conversation_state
        session[:playground_conversations]&.delete(@version.id.to_s)
      end

      def execute_response_api
        previous_response_id = conversation_state["response_id"]

        result = if previous_response_id
          OpenaiResponseService.call_with_context(
            model: model_from_config,
            user_prompt: rendered_prompt,
            previous_response_id: previous_response_id,
            tools: tools_from_config
          )
        else
          OpenaiResponseService.call(
            model: model_from_config,
            system_prompt: rendered_system_prompt,
            user_prompt: rendered_prompt,
            tools: tools_from_config,
            temperature: temperature_from_config
          )
        end

        update_conversation_state(result)
        result
      end
    end
  end
end
```

## View Changes

### Unified Playground View with Mode Detection

The main playground view conditionally renders based on provider:

```erb
<%# app/views/prompt_tracker/testing/playground/show.html.erb (updated) %>

<div class="container-fluid mt-4"
     data-controller="playground <%= 'conversation' if response_api_provider? %>"
     data-playground-provider-value="<%= provider %>">

  <%# Header with provider badge %>
  <div class="row mb-3">
    <div class="col">
      <h1>
        <i class="bi bi-play-circle"></i>
        Playground: <%= @prompt&.name || "New Prompt" %>
        <span class="badge <%= response_api_provider? ? 'bg-success' : 'bg-primary' %>">
          <%= response_api_provider? ? 'Response API' : 'Chat Completions' %>
        </span>
      </h1>
    </div>
  </div>

  <%# Tools bar (Response API only) %>
  <% if response_api_provider? %>
    <%= render "response_api_tools_bar", tools: enabled_tools %>
  <% end %>

  <div class="row">
    <%# Left: Template editors (always shown) %>
    <div class="col-lg-6">
      <%= render "template_editors" %>
      <%= render "variable_inputs" %>

      <% if response_api_provider? %>
        <%= render "prompt_tracker/testing/playground/response_api_tools" %>
      <% end %>
    </div>

    <%# Right: Output panel (adapts to mode) %>
    <div class="col-lg-6">
      <% if response_api_provider? %>
        <%# Conversation mode - uses shared component %>
        <%= render "prompt_tracker/shared/conversation_panel",
                   messages: conversation_state["messages"],
                   can_reset: conversation_state["messages"].any? %>
      <% else %>
        <%# Single response mode %>
        <%= render "single_response_panel" %>
      <% end %>
    </div>
  </div>
</div>
```

### Shared Conversation Panel (Extracted from Assistant Playground)

```erb
<%# app/views/prompt_tracker/shared/_conversation_panel.html.erb %>
<%# Shared between Assistant Playground and Prompt Playground (Response API mode) %>

<div class="card h-100" data-controller="conversation">
  <div class="card-header d-flex justify-content-between align-items-center">
    <h5 class="mb-0"><i class="bi bi-chat-dots"></i> Conversation</h5>
    <% if can_reset %>
      <button class="btn btn-sm btn-outline-secondary"
              data-action="conversation#reset">
        <i class="bi bi-arrow-clockwise"></i> Reset
      </button>
    <% end %>
  </div>

  <div class="card-body p-0 d-flex flex-column" style="height: 500px;">
    <%# Messages container - reuses assistant playground styles %>
    <div class="messages-container flex-grow-1 overflow-auto p-3"
         data-conversation-target="messagesContainer">
      <% if messages.empty? %>
        <div class="text-center text-muted py-5">
          <i class="bi bi-chat-left-text" style="font-size: 3rem;"></i>
          <p class="mt-3">Send a message to start the conversation</p>
        </div>
      <% else %>
        <%= render "prompt_tracker/shared/conversation_messages", messages: messages %>
      <% end %>

      <%# Typing indicator (hidden by default) %>
      <div class="message assistant-message loading" style="display: none;"
           data-conversation-target="typingIndicator">
        <div class="message-avatar"><i class="bi bi-robot"></i></div>
        <div class="message-content">
          <div class="typing-indicator"><span></span><span></span><span></span></div>
        </div>
      </div>
    </div>

    <%# Message input %>
    <div class="border-top p-3">
      <form data-action="conversation#submit">
        <div class="input-group">
          <textarea class="form-control" rows="2"
                    placeholder="Type your message..."
                    data-conversation-target="messageInput"
                    required></textarea>
          <button type="submit" class="btn btn-primary"
                  data-conversation-target="sendButton">
            <i class="bi bi-send"></i> Send
          </button>
        </div>
        <small class="text-muted">Press Enter to send, Shift+Enter for new line</small>
      </form>
    </div>
  </div>
</div>
```

## Stimulus Controller (Shared)

The conversation controller is extracted from `assistant_playground_controller.js` for reuse:

```javascript
// app/javascript/prompt_tracker/controllers/conversation_controller.js
// Shared controller for conversation UI (used by both Assistant and Prompt Playground)

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messagesContainer", "messageInput", "sendButton", "typingIndicator"]

  static values = {
    sendUrl: String,
    resetUrl: String
  }

  connect() {
    this.scrollToBottom()
    this.setupKeyboardShortcuts()
  }

  setupKeyboardShortcuts() {
    this.messageInputTarget.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.submit(e)
      }
    })
  }

  async submit(event) {
    event.preventDefault()

    const content = this.messageInputTarget.value.trim()
    if (!content) return

    // Disable input during submission
    this.messageInputTarget.disabled = true
    this.sendButtonTarget.disabled = true

    // Add user message to UI immediately
    this.addMessage("user", content)
    this.messageInputTarget.value = ""

    // Show typing indicator
    this.showTypingIndicator()

    try {
      const response = await fetch(this.sendUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCsrfToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({ content })
      })

      const data = await response.json()

      if (data.success) {
        this.addMessage("assistant", data.text, data.tools_used)
      } else {
        this.addErrorMessage(data.error)
      }
    } catch (error) {
      this.addErrorMessage("Failed to send message")
    } finally {
      this.hideTypingIndicator()
      this.messageInputTarget.disabled = false
      this.sendButtonTarget.disabled = false
      this.messageInputTarget.focus()
      this.scrollToBottom()
    }
  }

  addMessage(role, content, toolsUsed = []) {
    const messageHtml = this.buildMessageHtml(role, content, toolsUsed)
    this.messagesContainerTarget.insertAdjacentHTML("beforeend", messageHtml)
    this.scrollToBottom()
  }

  buildMessageHtml(role, content, toolsUsed) {
    const icon = role === "user" ? "person" : "robot"
    const toolsHtml = toolsUsed.length > 0
      ? `<div class="tools-used mt-2">${toolsUsed.map(t => `<span class="tool-badge">${t}</span>`).join("")}</div>`
      : ""

    return `
      <div class="message ${role}-message fade-in">
        <div class="message-avatar"><i class="bi bi-${icon}"></i></div>
        <div class="message-content">
          <div class="message-text">${this.escapeHtml(content)}</div>
          ${toolsHtml}
          <div class="message-meta">
            <small class="text-muted">${new Date().toLocaleTimeString()}</small>
          </div>
        </div>
      </div>
    `
  }

  showTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.style.display = "flex"
    }
  }

  hideTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.style.display = "none"
    }
  }

  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  async reset() {
    if (!confirm("Reset conversation? This cannot be undone.")) return

    await fetch(this.resetUrlValue, { method: "POST", headers: { "X-CSRF-Token": this.getCsrfToken() } })
    this.messagesContainerTarget.innerHTML = `
      <div class="text-center text-muted py-5">
        <i class="bi bi-chat-left-text" style="font-size: 3rem;"></i>
        <p class="mt-3">Send a message to start the conversation</p>
      </div>
    `
  }

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

## Testing Strategy

### Controller Tests

```ruby
# spec/controllers/prompt_tracker/testing/playground_controller_spec.rb
RSpec.describe PromptTracker::Testing::PlaygroundController do
  describe "POST #execute" do
    context "with openai_responses provider" do
      let(:version) { create(:prompt_version, model_config: { "provider" => "openai_responses" }) }

      it "calls OpenaiResponseService" do
        expect(OpenaiResponseService).to receive(:call)
        post :execute, params: { id: version.id, variables: { question: "Hello" } }
      end

      it "stores response_id in session for continuity" do
        allow(OpenaiResponseService).to receive(:call).and_return(
          { text: "Hi!", response_id: "resp_123", tools_used: [] }
        )

        post :execute, params: { id: version.id }

        expect(session[:playground_conversations][version.id.to_s]["response_id"]).to eq("resp_123")
      end

      it "continues conversation with previous_response_id" do
        session[:playground_conversations] = {
          version.id.to_s => { "response_id" => "resp_123", "messages" => [] }
        }

        expect(OpenaiResponseService).to receive(:call_with_context).with(
          hash_including(previous_response_id: "resp_123")
        )

        post :execute, params: { id: version.id }
      end
    end
  end

  describe "POST #reset_conversation" do
    it "clears conversation state from session" do
      session[:playground_conversations] = { version.id.to_s => { "response_id" => "resp_123" } }

      post :reset_conversation, params: { id: version.id }

      expect(session[:playground_conversations][version.id.to_s]).to be_nil
    end
  end
end
```

### System Tests

```ruby
# spec/system/playground_response_api_spec.rb
RSpec.describe "Playground with Response API", type: :system do
  let(:version) { create(:prompt_version, model_config: { "provider" => "openai_responses", "model" => "gpt-4o" }) }

  it "shows conversation UI for Response API provider" do
    visit playground_path(version)

    expect(page).to have_content("Response API")
    expect(page).to have_button("Send Message")
  end

  it "maintains conversation across messages" do
    visit playground_path(version)

    fill_in "question", with: "What is 2+2?"
    click_button "Send Message"

    expect(page).to have_content("👤 You: What is 2+2?")
    expect(page).to have_content("🤖 Assistant:")

    fill_in "question", with: "And 3+3?"
    click_button "Send Message"

    # Should show both turns
    expect(page).to have_content("What is 2+2?")
    expect(page).to have_content("And 3+3?")
  end

  it "resets conversation when clicking Reset" do
    # ... setup conversation ...

    click_button "Reset"

    expect(page).not_to have_css(".message")
  end
end
```

## Rollout Plan

### Phase 1: Shared Component Extraction (Week 1)

**Goal:** Extract reusable components from Assistant Playground

1. **Extract shared partials:**
   - `app/views/prompt_tracker/shared/_conversation_messages.html.erb`
   - `app/views/prompt_tracker/shared/_conversation_panel.html.erb`
   - `app/views/prompt_tracker/shared/_tool_output_display.html.erb`
   - `app/views/prompt_tracker/shared/_function_editor.html.erb`

2. **Extract shared Stimulus controller:**
   - `app/javascript/prompt_tracker/controllers/conversation_controller.js`
   - Update `assistant_playground_controller.js` to use shared controller

3. **Extract shared CSS:**
   - `app/assets/stylesheets/prompt_tracker/shared/conversation.css`

4. **Update Assistant Playground:**
   - Refactor to use extracted shared components
   - Verify no regressions

### Phase 2: Backend Integration (Week 2)

**Goal:** Add Response API support to PlaygroundController

1. **Add helper methods:**
   - `PlaygroundHelper#response_api_provider?`
   - `PlaygroundHelper#supports_conversation?`
   - `PlaygroundHelper#available_tools_for_provider`

2. **Add controller actions:**
   - `PlaygroundController#execute` (send message)
   - `PlaygroundController#reset_conversation`
   - `PlaygroundController#save_conversation`

3. **Implement session state management:**
   - Conversation state per version
   - Response ID tracking for continuity

4. **Add routes:**
   - `POST /playground/:id/execute`
   - `POST /playground/:id/reset`
   - `POST /playground/:id/save_conversation`

### Phase 3: Frontend Integration (Week 3)

**Goal:** Update Playground UI with mode detection

1. **Update playground view:**
   - Add provider badge
   - Conditionally render conversation panel vs single response
   - Add tools panel for Response API mode

2. **Create Response API-specific partials:**
   - `_response_api_tools.html.erb`
   - `_response_api_tools_bar.html.erb`

3. **Wire up Stimulus controllers:**
   - Connect `conversation` controller when in Response API mode
   - Connect `function-editor` controller for function management

4. **Add tool management:**
   - Tool checkboxes UI
   - File management integration (reuse from assistant)

### Phase 4: Polish & Testing (Week 4)

1. **Streaming support** (optional)
2. **Error handling and retry UI**
3. **Comprehensive tests:**
   - Controller specs for mode detection
   - System tests for conversation flow
   - Shared component specs

## Implementation Checklist

### Files to Create

- [ ] `app/views/prompt_tracker/shared/_conversation_messages.html.erb`
- [ ] `app/views/prompt_tracker/shared/_conversation_panel.html.erb`
- [ ] `app/views/prompt_tracker/shared/_tool_output_display.html.erb`
- [ ] `app/views/prompt_tracker/shared/_function_editor.html.erb`
- [ ] `app/views/prompt_tracker/testing/playground/_response_api_tools.html.erb`
- [ ] `app/javascript/prompt_tracker/controllers/conversation_controller.js`
- [ ] `app/assets/stylesheets/prompt_tracker/shared/conversation.css`
- [ ] `app/helpers/playground_helper.rb`

### Files to Modify

- [ ] `app/controllers/prompt_tracker/testing/playground_controller.rb` - Add execute, reset, save actions
- [ ] `app/views/prompt_tracker/testing/playground/show.html.erb` - Add mode detection
- [ ] `app/javascript/prompt_tracker/controllers/playground_controller.js` - Add conversation support
- [ ] `config/routes.rb` - Add new routes
- [ ] `app/views/prompt_tracker/testing/openai/assistant_playground/show.html.erb` - Use shared components

## Success Metrics

| Metric | Target |
|--------|--------|
| Playground Response API calls working | 100% |
| Conversation continuity working | 100% |
| User session state maintained | No data loss |
| Shared component coverage | 70%+ code reuse |
| Assistant Playground still works | No regressions |

## Dependencies

- **PRD-01**: `OpenaiResponseService` (must be complete)
- **PRD-02**: Test runner Response API support (informs patterns)
- Existing: `PlaygroundController` structure
- Existing: `AssistantPlaygroundController` (source for extraction)
- Existing: Turbo/Stimulus for frontend

## Open Questions

1. **Session size limits**: Long conversations may exceed session storage.
   - **Recommendation**: Limit to 20 messages in playground; use database for saved conversations

2. **Concurrent sessions**: What if user opens playground in multiple tabs?
   - **Recommendation**: Session-based state per tab via unique playground session ID

3. **Streaming**: Should we support streaming responses in playground?
   - **Recommendation**: Phase 2 - add optional streaming toggle

4. **Function execution**: Should playground support executing user-defined functions?
   - **Recommendation**: Display function calls but don't execute (like Assistant Playground)

## References

- PRD-01: OpenAI Response API Service Integration
- PRD-02: Test Runner Response API Support
- `app/controllers/prompt_tracker/testing/playground_controller.rb`
- `app/controllers/prompt_tracker/testing/openai/assistant_playground_controller.rb`
- `app/javascript/prompt_tracker/controllers/assistant_playground_controller.js`
- `app/assets/stylesheets/prompt_tracker/assistant_playground.css`
