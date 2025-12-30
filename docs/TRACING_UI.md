# 🎨 Tracing UI - Views & Controllers

## Overview

Three simple views to visualize traces and sessions.

---

## 1. Sessions List

**Route**: `GET /prompt_tracker/sessions`

**Purpose**: Show all unique sessions with summary metrics.

### Controller

**File**: `app/controllers/prompt_tracker/sessions_controller.rb`

```ruby
module PromptTracker
  class SessionsController < ApplicationController
    def index
      # Get unique session_ids with aggregated data
      @sessions = Trace.where.not(session_id: nil)
                       .group(:session_id)
                       .select(
                         "session_id",
                         "COUNT(*) as trace_count",
                         "MAX(created_at) as last_activity",
                         "MIN(created_at) as first_activity",
                         "array_agg(DISTINCT user_id) as user_ids"
                       )
                       .order("last_activity DESC")
                       .page(params[:page])
                       .per(25)
    end
    
    def show
      @session_id = params[:id]
      @traces = Trace.in_session(@session_id)
                     .includes(:llm_responses, :spans)
                     .order(created_at: :asc)
      
      # Calculate session metrics
      @total_cost = @traces.joins(:llm_responses)
                           .sum("prompt_tracker_llm_responses.cost_usd")
      @total_duration = @traces.sum(:duration_ms)
      @total_tokens = @traces.joins(:llm_responses)
                             .sum("prompt_tracker_llm_responses.tokens_total")
    end
  end
end
```

### View

**File**: `app/views/prompt_tracker/sessions/index.html.erb`

```erb
<div class="container mt-4">
  <h1>Sessions</h1>
  
  <div class="card">
    <div class="card-body">
      <table class="table">
        <thead>
          <tr>
            <th>Session ID</th>
            <th>User</th>
            <th>Traces</th>
            <th>Last Activity</th>
            <th>Duration</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @sessions.each do |session| %>
            <tr>
              <td>
                <code><%= session.session_id %></code>
              </td>
              <td>
                <%= session.user_ids.compact.first || "N/A" %>
              </td>
              <td>
                <span class="badge bg-primary">
                  <%= session.trace_count %> traces
                </span>
              </td>
              <td>
                <%= time_ago_in_words(session.last_activity) %> ago
              </td>
              <td>
                <%= distance_of_time_in_words(
                  session.first_activity, 
                  session.last_activity
                ) %>
              </td>
              <td>
                <%= link_to "View", 
                    session_path(session.session_id), 
                    class: "btn btn-sm btn-primary" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
      
      <%= paginate @sessions %>
    </div>
  </div>
</div>
```

---

## 2. Session Detail

**Route**: `GET /prompt_tracker/sessions/:id`

**Purpose**: Show all traces in a session (like a chat thread).

### View

**File**: `app/views/prompt_tracker/sessions/show.html.erb`

```erb
<div class="container mt-4">
  <div class="d-flex justify-content-between align-items-center mb-4">
    <h1>Session: <code><%= @session_id %></code></h1>
    <%= link_to "← All Sessions", sessions_path, class: "btn btn-secondary" %>
  </div>
  
  <!-- Session Metrics -->
  <div class="row mb-4">
    <div class="col-md-3">
      <div class="card">
        <div class="card-body text-center">
          <h3><%= @traces.count %></h3>
          <p class="text-muted mb-0">Traces</p>
        </div>
      </div>
    </div>
    <div class="col-md-3">
      <div class="card">
        <div class="card-body text-center">
          <h3>$<%= number_with_precision(@total_cost, precision: 4) %></h3>
          <p class="text-muted mb-0">Total Cost</p>
        </div>
      </div>
    </div>
    <div class="col-md-3">
      <div class="card">
        <div class="card-body text-center">
          <h3><%= number_with_delimiter(@total_tokens) %></h3>
          <p class="text-muted mb-0">Total Tokens</p>
        </div>
      </div>
    </div>
    <div class="col-md-3">
      <div class="card">
        <div class="card-body text-center">
          <h3><%= @total_duration %>ms</h3>
          <p class="text-muted mb-0">Total Duration</p>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Traces Timeline -->
  <div class="card">
    <div class="card-header">
      <h5>Traces Timeline</h5>
    </div>
    <div class="card-body">
      <% @traces.each_with_index do |trace, index| %>
        <div class="trace-item mb-3 p-3 border rounded">
          <div class="d-flex justify-content-between align-items-start">
            <div>
              <h6>
                <%= index + 1 %>. <%= trace.name %>
                <span class="badge bg-<%= trace.status == 'completed' ? 'success' : 'warning' %>">
                  <%= trace.status %>
                </span>
              </h6>
              <small class="text-muted">
                <%= trace.created_at.strftime("%H:%M:%S") %>
              </small>
            </div>
            <div class="text-end">
              <div><strong><%= trace.duration_ms %>ms</strong></div>
              <div class="text-muted">
                <%= trace.llm_responses.count %> LLM calls
              </div>
              <%= link_to "Details →", trace_path(trace), class: "btn btn-sm btn-outline-primary mt-2" %>
            </div>
          </div>
          
          <% if trace.input.present? %>
            <div class="mt-2">
              <strong>Input:</strong>
              <div class="text-muted"><%= truncate(trace.input, length: 100) %></div>
            </div>
          <% end %>
          
          <% if trace.output.present? %>
            <div class="mt-2">
              <strong>Output:</strong>
              <div class="text-muted"><%= truncate(trace.output, length: 100) %></div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

---

## 3. Trace Detail

**Route**: `GET /prompt_tracker/traces/:id`

**Purpose**: Show detailed view of a single trace with all spans and generations.

### Controller

**File**: `app/controllers/prompt_tracker/traces_controller.rb`

```ruby
module PromptTracker
  class TracesController < ApplicationController
    def index
      @traces = Trace.includes(:llm_responses, :spans)
                     .order(created_at: :desc)
                     .page(params[:page])
                     .per(25)
      
      # Filters
      @traces = @traces.where(status: params[:status]) if params[:status].present?
      @traces = @traces.for_user(params[:user_id]) if params[:user_id].present?
    end
    
    def show
      @trace = Trace.includes(
        spans: [:child_spans, :llm_responses],
        llm_responses: [:prompt_version, :evaluations]
      ).find(params[:id])
      
      @root_spans = @trace.spans.root_level.order(:started_at)
      @orphan_generations = @trace.llm_responses.where(span_id: nil)
    end
  end
end
```

### View

**File**: `app/views/prompt_tracker/traces/show.html.erb`

```erb
<div class="container mt-4">
  <div class="d-flex justify-content-between align-items-center mb-4">
    <h1>Trace: <%= @trace.name %></h1>
    <div>
      <% if @trace.session_id.present? %>
        <%= link_to "← Session", session_path(@trace.session_id), class: "btn btn-secondary" %>
      <% end %>
      <%= link_to "All Traces", traces_path, class: "btn btn-secondary" %>
    </div>
  </div>
  
  <!-- Trace Info -->
  <div class="card mb-4">
    <div class="card-body">
      <div class="row">
        <div class="col-md-2">
          <strong>Status:</strong><br>
          <span class="badge bg-<%= @trace.status == 'completed' ? 'success' : 'warning' %>">
            <%= @trace.status %>
          </span>
        </div>
        <div class="col-md-2">
          <strong>Duration:</strong><br>
          <%= @trace.duration_ms %>ms
        </div>
        <div class="col-md-2">
          <strong>Started:</strong><br>
          <%= @trace.started_at.strftime("%H:%M:%S") %>
        </div>
        <div class="col-md-3">
          <strong>User:</strong><br>
          <%= @trace.user_id || "N/A" %>
        </div>
        <div class="col-md-3">
          <strong>Session:</strong><br>
          <% if @trace.session_id.present? %>
            <%= link_to @trace.session_id, session_path(@trace.session_id) %>
          <% else %>
            N/A
          <% end %>
        </div>
      </div>
      
      <% if @trace.input.present? %>
        <div class="mt-3">
          <strong>Input:</strong>
          <pre class="bg-light p-2 rounded"><%= @trace.input %></pre>
        </div>
      <% end %>
      
      <% if @trace.output.present? %>
        <div class="mt-3">
          <strong>Output:</strong>
          <pre class="bg-light p-2 rounded"><%= @trace.output %></pre>
        </div>
      <% end %>
    </div>
  </div>
  
  <!-- Execution Timeline -->
  <div class="card">
    <div class="card-header">
      <h5>Execution Timeline</h5>
    </div>
    <div class="card-body">
      <%= render "timeline", 
                 root_spans: @root_spans, 
                 orphan_generations: @orphan_generations %>
    </div>
  </div>
</div>
```

### Timeline Partial

**File**: `app/views/prompt_tracker/traces/_timeline.html.erb`

```erb
<div class="timeline">
  <!-- Root-level spans -->
  <% root_spans.each do |span| %>
    <%= render "span_item", span: span, depth: 0 %>
  <% end %>
  
  <!-- Orphan generations (not in any span) -->
  <% orphan_generations.each do |generation| %>
    <%= render "generation_item", generation: generation, depth: 0 %>
  <% end %>
</div>
```

### Span Item Partial

**File**: `app/views/prompt_tracker/traces/_span_item.html.erb`

```erb
<div class="span-item mb-2 p-3 border-start border-3 border-primary" 
     style="margin-left: <%= depth * 20 %>px;">
  <div class="d-flex justify-content-between">
    <div>
      <strong><%= span.name %></strong>
      <span class="badge bg-secondary"><%= span.span_type %></span>
      <span class="badge bg-<%= span.status == 'completed' ? 'success' : 'warning' %>">
        <%= span.status %>
      </span>
    </div>
    <div class="text-muted">
      <%= span.duration_ms %>ms
    </div>
  </div>
  
  <!-- Nested generations in this span -->
  <% span.llm_responses.each do |generation| %>
    <%= render "generation_item", generation: generation, depth: depth + 1 %>
  <% end %>
  
  <!-- Nested child spans -->
  <% span.child_spans.order(:started_at).each do |child_span| %>
    <%= render "span_item", span: child_span, depth: depth + 1 %>
  <% end %>
</div>
```

### Generation Item Partial

**File**: `app/views/prompt_tracker/traces/_generation_item.html.erb`

```erb
<div class="generation-item mt-2 p-2 bg-light rounded" 
     style="margin-left: <%= depth * 20 %>px;">
  <div class="d-flex justify-content-between align-items-start">
    <div>
      <strong>🤖 LLM Generation</strong>
      <span class="badge bg-info"><%= generation.model %></span>
      <span class="badge bg-<%= generation.status == 'success' ? 'success' : 'danger' %>">
        <%= generation.status %>
      </span>
      <br>
      <small class="text-muted">
        <%= generation.tokens_total %> tokens • 
        $<%= number_with_precision(generation.cost_usd, precision: 4) %> • 
        <%= generation.response_time_ms %>ms
      </small>
    </div>
    <div>
      <%= link_to "View →", llm_response_path(generation), 
          class: "btn btn-sm btn-outline-primary" %>
    </div>
  </div>
</div>
```

---

## Routes

**File**: `config/routes.rb`

```ruby
PromptTracker::Engine.routes.draw do
  # ... existing routes ...
  
  # Tracing routes
  resources :sessions, only: [:index, :show]
  resources :traces, only: [:index, :show]
  resources :spans, only: [:show]
end
```

---

## Navigation Updates

Add to main navigation:

```erb
<li class="nav-item">
  <%= link_to "Sessions", sessions_path, class: "nav-link" %>
</li>
<li class="nav-item">
  <%= link_to "Traces", traces_path, class: "nav-link" %>
</li>
```

---

## Summary

**3 Controllers**:
- `SessionsController` - List sessions, show session detail
- `TracesController` - List traces, show trace detail
- `SpansController` - (Optional) Show individual span

**5 Views**:
- `sessions/index.html.erb` - All sessions
- `sessions/show.html.erb` - Session detail (trace list)
- `traces/index.html.erb` - All traces
- `traces/show.html.erb` - Trace detail (timeline)
- `traces/_timeline.html.erb` - Recursive timeline rendering

**Simple & Clean**: No JavaScript, no complex visualizations, just clear hierarchical display.

