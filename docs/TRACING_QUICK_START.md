# ⚡ Quick Start - 5 Minute Guide

## What You're Building

Add hierarchical tracing to PromptTracker in **2-3 days** with this ultra-minimal MVP.

---

## 📖 Read This First (5 minutes)

### 1. Core Concepts

**Session** = A conversation/thread (e.g., chat with user_123)
- Just a `session_id` string
- Groups multiple traces together

**Trace** = One workflow/request (e.g., "answer question")
- Has: name, input, output, status, timestamps
- Contains: spans and LLM calls

**Span** = A step within a trace (e.g., "search database")
- Has: name, type, input, output, timestamps
- Can be nested (parent/child)

**Generation** = Your existing `LlmResponse` (LLM API call)
- No changes needed!
- Just add optional trace_id and span_id

### 2. Visual Example

```
Session: "chat_user123"
  │
  ├─ Trace: "greeting" (200ms)
  │   └─ LLM Call (gpt-4, $0.001)
  │
  ├─ Trace: "question_1" (1,250ms)
  │   ├─ Span: "search_kb" (200ms)
  │   └─ Span: "generate_answer" (1,000ms)
  │       └─ LLM Call (gpt-4, $0.003)
  │
  └─ Trace: "question_2" (850ms)
      └─ LLM Call (gpt-4, $0.002)
```

---

## 🚀 Implementation (2-3 days)

### Day 1: Database & Models

**Step 1**: Create migrations
```bash
rails g migration CreatePromptTrackerTraces
rails g migration CreatePromptTrackerSpans
rails g migration AddTracingToLlmResponses
```

**Step 2**: Copy schema from `docs/TRACING_MODELS.md`

**Step 3**: Create models
- `app/models/prompt_tracker/trace.rb`
- `app/models/prompt_tracker/span.rb`
- Update `app/models/prompt_tracker/llm_response.rb`

**Step 4**: Run migrations
```bash
rails db:migrate
```

### Day 2: Services & UI

**Step 5**: Update LlmCallService
- Add `trace:` and `span:` parameters
- See `docs/TRACING_API.md`

**Step 6**: Create controllers
- `app/controllers/prompt_tracker/sessions_controller.rb`
- `app/controllers/prompt_tracker/traces_controller.rb`

**Step 7**: Create views
- Sessions list & detail
- Traces list & detail
- Timeline partials

**Step 8**: Add routes
```ruby
resources :sessions, only: [:index, :show]
resources :traces, only: [:index, :show]
```

### Day 3: Testing & Polish

**Step 9**: Write tests
- Model tests (Trace, Span)
- Integration tests
- Create factories

**Step 10**: Update navigation
- Add "Sessions" and "Traces" links

**Step 11**: Test end-to-end
- Create a trace manually
- View in UI
- Verify everything works

---

## 💻 Usage Examples

### Simple (No Spans)

```ruby
# Create trace
trace = PromptTracker::Trace.create!(
  name: "greeting",
  session_id: "chat_123",
  started_at: Time.current
)

# Track LLM call
result = LlmCallService.track(
  prompt_name: "greeting",
  variables: { name: "John" },
  provider: "openai",
  model: "gpt-4",
  trace: trace  # ← Link to trace
) { |prompt| call_llm(prompt) }

# Complete trace
trace.complete!(output: result[:response_text])
```

### With Spans

```ruby
# Create trace
trace = PromptTracker::Trace.create!(
  name: "rag_qa",
  session_id: "chat_123",
  started_at: Time.current
)

# Step 1: Search (span)
search_span = trace.spans.create!(
  name: "search_kb",
  span_type: "retrieval",
  started_at: Time.current
)
docs = search_knowledge_base(query)
search_span.complete!(output: "Found #{docs.count} docs")

# Step 2: Generate (span + LLM call)
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

## 📚 Full Documentation

For detailed information, see:

1. **[TRACING_README.md](TRACING_README.md)** - Complete guide and index
2. **[TRACING_MVP.md](TRACING_MVP.md)** - Detailed overview
3. **[TRACING_IMPLEMENTATION_PLAN.md](TRACING_IMPLEMENTATION_PLAN.md)** - Step-by-step plan
4. **[TRACING_EXAMPLES.md](TRACING_EXAMPLES.md)** - Real-world examples
5. **[TRACING_COMPARISON.md](TRACING_COMPARISON.md)** - Comparison with Langfuse

---

## ✅ Checklist

Copy this to track your progress:

```markdown
## Phase 1: Database & Models
- [ ] Create traces migration
- [ ] Create spans migration
- [ ] Update llm_responses migration
- [ ] Create Trace model
- [ ] Create Span model
- [ ] Update LlmResponse model
- [ ] Run migrations

## Phase 2: Services & UI
- [ ] Update LlmCallService
- [ ] Create SessionsController
- [ ] Create TracesController
- [ ] Create sessions/index view
- [ ] Create sessions/show view
- [ ] Create traces/index view
- [ ] Create traces/show view
- [ ] Create timeline partials
- [ ] Add routes

## Phase 3: Testing
- [ ] Trace model tests
- [ ] Span model tests
- [ ] Integration tests
- [ ] Create factories
- [ ] Test end-to-end

## Phase 4: Polish
- [ ] Update navigation
- [ ] Update README
- [ ] Test in browser
- [ ] Deploy
```

---

## 🎯 Success Criteria

After implementation, you should be able to:

1. ✅ Create a trace with `Trace.create!`
2. ✅ Add spans with `trace.spans.create!`
3. ✅ Link LLM calls with `trace:` parameter
4. ✅ View sessions at `/sessions`
5. ✅ View session detail at `/sessions/:id`
6. ✅ View trace detail at `/traces/:id`
7. ✅ See hierarchical timeline with spans and LLM calls
8. ✅ Existing code still works (backward compatible)

---

## 🆘 Need Help?

**Stuck on database?** → See `docs/TRACING_MODELS.md`

**Stuck on API?** → See `docs/TRACING_API.md`

**Stuck on UI?** → See `docs/TRACING_UI.md`

**Need examples?** → See `docs/TRACING_EXAMPLES.md`

**Want to compare with Langfuse?** → See `docs/TRACING_COMPARISON.md`

---

## 🚀 Next Steps

After MVP is working:

1. **Use it!** - Start creating traces in your app
2. **Gather feedback** - See what's missing
3. **Iterate** - Add features as needed

**Future enhancements** (see `docs/TRACING_COMPARISON.md`):
- Phase 2: Enhanced UI (waterfall charts, filtering)
- Phase 3: Developer Experience (auto-instrumentation)
- Phase 4: Advanced Features (distributed tracing, events)
- Phase 5: Scale & Performance (async processing)

---

## 💡 Pro Tips

1. **Start simple** - Use traces without spans first
2. **Use session_id** - Group related traces (e.g., chat conversations)
3. **Name descriptively** - "rag_question" not "trace_1"
4. **Always complete** - Call `trace.complete!` or `trace.mark_error!`
5. **Keep input/output short** - Use metadata for large data

---

## 📊 What You Get

**Before**:
- Flat list of LLM calls
- No grouping or context
- Hard to debug multi-step workflows

**After**:
- Hierarchical traces with spans
- Sessions group conversations
- Clear execution timeline
- Easy to debug complex workflows

**Time investment**: 2-3 days
**Value**: Langfuse-style observability in your app

