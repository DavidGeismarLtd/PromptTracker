# 📋 Implementation Plan - Step by Step

## Phase 1: Database & Models (Day 1)

### Step 1.1: Create Trace Migration

**File**: `db/migrate/YYYYMMDDHHMMSS_create_prompt_tracker_traces.rb`

```ruby
class CreatePromptTrackerTraces < ActiveRecord::Migration[7.2]
  def change
    create_table :prompt_tracker_traces do |t|
      t.string :name, null: false
      t.text :input
      t.text :output
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_ms
      
      # Context
      t.string :session_id
      t.string :user_id
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :prompt_tracker_traces, :session_id
    add_index :prompt_tracker_traces, :user_id
    add_index :prompt_tracker_traces, [:status, :created_at]
  end
end
```

**Run**: `rails db:migrate`

---

### Step 1.2: Create Span Migration

**File**: `db/migrate/YYYYMMDDHHMMSS_create_prompt_tracker_spans.rb`

```ruby
class CreatePromptTrackerSpans < ActiveRecord::Migration[7.2]
  def change
    create_table :prompt_tracker_spans do |t|
      t.references :trace, null: false, 
                   foreign_key: { to_table: :prompt_tracker_traces }
      t.bigint :parent_span_id
      t.string :name, null: false
      t.string :span_type
      t.text :input
      t.text :output
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_ms
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :prompt_tracker_spans, :parent_span_id
    add_index :prompt_tracker_spans, [:trace_id, :created_at]
    add_index :prompt_tracker_spans, :status
    add_foreign_key :prompt_tracker_spans, :prompt_tracker_spans, 
                    column: :parent_span_id
  end
end
```

**Run**: `rails db:migrate`

---

### Step 1.3: Update LlmResponses Migration

**File**: `db/migrate/YYYYMMDDHHMMSS_add_tracing_to_llm_responses.rb`

```ruby
class AddTracingToLlmResponses < ActiveRecord::Migration[7.2]
  def change
    add_reference :prompt_tracker_llm_responses, :trace,
                  foreign_key: { to_table: :prompt_tracker_traces }
    add_reference :prompt_tracker_llm_responses, :span,
                  foreign_key: { to_table: :prompt_tracker_spans }
    
    add_index :prompt_tracker_llm_responses, [:trace_id, :created_at]
    add_index :prompt_tracker_llm_responses, [:span_id, :created_at]
  end
end
```

**Run**: `rails db:migrate`

---

### Step 1.4: Create Trace Model

**File**: `app/models/prompt_tracker/trace.rb`

Copy from `docs/TRACING_MODELS.md` (Trace Model section)

---

### Step 1.5: Create Span Model

**File**: `app/models/prompt_tracker/span.rb`

Copy from `docs/TRACING_MODELS.md` (Span Model section)

---

### Step 1.6: Update LlmResponse Model

**File**: `app/models/prompt_tracker/llm_response.rb`

Add associations:
```ruby
belongs_to :trace, class_name: "PromptTracker::Trace", optional: true
belongs_to :span, class_name: "PromptTracker::Span", optional: true

scope :in_trace, ->(trace_id) { where(trace_id: trace_id) }
scope :in_span, ->(span_id) { where(span_id: span_id) }
```

---

## Phase 2: Service Layer (Day 1-2)

### Step 2.1: Update LlmCallService

**File**: `app/services/prompt_tracker/llm_call_service.rb`

Add to `initialize`:
```ruby
def initialize(prompt_name:, variables: {}, provider:, model:, 
               version: nil, user_id: nil, session_id: nil, 
               environment: nil, metadata: nil,
               trace: nil, span: nil)  # ← ADD THESE
  # ... existing code ...
  @trace = trace
  @span = span
end
```

Update `create_pending_response`:
```ruby
def create_pending_response(prompt_version, rendered_prompt)
  prompt_version.llm_responses.create!(
    # ... existing fields ...
    trace: @trace,    # ← ADD
    span: @span,      # ← ADD
  )
end
```

---

## Phase 3: Controllers & Views (Day 2)

### Step 3.1: Create SessionsController

**File**: `app/controllers/prompt_tracker/sessions_controller.rb`

Copy from `docs/TRACING_UI.md` (SessionsController section)

---

### Step 3.2: Create TracesController

**File**: `app/controllers/prompt_tracker/traces_controller.rb`

Copy from `docs/TRACING_UI.md` (TracesController section)

---

### Step 3.3: Create Views

Create these files (copy from `docs/TRACING_UI.md`):
- `app/views/prompt_tracker/sessions/index.html.erb`
- `app/views/prompt_tracker/sessions/show.html.erb`
- `app/views/prompt_tracker/traces/index.html.erb`
- `app/views/prompt_tracker/traces/show.html.erb`
- `app/views/prompt_tracker/traces/_timeline.html.erb`
- `app/views/prompt_tracker/traces/_span_item.html.erb`
- `app/views/prompt_tracker/traces/_generation_item.html.erb`

---

### Step 3.4: Add Routes

**File**: `config/routes.rb`

```ruby
PromptTracker::Engine.routes.draw do
  # ... existing routes ...
  
  resources :sessions, only: [:index, :show]
  resources :traces, only: [:index, :show]
end
```

---

## Phase 4: Testing (Day 2-3)

### Step 4.1: Model Tests

**File**: `spec/models/prompt_tracker/trace_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe PromptTracker::Trace, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:status).in_array(%w[running completed error]) }
  end
  
  describe "associations" do
    it { should have_many(:spans).dependent(:destroy) }
    it { should have_many(:llm_responses).dependent(:nullify) }
  end
  
  describe "#complete!" do
    let(:trace) { create(:trace, status: "running", started_at: 2.seconds.ago) }
    
    it "marks trace as completed and calculates duration" do
      trace.complete!(output: "result")
      
      expect(trace.status).to eq("completed")
      expect(trace.output).to eq("result")
      expect(trace.ended_at).to be_present
      expect(trace.duration_ms).to be >= 2000
    end
  end
  
  describe "#mark_error!" do
    let(:trace) { create(:trace, status: "running") }
    
    it "marks trace as error" do
      trace.mark_error!(error_message: "Something went wrong")
      
      expect(trace.status).to eq("error")
      expect(trace.metadata["error"]).to eq("Something went wrong")
    end
  end
end
```

---

### Step 4.2: Span Tests

**File**: `spec/models/prompt_tracker/span_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe PromptTracker::Span, type: :model do
  describe "associations" do
    it { should belong_to(:trace) }
    it { should belong_to(:parent_span).optional }
    it { should have_many(:child_spans) }
    it { should have_many(:llm_responses) }
  end
  
  describe "#create_child_span" do
    let(:trace) { create(:trace) }
    let(:parent_span) { create(:span, trace: trace) }
    
    it "creates a child span" do
      child = parent_span.create_child_span(
        name: "child_operation",
        span_type: "function"
      )
      
      expect(child.parent_span).to eq(parent_span)
      expect(child.trace).to eq(trace)
      expect(child.status).to eq("running")
    end
  end
end
```

---

### Step 4.3: Integration Test

**File**: `spec/integration/tracing_workflow_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Tracing Workflow", type: :integration do
  let(:prompt) { create(:prompt) }
  let(:version) { create(:prompt_version, :active, prompt: prompt) }
  
  it "creates a complete trace with spans and generations" do
    # Create trace
    trace = PromptTracker::Trace.create!(
      name: "test_workflow",
      input: "test input",
      session_id: "session_123",
      user_id: "user_456",
      started_at: Time.current
    )
    
    # Create span
    span = trace.spans.create!(
      name: "test_span",
      span_type: "function",
      started_at: Time.current
    )
    
    # Track LLM call
    result = PromptTracker::LlmCallService.track(
      prompt_name: prompt.name,
      variables: { test: "value" },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: span
    ) do |rendered_prompt|
      { text: "Test response", usage: { total_tokens: 100 } }
    end
    
    # Complete span and trace
    span.complete!(output: result[:response_text])
    trace.complete!(output: result[:response_text])
    
    # Verify relationships
    expect(trace.spans.count).to eq(1)
    expect(trace.llm_responses.count).to eq(1)
    expect(span.llm_responses.count).to eq(1)
    expect(trace.status).to eq("completed")
    expect(span.status).to eq("completed")
  end
end
```

---

### Step 4.4: Create Factories

**File**: `spec/factories/prompt_tracker/traces.rb`

```ruby
FactoryBot.define do
  factory :trace, class: "PromptTracker::Trace" do
    sequence(:name) { |n| "trace_#{n}" }
    status { "running" }
    started_at { Time.current }
    session_id { "session_#{rand(1000)}" }
    user_id { "user_#{rand(1000)}" }
    metadata { {} }
    
    trait :completed do
      status { "completed" }
      ended_at { started_at + 1.second }
      output { "Completed successfully" }
    end
    
    trait :with_spans do
      after(:create) do |trace|
        create_list(:span, 3, trace: trace)
      end
    end
  end
end
```

**File**: `spec/factories/prompt_tracker/spans.rb`

```ruby
FactoryBot.define do
  factory :span, class: "PromptTracker::Span" do
    association :trace, factory: :trace
    sequence(:name) { |n| "span_#{n}" }
    span_type { "function" }
    status { "running" }
    started_at { Time.current }
    metadata { {} }
    
    trait :completed do
      status { "completed" }
      ended_at { started_at + 500.milliseconds }
      output { "Span completed" }
    end
    
    trait :with_children do
      after(:create) do |span|
        create_list(:span, 2, trace: span.trace, parent_span: span)
      end
    end
  end
end
```

---

## Phase 5: Documentation & Polish (Day 3)

### Step 5.1: Update README

Add section about tracing to main README.

### Step 5.2: Add Navigation

Update `app/views/layouts/prompt_tracker/application.html.erb`:

```erb
<li class="nav-item">
  <%= link_to "Sessions", sessions_path, class: "nav-link" %>
</li>
<li class="nav-item">
  <%= link_to "Traces", traces_path, class: "nav-link" %>
</li>
```

---

## Checklist

- [ ] Phase 1: Database & Models
  - [ ] Create traces migration
  - [ ] Create spans migration
  - [ ] Update llm_responses migration
  - [ ] Create Trace model
  - [ ] Create Span model
  - [ ] Update LlmResponse model
  
- [ ] Phase 2: Service Layer
  - [ ] Update LlmCallService
  
- [ ] Phase 3: Controllers & Views
  - [ ] Create SessionsController
  - [ ] Create TracesController
  - [ ] Create all views
  - [ ] Add routes
  
- [ ] Phase 4: Testing
  - [ ] Trace model tests
  - [ ] Span model tests
  - [ ] Integration tests
  - [ ] Create factories
  
- [ ] Phase 5: Documentation
  - [ ] Update README
  - [ ] Add navigation
  - [ ] Test end-to-end

**Total Estimated Time**: 2-3 days

