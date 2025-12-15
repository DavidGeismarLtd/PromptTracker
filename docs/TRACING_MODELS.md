# 📦 Tracing Models - Technical Specification

## Model Definitions

### 1. Trace Model

**Purpose**: Groups related operations (spans and generations) into a single workflow.

**File**: `app/models/prompt_tracker/trace.rb`

```ruby
module PromptTracker
  class Trace < ApplicationRecord
    # Associations
    has_many :spans, dependent: :destroy
    has_many :llm_responses, dependent: :nullify
    
    # Validations
    validates :name, presence: true
    validates :status, inclusion: { in: %w[running completed error] }
    
    # Scopes
    scope :in_session, ->(session_id) { where(session_id: session_id) }
    scope :for_user, ->(user_id) { where(user_id: user_id) }
    scope :running, -> { where(status: "running") }
    scope :completed, -> { where(status: "completed") }
    
    # Callbacks
    before_save :calculate_duration, if: :ended_at_changed?
    
    # Instance Methods
    def complete!(output: nil)
      update!(
        status: "completed",
        output: output,
        ended_at: Time.current
      )
    end
    
    def mark_error!(error_message:)
      update!(
        status: "error",
        ended_at: Time.current,
        metadata: metadata.merge(error: error_message)
      )
    end
    
    def running?
      status == "running"
    end
    
    private
    
    def calculate_duration
      return unless started_at && ended_at
      self.duration_ms = ((ended_at - started_at) * 1000).round
    end
  end
end
```

**Schema**:
```ruby
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
```

---

### 2. Span Model

**Purpose**: Represents a unit of work within a trace (can be nested).

**File**: `app/models/prompt_tracker/span.rb`

```ruby
module PromptTracker
  class Span < ApplicationRecord
    # Associations
    belongs_to :trace
    belongs_to :parent_span, class_name: "Span", optional: true
    has_many :child_spans, class_name: "Span", 
             foreign_key: :parent_span_id, dependent: :destroy
    has_many :llm_responses, dependent: :nullify
    
    # Validations
    validates :name, presence: true
    validates :status, inclusion: { in: %w[running completed error] }
    validates :span_type, inclusion: { 
      in: %w[function tool retrieval database http],
      allow_nil: true
    }
    
    # Scopes
    scope :root_level, -> { where(parent_span_id: nil) }
    scope :running, -> { where(status: "running") }
    
    # Callbacks
    before_save :calculate_duration, if: :ended_at_changed?
    
    # Instance Methods
    def complete!(output: nil)
      update!(
        status: "completed",
        output: output,
        ended_at: Time.current
      )
    end
    
    def mark_error!(error_message:)
      update!(
        status: "error",
        ended_at: Time.current,
        metadata: metadata.merge(error: error_message)
      )
    end
    
    def create_child_span(name:, span_type: nil, **attrs)
      child_spans.create!(
        trace: trace,
        name: name,
        span_type: span_type,
        started_at: Time.current,
        status: "running",
        **attrs
      )
    end
    
    private
    
    def calculate_duration
      return unless started_at && ended_at
      self.duration_ms = ((ended_at - started_at) * 1000).round
    end
  end
end
```

**Schema**:
```ruby
create_table :prompt_tracker_spans do |t|
  t.references :trace, null: false, foreign_key: { to_table: :prompt_tracker_traces }
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
```

---

### 3. LlmResponse Updates

**Changes**: Add optional trace and span references.

**File**: `app/models/prompt_tracker/llm_response.rb`

```ruby
# Add to existing model:

# Associations
belongs_to :trace, class_name: "PromptTracker::Trace", optional: true
belongs_to :span, class_name: "PromptTracker::Span", optional: true

# Scopes
scope :in_trace, ->(trace_id) { where(trace_id: trace_id) }
scope :in_span, ->(span_id) { where(span_id: span_id) }
```

**Migration**:
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

---

## Relationships Diagram

```
Session (session_id string)
  │
  ├─── Trace 1
  │      ├─── Span 1.1
  │      │      └─── LlmResponse (generation)
  │      └─── Span 1.2
  │             ├─── Child Span 1.2.1
  │             └─── LlmResponse (generation)
  │
  └─── Trace 2
         └─── LlmResponse (generation, no span)
```

---

## Key Design Decisions

### 1. **Session is NOT a model**
- Just a `session_id` string on Trace
- Simpler: no extra table, no extra joins
- Langfuse does it this way too

### 2. **Trace and Span are separate**
- Trace = top-level container
- Span = nestable work unit
- Clear separation of concerns

### 3. **Everything is optional**
- LlmResponse can exist without trace/span (backward compatible)
- Trace can exist without spans (simple workflows)
- Spans can be nested or flat

### 4. **Status tracking**
- All have: running → completed/error
- Simple state machine
- Easy to query incomplete work

### 5. **Duration auto-calculated**
- Set `ended_at` → duration_ms calculated automatically
- No manual calculation needed
- Consistent across all models

---

## Example Queries

```ruby
# Get all traces in a session
Trace.in_session("chat_123").order(created_at: :asc)

# Get all spans in a trace
trace.spans.root_level.includes(:child_spans)

# Get all LLM calls in a trace
trace.llm_responses.order(created_at: :asc)

# Get all LLM calls in a span (including nested)
span.llm_responses + span.child_spans.flat_map(&:llm_responses)

# Find running traces
Trace.running.where("started_at < ?", 5.minutes.ago)

# Get session metrics
traces = Trace.in_session("chat_123")
{
  total_traces: traces.count,
  total_cost: traces.joins(:llm_responses).sum("llm_responses.cost_usd"),
  total_duration: traces.sum(:duration_ms)
}
```

