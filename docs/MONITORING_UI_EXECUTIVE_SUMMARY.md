# Monitoring UI Architecture - Executive Summary

## TL;DR

**Problem**: We have two different ways to view LLM calls - flat lists (call-centric) and hierarchical traces (execution-centric). How do we reconcile them?

**Solution**: Support both! Build a dual-mode architecture with cross-navigation links. Users pick the view that matches their current task.

**Effort**: Phase 1 is ~2-3 hours of work for immediate value.

---

## The Situation

### What We Have Now

**Call-Centric Views** (Existing):
- Tracked Calls: Flat list with filters
- Evaluations: Quality metrics
- Good for: Quality monitoring, debugging individual calls

**Execution-Centric Views** (New):
- Sessions: User journeys
- Traces: Workflow execution with expandable spans
- Good for: Debugging multi-step workflows, understanding execution flow

### The Challenge

These are **two different mental models** for the same data. Should we:
1. Force users to choose one?
2. Merge them into a single view?
3. Support both separately?

---

## The Proposed Solution

### Core Principle

> **Support both mental models and provide seamless navigation between them.**

### Why This Works

1. **LlmResponse is the central entity** - Everything connects through it
2. **Tracing is optional** - `trace_id` and `span_id` can be null
3. **Same data, different lenses** - No duplication
4. **Cross-navigation** - Users can switch between views

### The Architecture

```
5 Main Views:
├── Dashboard (overview & alerts)
├── Tracked Calls (call-centric) ←→ Traces (execution-centric)
├── Evaluations (quality-centric) ←→ Sessions (session-centric)
└── All connected via cross-navigation links
```

---

## Key Benefits

### 1. Backward Compatible
- Existing tracked calls without traces continue to work
- No breaking changes
- Gradual adoption path

### 2. Flexible
- Users choose the view that matches their task
- No forced migration to tracing
- Progressive enhancement

### 3. Use-Case Driven
- **Quality monitoring?** → Use Tracked Calls view
- **Workflow debugging?** → Use Traces view
- **User journey analysis?** → Use Sessions view
- **Quality review?** → Use Evaluations view

### 4. No Duplication
- Same `LlmResponse` records
- Different views of the same data
- Single source of truth

---

## Implementation Plan

### Phase 1: Cross-Navigation (Quick Wins) 🎯
**Time**: 2-3 hours  
**Impact**: High

**What We'll Build**:
1. "View in Trace" button in Tracked Calls table
2. "View Session" button in Tracked Calls table
3. Evaluation badges in trace timeline
4. Trace context card on LLM Response detail page
5. Dropdown navigation menu
6. "View in Trace" button in Evaluations table

**Result**: Users can navigate seamlessly between all views

---

### Phase 2: Enhanced Filtering (Later)
**Time**: 3-4 hours  
**Impact**: Medium

- Add trace name filter to Tracked Calls
- Add session filter to Traces
- Improve breadcrumbs and navigation

---

### Phase 3: Metrics & Aggregations (Later)
**Time**: 6-8 hours  
**Impact**: High

- Evaluation summary on Trace detail page
- Session-level metrics
- Trace-level evaluations
- Dashboard charts

---

### Phase 4: Advanced Features (Future)
**Time**: 10-12 hours  
**Impact**: Medium

- Trace comparison
- Full-text search
- Session replay
- Trace templates

---

## Example User Flows

### Flow 1: Quality Monitoring
```
1. Start at Tracked Calls view
2. Filter by "failed evaluations"
3. Click a call to see details
4. See "Execution Context" card showing trace
5. Click "View in Trace" to see full workflow
6. Understand why it failed in context
```

### Flow 2: Workflow Debugging
```
1. Start at Traces view
2. Find a failed trace
3. Expand to see timeline
4. See evaluation badges on each LLM call
5. Click failed evaluation to see details
6. Click "View Response" to see full call details
```

### Flow 3: User Journey Analysis
```
1. Start at Sessions view
2. Find user's session
3. Expand to see all traces
4. Expand a trace to see timeline
5. See all LLM calls and evaluations
6. Understand complete user journey
```

---

## What Makes This Better Than Alternatives

### Alternative 1: Force Everyone to Use Tracing
❌ **Problem**: Breaking change, forces complexity on simple use cases

### Alternative 2: Merge Into Single View
❌ **Problem**: Confusing UI, tries to do too much

### Alternative 3: Keep Completely Separate
❌ **Problem**: Data silos, users can't find related information

### Our Approach: Dual-Mode with Cross-Navigation
✅ **Benefits**:
- Backward compatible
- Each view optimized for its use case
- Easy to navigate between views
- No data duplication
- Progressive enhancement

---

## Technical Highlights

### Data Model (Already Exists!)
```ruby
LlmResponse
  belongs_to :trace, optional: true
  belongs_to :span, optional: true
  belongs_to :prompt_version
  has_many :evaluations

Trace
  has_many :spans
  has_many :llm_responses

Span
  belongs_to :trace
  has_many :llm_responses
```

### Cross-Navigation (What We'll Add)
```erb
<!-- In Tracked Calls table -->
<% if llm_response.trace_id.present? %>
  <%= link_to "View in Trace", monitoring_trace_path(llm_response.trace_id) %>
<% end %>

<!-- In Trace timeline -->
<% if generation.evaluations.any? %>
  <% generation.evaluations.each do |eval| %>
    <%= link_to eval.evaluator_key, monitoring_evaluation_path(eval) %>
  <% end %>
<% end %>
```

---

## Success Criteria

### Phase 1 Success
- ✅ All cross-navigation links work
- ✅ No N+1 query issues
- ✅ Page load times < 500ms
- ✅ Users can navigate between views seamlessly

### Long-Term Success
- 30% of LLM responses have trace_id (within 3 months)
- 50% of users use Sessions/Traces views
- Reduced support requests about finding data
- Faster debugging of issues

---

## Risks & Mitigations

### Risk 1: Users Don't Understand When to Use Each View
**Mitigation**: Clear documentation, tooltips, and "When to Use" guide

### Risk 2: Performance Issues with Nested Queries
**Mitigation**: Eager loading, pagination, caching

### Risk 3: Confusion from Too Many Views
**Mitigation**: Grouped dropdown menu, clear naming, breadcrumbs

---

## Decision Points

### ✅ Decided
1. Support both call-centric and execution-centric views
2. Use cross-navigation links to connect them
3. Keep tracing optional (backward compatible)
4. Implement in phases starting with quick wins

### 🤔 Open Questions
1. Should we support trace-level evaluations? (evaluate entire workflow)
2. Should sessions be a database table? (currently just a string)
3. Real-time updates via Turbo Streams or manual refresh?
4. Add Gantt chart view for trace timelines?

---

## Next Steps

1. ✅ Review this plan
2. ⬜ Approve Phase 1 implementation
3. ⬜ Create implementation tickets
4. ⬜ Start with highest-impact tasks (cross-navigation links)
5. ⬜ Deploy to staging for testing
6. ⬜ Gather user feedback
7. ⬜ Plan Phase 2 based on learnings

---

## Questions?

See the full documentation:
- [MONITORING_UI_ARCHITECTURE.md](./MONITORING_UI_ARCHITECTURE.md) - Complete architecture
- [MONITORING_UI_VIEWS.md](./MONITORING_UI_VIEWS.md) - View reference guide
- [MONITORING_PHASE1_IMPLEMENTATION.md](./MONITORING_PHASE1_IMPLEMENTATION.md) - Implementation guide
- [MONITORING_UI_PLAN_README.md](./MONITORING_UI_PLAN_README.md) - Documentation index

---

**Recommendation**: Approve Phase 1 and start implementation. It's low-risk, high-impact, and takes only 2-3 hours.

