# Evaluator Hierarchy Refactoring Plan

## Overview

Refactor the evaluator hierarchy from **testable-based** to **API-based**. Each OpenAI API has different capabilities and data structures, so evaluators should be organized by the API they work with.

## Current State

### Current Hierarchy
```
BaseEvaluator (abstract)
  ├─ BasePromptVersionEvaluator (accepts response_text: String)
  │    ├─ ExactMatchEvaluator
  │    ├─ FormatEvaluator
  │    ├─ KeywordEvaluator
  │    ├─ LengthEvaluator
  │    ├─ LlmJudgeEvaluator
  │    └─ PatternMatchEvaluator
  │
  └─ BaseOpenaiAssistantEvaluator (accepts conversation_data: Hash)
       ├─ ConversationJudgeEvaluator
       ├─ FileSearchEvaluator
       └─ FunctionCallEvaluator
```

### Current Problems
1. Evaluators are tied to testable type, not API/test mode
2. PromptVersions running conversational tests can't use conversation evaluators
3. Naming doesn't reflect the actual API being used

## API Comparison

| API | Data Structure | Use Case | Unique Features |
|-----|----------------|----------|-----------------|
| **Chat Completions** | `response_text: String` | Single-turn tests | Simple request/response |
| **Response API** | `conversation_data: Hash` | Conversational PromptVersion tests | Multi-turn, tool_calls |
| **Assistants API** | `conversation_data: Hash` | Assistant tests | run_steps, file_search, threads |

## Proposed State

### New Hierarchy (API-Based with Nesting)
```
BaseEvaluator (abstract)
  │
  ├─ BaseChatCompletionEvaluator (response_text: String)
  │    │  Used for: single-turn tests (any testable)
  │    │
  │    ├─ ExactMatchEvaluator
  │    ├─ FormatEvaluator
  │    ├─ KeywordEvaluator
  │    ├─ LengthEvaluator
  │    ├─ LlmJudgeEvaluator
  │    └─ PatternMatchEvaluator
  │
  └─ BaseConversationalEvaluator (conversation_data: Hash)
       │  Used for: conversational tests (Response API or Assistants API)
       │
       ├─ ConversationJudgeEvaluator  ─┐
       ├─ FunctionCallEvaluator       ─┴─ Work with BOTH Response API and Assistants API
       │
       └─ BaseAssistantsApiEvaluator (extends BaseConversationalEvaluator)
            │  Used for: Assistants only (requires run_steps, threads, etc.)
            │
            └─ FileSearchEvaluator  ─── Only works with Assistants API
```

### Key Design Decisions

1. **Three-level hierarchy**: BaseEvaluator → API-specific base → Concrete evaluator
2. **Nested conversational classes**: `BaseAssistantsApiEvaluator < BaseConversationalEvaluator`
3. **Inheritance determines compatibility**: No need for separate `compatible_modes` method
4. **Response API evaluators work with Assistants**: Since Assistants API is a superset

---

## File Changes Required

### 1. Rename/Create Base Evaluator Classes

#### `app/services/prompt_tracker/evaluators/base_prompt_version_evaluator.rb`
- **Rename file to:** `base_chat_completion_evaluator.rb`
- **Rename class to:** `BaseChatCompletionEvaluator`
- Works with Chat Completions API (single-turn)
- Accepts `response_text: String`

#### `app/services/prompt_tracker/evaluators/base_openai_assistant_evaluator.rb`
- **Rename file to:** `base_conversational_evaluator.rb`
- **Rename class to:** `BaseConversationalEvaluator`
- Works with Response API AND Assistants API
- Accepts `conversation_data: Hash`

#### NEW: `app/services/prompt_tracker/evaluators/base_assistants_api_evaluator.rb`
- **Create new file**
- **Class:** `BaseAssistantsApiEvaluator < BaseConversationalEvaluator`
- Works with Assistants API only (requires run_steps)
- Inherits `conversation_data` handling from parent

### 2. Update All Chat Completion Evaluators

Update parent class in these files:
- `exact_match_evaluator.rb` - change `< BasePromptVersionEvaluator` to `< BaseChatCompletionEvaluator`
- `format_evaluator.rb` - same change
- `keyword_evaluator.rb` - same change
- `length_evaluator.rb` - same change
- `llm_judge_evaluator.rb` - same change
- `pattern_match_evaluator.rb` - same change

### 3. Update Conversational Evaluators

Update parent class in these files:
- `conversation_judge_evaluator.rb` - change `< BaseOpenaiAssistantEvaluator` to `< BaseConversationalEvaluator`
- `function_call_evaluator.rb` - same change

### 4. Update Assistants-Only Evaluators

Update parent class:
- `file_search_evaluator.rb` - change `< BaseOpenaiAssistantEvaluator` to `< BaseAssistantsApiEvaluator`

### 5. Update BaseEvaluator

**File:** `app/services/prompt_tracker/evaluators/base_evaluator.rb`

Remove testable-based compatibility, add API-type method:

```ruby
# Remove these methods:
# - compatible_with
# - compatible_with?

# Add this method (optional, for introspection):
def self.api_type
  raise NotImplementedError, "Subclasses must implement .api_type"
end
# Returns: :chat_completion, :conversational, or :assistants_api
```

### 6. Update EvaluatorRegistry

**File:** `app/services/prompt_tracker/evaluator_registry.rb`

```ruby
# OLD
def for_testable(testable)
  all.select { |_key, meta| meta[:evaluator_class].compatible_with?(testable) }
end

# NEW - Filter by test mode and testable type
def for_test(test)
  test_mode = test.test_mode || "single_turn"
  testable = test.testable

  all.select do |_key, meta|
    klass = meta[:evaluator_class]

    if test_mode == "single_turn"
      # Only Chat Completion evaluators
      klass < BaseChatCompletionEvaluator
    elsif testable.is_a?(PromptTracker::Openai::Assistant)
      # All conversational evaluators (including Assistants-specific)
      klass < BaseConversationalEvaluator
    else
      # Response API: conversational but NOT Assistants-specific
      klass < BaseConversationalEvaluator && !(klass < BaseAssistantsApiEvaluator)
    end
  end
end

# Simpler mode-only filter for UI (before test is saved)
def for_mode(test_mode, testable: nil)
  all.select do |_key, meta|
    klass = meta[:evaluator_class]

    if test_mode.to_s == "single_turn"
      klass < BaseChatCompletionEvaluator
    elsif testable&.is_a?(PromptTracker::Openai::Assistant)
      klass < BaseConversationalEvaluator
    elsif testable.present?
      # PromptVersion in conversational mode - exclude Assistants-only
      klass < BaseConversationalEvaluator && !(klass < BaseAssistantsApiEvaluator)
    else
      # No testable specified - show all conversational
      klass < BaseConversationalEvaluator
    end
  end
end
```

---

## New Base Class Implementations

### BaseChatCompletionEvaluator

```ruby
# app/services/prompt_tracker/evaluators/base_chat_completion_evaluator.rb
# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Base class for evaluators that work with Chat Completions API responses.
    # These evaluators receive response_text (String) and evaluate single-turn responses.
    #
    # Used for: single_turn test mode on any testable
    #
    class BaseChatCompletionEvaluator < BaseEvaluator
      attr_reader :response_text

      def self.api_type
        :chat_completion
      end

      def initialize(response_text, config = {})
        @response_text = response_text
        super(config)
      end

      def evaluate
        score = evaluate_score
        feedback_text = generate_feedback

        Evaluation.create!(
          llm_response: config[:llm_response],
          test_run: config[:test_run],
          evaluator_type: self.class.name,
          evaluator_config_id: config[:evaluator_config_id],
          score: score,
          score_min: 0,
          score_max: 100,
          passed: passed?,
          feedback: feedback_text,
          metadata: metadata,
          evaluation_context: config[:evaluation_context] || "tracked_call"
        )
      end
    end
  end
end
```

### BaseConversationalEvaluator

```ruby
# app/services/prompt_tracker/evaluators/base_conversational_evaluator.rb
# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Base class for evaluators that work with conversational data.
    # Works with both Response API and Assistants API conversations.
    #
    # Used for: conversational test mode
    #
    class BaseConversationalEvaluator < BaseEvaluator
      attr_reader :conversation_data

      def self.api_type
        :conversational
      end

      def initialize(conversation_data, config = {})
        @conversation_data = conversation_data || {}
        super(config)
      end

      # Helper: Get messages from conversation
      def messages
        @messages ||= conversation_data["messages"] || conversation_data[:messages] || []
      end

      # Helper: Get assistant messages only
      def assistant_messages
        @assistant_messages ||= messages.select do |msg|
          role = msg["role"] || msg[:role]
          role == "assistant"
        end
      end

      def evaluate
        score = evaluate_score
        feedback_text = generate_feedback

        Evaluation.create!(
          test_run: config[:test_run],
          evaluator_type: self.class.name,
          evaluator_config_id: config[:evaluator_config_id],
          score: score,
          score_min: 0,
          score_max: 100,
          passed: passed?,
          feedback: feedback_text,
          metadata: metadata,
          evaluation_context: config[:evaluation_context] || "tracked_call"
        )
      end
    end
  end
end
```

### BaseAssistantsApiEvaluator

```ruby
# app/services/prompt_tracker/evaluators/base_assistants_api_evaluator.rb
# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Base class for evaluators that require Assistants API-specific data.
    # Extends BaseConversationalEvaluator with access to run_steps, threads, etc.
    #
    # Used for: Assistants only (not Response API)
    #
    class BaseAssistantsApiEvaluator < BaseConversationalEvaluator
      def self.api_type
        :assistants_api
      end

      # Helper: Get run_steps from conversation data
      def run_steps
        @run_steps ||= conversation_data["run_steps"] || conversation_data[:run_steps] || []
      end

      # Helper: Check if run_steps are available
      def run_steps_available?
        run_steps.any?
      end
    end
  end
end
```

---

## UI Changes Required

### 1. Test Form - Dynamic Evaluator Filtering

**File:** `app/views/prompt_tracker/testing/tests/_form.html.erb`

The evaluator list must update when the user changes `test_mode`.

#### Stimulus Controller Approach (Recommended)

Create a Stimulus controller that:
1. Listens to test_mode radio button changes
2. Shows/hides evaluator cards based on their `data-api-type` attribute
3. Unchecks hidden evaluators to prevent invalid selections

```javascript
// app/javascript/controllers/test_mode_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["evaluatorCard"]
  static values = {
    testableType: String  // "assistant" or "prompt_version"
  }

  connect() {
    this.filterEvaluators()
  }

  filterEvaluators() {
    const selectedMode = document.querySelector('input[name="test[test_mode]"]:checked')?.value
    const isAssistant = this.testableTypeValue === "assistant"

    this.evaluatorCardTargets.forEach(card => {
      const apiType = card.dataset.apiType  // "chat_completion", "conversational", or "assistants_api"
      let isVisible = false

      if (selectedMode === "single_turn") {
        // Only show Chat Completion evaluators
        isVisible = apiType === "chat_completion"
      } else if (isAssistant) {
        // Show all conversational evaluators (including Assistants-specific)
        isVisible = apiType === "conversational" || apiType === "assistants_api"
      } else {
        // PromptVersion conversational: exclude Assistants-specific
        isVisible = apiType === "conversational"
      }

      card.classList.toggle('d-none', !isVisible)

      // Uncheck hidden evaluators
      if (!isVisible) {
        const checkbox = card.querySelector('input[type="checkbox"]')
        if (checkbox) checkbox.checked = false
      }
    })
  }
}
```

### 2. Update Evaluator Card Markup

**File:** `app/views/prompt_tracker/testing/tests/_form.html.erb`

Add API type data attribute to each evaluator card:

```erb
<%
  # Determine testable type for filtering
  testable = test.testable
  testable_type = testable.is_a?(PromptTracker::Openai::Assistant) ? "assistant" : "prompt_version"
%>

<div data-controller="test-mode" data-test-mode-testable-type-value="<%= testable_type %>">
  <!-- Test Mode selection -->
  ...

  <!-- Evaluators list -->
  <div id="evaluators-list" class="row">
    <% available_evaluators.each do |key, meta| %>
      <%
        evaluator_class = meta[:evaluator_class]
        api_type = evaluator_class.api_type rescue :chat_completion
      %>

      <div class="col-lg-6 col-xl-4 mb-3"
           data-test-mode-target="evaluatorCard"
           data-api-type="<%= api_type %>">
        <!-- existing card markup -->
      </div>
    <% end %>
  </div>
</div>
```

### 3. Add Visual API Type Badge to Evaluators

Show which API each evaluator is for:

```erb
<%
  api_type = evaluator_class.api_type rescue :chat_completion
  api_badge = case api_type
              when :chat_completion
                { class: "bg-secondary", icon: "chat-left-text", label: "Single-Turn" }
              when :conversational
                { class: "bg-info", icon: "chat-dots", label: "Conversational" }
              when :assistants_api
                { class: "bg-primary", icon: "robot", label: "Assistants Only" }
              end
%>

<div class="d-flex justify-content-between align-items-start">
  <div>
    <strong><i class="bi bi-<%= meta[:icon] %>"></i> <%= meta[:name] %></strong>
    <br>
    <small class="text-muted"><%= meta[:description] %></small>
  </div>
  <div class="d-flex flex-column align-items-end">
    <span class="badge <%= api_badge[:class] %>">
      <i class="bi bi-<%= api_badge[:icon] %>"></i> <%= api_badge[:label] %>
    </span>
  </div>
</div>
```

### 4. Connect Radio Buttons to Controller

```erb
<%= form_with(model: test, ...) do |f| %>
  <div data-controller="test-mode"
       data-test-mode-testable-type-value="<%= testable_type %>">

    <!-- Test Mode radio buttons with data-action -->
    <div class="form-check">
      <%= f.radio_button :test_mode, "single_turn",
          class: "form-check-input",
          data: { action: "change->test-mode#filterEvaluators" } %>
    </div>
    <div class="form-check">
      <%= f.radio_button :test_mode, "conversational",
          class: "form-check-input",
          data: { action: "change->test-mode#filterEvaluators" } %>
    </div>

    <!-- Evaluators list -->
    <div id="evaluators-list" class="row">
      <!-- Cards with data-test-mode-target="evaluatorCard" -->
    </div>
  </div>
<% end %>
```

---

## Migration Path

### Phase 1: Create New Base Classes (Non-Breaking)
1. Create `BaseChatCompletionEvaluator` with content from `BasePromptVersionEvaluator`
2. Create `BaseConversationalEvaluator` with content from `BaseOpenaiAssistantEvaluator`
3. Create `BaseAssistantsApiEvaluator` extending `BaseConversationalEvaluator`
4. Add `api_type` class method to each base class
5. Update EvaluatorRegistry to support new `for_test` method (keep old method for now)

### Phase 2: Migrate Concrete Evaluators
1. Update single-turn evaluators to inherit from `BaseChatCompletionEvaluator`:
   - ExactMatchEvaluator
   - FormatEvaluator
   - KeywordEvaluator
   - LengthEvaluator
   - LlmJudgeEvaluator
   - PatternMatchEvaluator
2. Update conversational evaluators to inherit from `BaseConversationalEvaluator`:
   - ConversationJudgeEvaluator
   - FunctionCallEvaluator
3. Update Assistants-only evaluators to inherit from `BaseAssistantsApiEvaluator`:
   - FileSearchEvaluator

### Phase 3: Update UI
1. Create Stimulus controller `test_mode_controller.js`
2. Update test form with `data-api-type` attributes on evaluator cards
3. Add visual API type badges to evaluator cards
4. Test dynamic filtering behavior

### Phase 4: Cleanup
1. Remove old base class files (`BasePromptVersionEvaluator`, `BaseOpenaiAssistantEvaluator`)
2. Remove old `compatible_with` method from BaseEvaluator
3. Remove `for_testable` method from EvaluatorRegistry
4. Update all specs to use new inheritance

---

## Test Plan

### Unit Tests - Base Classes
- [ ] `BaseChatCompletionEvaluator.api_type` returns `:chat_completion`
- [ ] `BaseConversationalEvaluator.api_type` returns `:conversational`
- [ ] `BaseAssistantsApiEvaluator.api_type` returns `:assistants_api`
- [ ] `BaseAssistantsApiEvaluator` inherits from `BaseConversationalEvaluator`

### Unit Tests - Evaluator Inheritance
- [ ] All single-turn evaluators inherit from `BaseChatCompletionEvaluator`
- [ ] ConversationJudgeEvaluator inherits from `BaseConversationalEvaluator`
- [ ] FunctionCallEvaluator inherits from `BaseConversationalEvaluator`
- [ ] FileSearchEvaluator inherits from `BaseAssistantsApiEvaluator`

### Unit Tests - EvaluatorRegistry
- [ ] `for_test(single_turn_test)` returns only `BaseChatCompletionEvaluator` subclasses
- [ ] `for_test(conversational_prompt_version_test)` returns only `BaseConversationalEvaluator` subclasses (excludes `BaseAssistantsApiEvaluator` subclasses)
- [ ] `for_test(assistant_test)` returns all `BaseConversationalEvaluator` subclasses (including `BaseAssistantsApiEvaluator`)
- [ ] `for_mode(:single_turn)` returns only Chat Completion evaluators
- [ ] `for_mode(:conversational, testable: assistant)` includes FileSearchEvaluator
- [ ] `for_mode(:conversational, testable: prompt_version)` excludes FileSearchEvaluator

### Integration Tests
- [ ] Creating a single-turn test shows single-turn evaluators only
- [ ] Creating a conversational test on PromptVersion shows conversational evaluators (not Assistants-only)
- [ ] Creating a conversational test on Assistant shows all conversational evaluators
- [ ] Switching test mode in form updates visible evaluators
- [ ] Hidden evaluators are unchecked when switching modes

### System Tests
- [ ] Full flow: create conversational test on PromptVersion, select ConversationJudgeEvaluator, run test
- [ ] Full flow: verify FileSearchEvaluator only appears for Assistant tests

---

## Summary of Changes

| Old Class | New Class | API Type |
|-----------|-----------|----------|
| `BasePromptVersionEvaluator` | `BaseChatCompletionEvaluator` | `:chat_completion` |
| `BaseOpenaiAssistantEvaluator` | `BaseConversationalEvaluator` | `:conversational` |
| (new) | `BaseAssistantsApiEvaluator` | `:assistants_api` |

| Evaluator | Old Parent | New Parent |
|-----------|------------|------------|
| ExactMatchEvaluator | BasePromptVersionEvaluator | BaseChatCompletionEvaluator |
| FormatEvaluator | BasePromptVersionEvaluator | BaseChatCompletionEvaluator |
| KeywordEvaluator | BasePromptVersionEvaluator | BaseChatCompletionEvaluator |
| LengthEvaluator | BasePromptVersionEvaluator | BaseChatCompletionEvaluator |
| LlmJudgeEvaluator | BasePromptVersionEvaluator | BaseChatCompletionEvaluator |
| PatternMatchEvaluator | BasePromptVersionEvaluator | BaseChatCompletionEvaluator |
| ConversationJudgeEvaluator | BaseOpenaiAssistantEvaluator | BaseConversationalEvaluator |
| FunctionCallEvaluator | BaseOpenaiAssistantEvaluator | BaseConversationalEvaluator |
| FileSearchEvaluator | BaseOpenaiAssistantEvaluator | BaseAssistantsApiEvaluator |
