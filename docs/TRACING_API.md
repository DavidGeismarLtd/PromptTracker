# 🔌 Tracing API - Developer Guide

## How to Use Tracing in Your Code

### Option 1: Manual (Full Control)

**Best for**: Complex workflows where you need fine-grained control.

```ruby
# 1. Create a trace
trace = PromptTracker::Trace.create!(
  name: "customer_support_workflow",
  input: "User asks: How do I reset my password?",
  session_id: "chat_#{user.id}_#{Date.today}",
  user_id: user.id,
  started_at: Time.current,
  metadata: { source: "web_chat" }
)

# 2. Create spans for different steps
search_span = trace.spans.create!(
  name: "search_knowledge_base",
  span_type: "retrieval",
  input: "password reset",
  started_at: Time.current
)

# Do the search
results = KnowledgeBase.search("password reset")

search_span.complete!(output: "Found #{results.count} articles")

# 3. Create another span with LLM call
response_span = trace.spans.create!(
  name: "generate_response",
  span_type: "function",
  input: { query: "...", context: results },
  started_at: Time.current
)

# Track LLM call within the span
result = PromptTracker::LlmCallService.track(
  prompt_name: "support_response",
  variables: { context: results.to_json },
  provider: "openai",
  model: "gpt-4",
  trace: trace,        # ← Link to trace
  span: response_span  # ← Link to span
) do |rendered_prompt|
  # Your LLM call
  OpenAI::Client.new.chat(
    messages: [{ role: "user", content: rendered_prompt }]
  )
end

response_span.complete!(output: result[:response_text])

# 4. Complete the trace
trace.complete!(output: result[:response_text])
```

---

### Option 2: Simple (No Spans)

**Best for**: Single-step workflows.

```ruby
# Just create a trace and link the LLM call
trace = PromptTracker::Trace.create!(
  name: "simple_greeting",
  input: "Generate greeting for #{user.name}",
  session_id: "chat_#{user.id}",
  started_at: Time.current
)

result = PromptTracker::LlmCallService.track(
  prompt_name: "greeting",
  variables: { name: user.name },
  provider: "openai",
  model: "gpt-4",
  trace: trace  # ← Just link to trace, no span needed
) { |prompt| call_llm(prompt) }

trace.complete!(output: result[:response_text])
```

---

### Option 3: No Tracing (Backward Compatible)

**Best for**: Existing code, simple logging.

```ruby
# This still works exactly as before!
result = PromptTracker::LlmCallService.track(
  prompt_name: "greeting",
  variables: { name: "John" },
  provider: "openai",
  model: "gpt-4"
) { |prompt| call_llm(prompt) }

# LlmResponse is created, but not linked to any trace
```

---

## Service Layer Updates

### LlmCallService Changes

**File**: `app/services/prompt_tracker/llm_call_service.rb`

```ruby
# Add to initialize method:
def initialize(prompt_name:, variables: {}, provider:, model:, 
               version: nil, user_id: nil, session_id: nil, 
               environment: nil, metadata: nil,
               trace: nil, span: nil)  # ← NEW PARAMETERS
  # ... existing code ...
  @trace = trace
  @span = span
end

# Update create_pending_response method:
def create_pending_response(prompt_version, rendered_prompt)
  prompt_version.llm_responses.create!(
    rendered_prompt: rendered_prompt,
    variables_used: variables,
    provider: provider,
    model: model,
    status: "pending",
    user_id: user_id,
    session_id: session_id,
    environment: environment,
    context: metadata,
    trace: @trace,    # ← NEW
    span: @span,      # ← NEW
    # ... rest of existing fields ...
  )
end
```

---

## Real-World Examples

### Example 1: Multi-Turn Chat

```ruby
class ChatService
  def handle_message(user:, message:, conversation_id:)
    # Use conversation_id as session_id
    trace = PromptTracker::Trace.create!(
      name: "chat_message",
      input: message,
      session_id: conversation_id,
      user_id: user.id,
      started_at: Time.current
    )
    
    # Generate response
    result = PromptTracker::LlmCallService.track(
      prompt_name: "chat_response",
      variables: { 
        message: message,
        history: load_history(conversation_id)
      },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      user_id: user.id,
      session_id: conversation_id
    ) { |prompt| call_llm(prompt) }
    
    trace.complete!(output: result[:response_text])
    
    result[:response_text]
  end
end

# Usage:
# Message 1: session_id = "conv_123"
ChatService.new.handle_message(
  user: current_user,
  message: "Hello!",
  conversation_id: "conv_123"
)

# Message 2: same session_id = "conv_123"
ChatService.new.handle_message(
  user: current_user,
  message: "How are you?",
  conversation_id: "conv_123"
)

# Now you can view all traces in session "conv_123"
```

---

### Example 2: RAG Pipeline

```ruby
class RagService
  def answer_question(question:, user:)
    trace = PromptTracker::Trace.create!(
      name: "rag_question_answering",
      input: question,
      session_id: "user_#{user.id}_#{Date.today}",
      user_id: user.id,
      started_at: Time.current
    )
    
    # Step 1: Retrieval
    retrieval_span = trace.spans.create!(
      name: "retrieve_documents",
      span_type: "retrieval",
      input: question,
      started_at: Time.current
    )
    
    docs = VectorStore.search(question, limit: 5)
    retrieval_span.complete!(output: "Retrieved #{docs.count} documents")
    
    # Step 2: Generation
    generation_span = trace.spans.create!(
      name: "generate_answer",
      span_type: "function",
      started_at: Time.current
    )
    
    result = PromptTracker::LlmCallService.track(
      prompt_name: "rag_answer",
      variables: { 
        question: question,
        context: docs.map(&:content).join("\n")
      },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: generation_span
    ) { |prompt| call_llm(prompt) }
    
    generation_span.complete!(output: result[:response_text])
    trace.complete!(output: result[:response_text])
    
    result[:response_text]
  end
end
```

---

### Example 3: Nested Spans

```ruby
trace = PromptTracker::Trace.create!(
  name: "content_pipeline",
  started_at: Time.current
)

# Parent span
processing_span = trace.spans.create!(
  name: "process_content",
  span_type: "function",
  started_at: Time.current
)

# Child span 1
enhancement_span = processing_span.create_child_span(
  name: "enhance_content",
  span_type: "function"
)

result1 = PromptTracker::LlmCallService.track(
  prompt_name: "enhance",
  variables: { content: "..." },
  provider: "openai",
  model: "gpt-4",
  trace: trace,
  span: enhancement_span
) { |prompt| call_llm(prompt) }

enhancement_span.complete!(output: result1[:response_text])

# Child span 2
translation_span = processing_span.create_child_span(
  name: "translate_content",
  span_type: "function"
)

result2 = PromptTracker::LlmCallService.track(
  prompt_name: "translate",
  variables: { content: result1[:response_text] },
  provider: "openai",
  model: "gpt-4",
  trace: trace,
  span: translation_span
) { |prompt| call_llm(prompt) }

translation_span.complete!(output: result2[:response_text])
processing_span.complete!(output: result2[:response_text])
trace.complete!(output: result2[:response_text])
```

---

## Error Handling

```ruby
trace = PromptTracker::Trace.create!(
  name: "risky_operation",
  started_at: Time.current
)

begin
  # Your code
  result = do_something_risky
  trace.complete!(output: result)
rescue => e
  trace.mark_error!(error_message: e.message)
  raise
end
```

---

## Best Practices

### 1. **Use session_id for conversations**
```ruby
# Good: Consistent session_id across messages
session_id = "chat_#{user.id}_#{conversation.id}"
```

### 2. **Name traces descriptively**
```ruby
# Good
name: "customer_support_question"
name: "rag_document_search"

# Bad
name: "trace_1"
name: "llm_call"
```

### 3. **Use span_type consistently**
```ruby
# Standard types:
"retrieval"  # Database/vector search
"function"   # Business logic
"tool"       # External API calls
"http"       # HTTP requests
```

### 4. **Always complete traces**
```ruby
# Always call complete! or mark_error!
trace.complete!(output: result)
# or
trace.mark_error!(error_message: "Something went wrong")
```

### 5. **Keep input/output concise**
```ruby
# Good: Summary
input: "User question about billing"
output: "Generated 150-word response"

# Bad: Full content (use metadata instead)
input: "Very long text..." # Don't do this
```

