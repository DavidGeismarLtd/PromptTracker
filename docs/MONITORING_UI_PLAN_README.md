# Monitoring UI Architecture - Planning Documents

This directory contains the complete planning documentation for the Monitoring UI enhancement that reconciles **call-level monitoring** (LLM responses with evaluations) with **execution-level monitoring** (Sessions → Traces → Spans).

---

## 📚 Document Overview

### 1. [MONITORING_UI_ARCHITECTURE.md](./MONITORING_UI_ARCHITECTURE.md)
**The main architectural document** - Read this first!

**Contents**:
- Executive summary and rationale
- Current state analysis
- Detailed view architecture (5 main views)
- Cross-navigation strategy
- Implementation phases (1-4)
- Data flow & relationships
- Success metrics
- Open questions & future considerations

**Key Takeaway**: We're building a **dual-mode architecture** that supports both call-centric and execution-centric views, connected via cross-navigation links.

---

### 2. [MONITORING_UI_VIEWS.md](./MONITORING_UI_VIEWS.md)
**Quick reference guide** for all monitoring views

**Contents**:
- View comparison matrix
- Navigation flow diagram
- Cross-navigation links reference
- When to use each view
- Data hierarchy visualization
- Implementation checklist
- FAQ

**Key Takeaway**: Each view serves a specific purpose. Users can choose the view that matches their current task.

---

### 3. [MONITORING_PHASE1_IMPLEMENTATION.md](./MONITORING_PHASE1_IMPLEMENTATION.md)
**Step-by-step implementation guide** for Phase 1

**Contents**:
- Task breakdown with time estimates
- Detailed code examples for each task
- Testing procedures
- Common issues & solutions
- Performance considerations
- Rollout plan
- Success criteria

**Key Takeaway**: Phase 1 focuses on cross-navigation (2-3 hours of work) to connect existing views.

---

## 🎯 The Core Problem We're Solving

We have **two different ways** to view the same LLM call data:

### Call-Centric View (Existing)
```
LLM Response → Evaluations
```
**Good for**: Quality monitoring, filtering, cost analysis

### Execution-Centric View (New)
```
Session → Trace → Span → LLM Response → Evaluations
```
**Good for**: Workflow debugging, understanding execution flow

### The Solution
**Support both!** Connect them with cross-navigation links so users can switch between views based on their current task.

---

## 🏗️ Architecture Summary

### 5 Main Views

| View | Route | Purpose | Mental Model |
|------|-------|---------|--------------|
| **Dashboard** | `/monitoring` | Overview & alerts | Mixed |
| **Tracked Calls** | `/monitoring/responses` | Quality monitoring | Call-centric |
| **Sessions** | `/monitoring/sessions` | User journeys | Session-centric |
| **Traces** | `/monitoring/traces` | Workflow debugging | Execution-centric |
| **Evaluations** | `/monitoring/evaluations` | Quality review | Evaluation-centric |

### Navigation Structure

```
Dashboard (entry point)
    ├── Tracked Calls ←→ Trace ←→ Session
    ├── Evaluations ←→ LLM Response ←→ Trace
    ├── Sessions → Traces → Spans → LLM Responses
    └── Traces → Spans → LLM Responses
```

### Key Relationships

```
Session (string)
  └── Trace (model)
      ├── Span (model)
      │   └── LLM Response (model) ← CENTRAL ENTITY
      │       └── Evaluation (model)
      └── LLM Response (direct)
          └── Evaluation

Standalone LLM Response (no trace)
  └── Evaluation
```

---

## 📋 Implementation Phases

### Phase 1: Cross-Navigation (Quick Wins) 🎯
**Estimated Time**: 2-3 hours  
**Status**: 📝 Planned

**Tasks**:
1. Add "View in Trace" button to Tracked Calls table
2. Add "View Session" button to Tracked Calls table
3. Show evaluation badges in trace timeline
4. Add trace context card to LLM Response detail page
5. Update navigation menu with dropdown
6. Add "View in Trace" to Evaluations table

**Impact**: High - Users can immediately navigate between views

---

### Phase 2: Enhanced Filtering & Navigation 🔍
**Estimated Time**: 3-4 hours  
**Status**: 📝 Planned

**Tasks**:
1. Add trace name filter to Tracked Calls view
2. Add session filter to Traces view
3. Add breadcrumbs showing context
4. Improve dropdown menu UX

**Impact**: Medium - Improves discoverability

---

### Phase 3: Trace-Level Metrics & Aggregations 📊
**Estimated Time**: 6-8 hours  
**Status**: 📝 Planned

**Tasks**:
1. Add evaluation summary to Trace detail page
2. Add session-level metrics
3. Add trace-level evaluation capability
4. Add charts to dashboard

**Impact**: High - Provides new insights

---

### Phase 4: Advanced Features 🚀
**Estimated Time**: 10-12 hours  
**Status**: 💭 Future

**Tasks**:
1. Trace comparison view
2. Full-text trace search
3. Session replay timeline
4. Trace templates
5. Trace-level alerts

**Impact**: Medium - Nice-to-have features

---

## 🎨 Visual Diagrams

### Navigation Flow
See the Mermaid diagram in the architecture document showing how all views connect.

### Data Model
See the data hierarchy diagram showing relationships between Session, Trace, Span, LLM Response, and Evaluation.

---

## ✅ Why This Approach Is Better

### 1. **Flexibility**
- Users choose the view that matches their mental model
- No forced migration to tracing
- Progressive enhancement

### 2. **Backward Compatibility**
- Existing tracked calls without traces continue to work
- No breaking changes
- Gradual adoption path

### 3. **Use-Case Driven**
- Each view optimized for specific tasks
- Call-centric for quality monitoring
- Execution-centric for workflow debugging

### 4. **No Duplication**
- Same data, different lenses
- Cross-navigation prevents silos
- Single source of truth (LlmResponse)

### 5. **Scalability**
- Hierarchical views handle complex workflows
- Flat views handle high-volume filtering
- Both scale independently

---

## 🚀 Getting Started

### For Implementers
1. Read [MONITORING_UI_ARCHITECTURE.md](./MONITORING_UI_ARCHITECTURE.md) for full context
2. Follow [MONITORING_PHASE1_IMPLEMENTATION.md](./MONITORING_PHASE1_IMPLEMENTATION.md) step-by-step
3. Use [MONITORING_UI_VIEWS.md](./MONITORING_UI_VIEWS.md) as a reference

### For Reviewers
1. Review the architecture document for rationale
2. Check the implementation guide for code quality
3. Verify all cross-navigation links work
4. Test the complete user flows

### For Users
1. Use [MONITORING_UI_VIEWS.md](./MONITORING_UI_VIEWS.md) to understand which view to use
2. Refer to the "When to Use Each View" section
3. Explore cross-navigation links to switch between views

---

## 📊 Success Metrics

### User Adoption
- % of LLM responses with trace_id (target: 30% within 3 months)
- % of users using Sessions/Traces views (target: 50%)
- Average session duration in Monitoring section (should increase)

### Performance
- Page load time for Traces index < 500ms
- Expandable trace timeline renders < 200ms
- Session aggregation queries < 1s

### Quality
- Reduction in "I can't find X" support requests
- Increase in evaluation coverage
- Faster time to debug issues

---

## 🤔 Open Questions

### 1. Should we support trace-level evaluations?
**Proposal**: Add `trace_id` to Evaluations table to evaluate entire workflows

### 2. Should sessions be a database table?
**Current**: Just a string field  
**Alternative**: Create Session model with metadata

### 3. How to handle real-time updates?
**Options**: Turbo Streams, polling, or manual refresh

### 4. How to visualize trace timelines?
**Current**: Nested tree  
**Alternative**: Gantt chart for parallel execution

---

## 📝 Next Steps

1. ✅ Review this plan with stakeholders
2. ⬜ Prioritize Phase 1 tasks
3. ⬜ Create implementation tickets
4. ⬜ Begin with "View in Trace" links (highest impact, lowest effort)
5. ⬜ Gather user feedback after Phase 1
6. ⬜ Iterate based on feedback

---

## 📞 Questions or Feedback?

If you have questions about this plan or suggestions for improvements:
1. Review the architecture document first
2. Check the FAQ in the views reference
3. Open a discussion with specific questions

---

## 📚 Related Documentation

- [TRACING_MODELS.md](./TRACING_MODELS.md) - Database schema for tracing
- [TRACING_IMPLEMENTATION_PLAN.md](./TRACING_IMPLEMENTATION_PLAN.md) - Original tracing implementation
- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) - Overall PromptTracker implementation

---

**Last Updated**: 2025-12-17  
**Status**: Planning Complete, Ready for Implementation  
**Next Milestone**: Phase 1 Implementation

