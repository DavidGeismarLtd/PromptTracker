# 📁 File Structure - What Goes Where

## Documentation Files (Already Created)

```
docs/
├── TRACING_README.md              # Main index - start here
├── TRACING_QUICK_START.md         # 5-minute guide
├── TRACING_MVP.md                 # Overview and scope
├── TRACING_MODELS.md              # Database schema
├── TRACING_API.md                 # Developer API guide
├── TRACING_UI.md                  # Controllers and views
├── TRACING_IMPLEMENTATION_PLAN.md # Step-by-step plan
├── TRACING_EXAMPLES.md            # Real-world examples
├── TRACING_COMPARISON.md          # vs. Langfuse
└── TRACING_FILE_STRUCTURE.md      # This file
```

---

## Files to Create (Implementation)

### Phase 1: Database & Models

```
db/migrate/
├── YYYYMMDDHHMMSS_create_prompt_tracker_traces.rb
├── YYYYMMDDHHMMSS_create_prompt_tracker_spans.rb
└── YYYYMMDDHHMMSS_add_tracing_to_llm_responses.rb

app/models/prompt_tracker/
├── trace.rb                       # NEW
├── span.rb                        # NEW
└── llm_response.rb                # UPDATE (add associations)
```

### Phase 2: Services

```
app/services/prompt_tracker/
└── llm_call_service.rb            # UPDATE (add trace/span params)
```

### Phase 3: Controllers

```
app/controllers/prompt_tracker/
├── sessions_controller.rb         # NEW
└── traces_controller.rb           # NEW
```

### Phase 4: Views

```
app/views/prompt_tracker/
├── sessions/
│   ├── index.html.erb             # NEW - Sessions list
│   └── show.html.erb              # NEW - Session detail
└── traces/
    ├── index.html.erb             # NEW - Traces list
    ├── show.html.erb              # NEW - Trace detail
    └── _timeline.html.erb         # NEW - Timeline partial
    └── _span_item.html.erb        # NEW - Span partial
    └── _generation_item.html.erb  # NEW - Generation partial
```

### Phase 5: Routes

```
config/
└── routes.rb                      # UPDATE (add sessions/traces routes)
```

### Phase 6: Tests

```
spec/models/prompt_tracker/
├── trace_spec.rb                  # NEW
└── span_spec.rb                   # NEW

spec/factories/prompt_tracker/
├── traces.rb                      # NEW
└── spans.rb                       # NEW

spec/integration/
└── tracing_workflow_spec.rb       # NEW
```

---

## Complete File Tree

```
prompt_tracker/
│
├── docs/                          # ✅ DONE - Documentation
│   ├── TRACING_README.md
│   ├── TRACING_QUICK_START.md
│   ├── TRACING_MVP.md
│   ├── TRACING_MODELS.md
│   ├── TRACING_API.md
│   ├── TRACING_UI.md
│   ├── TRACING_IMPLEMENTATION_PLAN.md
│   ├── TRACING_EXAMPLES.md
│   ├── TRACING_COMPARISON.md
│   └── TRACING_FILE_STRUCTURE.md
│
├── db/migrate/                    # ⏳ TODO - Migrations
│   ├── YYYYMMDDHHMMSS_create_prompt_tracker_traces.rb
│   ├── YYYYMMDDHHMMSS_create_prompt_tracker_spans.rb
│   └── YYYYMMDDHHMMSS_add_tracing_to_llm_responses.rb
│
├── app/
│   ├── models/prompt_tracker/    # ⏳ TODO - Models
│   │   ├── trace.rb              # NEW
│   │   ├── span.rb               # NEW
│   │   └── llm_response.rb       # UPDATE
│   │
│   ├── services/prompt_tracker/  # ⏳ TODO - Services
│   │   └── llm_call_service.rb   # UPDATE
│   │
│   ├── controllers/prompt_tracker/ # ⏳ TODO - Controllers
│   │   ├── sessions_controller.rb # NEW
│   │   └── traces_controller.rb   # NEW
│   │
│   └── views/prompt_tracker/     # ⏳ TODO - Views
│       ├── sessions/
│       │   ├── index.html.erb    # NEW
│       │   └── show.html.erb     # NEW
│       └── traces/
│           ├── index.html.erb    # NEW
│           ├── show.html.erb     # NEW
│           ├── _timeline.html.erb # NEW
│           ├── _span_item.html.erb # NEW
│           └── _generation_item.html.erb # NEW
│
├── config/
│   └── routes.rb                 # ⏳ TODO - Update routes
│
└── spec/                         # ⏳ TODO - Tests
    ├── models/prompt_tracker/
    │   ├── trace_spec.rb         # NEW
    │   └── span_spec.rb          # NEW
    ├── factories/prompt_tracker/
    │   ├── traces.rb             # NEW
    │   └── spans.rb              # NEW
    └── integration/
        └── tracing_workflow_spec.rb # NEW
```

---

## Implementation Order

### Day 1: Database & Models
1. Create migration files (3 files)
2. Create model files (2 new, 1 update)
3. Run migrations
4. Test models in console

### Day 2: Services & UI
5. Update LlmCallService (1 file)
6. Create controllers (2 files)
7. Create views (7 files)
8. Update routes (1 file)
9. Test in browser

### Day 3: Testing & Polish
10. Create test files (5 files)
11. Run tests
12. Fix any issues
13. Update navigation
14. Deploy

---

## File Count Summary

**Documentation**: 10 files ✅ (already created)

**Implementation**:
- Migrations: 3 files
- Models: 2 new + 1 update = 3 files
- Services: 1 update
- Controllers: 2 files
- Views: 7 files
- Routes: 1 update
- Tests: 5 files

**Total to create/update**: ~22 files

**Estimated time**: 2-3 days

---

## Quick Reference

### Where to find code examples:

**Migrations** → `docs/TRACING_MODELS.md` (Schema sections)

**Models** → `docs/TRACING_MODELS.md` (Model sections)

**Service updates** → `docs/TRACING_API.md` (Service Layer Updates)

**Controllers** → `docs/TRACING_UI.md` (Controller sections)

**Views** → `docs/TRACING_UI.md` (View sections)

**Tests** → `docs/TRACING_IMPLEMENTATION_PLAN.md` (Phase 4)

**Usage examples** → `docs/TRACING_EXAMPLES.md`

---

## Checklist Format

Use this to track your progress:

```markdown
## Migrations
- [ ] create_prompt_tracker_traces.rb
- [ ] create_prompt_tracker_spans.rb
- [ ] add_tracing_to_llm_responses.rb
- [ ] rails db:migrate

## Models
- [ ] app/models/prompt_tracker/trace.rb
- [ ] app/models/prompt_tracker/span.rb
- [ ] Update app/models/prompt_tracker/llm_response.rb

## Services
- [ ] Update app/services/prompt_tracker/llm_call_service.rb

## Controllers
- [ ] app/controllers/prompt_tracker/sessions_controller.rb
- [ ] app/controllers/prompt_tracker/traces_controller.rb

## Views
- [ ] app/views/prompt_tracker/sessions/index.html.erb
- [ ] app/views/prompt_tracker/sessions/show.html.erb
- [ ] app/views/prompt_tracker/traces/index.html.erb
- [ ] app/views/prompt_tracker/traces/show.html.erb
- [ ] app/views/prompt_tracker/traces/_timeline.html.erb
- [ ] app/views/prompt_tracker/traces/_span_item.html.erb
- [ ] app/views/prompt_tracker/traces/_generation_item.html.erb

## Routes
- [ ] Update config/routes.rb

## Tests
- [ ] spec/models/prompt_tracker/trace_spec.rb
- [ ] spec/models/prompt_tracker/span_spec.rb
- [ ] spec/factories/prompt_tracker/traces.rb
- [ ] spec/factories/prompt_tracker/spans.rb
- [ ] spec/integration/tracing_workflow_spec.rb

## Polish
- [ ] Update navigation
- [ ] Test in browser
- [ ] Update README
```

---

## Next Steps

1. **Read** `docs/TRACING_QUICK_START.md` for overview
2. **Follow** `docs/TRACING_IMPLEMENTATION_PLAN.md` for step-by-step
3. **Reference** other docs as needed
4. **Check off** files as you create them
5. **Test** after each phase
6. **Deploy** when complete

Good luck! 🚀

