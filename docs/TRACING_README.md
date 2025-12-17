# 🔍 Hierarchical Tracing - Complete Guide

## 📚 Documentation Index

This is the **ultra-minimal MVP** for adding Langfuse-style hierarchical tracing to PromptTracker.

### Quick Links

**⚡ START HERE**: **[TRACING_QUICK_START.md](TRACING_QUICK_START.md)** - 5-minute overview + implementation checklist

**Detailed Documentation**:
1. **[TRACING_MVP.md](TRACING_MVP.md)** - Overview and core concepts
2. **[TRACING_MODELS.md](TRACING_MODELS.md)** - Database schema and model definitions
3. **[TRACING_API.md](TRACING_API.md)** - How to use tracing in your code
4. **[TRACING_UI.md](TRACING_UI.md)** - Controllers and views
5. **[TRACING_IMPLEMENTATION_PLAN.md](TRACING_IMPLEMENTATION_PLAN.md)** - Step-by-step implementation
6. **[TRACING_EXAMPLES.md](TRACING_EXAMPLES.md)** - Real-world usage examples
7. **[TRACING_COMPARISON.md](TRACING_COMPARISON.md)** - How this compares to Langfuse

---

## 🎯 What Is This?

Add **hierarchical tracing** to PromptTracker to:
- Group related LLM calls into **traces** (workflows)
- Organize traces into **sessions** (conversations/threads)
- Track **spans** (steps within a workflow)
- Visualize execution flow in the UI

### Before (Current)
```
LlmResponse 1 (isolated)
LlmResponse 2 (isolated)
LlmResponse 3 (isolated)
```

### After (With Tracing)
```
Session: "chat_123"
  ├─ Trace: "greeting" (200ms, $0.001)
  │   └─ LLM Call
  ├─ Trace: "question_1" (1,250ms, $0.003)
  │   ├─ Span: "search_kb" (200ms)
  │   └─ Span: "generate_answer" (1,000ms)
  │       └─ LLM Call
  └─ Trace: "question_2" (850ms, $0.002)
      └─ LLM Call
```

---

## 🚀 Quick Start

### 1. Read the Overview
Start with **[TRACING_MVP.md](TRACING_MVP.md)** to understand:
- Core concepts (Trace, Span, Session, Generation)
- Data model (3 simple tables)
- What's included vs. what's not

### 2. Understand the Models
Read **[TRACING_MODELS.md](TRACING_MODELS.md)** to see:
- Database schema
- Model definitions
- Relationships

### 3. Learn the API
Read **[TRACING_API.md](TRACING_API.md)** to learn:
- How to create traces
- How to add spans
- How to link LLM calls
- Error handling

### 4. See Examples
Read **[TRACING_EXAMPLES.md](TRACING_EXAMPLES.md)** for:
- Chat bot example
- RAG pipeline example
- Multi-step workflows
- Nested spans

### 5. Implement It
Follow **[TRACING_IMPLEMENTATION_PLAN.md](TRACING_IMPLEMENTATION_PLAN.md)**:
- Day 1: Database & models
- Day 2: Services & UI
- Day 3: Testing & polish

---

## 📊 Core Concepts (Quick Reference)

### Session
- **What**: A group of related traces (e.g., chat conversation)
- **How**: Just a `session_id` string
- **Example**: `"chat_user123_conv456"`

### Trace
- **What**: A single workflow/request (e.g., "answer question")
- **Fields**: name, input, output, status, timestamps
- **Example**: "rag_question_answering"

### Span
- **What**: A step within a trace (e.g., "search database")
- **Fields**: name, type, input, output, timestamps
- **Can nest**: Parent/child relationships
- **Example**: "retrieve_documents" (type: "retrieval")

### Generation
- **What**: Your existing `LlmResponse` model
- **Change**: Add optional `trace_id` and `span_id`
- **Example**: LLM API call with tokens, cost, etc.

---

## 💻 Usage (Quick Reference)

### Simple (No Spans)
```ruby
trace = PromptTracker::Trace.create!(
  name: "greeting",
  session_id: "chat_123",
  started_at: Time.current
)

result = LlmCallService.track(
  prompt_name: "greeting",
  variables: { name: "John" },
  provider: "openai",
  model: "gpt-4",
  trace: trace  # ← Link to trace
) { |prompt| call_llm(prompt) }

trace.complete!(output: result[:response_text])
```

### With Spans
```ruby
trace = PromptTracker::Trace.create!(
  name: "rag_qa",
  session_id: "chat_123",
  started_at: Time.current
)

# Step 1: Search
search_span = trace.spans.create!(
  name: "search_kb",
  span_type: "retrieval",
  started_at: Time.current
)
docs = search_knowledge_base(query)
search_span.complete!(output: "Found #{docs.count} docs")

# Step 2: Generate
gen_span = trace.spans.create!(
  name: "generate_answer",
  span_type: "function",
  started_at: Time.current
)

result = LlmCallService.track(
  prompt_name: "answer",
  variables: { context: docs },
  provider: "openai",
  model: "gpt-4",
  trace: trace,
  span: gen_span  # ← Link to span
) { |prompt| call_llm(prompt) }

gen_span.complete!(output: result[:response_text])
trace.complete!(output: result[:response_text])
```

---

## 🎨 UI Views

### Sessions List (`/sessions`)
See all conversations/threads with metrics.

### Session Detail (`/sessions/:id`)
See all traces in a session (like a chat history).

### Trace Detail (`/traces/:id`)
See execution timeline with spans and LLM calls.

---

## ✅ What's Included

- ✅ 2 new models (Trace, Span)
- ✅ 3 migrations (traces, spans, update llm_responses)
- ✅ Updated LlmCallService (accepts trace/span params)
- ✅ 2 controllers (Sessions, Traces)
- ✅ 5 views (list + detail pages)
- ✅ 100% backward compatible (existing code works)
- ✅ Simple & clean (no JavaScript, no complex viz)

---

## ❌ What's NOT Included (Future)

- ❌ Auto-tracing decorators
- ❌ Distributed tracing (cross-service)
- ❌ Waterfall charts / complex visualizations
- ❌ Trace context managers
- ❌ Automatic metric aggregation
- ❌ Events (just traces/spans/generations)

---

## 📋 Implementation Checklist

Follow **[TRACING_IMPLEMENTATION_PLAN.md](TRACING_IMPLEMENTATION_PLAN.md)** for detailed steps.

**High-level**:
1. Create migrations (traces, spans, update llm_responses)
2. Create models (Trace, Span)
3. Update LlmResponse model (add associations)
4. Update LlmCallService (accept trace/span params)
5. Create controllers (Sessions, Traces)
6. Create views (list + detail)
7. Write tests (models + integration)
8. Update navigation

**Estimated Time**: 2-3 days

---

## 🎓 Learning Path

**If you're new to tracing**:
1. Read [TRACING_MVP.md](TRACING_MVP.md) - Understand the "why"
2. Read [TRACING_EXAMPLES.md](TRACING_EXAMPLES.md) - See real examples
3. Read [TRACING_API.md](TRACING_API.md) - Learn the API
4. Follow [TRACING_IMPLEMENTATION_PLAN.md](TRACING_IMPLEMENTATION_PLAN.md) - Build it

**If you want to implement it**:
1. Read [TRACING_MODELS.md](TRACING_MODELS.md) - Understand the schema
2. Follow [TRACING_IMPLEMENTATION_PLAN.md](TRACING_IMPLEMENTATION_PLAN.md) - Step by step
3. Reference [TRACING_UI.md](TRACING_UI.md) - For controllers/views
4. Reference [TRACING_API.md](TRACING_API.md) - For service updates

**If you want to use it**:
1. Read [TRACING_API.md](TRACING_API.md) - Learn the API
2. Read [TRACING_EXAMPLES.md](TRACING_EXAMPLES.md) - Copy/paste patterns
3. Reference [TRACING_MODELS.md](TRACING_MODELS.md) - For queries

---

## 🔑 Key Design Decisions

1. **Session is NOT a model** - Just a string, simpler
2. **Trace and Span are separate** - Clear separation
3. **Everything is optional** - Backward compatible
4. **Status tracking** - running → completed/error
5. **Duration auto-calculated** - Set ended_at, duration_ms calculated
6. **No JavaScript** - Server-rendered HTML only
7. **No complex viz** - Simple hierarchical lists

---

## 📞 Questions?

- **What's a trace?** - A single workflow/request
- **What's a span?** - A step within a trace
- **What's a session?** - A group of related traces
- **Do I have to use tracing?** - No! It's optional
- **Will my existing code break?** - No! 100% backward compatible
- **How long to implement?** - 2-3 days for MVP

---

## 🎯 Success Criteria

After implementing, you should be able to:
1. ✅ Group LLM calls into logical traces
2. ✅ See all traces in a session (chat thread)
3. ✅ View trace timeline with spans
4. ✅ Track multi-step workflows (RAG, agents, etc.)
5. ✅ Existing code still works without changes

---

## 📖 Based On

This design is based on **Langfuse's data model**:
- [Langfuse Data Model](https://langfuse.com/docs/observability/data-model)
- [Langfuse Sessions](https://langfuse.com/docs/observability/features/sessions)
- [Langfuse Observation Types](https://langfuse.com/docs/observability/features/observation-types)

**Simplified for MVP**: We kept only the essential features needed to be useful.
