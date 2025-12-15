# 🎯 Hierarchical Tracing MVP - Ultra Minimal Version

## Overview

Add **Langfuse-style hierarchical tracing** to PromptTracker with the absolute minimum features needed to be useful.

### What We're Building

```
Session (e.g., "Chat Thread #123")
  └── Trace (e.g., "Handle user question")
        ├── Span (e.g., "Search knowledge base")
        └── Generation (e.g., "Generate answer") ← Your existing LlmResponse
```

---

## 🎯 Core Concepts (Langfuse Model)

### 1. **Generation** (Already exists!)
- Your current `LlmResponse` model
- Represents a single LLM API call
- **No changes needed** - just add optional trace/span references

### 2. **Trace** (NEW - Simple)
- Groups related operations together
- Example: "Handle customer support question"
- Has: name, input, output, status, timestamps

### 3. **Span** (NEW - Simple)  
- A step within a trace
- Example: "Search database", "Call weather API"
- Can be nested (parent/child)
- Has: name, type, input, output, timestamps

### 4. **Session** (NEW - Super Simple)
- Groups multiple traces together
- Example: "Chat conversation with user_123"
- Just a `session_id` string that links traces

---

## 📊 Data Model (Minimal)

### New Tables

#### `prompt_tracker_traces`
```ruby
t.string :name, null: false              # "customer_support_request"
t.text :input                            # Initial input
t.text :output                           # Final output
t.string :status, default: "running"     # running, completed, error
t.datetime :started_at, null: false
t.datetime :ended_at
t.integer :duration_ms                   # Auto-calculated
t.string :session_id                     # Links to session (optional)
t.string :user_id                        # Who triggered this
t.jsonb :metadata, default: {}           # Flexible storage
```

#### `prompt_tracker_spans`
```ruby
t.references :trace, null: false         # Parent trace
t.bigint :parent_span_id                 # For nesting (optional)
t.string :name, null: false              # "search_database"
t.string :span_type                      # "function", "tool", "retrieval"
t.text :input
t.text :output
t.string :status, default: "running"
t.datetime :started_at, null: false
t.datetime :ended_at
t.integer :duration_ms
t.jsonb :metadata, default: {}
```

#### Update `prompt_tracker_llm_responses`
```ruby
# Just add these two optional columns:
t.references :trace                      # Optional: which trace?
t.references :span                       # Optional: which span?
```

---

## 🚀 Usage Examples

### Example 1: Simple Trace (No Spans)

```ruby
# Create a trace
trace = PromptTracker::Trace.create!(
  name: "greeting_generation",
  input: "Generate greeting for John",
  user_id: "user_123",
  session_id: "chat_456",
  started_at: Time.current
)

# Track LLM call within trace
result = LlmCallService.track(
  prompt_name: "greeting",
  variables: { name: "John" },
  provider: "openai",
  model: "gpt-4",
  trace: trace  # ← NEW: Link to trace
) { |prompt| call_llm(prompt) }

# End the trace
trace.update!(
  output: result[:response_text],
  status: "completed",
  ended_at: Time.current
)
```

### Example 2: Trace with Spans

```ruby
# Create trace
trace = PromptTracker::Trace.create!(
  name: "customer_support_workflow",
  input: "User asks about billing",
  session_id: "chat_789",
  started_at: Time.current
)

# Step 1: Search knowledge base (span)
search_span = trace.spans.create!(
  name: "search_knowledge_base",
  span_type: "retrieval",
  input: "billing questions",
  started_at: Time.current
)
# ... do search ...
search_span.update!(
  output: "Found 3 articles",
  status: "completed",
  ended_at: Time.current
)

# Step 2: Generate response (span + generation)
response_span = trace.spans.create!(
  name: "generate_response",
  span_type: "function",
  started_at: Time.current
)

result = LlmCallService.track(
  prompt_name: "support_response",
  variables: { context: "..." },
  provider: "openai",
  model: "gpt-4",
  trace: trace,
  span: response_span  # ← Link to span
) { |prompt| call_llm(prompt) }

response_span.update!(
  output: result[:response_text],
  status: "completed",
  ended_at: Time.current
)

# End trace
trace.update!(
  output: result[:response_text],
  status: "completed",
  ended_at: Time.current
)
```

---

## 🎨 UI Views (Minimal)

### 1. Sessions List (`/sessions`)
```
┌─────────────────────────────────────────────────┐
│ Sessions                                        │
├─────────────────────────────────────────────────┤
│ chat_123  │ user_456  │ 5 traces  │ 2 hours ago │
│ chat_124  │ user_789  │ 3 traces  │ 1 hour ago  │
└─────────────────────────────────────────────────┘
```

### 2. Session Detail (`/sessions/:id`)
```
┌─────────────────────────────────────────────────┐
│ Session: chat_123                               │
│ User: user_456                                  │
├─────────────────────────────────────────────────┤
│ Traces:                                         │
│  ├─ greeting_generation (200ms, $0.001)         │
│  ├─ follow_up_question (350ms, $0.002)          │
│  └─ farewell_message (150ms, $0.001)            │
└─────────────────────────────────────────────────┘
```

### 3. Trace Detail (`/traces/:id`)
```
┌─────────────────────────────────────────────────┐
│ Trace: customer_support_workflow                │
│ Status: completed │ Duration: 1,250ms           │
├─────────────────────────────────────────────────┤
│ Timeline:                                       │
│  ├─ search_knowledge_base (span) - 200ms        │
│  └─ generate_response (span) - 1,000ms          │
│      └─ LLM Call (generation) - 950ms           │
└─────────────────────────────────────────────────┘
```

---

## ✅ What's Included in MVP

1. ✅ **3 new models**: Trace, Span, Session (implicit via session_id)
2. ✅ **2 migrations**: Create traces/spans tables, update llm_responses
3. ✅ **3 controllers**: SessionsController, TracesController, SpansController
4. ✅ **3 views**: Sessions list, Session detail, Trace detail
5. ✅ **Backward compatible**: Existing code works without traces

---

## ❌ What's NOT Included (Future)

- ❌ Auto-tracing decorators
- ❌ Distributed tracing (cross-service)
- ❌ Complex visualizations (waterfall charts)
- ❌ Trace context managers
- ❌ Automatic metric aggregation
- ❌ Events (just traces/spans/generations)

---

## 📋 Implementation Checklist

- [ ] Create migrations (traces, spans)
- [ ] Create models (Trace, Span)
- [ ] Update LlmResponse model (add trace/span references)
- [ ] Update LlmCallService (accept trace/span params)
- [ ] Create controllers (Sessions, Traces, Spans)
- [ ] Create views (list + detail pages)
- [ ] Write tests (model + integration)
- [ ] Update documentation

**Estimated Time**: 2-3 days for a single developer

---

## 🎯 Success Criteria

After MVP, you can:
1. ✅ Group LLM calls into logical traces
2. ✅ See all traces in a session (chat thread)
3. ✅ View trace timeline with spans
4. ✅ Track multi-step workflows
5. ✅ Existing code still works (backward compatible)

