# 💡 Real-World Examples

## Example 1: Simple Chat Bot

### Scenario
User sends messages to a chatbot. Each message is a trace, all messages in the conversation share a session_id.

### Code

```ruby
class ChatBotController < ApplicationController
  def send_message
    user = current_user
    conversation_id = params[:conversation_id]
    message = params[:message]
    
    # Create trace for this message
    trace = PromptTracker::Trace.create!(
      name: "chat_message",
      input: message,
      session_id: conversation_id,  # ← Groups all messages in this conversation
      user_id: user.id,
      started_at: Time.current,
      metadata: { source: "web_ui" }
    )
    
    # Generate response
    result = PromptTracker::LlmCallService.track(
      prompt_name: "chatbot_response",
      variables: { 
        message: message,
        history: load_conversation_history(conversation_id)
      },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      user_id: user.id,
      session_id: conversation_id
    ) do |rendered_prompt|
      call_openai(rendered_prompt)
    end
    
    # Complete trace
    trace.complete!(output: result[:response_text])
    
    render json: { response: result[:response_text] }
  end
end
```

### What You Get

**Sessions View** (`/sessions`):
```
conversation_abc123  │ user_1  │ 5 traces  │ 10 minutes ago
```

**Session Detail** (`/sessions/conversation_abc123`):
```
1. chat_message (200ms) - "Hello!"
2. chat_message (350ms) - "How are you?"
3. chat_message (280ms) - "Tell me a joke"
4. chat_message (420ms) - "What's the weather?"
5. chat_message (190ms) - "Goodbye!"
```

**Trace Detail** (`/traces/:id`):
```
Trace: chat_message
Input: "Tell me a joke"
Output: "Why did the chicken cross the road?..."
└── LLM Generation (280ms, gpt-4, $0.002)
```

---

## Example 2: RAG Question Answering

### Scenario
User asks a question. System searches knowledge base, then generates answer using retrieved context.

### Code

```ruby
class QaService
  def answer_question(question:, user:)
    # Create trace
    trace = PromptTracker::Trace.create!(
      name: "rag_question_answering",
      input: question,
      session_id: "user_#{user.id}_#{Date.today}",
      user_id: user.id,
      started_at: Time.current
    )
    
    # Step 1: Retrieval (span)
    retrieval_span = trace.spans.create!(
      name: "retrieve_documents",
      span_type: "retrieval",
      input: question,
      started_at: Time.current,
      metadata: { vector_store: "pinecone" }
    )
    
    documents = VectorStore.search(question, limit: 5)
    
    retrieval_span.complete!(
      output: "Retrieved #{documents.count} documents"
    )
    
    # Step 2: Generation (span + LLM call)
    generation_span = trace.spans.create!(
      name: "generate_answer",
      span_type: "function",
      input: { question: question, doc_count: documents.count },
      started_at: Time.current
    )
    
    result = PromptTracker::LlmCallService.track(
      prompt_name: "rag_answer",
      variables: { 
        question: question,
        context: documents.map(&:content).join("\n\n")
      },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: generation_span
    ) do |rendered_prompt|
      call_openai(rendered_prompt)
    end
    
    generation_span.complete!(output: result[:response_text])
    trace.complete!(output: result[:response_text])
    
    result[:response_text]
  end
end
```

### What You Get

**Trace Detail**:
```
Trace: rag_question_answering
Input: "What is machine learning?"
Output: "Machine learning is a subset of AI..."
Duration: 1,250ms

Timeline:
├─ retrieve_documents (retrieval) - 200ms
│  Output: "Retrieved 5 documents"
│
└─ generate_answer (function) - 1,000ms
   └─ LLM Generation (950ms, gpt-4, $0.003)
      Output: "Machine learning is a subset of AI..."
```

---

## Example 3: Multi-Step Content Pipeline

### Scenario
Generate content, enhance it, translate it, and format it.

### Code

```ruby
class ContentPipelineService
  def process_content(topic:, target_language:)
    trace = PromptTracker::Trace.create!(
      name: "content_pipeline",
      input: { topic: topic, language: target_language },
      started_at: Time.current
    )
    
    # Step 1: Generate initial content
    generate_span = trace.spans.create!(
      name: "generate_content",
      span_type: "function",
      started_at: Time.current
    )
    
    content = PromptTracker::LlmCallService.track(
      prompt_name: "content_generator",
      variables: { topic: topic },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: generate_span
    ) { |prompt| call_openai(prompt) }
    
    generate_span.complete!(output: content[:response_text])
    
    # Step 2: Enhance content
    enhance_span = trace.spans.create!(
      name: "enhance_content",
      span_type: "function",
      started_at: Time.current
    )
    
    enhanced = PromptTracker::LlmCallService.track(
      prompt_name: "content_enhancer",
      variables: { content: content[:response_text] },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: enhance_span
    ) { |prompt| call_openai(prompt) }
    
    enhance_span.complete!(output: enhanced[:response_text])
    
    # Step 3: Translate
    translate_span = trace.spans.create!(
      name: "translate_content",
      span_type: "function",
      started_at: Time.current
    )
    
    translated = PromptTracker::LlmCallService.track(
      prompt_name: "translator",
      variables: { 
        content: enhanced[:response_text],
        target_language: target_language
      },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: translate_span
    ) { |prompt| call_openai(prompt) }
    
    translate_span.complete!(output: translated[:response_text])
    trace.complete!(output: translated[:response_text])
    
    translated[:response_text]
  end
end
```

### What You Get

**Trace Detail**:
```
Trace: content_pipeline
Duration: 4,500ms
Total Cost: $0.009

Timeline:
├─ generate_content (function) - 1,200ms
│  └─ LLM Generation (1,150ms, gpt-4, $0.003)
│
├─ enhance_content (function) - 1,800ms
│  └─ LLM Generation (1,750ms, gpt-4, $0.004)
│
└─ translate_content (function) - 1,500ms
   └─ LLM Generation (1,450ms, gpt-4, $0.002)
```

---

## Example 4: Nested Spans (Agent with Tools)

### Scenario
AI agent decides to use multiple tools to answer a question.

### Code

```ruby
class AgentService
  def run(query:)
    trace = PromptTracker::Trace.create!(
      name: "agent_workflow",
      input: query,
      started_at: Time.current
    )
    
    # Main agent span
    agent_span = trace.spans.create!(
      name: "agent_reasoning",
      span_type: "function",
      started_at: Time.current
    )
    
    # Tool 1: Weather API (nested under agent)
    weather_span = agent_span.create_child_span(
      name: "call_weather_api",
      span_type: "tool"
    )
    weather_data = call_weather_api("Paris")
    weather_span.complete!(output: weather_data.to_json)
    
    # Tool 2: Search (nested under agent)
    search_span = agent_span.create_child_span(
      name: "search_web",
      span_type: "tool"
    )
    search_results = search_web("Paris weather")
    search_span.complete!(output: "Found #{search_results.count} results")
    
    # Final LLM call to synthesize
    result = PromptTracker::LlmCallService.track(
      prompt_name: "agent_synthesize",
      variables: { 
        query: query,
        weather: weather_data,
        search: search_results
      },
      provider: "openai",
      model: "gpt-4",
      trace: trace,
      span: agent_span
    ) { |prompt| call_openai(prompt) }
    
    agent_span.complete!(output: result[:response_text])
    trace.complete!(output: result[:response_text])
    
    result[:response_text]
  end
end
```

### What You Get

**Trace Detail**:
```
Trace: agent_workflow
Input: "What's the weather in Paris?"

Timeline:
└─ agent_reasoning (function) - 2,500ms
   ├─ call_weather_api (tool) - 300ms
   │  Output: {"temp": 18, "condition": "sunny"}
   │
   ├─ search_web (tool) - 450ms
   │  Output: "Found 10 results"
   │
   └─ LLM Generation (1,700ms, gpt-4, $0.004)
      Output: "The weather in Paris is currently sunny..."
```

---

## Example 5: Error Handling

### Code

```ruby
trace = PromptTracker::Trace.create!(
  name: "risky_operation",
  input: "Process this",
  started_at: Time.current
)

begin
  span = trace.spans.create!(
    name: "dangerous_step",
    span_type: "function",
    started_at: Time.current
  )
  
  # Something that might fail
  result = do_risky_thing
  
  span.complete!(output: result)
  trace.complete!(output: result)
  
rescue => e
  span&.mark_error!(error_message: e.message)
  trace.mark_error!(error_message: e.message)
  raise
end
```

### What You Get

**Trace Detail**:
```
Trace: risky_operation
Status: error ❌
Duration: 150ms

Timeline:
└─ dangerous_step (function) - error ❌
   Error: "API rate limit exceeded"
```

---

## Key Patterns

1. **Session ID = Conversation/Thread ID**
   - Use same session_id for related traces
   - Example: `"chat_#{user_id}_#{conversation_id}"`

2. **Trace = One User Request**
   - Each API call, message, or workflow = one trace
   - Name it descriptively: "rag_question", "chat_message"

3. **Spans = Steps Within Trace**
   - Use for retrieval, tool calls, processing steps
   - Can be nested for complex workflows

4. **Always Complete Traces**
   - Call `trace.complete!` or `trace.mark_error!`
   - Don't leave traces in "running" state

5. **Link LLM Calls**
   - Pass `trace:` and optionally `span:` to LlmCallService
   - Creates proper hierarchy

