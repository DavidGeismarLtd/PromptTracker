# Monitoring UI Views - Quick Reference

This document provides a quick reference for all monitoring views and their purposes.

---

## View Comparison Matrix

| View | Route | Primary Use Case | Mental Model | Filters | Shows Evaluations? |
|------|-------|------------------|--------------|---------|-------------------|
| **Dashboard** | `/monitoring` | Overview & alerts | Mixed | None | ✅ Failed only |
| **Tracked Calls** | `/monitoring/responses` | Quality monitoring | Call-centric | Prompt, Version, Env, User, Session, Status | ✅ All |
| **Sessions** | `/monitoring/sessions` | User journeys | Session-centric | User, Date | ✅ In timeline |
| **Traces** | `/monitoring/traces` | Workflow debugging | Execution-centric | Name, Status, User, Session | ✅ In timeline |
| **Evaluations** | `/monitoring/evaluations` | Quality review | Evaluation-centric | Prompt, Evaluator, Status | ✅ Primary focus |

---

## Navigation Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         MONITORING SECTION                       │
└─────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
        ┌───────────────┐  ┌──────────┐  ┌──────────────┐
        │   Dashboard   │  │ Tracked  │  │ Evaluations  │
        │   (Overview)  │  │  Calls   │  │  (Quality)   │
        └───────────────┘  └──────────┘  └──────────────┘
                                  │             │
                    ┌─────────────┼─────────────┘
                    │             │
                    ▼             ▼
        ┌───────────────┐  ┌──────────────┐
        │   Sessions    │  │    Traces    │
        │ (User Journey)│  │ (Workflows)  │
        └───────────────┘  └──────────────┘
                    │             │
                    └─────────────┼─────────────┐
                                  │             │
                                  ▼             ▼
                        ┌──────────────┐  ┌──────────┐
                        │ LLM Response │  │   Span   │
                        │   (Detail)   │  │ (Detail) │
                        └──────────────┘  └──────────┘
```

---

## Cross-Navigation Links

### From Tracked Calls View
- **→ Trace**: "View in Trace" button (if `trace_id` present)
- **→ Session**: "View Session" button (if `session_id` present)
- **→ LLM Response Detail**: Click row
- **→ Evaluation**: Click evaluation badge
- **→ Prompt Version**: Click prompt name

### From Sessions View
- **→ Traces**: Expand session row
- **→ Spans**: Expand trace row
- **→ LLM Response**: Click generation in timeline
- **→ Evaluation**: Click evaluation badge in timeline

### From Traces View
- **→ Session**: "View Session" button (if `session_id` present)
- **→ Spans**: Expand trace row
- **→ LLM Response**: Click generation in timeline
- **→ Evaluation**: Click evaluation badge in timeline

### From Evaluations View
- **→ LLM Response**: Click evaluation row
- **→ Trace**: "View in Trace" button (if LLM response has `trace_id`)
- **→ Prompt Version**: Click prompt name

### From LLM Response Detail
- **→ Trace**: Link in "Execution Context" card (if `trace_id` present)
- **→ Span**: Shown in "Execution Context" card (if `span_id` present)
- **→ Session**: Link in "Execution Context" card (if `session_id` present)
- **→ Evaluation**: Click evaluation in list
- **→ Prompt Version**: Click prompt name

---

## When to Use Each View

### Use **Dashboard** when:
- 🎯 You want a quick health check
- 🚨 You need to see recent alerts
- 📊 You want high-level metrics

### Use **Tracked Calls** when:
- 🔍 You need to filter by specific criteria
- 📉 You're investigating quality issues
- 💰 You're tracking costs
- ⚡ You're analyzing performance
- 🐛 You're debugging individual calls

### Use **Sessions** when:
- 👤 You're investigating a user's journey
- 💬 You're debugging a conversation
- 🔄 You want to see all related workflows
- 📅 You're analyzing user behavior over time

### Use **Traces** when:
- 🔄 You're debugging a workflow
- 🏗️ You want to understand execution flow
- ⏱️ You're analyzing performance bottlenecks
- 🔗 You need to see step-by-step execution
- 🐛 You're debugging multi-step processes

### Use **Evaluations** when:
- ✅ You're reviewing quality metrics
- 📊 You want to see evaluation trends
- 🔍 You're investigating failed evaluations
- 👥 You need to queue human reviews
- 📈 You're analyzing evaluator performance

---

## Data Hierarchy

```
Session (logical grouping)
  └── Trace (workflow execution)
      ├── Span (execution step)
      │   └── LLM Response (generation)
      │       └── Evaluation (quality check)
      └── LLM Response (direct trace call)
          └── Evaluation (quality check)

Standalone LLM Response (no trace)
  └── Evaluation (quality check)
```

---

## View Details

### 1. Dashboard (`/monitoring`)

**Purpose**: High-level overview and alerts

**Sections**:
- 🚨 **Alerts**: Failed evaluations requiring attention
- 📊 **Quick Stats**: Total calls, avg score, error rate, active sessions
- 📈 **Recent Activity**: Last 20 tracked calls
- 🔗 **Quick Links**: Jump to other views

**Best For**: Daily health checks, spotting issues quickly

---

### 2. Tracked Calls (`/monitoring/responses`)

**Purpose**: Flat list of all LLM calls with powerful filtering

**Columns**:
- Prompt & Version
- Input/Output preview
- Evaluations (badges)
- Status
- Cost
- Response time
- Environment
- User
- Session
- Created at

**Filters**:
- Prompt
- Version
- Environment
- User
- Session
- Status (success/error/timeout)
- Evaluation status (passed/failed/pending)
- Date range

**Actions**:
- Click row → LLM Response detail
- "View in Trace" → Trace detail (if traced)
- "View Session" → Session view (if in session)

**Best For**: Quality monitoring, cost analysis, debugging individual calls

---

### 3. Sessions (`/monitoring/sessions`)

**Purpose**: Group related traces by user session

**List View Columns**:
- Session ID
- User
- Trace count
- Total cost
- Duration
- Status
- Started at

**Expandable Hierarchy**:
```
Session Row
  └── Traces Table (nested)
      └── Timeline (nested)
          ├── Spans (expandable tree)
          └── LLM Responses (with evaluations)
```

**Filters**:
- User
- Date range
- Status

**Best For**: User journey analysis, conversation debugging, session-level insights

---

### 4. Traces (`/monitoring/traces`)

**Purpose**: View individual workflow executions

**List View Columns**:
- Trace name
- Session ID
- Span count
- LLM call count
- Duration
- Cost
- Status
- Started at

**Expandable Timeline**:
```
Trace Row
  └── Timeline
      ├── Root Spans (expandable)
      │   ├── Child Spans (recursive)
      │   └── LLM Responses (with evaluations)
      └── Orphan LLM Responses (not in any span)
```

**Filters**:
- Trace name
- Status
- User
- Session
- Date range

**Actions**:
- Click trace → Trace detail page
- "View Session" → Session view (if in session)
- Expand → See timeline inline

**Best For**: Workflow debugging, performance analysis, execution flow understanding

---

### 5. Evaluations (`/monitoring/evaluations`)

**Purpose**: Focus on quality metrics and review

**List View Columns**:
- Prompt & Version
- Evaluator type
- Score
- Passed/Failed
- Feedback
- Created at

**Filters**:
- Prompt
- Version
- Evaluator type
- Status (passed/failed)
- Date range

**Actions**:
- Click row → Evaluation detail
- "View LLM Response" → LLM Response detail
- "View in Trace" → Trace detail (if traced)

**Best For**: Quality review, evaluator performance analysis, human review queue

---

## Implementation Checklist

### Phase 1: Cross-Navigation (Quick Wins)
- [ ] Add "View in Trace" button to Tracked Calls table
- [ ] Add "View Session" button to Tracked Calls table
- [ ] Show evaluation badges in trace timeline
- [ ] Add trace context card to LLM Response detail page
- [ ] Update navigation menu with dropdown

### Phase 2: Enhanced Filtering
- [ ] Add trace name filter to Tracked Calls
- [ ] Add session filter to Traces
- [ ] Add breadcrumbs showing context
- [ ] Add "View in Trace" to Evaluations table

### Phase 3: Metrics & Aggregations
- [ ] Add evaluation summary to Trace detail
- [ ] Add session-level metrics
- [ ] Add charts to dashboard

---

## FAQ

**Q: Should I always use tracing?**  
A: No! Tracing is optional. Use it when you have multi-step workflows. Simple single-call use cases don't need tracing.

**Q: Can I see evaluations in the trace timeline?**  
A: Yes! Phase 1 will add evaluation badges to the timeline view.

**Q: How do I navigate from a tracked call to its trace?**  
A: Click the "View in Trace" button in the Tracked Calls table (only visible if the call has a trace).

**Q: What's the difference between Sessions and Traces?**  
A: Sessions group multiple traces together (e.g., a user conversation). Traces represent individual workflows (e.g., one RAG query).

**Q: Can I filter tracked calls by trace name?**  
A: Yes! This will be added in Phase 2.

**Q: Will this break existing code?**  
A: No! All existing tracked calls without traces will continue to work. Tracing is purely additive.


