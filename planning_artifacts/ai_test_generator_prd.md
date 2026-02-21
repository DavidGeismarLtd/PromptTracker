# AI Test Generator PRD

## Overview

Add an AI-powered test generation feature to PromptTracker that analyzes a PromptVersion's configuration and automatically generates comprehensive test cases with appropriate evaluators.

## Problem Statement

Currently, users must manually create tests for their prompts by:
1. Thinking through different test scenarios
2. Creating individual tests one by one
3. Selecting and configuring evaluators for each test
4. Defining test input variables manually

This is time-consuming and error-prone. Users may:
- Miss important edge cases
- Not know which evaluators are appropriate for their prompt
- Spend significant time on repetitive configuration

## Goals

1. **One-click test generation**: Generate a comprehensive test suite from a single prompt version
2. **Context-aware**: Analyze prompt content, variables, tools, and functions to generate relevant tests
3. **Smart evaluator selection**: Choose appropriate evaluators based on prompt characteristics
4. **Customizable**: Allow users to provide optional instructions for what to test
5. **Consistent UX**: Follow existing modal patterns and Turbo Streams for real-time updates

## Non-Goals

- Generating test datasets (DatasetRows) - this is a separate feature
- Running the generated tests automatically
- Modifying existing tests
- Test generation for Assistants (future scope)

---

## User Experience

### Entry Point

Add a button next to "New Test" in the tests card header:

```erb
<%# app/views/prompt_tracker/testing/tests/_tests_card.html.erb %>
<button type="button" class="btn btn-sm btn-outline-primary"
        data-bs-toggle="modal" data-bs-target="#generate-tests-modal">
  <i class="bi bi-magic"></i> Generate with AI
</button>
```

### Modal Interface

The modal provides:
1. **Instructions textarea** (optional): User can describe what to focus on
2. **Context preview**: Shows what the AI will analyze
3. **Generate button**: Triggers the generation

```
┌─────────────────────────────────────────────────────────┐
│ Generate Tests with AI                             [X] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Instructions (optional)                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Describe what you'd like to test, or leave empty   │ │
│ │ for AI to generate a comprehensive test suite...   │ │
│ │                                                     │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│ Examples: "Test edge cases for empty inputs",           │
│ "Focus on error handling", "Test all variable combos"   │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ℹ️ AI will analyze:                                  │ │
│ │ • System prompt: You are a customer support...      │ │
│ │ • User prompt: Hello {{name}}, how can I help...    │ │
│ │ • Variables: name (string), issue (string)         │ │
│ │ • Tools: web_search, code_interpreter               │ │
│ │ • Functions: get_weather, search_products           │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                    [Cancel]  [🪄 Generate Tests]        │
└─────────────────────────────────────────────────────────┘
```

### Loading State

During generation, show a loading indicator:
- Disable the Generate button
- Show spinner with "Generating tests..."
- Modal remains open

### Success State

On completion:
- Close modal
- Flash message: "Generated X tests successfully"
- Tests table updated via Turbo Streams
- Redirect to prompt version show page (tests section)

---

## Technical Architecture

### 1. Service Class: `TestGeneratorService`

Location: `app/services/prompt_tracker/test_generator_service.rb`

```ruby
module PromptTracker
  class TestGeneratorService
    DEFAULT_MODEL = ENV.fetch("TEST_GENERATOR_MODEL", "gpt-4o-mini")
    DEFAULT_TEMPERATURE = 0.7

    def self.generate(prompt_version:, instructions: nil)
      new(prompt_version: prompt_version, instructions: instructions).generate
    end

    def initialize(prompt_version:, instructions: nil)
      @prompt_version = prompt_version
      @instructions = instructions
    end

    def generate
      context = build_context
      evaluator_schemas = build_evaluator_schemas
      prompt = build_generation_prompt(context, evaluator_schemas)

      chat = RubyLLM.chat(model: DEFAULT_MODEL)
        .with_temperature(DEFAULT_TEMPERATURE)
        .with_schema(build_generation_schema)

      response = chat.ask(prompt)
      parse_and_create_tests(response.content)
    end

    private

    attr_reader :prompt_version, :instructions

    # ... implementation details below
  end
end
```

### 2. Context Building

The service extracts all relevant data from the PromptVersion:

```ruby
def build_context
  {
    prompt_name: prompt_version.prompt.name,
    system_prompt: prompt_version.system_prompt,
    user_prompt: prompt_version.user_prompt,
    variables: prompt_version.variables_schema || [],
    model_config: prompt_version.model_config || {},
    tools: extract_tools,
    functions: extract_functions,
    response_schema: prompt_version.response_schema,
    api_type: prompt_version.api_type
  }
end

def extract_tools
  prompt_version.model_config&.dig("tools") || []
end

def extract_functions
  prompt_version.model_config&.dig("tool_config", "functions") || []
end
```

### 3. Evaluator Schema Aggregation (Key Design Decision)

**Question**: How do we pull the right JSON schema for each evaluator to send to `build_generation_schema`?

**Answer**: We use the existing `param_schema` class method that every evaluator already implements:

```ruby
def build_evaluator_schemas
  EvaluatorRegistry.for_testable(prompt_version).map do |key, meta|
    evaluator_class = meta[:evaluator_class]

    {
      key: key.to_s,
      name: meta[:name],
      description: meta[:description],
      param_schema: evaluator_class.param_schema,
      default_config: meta[:default_config]
    }
  end
end
```

Each evaluator class defines its `param_schema`:

| Evaluator | `param_schema` |
|-----------|----------------|
| `LlmJudgeEvaluator` | `{ judge_model: { type: :string }, custom_instructions: { type: :string }, threshold_score: { type: :integer } }` |
| `KeywordEvaluator` | `{ required_keywords: { type: :array }, forbidden_keywords: { type: :array }, case_sensitive: { type: :boolean } }` |
| `LengthEvaluator` | `{ min_length: { type: :integer }, max_length: { type: :integer } }` |
| `FormatEvaluator` | `{ format: { type: :symbol }, required_keys: { type: :array }, strict: { type: :boolean } }` |
| `FunctionCallEvaluator` | `{ expected_functions: { type: :array }, require_all: { type: :boolean }, check_arguments: { type: :boolean } }` |
| `ExactMatchEvaluator` | `{ expected_text: { type: :string }, case_sensitive: { type: :boolean }, trim_whitespace: { type: :boolean } }` |

**This information is embedded in the prompt** so the LLM knows exactly what config fields each evaluator accepts.

### 4. Prompt Construction

The generation prompt includes:
1. Full context about the PromptVersion
2. Available evaluators with their schemas
3. User instructions (or default comprehensive testing)
4. Output format instructions

```ruby
def build_generation_prompt(context, evaluator_schemas)
  <<~PROMPT
    You are an expert QA engineer creating test cases for an LLM prompt.

    ## PROMPT TO TEST

    **Name**: #{context[:prompt_name]}

    **System Prompt**:
    #{context[:system_prompt].presence || "(No system prompt)"}

    **User Prompt Template**:
    #{context[:user_prompt]}

    **Variables**:
    #{format_variables(context[:variables])}

    **API Type**: #{context[:api_type] || "Standard chat completion"}

    **Tools Enabled**: #{context[:tools].presence&.join(", ") || "None"}

    **Functions Available**:
    #{format_functions(context[:functions])}

    **Structured Output Schema**: #{context[:response_schema].present? ? "Yes" : "No"}
    #{context[:response_schema].present? ? JSON.pretty_generate(context[:response_schema]) : ""}

    ## AVAILABLE EVALUATORS

    #{format_evaluator_schemas(evaluator_schemas)}

    ## USER INSTRUCTIONS

    #{instructions.presence || "Generate a comprehensive test suite covering happy paths, edge cases, error scenarios, and any tool/function usage validation."}

    ## TASK

    Generate 3-6 test cases that thoroughly validate this prompt. For each test:

    1. **name**: A descriptive snake_case name (e.g., test_greeting_premium_user, test_empty_input_handling)
    2. **description**: Clear explanation of what this test validates
    3. **evaluator_configs**: Array of evaluators to run, each with:
       - **evaluator_key**: One of the available evaluator keys listed above
       - **config**: Configuration object matching that evaluator's param_schema
    4. **reasoning**: Why this test case is important

    ## GUIDELINES

    - Include at least one test for the "happy path" (normal expected usage)
    - Include edge cases (empty inputs, very long inputs, special characters)
    - If tools are enabled (web_search, code_interpreter, file_search), add tests that verify tool usage
    - If functions are defined, add tests with FunctionCallEvaluator
    - If structured output is expected, add FormatEvaluator
    - Always include at least one LlmJudgeEvaluator for quality assessment
    - Use KeywordEvaluator when specific terms must/must not appear
    - Use LengthEvaluator when response length matters

    Generate the test cases now.
  PROMPT
end

def format_variables(variables)
  return "None" if variables.blank?

  variables.map do |v|
    "- #{v['name']} (#{v['type']}, required: #{v['required']})"
  end.join("\n")
end

def format_functions(functions)
  return "None" if functions.blank?

  functions.map do |f|
    params = f['parameters']&.dig('properties')&.keys&.join(", ") || "none"
    "- #{f['name']}: #{f['description'] || 'No description'} (params: #{params})"
  end.join("\n")
end

def format_evaluator_schemas(evaluator_schemas)
  evaluator_schemas.map do |es|
    config_fields = es[:param_schema].map do |field, type_info|
      "    - #{field}: #{type_info[:type]}"
    end.join("\n")

    <<~EVALUATOR
      ### #{es[:name]} (key: "#{es[:key]}")
      #{es[:description]}

      **Config fields**:
      #{config_fields}

      **Defaults**: #{es[:default_config].to_json}
    EVALUATOR
  end.join("\n")
end
```

### 5. RubyLLM Schema for Structured Output

The LLM response is structured using RubyLLM's schema system:

```ruby
def build_generation_schema
  Class.new(RubyLLM::Schema) do
    array :tests, description: "Array of test cases to create" do
      string :name, description: "Snake_case test name (e.g., test_greeting_premium_user)"
      string :description, description: "What this test validates"
      string :reasoning, description: "Why this test case is important"

      array :evaluator_configs, description: "Evaluators for this test" do
        string :evaluator_key, description: "Evaluator type key (e.g., llm_judge, keyword, format)"
        hash :config, description: "Evaluator configuration matching its param_schema"
      end
    end

    string :overall_reasoning, description: "Overview of the test strategy"
  end
end
```

### 6. Test Creation

After receiving the structured response, create the actual Test and EvaluatorConfig records:

```ruby
def parse_and_create_tests(response_content)
  content = response_content.with_indifferent_access
  created_tests = []

  content[:tests].each do |test_data|
    test = prompt_version.tests.create!(
      name: test_data[:name],
      description: test_data[:description],
      enabled: true,
      metadata: {
        ai_generated: true,
        reasoning: test_data[:reasoning],
        generated_at: Time.current.iso8601
      }
    )

    test_data[:evaluator_configs].each do |ec_data|
      test.evaluator_configs.create!(
        evaluator_key: ec_data[:evaluator_key],
        config: ec_data[:config] || {},
        enabled: true
      )
    end

    created_tests << test
  end

  {
    tests: created_tests,
    overall_reasoning: content[:overall_reasoning],
    count: created_tests.size
  }
end
```

---

## Controller Implementation

### Routes

```ruby
# config/routes.rb (within PromptTracker engine)
namespace :testing do
  resources :prompt_versions, only: [] do
    member do
      post :generate_tests
    end
  end
end
```

### Controller Action

Add to `Testing::PromptVersionsController`:

```ruby
# POST /testing/prompt_versions/:id/generate_tests
def generate_tests
  @version = find_prompt_version

  result = TestGeneratorService.generate(
    prompt_version: @version,
    instructions: params[:instructions].presence
  )

  respond_to do |format|
    format.html do
      redirect_to testing_prompt_prompt_version_path(@prompt, @version),
                  notice: "Generated #{result[:count]} tests successfully."
    end
    format.turbo_stream do
      flash.now[:notice] = "Generated #{result[:count]} tests successfully."
      redirect_to testing_prompt_prompt_version_path(@prompt, @version),
                  status: :see_other
    end
    format.json do
      render json: {
        tests: result[:tests].map(&:as_json),
        reasoning: result[:overall_reasoning],
        count: result[:count]
      }
    end
  end
end
```

---

## View Components

### 1. Modal Partial

`app/views/prompt_tracker/testing/tests/_generate_tests_modal.html.erb`

```erb
<% version ||= @version %>
<% prompt ||= version.prompt %>

<div data-controller="modal-fix">
  <div class="modal fade" id="generate-tests-modal" tabindex="-1"
       data-modal-fix-target="modal" aria-hidden="true">
    <div class="modal-dialog modal-lg">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">
            <i class="bi bi-magic"></i> Generate Tests with AI
          </h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>

        <%= form_with url: generate_tests_testing_prompt_version_path(version),
                      method: :post,
                      data: { turbo_stream: true, controller: "test-generator" } do |f| %>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label">Instructions (optional)</label>
              <textarea name="instructions" class="form-control" rows="4"
                placeholder="Describe what you'd like to test, or leave empty for AI to generate a comprehensive test suite..."></textarea>
              <div class="form-text">
                Examples: "Test edge cases for empty inputs", "Focus on error handling",
                "Ensure function calls are made correctly"
              </div>
            </div>

            <div class="alert alert-info">
              <h6 class="alert-heading">
                <i class="bi bi-info-circle"></i> AI will analyze:
              </h6>
              <ul class="mb-0 small">
                <li>
                  <strong>System prompt:</strong>
                  <%= truncate(version.system_prompt, length: 60) || "None" %>
                </li>
                <li>
                  <strong>User prompt:</strong>
                  <%= truncate(version.user_prompt, length: 60) %>
                </li>
                <li>
                  <strong>Variables:</strong>
                  <%= version.variables_schema&.map { |v| v["name"] }&.join(", ").presence || "None" %>
                </li>
                <li>
                  <strong>Tools:</strong>
                  <%= version.model_config&.dig("tools")&.join(", ").presence || "None" %>
                </li>
                <li>
                  <strong>Functions:</strong>
                  <%= version.model_config&.dig("tool_config", "functions")&.map { |f| f["name"] }&.join(", ").presence || "None" %>
                </li>
              </ul>
            </div>
          </div>

          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary" data-test-generator-target="submitButton">
              <i class="bi bi-magic"></i> Generate Tests
            </button>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

### 2. Update Tests Card Header

Modify `_tests_card.html.erb` to include the generate button:

```erb
<div class="d-flex gap-2">
  <% if tests.any? %>
    <%= render "prompt_tracker/testing/tests/tests_column_visibility_dropdown",
               tests: tests, testable_param: testable %>
    <button type="button" class="btn btn-sm btn-success"
            data-bs-toggle="modal" data-bs-target="#runAllTestsModal">
      <i class="bi bi-play-circle"></i> Run All (<%= tests.count %>)
    </button>
  <% end %>

  <%# AI Generate button - only for PromptVersions %>
  <% if testable.is_a?(PromptTracker::PromptVersion) %>
    <button type="button" class="btn btn-sm btn-outline-primary"
            data-bs-toggle="modal" data-bs-target="#generate-tests-modal">
      <i class="bi bi-magic"></i> Generate with AI
    </button>
  <% end %>

  <button type="button" class="btn btn-sm btn-primary"
          data-bs-toggle="modal" data-bs-target="#new-test-modal">
    <i class="bi bi-plus-circle"></i> New Test
  </button>
</div>
```

### 3. Include Modal in Show View

Add to `testing/prompt_versions/show.html.erb`:

```erb
<%# Generate Tests Modal %>
<%= render "prompt_tracker/testing/tests/generate_tests_modal",
           version: @version, prompt: @prompt %>
```

---

## Stimulus Controller (Optional Enhancement)

For better loading states:

```javascript
// app/javascript/controllers/prompt_tracker/test_generator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "spinner"]

  submit(event) {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.innerHTML = `
      <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
      Generating tests...
    `
  }
}
```

---

## File Structure

```
app/
├── services/prompt_tracker/
│   └── test_generator_service.rb           # Main service
├── views/prompt_tracker/testing/tests/
│   ├── _tests_card.html.erb               # Updated to include AI button
│   └── _generate_tests_modal.html.erb     # New modal partial
├── views/prompt_tracker/testing/prompt_versions/
│   └── show.html.erb                       # Include modal
└── javascript/controllers/prompt_tracker/
    └── test_generator_controller.js        # Optional Stimulus controller
```

---

## Testing Strategy

### Unit Tests for TestGeneratorService

```ruby
# spec/services/prompt_tracker/test_generator_service_spec.rb

RSpec.describe PromptTracker::TestGeneratorService do
  let(:prompt_version) { create(:prompt_version, :with_tools) }

  describe ".generate" do
    context "with a standard prompt" do
      it "creates multiple tests with evaluator configs" do
        result = described_class.generate(prompt_version: prompt_version)

        expect(result[:count]).to be_between(3, 6)
        expect(result[:tests]).to all(be_a(PromptTracker::Test))
        expect(result[:tests].flat_map(&:evaluator_configs)).to be_present
      end
    end

    context "with user instructions" do
      it "respects user-provided focus areas" do
        result = described_class.generate(
          prompt_version: prompt_version,
          instructions: "Focus only on edge cases with empty inputs"
        )

        # Verify tests were created
        expect(result[:count]).to be >= 1
      end
    end

    context "with function-enabled prompt" do
      let(:prompt_version) { create(:prompt_version, :with_functions) }

      it "includes function_call evaluator" do
        result = described_class.generate(prompt_version: prompt_version)

        evaluator_keys = result[:tests]
          .flat_map(&:evaluator_configs)
          .map(&:evaluator_key)

        expect(evaluator_keys).to include("function_call")
      end
    end
  end

  describe "#build_context" do
    it "extracts all relevant prompt version data" do
      service = described_class.new(prompt_version: prompt_version)
      context = service.send(:build_context)

      expect(context).to include(
        :prompt_name,
        :system_prompt,
        :user_prompt,
        :variables,
        :tools,
        :functions
      )
    end
  end

  describe "#build_evaluator_schemas" do
    it "returns schemas for all compatible evaluators" do
      service = described_class.new(prompt_version: prompt_version)
      schemas = service.send(:build_evaluator_schemas)

      expect(schemas).to be_an(Array)
      expect(schemas.first).to include(:key, :name, :param_schema)
    end
  end
end
```

### Controller Tests

```ruby
# spec/requests/prompt_tracker/testing/prompt_versions/generate_tests_spec.rb

RSpec.describe "POST /testing/prompt_versions/:id/generate_tests" do
  let(:prompt_version) { create(:prompt_version) }

  it "generates tests and redirects with success message" do
    post generate_tests_testing_prompt_version_path(prompt_version),
         params: { instructions: "" }

    expect(response).to redirect_to(
      testing_prompt_prompt_version_path(prompt_version.prompt, prompt_version)
    )
    expect(flash[:notice]).to match(/Generated \d+ tests/)
  end

  it "passes user instructions to the service" do
    expect(PromptTracker::TestGeneratorService).to receive(:generate)
      .with(hash_including(instructions: "Focus on errors"))
      .and_call_original

    post generate_tests_testing_prompt_version_path(prompt_version),
         params: { instructions: "Focus on errors" }
  end
end
```

---

## Edge Cases & Considerations

### 1. Empty Prompt Version
If `system_prompt` and `user_prompt` are minimal, the AI should still generate basic tests.

### 2. No Compatible Evaluators
If `EvaluatorRegistry.for_testable` returns empty (edge case), fallback to a default LlmJudgeEvaluator.

### 3. LLM Response Errors
The service does NOT rescue StandardError (per user preferences). Errors propagate to controller.

### 4. Rate Limiting
Consider adding a rate limit or cooldown to prevent abuse:
- Max 1 generation per minute per prompt version
- Optional: use background job for very long prompts

### 5. Model Configuration
The service uses `ENV["TEST_GENERATOR_MODEL"]` or defaults to `gpt-4o-mini`. This keeps costs low while maintaining quality.

---

## Future Enhancements

1. **Dataset Row Generation**: After generating tests, optionally generate sample DatasetRows with test inputs
2. **Test Refinement**: "Regenerate this test" action for individual tests
3. **Batch Mode**: Generate tests for multiple prompt versions at once
4. **Custom Evaluator Discovery**: Support host app's custom evaluators via `EvaluatorRegistry.register`
5. **Test Templates**: Pre-defined test templates (security, compliance, performance)
6. **Assistant Support**: Extend to support Assistant testables with ConversationJudgeEvaluator

---

## Implementation Checklist

- [ ] Create `TestGeneratorService` class
- [ ] Add `generate_tests` route
- [ ] Add controller action
- [ ] Create `_generate_tests_modal.html.erb` partial
- [ ] Update `_tests_card.html.erb` with AI button
- [ ] Include modal in `show.html.erb`
- [ ] Add Stimulus controller for loading state
- [ ] Write RSpec tests for service
- [ ] Write request specs for controller
- [ ] Manual testing in browser

---

## Summary

This PRD outlines a complete implementation for AI-powered test generation in PromptTracker. The key technical decisions are:

1. **Service-based architecture** following `PromptGeneratorService` patterns
2. **Evaluator schema aggregation** via existing `param_schema` class methods
3. **Structured output** using RubyLLM schemas for reliable parsing
4. **Modal UX** consistent with existing patterns, wrapped in `modal-fix` controller
5. **Turbo integration** for seamless UI updates after generation

The feature enables users to quickly bootstrap comprehensive test suites while maintaining full control over editing and customization.
