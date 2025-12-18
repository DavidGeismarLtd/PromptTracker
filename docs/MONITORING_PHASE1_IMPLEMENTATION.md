# Phase 1 Implementation Guide: Cross-Navigation

This document provides step-by-step implementation instructions for Phase 1 of the Monitoring UI enhancement.

**Goal**: Connect existing views with cross-navigation links (2-3 hours of work)

---

## Task Overview

| # | Task | File(s) | Estimated Time | Status |
|---|------|---------|----------------|--------|
| 1 | Add "View in Trace" to Tracked Calls table | `_tracked_calls_table.html.erb` | 20 min | ⬜ |
| 2 | Add "View Session" to Tracked Calls table | `_tracked_calls_table.html.erb` | 15 min | ⬜ |
| 3 | Show evaluations in trace timeline | `_generation_item.html.erb` | 30 min | ⬜ |
| 4 | Add trace context to LLM Response detail | `llm_responses/show.html.erb` | 30 min | ⬜ |
| 5 | Update navigation menu with dropdown | `application.html.erb` | 45 min | ⬜ |
| 6 | Add "View in Trace" to Evaluations table | `evaluations/index.html.erb` | 20 min | ⬜ |

**Total Estimated Time**: ~2.5 hours

---

## Task 1: Add "View in Trace" to Tracked Calls Table

### File to Edit
`app/views/prompt_tracker/monitoring/shared/_tracked_calls_table.html.erb`

### Location
In the actions column (or create a new column if needed)

### Code to Add

```erb
<!-- In the table header -->
<th>Actions</th>

<!-- In the table body, for each tracked_call -->
<td>
  <%= link_to "View", monitoring_llm_response_path(tracked_call),
              class: "btn btn-sm btn-outline-primary" %>

  <% if tracked_call.trace_id.present? %>
    <%= link_to monitoring_trace_path(tracked_call.trace_id),
                class: "btn btn-sm btn-outline-info",
                title: "View in execution trace" do %>
      <i class="bi bi-diagram-2"></i> Trace
    <% end %>
  <% end %>

  <% if tracked_call.session_id.present? %>
    <%= link_to monitoring_sessions_path(session_id: tracked_call.session_id),
                class: "btn btn-sm btn-outline-secondary",
                title: "View all traces in this session" do %>
      <i class="bi bi-collection"></i> Session
    <% end %>
  <% end %>
</td>
```

### Testing
1. Navigate to `/monitoring/responses`
2. Find a tracked call with a trace (check seed data)
3. Verify "Trace" button appears and links to trace detail
4. Find a tracked call with a session_id
5. Verify "Session" button appears and links to sessions index with filter

---

## Task 2: Show Evaluations in Trace Timeline

### File to Edit
`app/views/prompt_tracker/monitoring/traces/_generation_item.html.erb`

### Location
After the generation details, before the closing div

### Code to Add

```erb
<!-- Add after the existing generation details -->
<% if generation.evaluations.any? %>
  <div class="mt-2 pt-2 border-top">
    <div class="d-flex align-items-center gap-2">
      <strong class="text-muted small">Evaluations:</strong>
      <div class="d-flex gap-1 flex-wrap">
        <% generation.evaluations.each do |eval| %>
          <%= link_to monitoring_evaluation_path(eval),
                      class: "badge #{eval.passed? ? 'bg-success' : 'bg-danger'} text-decoration-none",
                      title: "#{eval.evaluator_key}: #{eval.score} - Click for details",
                      data: { turbo_frame: "_top" } do %>
            <%= eval.evaluator_key %>: <%= eval.score.round %>
            <% if eval.passed? %>
              <i class="bi bi-check-circle-fill ms-1"></i>
            <% else %>
              <i class="bi bi-x-circle-fill ms-1"></i>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>

    <!-- Show failed evaluation feedback -->
    <% failed_evals = generation.evaluations.where(passed: false) %>
    <% if failed_evals.any? %>
      <div class="mt-2">
        <% failed_evals.each do |eval| %>
          <% if eval.feedback.present? %>
            <div class="alert alert-danger alert-sm mb-1 py-1 px-2">
              <small><strong><%= eval.evaluator_key %>:</strong> <%= eval.feedback %></small>
            </div>
          <% end %>
        <% end %>
      </div>
    <% end %>
  </div>
<% end %>
```

### Controller Update Required
Ensure evaluations are eager-loaded in the traces controller:

```ruby
# app/controllers/prompt_tracker/monitoring/traces_controller.rb
def index
  @traces = Trace.includes(
    spans: { llm_responses: :evaluations },  # Add :evaluations here
    llm_responses: :evaluations              # And here
  ).order(created_at: :desc).page(params[:page]).per(25)
end
```

### Testing
1. Navigate to `/monitoring/traces`
2. Expand a trace that has LLM responses with evaluations
3. Verify evaluation badges appear below each generation
4. Verify clicking badge navigates to evaluation detail
5. Verify failed evaluations show feedback

---

## Task 3: Add Trace Context to LLM Response Detail

### File to Edit
`app/views/prompt_tracker/monitoring/llm_responses/show.html.erb`

### Location
Near the top, after the page header but before the main content

### Code to Add

```erb
<!-- Add after the breadcrumbs/header -->
<% if @response.trace.present? %>
  <div class="card mb-4 border-info">
    <div class="card-header bg-info bg-opacity-10">
      <h5 class="mb-0">
        <i class="bi bi-diagram-2"></i> Execution Context
      </h5>
    </div>
    <div class="card-body">
      <dl class="row mb-0">
        <dt class="col-sm-2">Trace</dt>
        <dd class="col-sm-10">
          <%= link_to monitoring_trace_path(@response.trace), class: "fw-bold" do %>
            <%= @response.trace.name %>
          <% end %>
          <span class="badge bg-<%= @response.trace.status == 'completed' ? 'success' : @response.trace.status == 'error' ? 'danger' : 'warning' %> ms-2">
            <%= @response.trace.status %>
          </span>
          <% if @response.trace.duration_ms.present? %>
            <span class="text-muted ms-2">
              <i class="bi bi-clock"></i> <%= @response.trace.duration_ms %>ms
            </span>
          <% end %>
        </dd>

        <% if @response.span.present? %>
          <dt class="col-sm-2">Span</dt>
          <dd class="col-sm-10">
            <%= @response.span.name %>
            <% if @response.span.span_type.present? %>
              <span class="badge bg-info ms-2"><%= @response.span.span_type %></span>
            <% end %>
            <% if @response.span.duration_ms.present? %>
              <span class="text-muted ms-2">
                <i class="bi bi-clock"></i> <%= @response.span.duration_ms %>ms
              </span>
            <% end %>
          </dd>
        <% end %>

        <% if @response.trace.session_id.present? %>
          <dt class="col-sm-2">Session</dt>
          <dd class="col-sm-10">
            <%= link_to monitoring_sessions_path(session_id: @response.trace.session_id) do %>
              <%= truncate(@response.trace.session_id, length: 50) %>
              <i class="bi bi-box-arrow-up-right ms-1"></i>
            <% end %>
          </dd>
        <% end %>

        <% if @response.trace.user_id.present? %>
          <dt class="col-sm-2">User</dt>
          <dd class="col-sm-10">
            <code><%= @response.trace.user_id %></code>
          </dd>
        <% end %>
      </dl>

      <div class="mt-3">
        <%= link_to monitoring_trace_path(@response.trace), class: "btn btn-sm btn-outline-info" do %>
          <i class="bi bi-diagram-2"></i> View Full Trace Timeline
        <% end %>

        <% if @response.trace.session_id.present? %>
          <%= link_to monitoring_sessions_path(session_id: @response.trace.session_id),
                      class: "btn btn-sm btn-outline-secondary ms-2" do %>
            <i class="bi bi-collection"></i> View Session
          <% end %>
        <% end %>
      </div>
    </div>
  </div>
<% end %>
```

### Controller Update Required
Ensure trace and span are eager-loaded:

```ruby
# app/controllers/prompt_tracker/monitoring/llm_responses_controller.rb
def show
  @response = LlmResponse.includes(:trace, :span, :evaluations, :prompt_version)
                         .find(params[:id])
end
```

### Testing
1. Navigate to a tracked call detail page that has a trace
2. Verify the "Execution Context" card appears
3. Verify all trace/span details are shown
4. Verify links to trace and session work
5. Navigate to a tracked call without a trace
6. Verify the card does NOT appear

---

## Task 4: Update Navigation Menu with Dropdown

### File to Edit
`app/views/layouts/prompt_tracker/application.html.erb`

### Location
Replace the existing Monitoring nav item (around line 141)

### Code to Replace

**OLD**:
```erb
<li class="nav-item">
  <%= link_to monitoring_root_path, class: "nav-link #{'active' if controller_path.start_with?('prompt_tracker/monitoring')} pt-nav-monitoring" do %>
    <i class="bi bi-activity"></i> Monitoring
  <% end %>
</li>
```

**NEW**:
```erb
<li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle <%= 'active' if controller_path.start_with?('prompt_tracker/monitoring') %> pt-nav-monitoring"
     href="#"
     role="button"
     data-bs-toggle="dropdown"
     aria-expanded="false">
    <i class="bi bi-activity"></i> Monitoring
  </a>
  <ul class="dropdown-menu">
    <li>
      <%= link_to monitoring_root_path, class: "dropdown-item #{'active' if controller_name == 'dashboard'}" do %>
        <i class="bi bi-speedometer2"></i> Dashboard
      <% end %>
    </li>
    <li><hr class="dropdown-divider"></li>
    <li class="dropdown-header">Call-Level Views</li>
    <li>
      <%= link_to monitoring_llm_responses_path, class: "dropdown-item #{'active' if controller_name == 'llm_responses'}" do %>
        <i class="bi bi-chat-dots"></i> Tracked Calls
      <% end %>
    </li>
    <li>
      <%= link_to monitoring_evaluations_path, class: "dropdown-item #{'active' if controller_name == 'evaluations'}" do %>
        <i class="bi bi-clipboard-check"></i> Evaluations
      <% end %>
    </li>
    <li><hr class="dropdown-divider"></li>
    <li class="dropdown-header">Execution-Level Views</li>
    <li>
      <%= link_to monitoring_sessions_path, class: "dropdown-item #{'active' if controller_name == 'sessions'}" do %>
        <i class="bi bi-collection"></i> Sessions
      <% end %>
    </li>
    <li>
      <%= link_to monitoring_traces_path, class: "dropdown-item #{'active' if controller_name == 'traces'}" do %>
        <i class="bi bi-diagram-2"></i> Traces
      <% end %>
    </li>
  </ul>
</li>
```

### Testing
1. Refresh any page in the app
2. Hover over "Monitoring" in the navbar
3. Verify dropdown menu appears
4. Verify all 5 menu items are present
5. Verify section headers ("Call-Level Views", "Execution-Level Views")
6. Click each menu item and verify navigation works
7. Verify active state highlights current page

---

## Task 5: Add "View in Trace" to Evaluations Table

### File to Edit
`app/views/prompt_tracker/monitoring/evaluations/index.html.erb`

### Location
In the actions column of the evaluations table

### Code to Add

```erb
<!-- In the table, add an actions column -->
<td>
  <%= link_to "View", monitoring_evaluation_path(evaluation),
              class: "btn btn-sm btn-outline-primary" %>

  <%= link_to "Response", monitoring_llm_response_path(evaluation.llm_response),
              class: "btn btn-sm btn-outline-secondary" %>

  <% if evaluation.llm_response.trace_id.present? %>
    <%= link_to monitoring_trace_path(evaluation.llm_response.trace_id),
                class: "btn btn-sm btn-outline-info",
                title: "View in execution trace" do %>
      <i class="bi bi-diagram-2"></i> Trace
    <% end %>
  <% end %>
</td>
```

### Controller Update Required
Ensure trace is eager-loaded:

```ruby
# app/controllers/prompt_tracker/monitoring/evaluations_controller.rb
def index
  @evaluations = Evaluation.includes(llm_response: [:trace, :prompt_version])
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(25)
  # ... apply filters ...
end
```

### Testing
1. Navigate to `/monitoring/evaluations`
2. Find an evaluation whose LLM response has a trace
3. Verify "Trace" button appears
4. Click it and verify navigation to trace detail
5. Find an evaluation without a trace
6. Verify "Trace" button does NOT appear

---

## Testing Checklist

After implementing all tasks, test the complete cross-navigation flow:

### Flow 1: Tracked Call → Trace → Session
1. ✅ Start at `/monitoring/responses`
2. ✅ Click "Trace" button on a tracked call
3. ✅ Verify trace detail page loads
4. ✅ Click "View Session" button
5. ✅ Verify session view loads with correct filter

### Flow 2: Evaluation → LLM Response → Trace
1. ✅ Start at `/monitoring/evaluations`
2. ✅ Click "Trace" button on an evaluation
3. ✅ Verify trace detail page loads
4. ✅ Expand trace to see timeline
5. ✅ Verify evaluation badges appear in timeline

### Flow 3: Session → Trace → LLM Response
1. ✅ Start at `/monitoring/sessions`
2. ✅ Expand a session
3. ✅ Expand a trace
4. ✅ Click an LLM response in timeline
5. ✅ Verify LLM response detail page loads
6. ✅ Verify "Execution Context" card appears

### Flow 4: Navigation Menu
1. ✅ Click "Monitoring" dropdown
2. ✅ Navigate to each view via dropdown
3. ✅ Verify active state in dropdown
4. ✅ Verify breadcrumbs update correctly

---

## Common Issues & Solutions

### Issue 1: "View in Trace" button always shows
**Cause**: Not checking if `trace_id.present?`
**Solution**: Wrap button in `<% if trace_id.present? %>` condition

### Issue 2: Evaluations not showing in timeline
**Cause**: Not eager-loading evaluations in controller
**Solution**: Add `.includes(llm_responses: :evaluations)` to query

### Issue 3: Dropdown menu not working
**Cause**: Bootstrap JS not loaded or version mismatch
**Solution**: Verify Bootstrap 5 is loaded and `data-bs-toggle` is used (not `data-toggle`)

### Issue 4: N+1 queries when loading traces
**Cause**: Not eager-loading associations
**Solution**: Use `.includes()` for all nested associations

### Issue 5: Session filter not working
**Cause**: Using `session_id` as a route param instead of query param
**Solution**: Use `monitoring_sessions_path(session_id: value)` to pass as query param

---

## Performance Considerations

### Eager Loading
Always eager-load associations to prevent N+1 queries:

```ruby
# Good
Trace.includes(spans: { llm_responses: :evaluations })

# Bad
Trace.all  # Will cause N+1 when accessing spans, llm_responses, evaluations
```

### Pagination
All list views should be paginated:

```ruby
@traces = Trace.includes(...).page(params[:page]).per(25)
```

### Caching (Future Enhancement)
Consider fragment caching for expensive timeline renders:

```erb
<% cache ["trace-timeline", trace.id, trace.updated_at] do %>
  <%= render "timeline", trace: trace %>
<% end %>
```

---

## Rollout Plan

### Step 1: Deploy to Staging
1. Merge PR to staging branch
2. Deploy to staging environment
3. Run manual tests using checklist above
4. Verify no performance regressions

### Step 2: User Testing
1. Share staging link with 2-3 users
2. Ask them to test cross-navigation flows
3. Gather feedback on usability
4. Make adjustments if needed

### Step 3: Deploy to Production
1. Merge to main branch
2. Deploy to production
3. Monitor error logs for issues
4. Monitor performance metrics

### Step 4: Gather Metrics
1. Track usage of new navigation links (add analytics events)
2. Measure page load times
3. Gather user feedback
4. Plan Phase 2 based on learnings

---

## Success Criteria

Phase 1 is successful if:
- ✅ All cross-navigation links work correctly
- ✅ No N+1 query issues
- ✅ Page load times < 500ms
- ✅ No JavaScript errors in console
- ✅ Dropdown menu works on all browsers
- ✅ Users can navigate between views seamlessly
- ✅ Evaluation badges appear in trace timelines
- ✅ Trace context card appears on LLM response detail

---

## Next Steps After Phase 1

Once Phase 1 is complete and stable:
1. Gather user feedback
2. Measure adoption of tracing feature
3. Plan Phase 2: Enhanced Filtering & Navigation
4. Consider adding analytics to track navigation patterns
5. Document common user workflows
