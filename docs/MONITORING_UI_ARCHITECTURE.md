# Monitoring UI Architecture Plan

## Executive Summary

This document outlines the architectural plan for organizing the Monitoring section of PromptTracker to support both **flat call-level monitoring** (LLM responses with evaluations) and **hierarchical execution-level monitoring** (Sessions → Traces → Spans).

**Key Decision**: Keep both systems as complementary views rather than forcing users into one paradigm.

---

## Current State Analysis

### Existing Monitoring Views

1. **Dashboard** (`/monitoring`)
   - Shows failing evaluations alerts
   - Recent tracked calls
   - High-level metrics

2. **LLM Responses** (`/monitoring/responses`)
   - Flat list of all tracked LLM calls
   - Filters: prompt, version, environment, user, session, status
   - Shows evaluations inline

3. **Evaluations** (`/monitoring/evaluations`)
   - List of all evaluations (passed/failed)
   - Filters: prompt, evaluator type, status
   - Links to LLM response detail

4. **Prompt Versions** (`/monitoring/prompts/:id/versions/:id`)
   - Shows tracked calls for specific version
   - Auto-evaluator configurations
   - Version-specific metrics

### New Tracing Views (Recently Added)

5. **Traces** (`/monitoring/traces`)
   - List of execution traces
   - Expandable to show Spans → LLM Responses
   - Timeline visualization

6. **Sessions** (`/monitoring/sessions`)
   - Groups traces by session_id
   - Expandable: Session → Traces → Spans → LLM Responses
   - Multi-level hierarchy

---

## The Problem

We now have **two different mental models** for viewing the same data:

### Model A: Call-Centric (Existing)
```
LLM Response (the unit of interest)
├── Belongs to: Prompt Version
├── Has many: Evaluations
└── Context: user_id, session_id, environment
```

**Use Case**: "Show me all failed calls for prompt X in production"

### Model B: Execution-Centric (New)
```
Session (user conversation)
└── Traces (workflows)
    └── Spans (steps)
        └── LLM Responses (generations)
            └── Evaluations
```

**Use Case**: "Show me the execution flow of this RAG pipeline"

### The Tension

- **Model A** is great for: Quality monitoring, debugging individual calls, filtering by evaluation results
- **Model B** is great for: Understanding workflows, debugging multi-step processes, seeing execution context

**Question**: Should we force users to choose one, or support both?

---

## Proposed Solution: Dual-Mode Architecture

### Core Principle

> **Support both mental models and provide seamless navigation between them.**

Every `LlmResponse` can optionally belong to a `Trace` and `Span`. This means:
- Standalone calls (no trace) → Only visible in call-centric views
- Traced calls → Visible in BOTH views with cross-links

### Why This Is Better

1. **Backward Compatible**: Existing tracked calls without traces continue to work
2. **Progressive Enhancement**: Developers can add tracing when they need it
3. **Use-Case Driven**: Users pick the view that matches their current task
4. **No Data Duplication**: Same `LlmResponse` records, different lenses
5. **Flexible Adoption**: Teams can adopt tracing gradually

---

## Detailed View Architecture

### 1. Dashboard (Overview)
**Route**: `/monitoring`
**Purpose**: High-level health and quick access

**Sections**:
- **Alerts**: Failing evaluations (already exists)
- **Recent Activity**: Last 20 tracked calls (already exists)
- **Quick Stats**:
  - Total calls today
  - Average evaluation score
  - Error rate
  - Active sessions count
- **Quick Links**: Jump to Sessions, Traces, Tracked Calls, Evaluations

**Rationale**: Dashboard should provide situational awareness and fast navigation to detailed views.

---

### 2. Tracked Calls (Call-Centric)
**Route**: `/monitoring/responses`
**Purpose**: Flat list with powerful filtering for quality monitoring

**Primary Use Cases**:
- Quality assurance: "Show me all calls with failed evaluations"
- Debugging: "Find calls with errors in production"
- Analysis: "What's the average response time for prompt X?"
- Cost tracking: "Show me expensive calls this week"

**Features**:
- **Filters**: prompt, version, environment, user, session, status, evaluation status, date range
- **Columns**: prompt, version, input/output, evaluations, cost, time, environment
- **Actions**:
  - Click row → LLM response detail page
  - **NEW**: "View in Trace" button (if `trace_id` exists)
  - **NEW**: "View Session" button (if `session_id` exists)

**Rationale**: This is the primary view for quality monitoring. Most users will start here when investigating issues or reviewing quality metrics.

---

### 3. Sessions (Session-Centric)
**Route**: `/monitoring/sessions`
**Purpose**: Group related traces by user session

**Primary Use Cases**:
- Multi-turn conversations: "What happened during this user's chat session?"
- User journey analysis: "Show me all workflows this user triggered"
- Session debugging: "Why did this session fail?"

**Features**:
- **List View**: Sessions with metrics (trace count, total cost, duration, status)
- **Expandable Hierarchy**: Session → Traces → Spans → LLM Responses (✅ already implemented)
- **Filters**: user_id, date range, status
- **Session Detail Page**:
  - Timeline of all traces
  - Aggregated metrics
  - User context

**Rationale**: Sessions are the highest level of grouping. This view is essential for understanding user journeys and multi-turn interactions.

---

### 4. Traces (Execution-Centric)
**Route**: `/monitoring/traces`
**Purpose**: View individual workflow executions

**Primary Use Cases**:
- Workflow debugging: "Why did this RAG pipeline fail?"
- Performance analysis: "Which step is slowest?"
- Execution flow: "See the timeline of this multi-step process"

**Features**:
- **List View**: Traces with metrics (span count, LLM call count, duration, cost, status)
- **Expandable Timeline**: Trace → Spans → LLM Responses (✅ already implemented)
- **Filters**: name, status, user, session, date range
- **Trace Detail Page**:
  - Full timeline visualization
  - Span tree with nesting
  - **NEW**: Evaluation results for all LLM responses
  - **NEW**: Aggregated metrics (total cost, total tokens, pass rate)

**Rationale**: Traces are the core unit for understanding execution flow. This view is essential for debugging complex workflows.

---

### 5. Evaluations (Quality-Centric)
**Route**: `/monitoring/evaluations`
**Purpose**: Focus on quality metrics and review

**Primary Use Cases**:
- Quality review: "Show me all failed evaluations"
- Evaluator performance: "How is the LLM Judge evaluator performing?"
- Human review queue: "What needs manual review?"

**Features**:
- **List View**: Evaluations with pass/fail, score, evaluator type
- **Filters**: prompt, version, evaluator type, status (passed/failed), date range
- **Actions**:
  - Click → Evaluation detail page
  - **NEW**: "View LLM Response" button
  - **NEW**: "View in Trace" button (if LLM response has `trace_id`)

**Rationale**: Evaluations are first-class citizens for quality monitoring. This dedicated view makes it easy to review quality trends.

---

## Cross-Navigation Strategy

### Principle: Always Provide Context

Every view should show related data and provide links to other views.

### Navigation Paths

```
Tracked Calls ←→ Trace
    ↓              ↓
Evaluation ←→ LLM Response
    ↓              ↓
  Prompt ←→ Prompt Version
    ↓
 Session
```

### Implementation Details

#### A. Add "View in Trace" Links

**Where**: Tracked Calls table, Evaluation detail page, LLM Response detail page

**Condition**: Only show if `llm_response.trace_id.present?`

**Code**:
```erb
<% if llm_response.trace_id.present? %>
  <%= link_to monitoring_trace_path(llm_response.trace_id),
              class: "btn btn-sm btn-outline-info",
              title: "View in execution trace" do %>
    <i class="bi bi-diagram-2"></i> View in Trace
  <% end %>
<% end %>
```

#### B. Add "View Session" Links

**Where**: Tracked Calls table, Trace detail page

**Condition**: Only show if `session_id.present?`

**Code**:
```erb
<% if session_id.present? %>
  <%= link_to monitoring_sessions_path(session_id: session_id),
              class: "btn btn-sm btn-outline-primary",
              title: "View all traces in this session" do %>
    <i class="bi bi-collection"></i> View Session
  <% end %>
<% end %>
```

#### C. Show Evaluations in Trace Timeline

**Where**: `_generation_item.html.erb` partial (used in trace timeline)

**Purpose**: Show evaluation results inline when viewing traces

**Code**:
```erb
<!-- Add to app/views/prompt_tracker/monitoring/traces/_generation_item.html.erb -->
<% if generation.evaluations.any? %>
  <div class="mt-2">
    <strong class="text-muted small">Evaluations:</strong>
    <% generation.evaluations.each do |eval| %>
      <%= link_to monitoring_evaluation_path(eval),
                  class: "badge #{eval.passed? ? 'bg-success' : 'bg-danger'} text-decoration-none ms-1",
                  title: "#{eval.evaluator_key}: #{eval.score}" do %>
        <%= eval.evaluator_key %>: <%= eval.score.round %>
      <% end %>
    <% end %>
  </div>
<% end %>
```

#### D. Add Trace Context to LLM Response Detail

**Where**: LLM Response show page (`/monitoring/responses/:id`)

**Purpose**: Show trace/span context when viewing individual calls

**Code**:
```erb
<!-- Add to app/views/prompt_tracker/monitoring/llm_responses/show.html.erb -->
<% if @response.trace.present? %>
  <div class="card mb-3">
    <div class="card-header">
      <i class="bi bi-diagram-2"></i> Execution Context
    </div>
    <div class="card-body">
      <dl class="row mb-0">
        <dt class="col-sm-3">Trace</dt>
        <dd class="col-sm-9">
          <%= link_to @response.trace.name, monitoring_trace_path(@response.trace) %>
          <span class="badge bg-secondary"><%= @response.trace.status %></span>
        </dd>

        <% if @response.span.present? %>
          <dt class="col-sm-3">Span</dt>
          <dd class="col-sm-9">
            <%= @response.span.name %>
            <span class="badge bg-info"><%= @response.span.span_type %></span>
          </dd>
        <% end %>

        <% if @response.trace.session_id.present? %>
          <dt class="col-sm-3">Session</dt>
          <dd class="col-sm-9">
            <%= link_to truncate(@response.trace.session_id, length: 40),
                        monitoring_sessions_path(session_id: @response.trace.session_id) %>
          </dd>
        <% end %>
      </dl>
    </div>
  </div>
<% end %>
```

---

## Navigation Menu Structure

### Current State
Simple top-level links: Testing | Monitoring

### Proposed State
Dropdown menu for Monitoring section with all views:

```erb
<li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle <%= 'active' if controller_path.start_with?('prompt_tracker/monitoring') %>"
     href="#"
     role="button"
     data-bs-toggle="dropdown">
    <i class="bi bi-activity"></i> Monitoring
  </a>
  <ul class="dropdown-menu">
    <li>
      <%= link_to monitoring_root_path, class: "dropdown-item" do %>
        <i class="bi bi-speedometer2"></i> Dashboard
      <% end %>
    </li>
    <li><hr class="dropdown-divider"></li>
    <li class="dropdown-header">Call-Level Views</li>
    <li>
      <%= link_to monitoring_llm_responses_path, class: "dropdown-item" do %>
        <i class="bi bi-chat-dots"></i> Tracked Calls
      <% end %>
    </li>
    <li>
      <%= link_to monitoring_evaluations_path, class: "dropdown-item" do %>
        <i class="bi bi-clipboard-check"></i> Evaluations
      <% end %>
    </li>
    <li><hr class="dropdown-divider"></li>
    <li class="dropdown-header">Execution-Level Views</li>
    <li>
      <%= link_to monitoring_sessions_path, class: "dropdown-item" do %>
        <i class="bi bi-collection"></i> Sessions
      <% end %>
    </li>
    <li>
      <%= link_to monitoring_traces_path, class: "dropdown-item" do %>
        <i class="bi bi-diagram-2"></i> Traces
      <% end %>
    </li>
  </ul>
</li>
```

**Rationale**: Grouping views by mental model (call-level vs execution-level) helps users understand the distinction and choose the right view for their task.

---

## Data Flow & Relationships

### Database Schema (Existing)

```
┌─────────────┐
│   Session   │ (logical grouping via session_id string)
└──────┬──────┘
       │ 1:N
       ▼
┌─────────────┐
│    Trace    │
│ session_id  │
└──────┬──────┘
       │ 1:N
       ▼
┌─────────────┐         ┌──────────────┐
│    Span     │         │ PromptVersion│
│  trace_id   │         └──────┬───────┘
│parent_span  │                │ 1:N
└──────┬──────┘                │
       │ 1:N                   │
       ▼                       ▼
┌─────────────────────────────────┐
│        LlmResponse              │
│  trace_id (optional)            │
│  span_id (optional)             │
│  prompt_version_id (required)   │
│  session_id (optional)          │
└──────────────┬──────────────────┘
               │ 1:N
               ▼
        ┌─────────────┐
        │ Evaluation  │
        └─────────────┘
```

### Key Insights

1. **LlmResponse is the central entity**: Everything connects through it
2. **Tracing is optional**: `trace_id` and `span_id` can be null
3. **Session is a string**: Not a database table, just a grouping key
4. **Evaluations are always tied to LlmResponse**: Never directly to Trace/Span

### Query Patterns

#### Call-Centric Queries
```ruby
# Find all failed calls for a prompt
LlmResponse.tracked_calls
  .joins(:prompt_version)
  .where(prompt_versions: { prompt_id: prompt.id })
  .where(status: 'error')

# Find calls with failed evaluations
LlmResponse.tracked_calls
  .joins(:evaluations)
  .where(evaluations: { passed: false })
```

#### Execution-Centric Queries
```ruby
# Find all traces in a session
Trace.where(session_id: session_id)
  .includes(spans: :llm_responses)

# Find all LLM responses in a trace
LlmResponse.where(trace_id: trace.id)
  .includes(:evaluations)
```

#### Cross-Navigation Queries
```ruby
# From LLM Response → Trace
llm_response.trace  # belongs_to association

# From Trace → All Evaluations
trace.llm_responses.flat_map(&:evaluations)

# From Session → All Evaluations
Evaluation.joins(llm_response: :trace)
  .where(traces: { session_id: session_id })
```

---

## Implementation Phases

### Phase 1: Cross-Navigation (Quick Wins) 🎯

**Goal**: Connect existing views with minimal changes

**Tasks**:
1. ✅ Sessions index with expandable traces (DONE)
2. ✅ Traces index with expandable spans (DONE)
3. Add "View in Trace" button to Tracked Calls table
4. Add "View Session" button to Tracked Calls table
5. Show evaluation badges in trace timeline (`_generation_item.html.erb`)
6. Add trace context card to LLM Response detail page

**Estimated Effort**: 2-3 hours
**Impact**: High - Users can immediately navigate between views

---

### Phase 2: Enhanced Filtering & Navigation 🔍

**Goal**: Make it easier to filter and navigate

**Tasks**:
1. Add trace name filter to Tracked Calls view
2. Add session filter to Traces view (filter by session_id)
3. Update navigation menu with dropdown structure
4. Add "View in Trace" button to Evaluations table
5. Add breadcrumbs showing current context (Session → Trace → Span)

**Estimated Effort**: 3-4 hours
**Impact**: Medium - Improves discoverability

---

### Phase 3: Trace-Level Metrics & Aggregations 📊

**Goal**: Show aggregated metrics at trace/session level

**Tasks**:
1. Add evaluation summary to Trace detail page:
   - Total evaluations
   - Pass rate
   - Average score
   - Failed evaluations list
2. Add session-level metrics:
   - Total cost across all traces
   - Total tokens
   - Average evaluation score
3. Add trace-level evaluation (evaluate entire workflow, not just individual calls)
4. Add charts to dashboard showing trace metrics over time

**Estimated Effort**: 6-8 hours
**Impact**: High - Provides new insights

---

### Phase 4: Advanced Features 🚀

**Goal**: Polish and advanced use cases

**Tasks**:
1. Add comparison view: Compare two traces side-by-side
2. Add trace search: Full-text search across trace metadata
3. Add session replay: Show timeline of all events in a session
4. Add trace templates: Common trace patterns for documentation
5. Add trace-level alerts: Alert when trace fails or exceeds thresholds

**Estimated Effort**: 10-12 hours
**Impact**: Medium - Nice-to-have features

---

## Rationale Summary

### Why This Approach Is Better

#### 1. **Flexibility**
- Users can choose the view that matches their mental model
- No forced migration to tracing for simple use cases
- Progressive enhancement: add tracing when needed

#### 2. **Backward Compatibility**
- Existing tracked calls without traces continue to work
- No breaking changes to existing code
- Gradual adoption path

#### 3. **Use-Case Driven**
- Each view optimized for specific tasks
- Call-centric for quality monitoring
- Execution-centric for workflow debugging

#### 4. **No Duplication**
- Same data, different lenses
- Cross-navigation prevents silos
- Single source of truth (LlmResponse)

#### 5. **Scalability**
- Hierarchical views handle complex workflows
- Flat views handle high-volume filtering
- Both scale independently

#### 6. **Developer Experience**
- Clear separation of concerns
- Easy to understand which view to use
- Consistent patterns across views

---

## Success Metrics

### User Adoption
- % of LLM responses with trace_id (target: 30% within 3 months)
- % of users using Sessions/Traces views (target: 50% of active users)
- Average session duration in Monitoring section (should increase)

### Performance
- Page load time for Traces index < 500ms
- Expandable trace timeline renders < 200ms
- Session aggregation queries < 1s

### Quality
- Reduction in "I can't find X" support requests
- Increase in evaluation coverage (more calls evaluated)
- Faster time to debug issues (measured via user feedback)

---

## Open Questions & Future Considerations

### 1. Should we support trace-level evaluations?

**Question**: Can we evaluate an entire trace (workflow) rather than just individual LLM responses?

**Use Case**: "Did this RAG pipeline produce a good answer?" (considering retrieval + generation together)

**Proposal**: Add `trace_id` to Evaluations table (in addition to `llm_response_id`)

### 2. Should sessions be a database table?

**Current**: `session_id` is just a string field
**Alternative**: Create `Session` model with metadata (user, started_at, ended_at, etc.)

**Pros**: Better querying, can add session-level attributes
**Cons**: More complexity, migration needed

**Decision**: Keep as string for now, revisit if we need session-level attributes

### 3. How to handle real-time updates?

**Question**: Should trace timeline update in real-time as spans complete?

**Options**:
- Turbo Streams for live updates
- Polling with AJAX
- Manual refresh

**Decision**: Start with manual refresh, add Turbo Streams in Phase 4

### 4. How to visualize trace timelines?

**Current**: Nested expandable tree
**Alternative**: Gantt chart showing parallel execution

**Decision**: Keep tree for now, add Gantt chart as optional view in Phase 4

---

## Conclusion

This dual-mode architecture provides the best of both worlds:
- **Call-centric views** for quality monitoring and filtering
- **Execution-centric views** for workflow debugging and context

By connecting them with cross-navigation links, we create a cohesive monitoring experience that adapts to different use cases without forcing users into a single paradigm.

The phased implementation approach allows us to deliver value incrementally while gathering user feedback to guide future enhancements.

---

## Next Steps

1. Review this plan with stakeholders
2. Prioritize Phase 1 tasks
3. Create implementation tickets
4. Begin with "View in Trace" links (highest impact, lowest effort)
5. Gather user feedback after Phase 1
6. Iterate based on feedback
