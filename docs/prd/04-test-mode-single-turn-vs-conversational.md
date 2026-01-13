# PRD: Test Mode - Single-Turn vs Conversational

## Overview

This document describes adding a `test_mode` enum to the Test model, enabling PromptVersions to be tested in either single-turn or conversational (multi-turn) mode. This requires corresponding changes to datasets, UI, and test runners.

## Background

### Current State

| Testable Type | Test Mode | How It Works |
|---------------|-----------|--------------|
| `PromptVersion` | Single-turn only | Render prompt → LLM call → Evaluate response |
| `Assistant` | Conversational only | Interlocutor simulation → Multi-turn → Evaluate conversation |

### Problem Statement

Users want to test the same PromptVersion in different modes:
- **Single-turn**: Quick validation of prompt quality with varied inputs
- **Conversational**: Realistic multi-turn scenario testing

Currently, conversational testing requires creating an OpenAI Assistant. With Response API support, we can offer conversational testing for PromptVersions without Assistants.

### Goals

1. Add `test_mode` enum to Test model (`:single_turn`, `:conversational`)
2. Require compatible datasets for each test mode
3. Update UI to show test mode and filter appropriately
4. Route to correct test runner based on mode

## Technical Design

### Database Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_test_mode_to_tests.rb
class AddTestModeToTests < ActiveRecord::Migration[7.1]
  def change
    add_column :prompt_tracker_tests, :test_mode, :integer, default: 0, null: false
    add_index :prompt_tracker_tests, :test_mode
  end
end
```

### Model Changes

```ruby
# app/models/prompt_tracker/test.rb
class Test < ApplicationRecord
  enum :test_mode, { single_turn: 0, conversational: 1 }, default: :single_turn

  # Validations
  validate :dataset_compatible_with_test_mode
  validate :testable_supports_test_mode

  # Scopes
  scope :single_turn_tests, -> { where(test_mode: :single_turn) }
  scope :conversational_tests, -> { where(test_mode: :conversational) }

  # Check if test mode is allowed for this testable
  def testable_supports_test_mode?
    case testable
    when PromptVersion
      # Conversational requires Response API provider
      return true if single_turn?
      testable.model_config&.dig("provider") == "openai_responses"
    when Openai::Assistant
      # Assistants only support conversational
      conversational?
    else
      true
    end
  end

  private

  def dataset_compatible_with_test_mode
    return unless dataset.present?

    if conversational? && !dataset.conversational?
      errors.add(:dataset, "must be a conversational dataset for conversational tests")
    end
  end

  def testable_supports_test_mode
    return if testable_supports_test_mode?

    case testable
    when PromptVersion
      errors.add(:test_mode, "conversational mode requires Response API provider")
    when Openai::Assistant
      errors.add(:test_mode, "Assistants only support conversational mode")
    end
  end
end
```

### Dataset Type

Datasets need a `dataset_type` to indicate compatibility:

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_dataset_type_to_datasets.rb
class AddDatasetTypeToDatasets < ActiveRecord::Migration[7.1]
  def change
    add_column :prompt_tracker_datasets, :dataset_type, :integer, default: 0, null: false
    add_index :prompt_tracker_datasets, :dataset_type
  end
end

# app/models/prompt_tracker/dataset.rb
class Dataset < ApplicationRecord
  enum :dataset_type, { single_turn: 0, conversational: 1 }, default: :single_turn

  # Schema requirements based on type
  def required_schema
    base_schema = testable&.variables_schema || []

    return base_schema if single_turn?

    # Conversational datasets need additional fields
    base_schema + CONVERSATIONAL_FIELDS
  end

  CONVERSATIONAL_FIELDS = [
    { "name" => "interlocutor_simulation_prompt", "type" => "text", "required" => true },
    { "name" => "max_turns", "type" => "integer", "required" => false, "default" => 5 }
  ].freeze

  def conversational?
    dataset_type == "conversational"
  end
end
```

### Test Runner Selection

```ruby
# app/jobs/prompt_tracker/run_test_job.rb
class RunTestJob < ApplicationJob
  def perform(test_run_id)
    test_run = TestRun.find(test_run_id)
    runner = resolve_runner(test_run)
    runner.run
  end

  private

  def resolve_runner(test_run)
    test = test_run.test
    testable = test.testable

    runner_class = case testable
    when PromptVersion
      if test.conversational?
        # Must be Response API
        TestRunners::Openai::ResponseApiConversationalRunner
      else
        TestRunners::PromptVersionRunner
      end
    when Openai::Assistant
      TestRunners::Openai::AssistantRunner
    else
      raise "Unknown testable type: #{testable.class}"
    end

    runner_class.new(
      test_run: test_run,
      test: test,
      testable: testable,
      use_real_llm: use_real_llm?
    )
  end
end
```

## UI/UX Design

### Dataset Creation Flow

When creating a dataset, users must select the type:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Create New Dataset                                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Dataset Name: [Customer Support Scenarios          ]                │
│                                                                     │
│ Dataset Type:                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ ○ Single-Turn                                                   │ │
│ │   Each row provides variables for a single prompt/response.     │ │
│ │   Use for: Quick prompt validation, A/B testing variations.     │ │
│ │                                                                 │ │
│ │ ○ Conversational                                                │ │
│ │   Each row defines a multi-turn conversation scenario.          │ │
│ │   Requires: interlocutor_simulation_prompt, max_turns           │ │
│ │   Use for: Customer service flows, complex interactions.        │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ [Cancel]                                         [Create Dataset]   │
└─────────────────────────────────────────────────────────────────────┘
```

### Dataset Row Form (Conversational)

For conversational datasets, show the extra fields:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Add Dataset Row                                        [Conversational] │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ ── Template Variables ──────────────────────────────────────────────│
│                                                                     │
│ customer_name: [John Smith                         ]                │
│ issue_type:    [billing          ▼]                                 │
│                                                                     │
│ ── Conversation Settings ───────────────────────────────────────────│
│                                                                     │
│ Interlocutor Simulation Prompt:                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ You are a frustrated customer who has been charged twice for   │ │
│ │ order #12345. You're angry but will calm down if the agent     │ │
│ │ shows empathy and offers a clear resolution path.              │ │
│ │                                                                 │ │
│ │ Start the conversation by saying: "I've been double-charged!"  │ │
│ │                                                                 │ │
│ │ Escalate if the agent doesn't acknowledge the problem within   │ │
│ │ 2 turns. End with "[END]" when satisfied or after 5 turns.     │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ Max Turns: [5  ▼]  (1-10)                                           │
│                                                                     │
│ ── Expected Outcome (Optional) ─────────────────────────────────────│
│                                                                     │
│ expected_resolution: [refund_offered                ]               │
│                                                                     │
│ [Cancel]                                             [Add Row]      │
└─────────────────────────────────────────────────────────────────────┘
```

### Test Creation Flow

When creating a test, show test mode options:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Create New Test for: Customer Support v3                            │
│                       Provider: Response API | gpt-4o               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Test Name: [Escalation Handling Test              ]                 │
│                                                                     │
│ Test Mode:                                                          │
│   ○ Single-Turn   - Test individual prompt/responses                │
│   ● Conversational - Test multi-turn conversation flows             │
│                                                                     │
│ Dataset: [Select a conversational dataset...    ▼]                  │
│          ├── [Conv] Billing Issues Scenarios                        │
│          ├── [Conv] Technical Support Flows                         │
│          └── (Single-turn datasets hidden)                          │
│                                                                     │
│ Evaluators:                                                         │
│   ☑ ConversationJudge (recommended for conversational)              │
│   ☐ KeywordEvaluator                                                │
│   ☐ LengthEvaluator                                                 │
│                                                                     │
│ [Cancel]                                           [Create Test]    │
└─────────────────────────────────────────────────────────────────────┘
```

### PromptVersion Show Page - Test Tabs

Separate tests by mode:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Customer Support v3                                                 │
│ Provider: Response API | Model: gpt-4o                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ [Overview] [Playground] [Tests] [History]                           │
│                                                                     │
│ ┌─ Tests ───────────────────────────────────────────────────────────┤
│ │                                                                   │
│ │ [Single-Turn Tests (3)] [Conversational Tests (2)]  [+ New Test]  │
│ │                         ════════════════════════                  │
│ │                                                                   │
│ │ ┌─────────────────────────────────────────────────────────────┐   │
│ │ │ 🔄 Escalation Handling Test                                  │   │
│ │ │ Dataset: Billing Issues (5 rows) | Evaluators: ConvJudge     │   │
│ │ │ Last Run: 2 hours ago | Pass Rate: 80%                       │   │
│ │ │ [View Results] [Run Test]                                    │   │
│ │ └─────────────────────────────────────────────────────────────┘   │
│ │                                                                   │
│ │ ┌─────────────────────────────────────────────────────────────┐   │
│ │ │ 🔄 Empathy Response Test                                     │   │
│ │ │ Dataset: Angry Customer Flows (3 rows) | Evaluators: Judge   │   │
│ │ │ Last Run: 1 day ago | Pass Rate: 100%                        │   │
│ │ │ [View Results] [Run Test]                                    │   │
│ │ └─────────────────────────────────────────────────────────────┘   │
│ │                                                                   │
│ └───────────────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────────────┘
```

### Warning States

Show warnings for incompatible configurations:

```
⚠️ Conversational test mode requires Response API provider.
   Current provider: OpenAI (Chat Completions)
   [Switch to Response API]

⚠️ Selected dataset is single-turn but test mode is conversational.
   [Change Test Mode] or [Select Different Dataset]
```

## Validation Rules

### Test Mode Constraints

| Testable Type | Allowed Test Modes | Notes |
|--------------|-------------------|-------|
| `PromptVersion` (Chat Completions) | `single_turn` only | Chat Completions doesn't support stateful conversations |
| `PromptVersion` (Response API) | `single_turn`, `conversational` | Response API supports both |
| `Assistant` | `conversational` only | Assistants are inherently conversational |

### Dataset Compatibility Matrix

| Dataset Type | Can Be Used With |
|--------------|------------------|
| `single_turn` | Single-turn tests only |
| `conversational` | Conversational tests only |

## Testing Strategy

### Model Tests

```ruby
# spec/models/prompt_tracker/test_spec.rb
RSpec.describe PromptTracker::Test do
  describe "test_mode" do
    it "defaults to single_turn" do
      test = build(:test)
      expect(test.single_turn?).to be true
    end

    it "validates conversational mode requires Response API provider" do
      prompt_version = create(:prompt_version, model_config: { "provider" => "openai" })
      test = build(:test, testable: prompt_version, test_mode: :conversational)

      expect(test).not_to be_valid
      expect(test.errors[:test_mode]).to include("conversational mode requires Response API provider")
    end

    it "validates dataset compatibility" do
      dataset = create(:dataset, dataset_type: :single_turn)
      test = build(:test, test_mode: :conversational, dataset: dataset)

      expect(test).not_to be_valid
      expect(test.errors[:dataset]).to include("must be a conversational dataset")
    end
  end
end

# spec/models/prompt_tracker/dataset_spec.rb
RSpec.describe PromptTracker::Dataset do
  describe "dataset_type" do
    it "requires conversational fields for conversational type" do
      dataset = create(:dataset, dataset_type: :conversational)
      row = build(:dataset_row, dataset: dataset, variables: { "name" => "John" })

      expect(row).not_to be_valid
      expect(row.errors[:variables]).to include("missing interlocutor_simulation_prompt")
    end
  end
end
```

### Controller Tests

```ruby
# spec/controllers/prompt_tracker/tests_controller_spec.rb
RSpec.describe PromptTracker::TestsController do
  describe "POST #create" do
    context "with conversational mode" do
      it "requires Response API provider" do
        prompt_version = create(:prompt_version, model_config: { "provider" => "openai" })

        post :create, params: {
          test: { testable_id: prompt_version.id, test_mode: "conversational" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

### Feature Tests

```ruby
# spec/features/test_mode_spec.rb
RSpec.describe "Test Mode Selection", type: :feature do
  let(:prompt_version) { create(:prompt_version, model_config: { "provider" => "openai_responses" }) }

  it "shows test mode options for Response API prompts" do
    visit new_test_path(testable_type: "PromptVersion", testable_id: prompt_version.id)

    expect(page).to have_field("Single-Turn")
    expect(page).to have_field("Conversational")
  end

  it "filters datasets based on selected test mode" do
    single_dataset = create(:dataset, dataset_type: :single_turn)
    conv_dataset = create(:dataset, dataset_type: :conversational)

    visit new_test_path(testable_type: "PromptVersion", testable_id: prompt_version.id)

    choose "Conversational"

    expect(page).to have_select("Dataset", options: [conv_dataset.name])
    expect(page).not_to have_select("Dataset", options: [single_dataset.name])
  end
end
```

## Migration Path

### Existing Data

All existing tests default to `single_turn`:

```ruby
# In migration
PromptTracker::Test.update_all(test_mode: 0)  # 0 = single_turn
```

All existing datasets default to `single_turn`:

```ruby
PromptTracker::Dataset.update_all(dataset_type: 0)  # 0 = single_turn
```

### Backward Compatibility

- Existing tests continue working as single-turn
- Existing datasets remain single-turn
- No breaking changes to API or UI

## Rollout Plan

### Phase 1: Database & Models (Week 1)
1. Add migrations for `test_mode` and `dataset_type`
2. Add model validations
3. Add scopes and helper methods
4. Unit tests

### Phase 2: Test Runner Integration (Week 2)
1. Update `RunTestJob` with runner selection logic
2. Ensure `ResponseApiConversationalRunner` works with test mode
3. Integration tests

### Phase 3: UI (Week 3)
1. Dataset type selection in create form
2. Test mode selection in create form
3. Filtering datasets by type
4. Prompt version tests page with tabs

### Phase 4: Polish (Week 4)
1. Warning messages for incompatible configurations
2. Bulk dataset conversion tool (optional)
3. Documentation

## Success Metrics

| Metric | Target |
|--------|--------|
| Test mode validations working | 100% |
| Dataset/test mode compatibility enforced | 100% |
| UI clearly communicates mode differences | User testing |
| No regressions in existing single-turn tests | 100% |

## Dependencies

- **PRD-01**: OpenAI Response API Service
- **PRD-02**: Response API Conversation Runner
- Existing: Test and Dataset models

## Open Questions

1. **Migration of existing datasets**: Should we provide a tool to convert single-turn datasets to conversational by adding template interlocutor prompts?

2. **Evaluator compatibility**: Some evaluators (e.g., `ExactMatchEvaluator`) may not make sense for conversations. Should we restrict evaluator selection by test mode?

3. **A/B testing across modes**: Can users compare single-turn vs conversational test results for the same prompt?

## Future Considerations

1. **Hybrid mode**: Some tests might want to evaluate both the final response AND the conversation flow
2. **Conversation templates**: Pre-built interlocutor prompt templates for common scenarios
3. **Conversation branching**: Different paths based on assistant responses

## References

- PRD-01: OpenAI Response API Service Integration
- PRD-02: Response API Conversation Runner
- `docs/plans/assistant-testing-architecture.md`
- `app/models/prompt_tracker/test.rb`
- `app/models/prompt_tracker/dataset.rb`
