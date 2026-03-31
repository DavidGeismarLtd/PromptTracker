# frozen_string_literal: true

# ============================================================================
# Sample Traces & Spans for Hierarchical Monitoring
#
# This seed file creates a small, Langfuse-style example session:
#
#   Session: "chat_user123"
#     ├─ Trace: "greeting" (single LLM call)
#     ├─ Trace: "question_1" (nested spans: search_kb → generate_answer)
#     └─ Trace: "question_2" (single span with LLM call)
#
# It reuses existing successful LLM responses created in 08_llm_responses.rb
# so the monitoring UI can show a realistic hierarchy without duplicating
# prompt configuration.
# ============================================================================

puts "  Creating sample traces and spans..."

# Find the active customer support greeting version
support_greeting_v3 = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "customer_support_greeting" })
  .where(status: "active")
  .first!

# Reuse three successful responses as our example conversation turns
sample_responses = support_greeting_v3.llm_responses
  .successful
  .order(:created_at)
  .limit(3)
  .to_a

session_id = "chat_user123"
user_id = "user_123"
base_time = Time.current - 10.minutes

# Normalise session/user metadata so all three calls clearly belong together
sample_responses.each_with_index do |response, index|
  response.update!(
    user_id: user_id,
    session_id: session_id,
    conversation_id: session_id,
    turn_number: index + 1
  )
end

# --------------------------------------------------------------------------
# Trace 1: greeting (single LLM call)
# --------------------------------------------------------------------------

greeting_started_at = base_time
greeting_ended_at = greeting_started_at + 0.2.seconds

greeting_trace = PromptTracker::Trace.create!(
  name: "greeting",
  session_id: session_id,
  user_id: user_id,
  status: "success",
  started_at: greeting_started_at,
  ended_at: greeting_ended_at,
  duration_ms: ((greeting_ended_at - greeting_started_at) * 1000).round,
  input: sample_responses[0].rendered_prompt,
  output: sample_responses[0].response_text,
  metadata: { channel: "web", example: "chat_session" }
)

sample_responses[0].update!(trace: greeting_trace)

# --------------------------------------------------------------------------
# Trace 2: question_1 (search_kb span → generate_answer span)
# --------------------------------------------------------------------------

question1_started_at = base_time + 30.seconds
question1_ended_at = question1_started_at + 1.25.seconds

question1_trace = PromptTracker::Trace.create!(
  name: "question_1",
  session_id: session_id,
  user_id: user_id,
  status: "success",
  started_at: question1_started_at,
  ended_at: question1_ended_at,
  duration_ms: ((question1_ended_at - question1_started_at) * 1000).round,
  input: sample_responses[1].rendered_prompt,
  output: sample_responses[1].response_text,
  metadata: { channel: "web", example: "chat_session" }
)

search_kb_span = question1_trace.spans.create!(
  name: "search_kb",
  span_type: "retrieval",
  status: "success",
  started_at: question1_started_at,
  ended_at: question1_started_at + 0.2.seconds,
  duration_ms: 200,
  input: "Query: \"How do I update my billing info?\"",
  output: "Top 3 results from knowledge base",
  metadata: { index: "kb_articles", results_count: 3 }
)

generate_answer_span = question1_trace.spans.create!(
  parent_span: search_kb_span,
  name: "generate_answer",
  span_type: "llm",
  status: "success",
  started_at: question1_started_at + 0.25.seconds,
  ended_at: question1_ended_at,
  duration_ms: ((question1_ended_at - (question1_started_at + 0.25.seconds)) * 1000).round,
  input: "KB snippets + user question",
  output: sample_responses[1].response_text,
  metadata: { provider: sample_responses[1].provider, model: sample_responses[1].model }
)

sample_responses[1].update!(trace: question1_trace, span: generate_answer_span)

# --------------------------------------------------------------------------
# Trace 3: question_2 (single span with LLM call)
# --------------------------------------------------------------------------

question2_started_at = base_time + 70.seconds
question2_ended_at = question2_started_at + 0.85.seconds

question2_trace = PromptTracker::Trace.create!(
  name: "question_2",
  session_id: session_id,
  user_id: user_id,
  status: "success",
  started_at: question2_started_at,
  ended_at: question2_ended_at,
  duration_ms: ((question2_ended_at - question2_started_at) * 1000).round,
  input: sample_responses[2].rendered_prompt,
  output: sample_responses[2].response_text,
  metadata: { channel: "web", example: "chat_session" }
)

question2_span = question2_trace.spans.create!(
  name: "generate_answer",
  span_type: "llm",
  status: "success",
  started_at: question2_started_at,
  ended_at: question2_ended_at,
  duration_ms: ((question2_ended_at - question2_started_at) * 1000).round,
  input: sample_responses[2].rendered_prompt,
  output: sample_responses[2].response_text,
  metadata: { provider: sample_responses[2].provider, model: sample_responses[2].model }
)

sample_responses[2].update!(trace: question2_trace, span: question2_span)

puts "  ✓ Created sample traces and spans for session #{session_id}"
