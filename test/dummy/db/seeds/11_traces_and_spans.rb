# frozen_string_literal: true

# ============================================================================
# Traces and Spans (Logging/Tracing Data)
# ============================================================================

puts "  Creating traces and spans..."

# ============================================================================
# Session 1: Customer Support Chat (Multiple Traces)
# ============================================================================
session_1_id = "chat_support_#{SecureRandom.hex(4)}"

# Trace 1: Simple greeting generation
trace_1_started = 2.hours.ago
trace_1 = PromptTracker::Trace.create!(
  name: "customer_greeting",
  session_id: session_1_id,
  user_id: "user_alice",
  input: "Generate greeting for customer John with billing issue",
  started_at: trace_1_started,
  status: "completed",
  output: "Hello John! I'm here to help with your billing question.",
  ended_at: trace_1_started + 1.2.seconds,
  duration_ms: 1200,
  metadata: { source: "web_chat", priority: "normal" }
)

# Trace 2: RAG-based question answering (with multiple spans)
trace_2_started = 1.hour.ago
trace_2 = PromptTracker::Trace.create!(
  name: "rag_question_answering",
  session_id: session_1_id,
  user_id: "user_alice",
  input: "How do I reset my password?",
  started_at: trace_2_started,
  status: "completed",
  output: "To reset your password: 1. Click 'Forgot Password' 2. Enter your email 3. Check your inbox",
  ended_at: trace_2_started + 3.5.seconds,
  duration_ms: 3500,
  metadata: { source: "web_chat", model: "gpt-4o" }
)

# Spans for RAG trace
retrieval_span = PromptTracker::Span.create!(
  trace: trace_2,
  name: "search_knowledge_base",
  span_type: "retrieval",
  input: "password reset instructions",
  output: "Found 3 relevant documents",
  status: "completed",
  started_at: trace_2_started + 0.1.seconds,
  ended_at: trace_2_started + 0.8.seconds,
  duration_ms: 700,
  metadata: { documents_found: 3, index: "support_docs" }
)

generation_span = PromptTracker::Span.create!(
  trace: trace_2,
  name: "generate_response",
  span_type: "function",
  input: "Context: [3 documents] Question: How do I reset my password?",
  output: "To reset your password: 1. Click 'Forgot Password'...",
  status: "completed",
  started_at: trace_2_started + 0.9.seconds,
  ended_at: trace_2_started + 3.2.seconds,
  duration_ms: 2300,
  metadata: { model: "gpt-4o", tokens: 150 }
)

# ============================================================================
# Session 2: Technical Troubleshooting (Complex Workflow)
# ============================================================================
session_2_id = "tech_support_#{SecureRandom.hex(4)}"

# Trace 3: Multi-step troubleshooting with nested spans
trace_3_started = 30.minutes.ago
trace_3 = PromptTracker::Trace.create!(
  name: "troubleshoot_connection_issue",
  session_id: session_2_id,
  user_id: "user_bob",
  input: "My internet keeps disconnecting",
  started_at: trace_3_started,
  status: "completed",
  output: "Issue diagnosed: Router firmware outdated. Recommended: Update to v2.3.1",
  ended_at: trace_3_started + 8.seconds,
  duration_ms: 8000,
  metadata: { ticket_id: "TECH-12345", category: "network" }
)

# Parent span: Diagnosis
diagnosis_span = PromptTracker::Span.create!(
  trace: trace_3,
  name: "diagnose_issue",
  span_type: "function",
  input: "Symptoms: intermittent disconnections",
  output: "Possible causes: router, ISP, hardware",
  status: "completed",
  started_at: trace_3_started + 0.1.seconds,
  ended_at: trace_3_started + 4.seconds,
  duration_ms: 3900,
  metadata: { step: 1 }
)

# Child span: Database lookup
db_lookup_span = PromptTracker::Span.create!(
  trace: trace_3,
  parent_span: diagnosis_span,
  name: "lookup_device_history",
  span_type: "database",
  input: "device_id: router_001",
  output: "Found 12 previous incidents",
  status: "completed",
  started_at: trace_3_started + 0.5.seconds,
  ended_at: trace_3_started + 0.8.seconds,
  duration_ms: 300,
  metadata: { table: "device_incidents", rows_returned: 12 }
)

# Child span: External API call
api_span = PromptTracker::Span.create!(
  trace: trace_3,
  parent_span: diagnosis_span,
  name: "check_firmware_version",
  span_type: "http",
  input: "GET /api/devices/router_001/firmware",
  output: '{"current": "2.1.0", "latest": "2.3.1"}',
  status: "completed",
  started_at: trace_3_started + 1.second,
  ended_at: trace_3_started + 2.5.seconds,
  duration_ms: 1500,
  metadata: { endpoint: "device-service", http_status: 200 }
)

# Resolution span
resolution_span = PromptTracker::Span.create!(
  trace: trace_3,
  name: "generate_resolution",
  span_type: "function",
  input: "Diagnosis: outdated firmware (2.1.0 vs 2.3.1)",
  output: "Recommendation: Update router firmware to v2.3.1",
  status: "completed",
  started_at: trace_3_started + 4.5.seconds,
  ended_at: trace_3_started + 7.5.seconds,
  duration_ms: 3000,
  metadata: { confidence: 0.95, model: "gpt-4o" }
)

# ============================================================================
# Session 3: Failed/Error Traces
# ============================================================================
session_3_id = "error_demo_#{SecureRandom.hex(4)}"

# Trace 4: Failed trace (timeout)
trace_4_started = 15.minutes.ago
trace_4 = PromptTracker::Trace.create!(
  name: "complex_analysis",
  session_id: session_3_id,
  user_id: "user_charlie",
  input: "Analyze 500 customer reviews for sentiment",
  started_at: trace_4_started,
  status: "error",
  ended_at: trace_4_started + 30.seconds,
  duration_ms: 30000,
  metadata: { error: "Request timeout after 30 seconds", error_type: "TimeoutError" }
)

# Span that failed within the trace
failed_span = PromptTracker::Span.create!(
  trace: trace_4,
  name: "batch_sentiment_analysis",
  span_type: "function",
  input: "500 reviews to analyze",
  status: "error",
  started_at: trace_4_started + 0.5.seconds,
  ended_at: trace_4_started + 30.seconds,
  duration_ms: 29500,
  metadata: { error: "OpenAI API timeout", reviews_processed: 127 }
)

# ============================================================================
# Session 4: Currently Running Trace
# ============================================================================
session_4_id = "live_session_#{SecureRandom.hex(4)}"

# Trace 5: Running trace (in progress)
trace_5 = PromptTracker::Trace.create!(
  name: "generate_report",
  session_id: session_4_id,
  user_id: "user_diana",
  input: "Generate weekly sales report",
  started_at: 2.minutes.ago,
  status: "running",
  metadata: { report_type: "weekly_sales", format: "pdf" }
)

# Running span
PromptTracker::Span.create!(
  trace: trace_5,
  name: "fetch_sales_data",
  span_type: "database",
  input: "SELECT * FROM sales WHERE date >= '2024-01-01'",
  status: "completed",
  started_at: 2.minutes.ago,
  ended_at: 1.minute.ago,
  duration_ms: 60000,
  metadata: { rows_fetched: 15000 }
)

PromptTracker::Span.create!(
  trace: trace_5,
  name: "generate_summary",
  span_type: "function",
  input: "15000 sales records",
  status: "running",
  started_at: 1.minute.ago,
  metadata: { model: "gpt-4o" }
)

# ============================================================================
# Session 5: Email Processing Workflow
# ============================================================================
session_5_id = "email_workflow_#{SecureRandom.hex(4)}"

# Trace 6: Email processing with tool calls
trace_6_started = 45.minutes.ago
trace_6 = PromptTracker::Trace.create!(
  name: "process_support_email",
  session_id: session_5_id,
  user_id: "user_system",
  input: "Subject: Urgent - Account locked\nBody: I cannot access my account since yesterday...",
  started_at: trace_6_started,
  status: "completed",
  output: "Email classified as 'account_access', priority: high, auto-reply sent",
  ended_at: trace_6_started + 5.seconds,
  duration_ms: 5000,
  metadata: { email_id: "email_98765", channel: "support@example.com" }
)

# Classification span
PromptTracker::Span.create!(
  trace: trace_6,
  name: "classify_email",
  span_type: "function",
  input: "Email subject and body",
  output: '{"category": "account_access", "priority": "high", "sentiment": "frustrated"}',
  status: "completed",
  started_at: trace_6_started + 0.1.seconds,
  ended_at: trace_6_started + 1.5.seconds,
  duration_ms: 1400,
  metadata: { model: "gpt-4o-mini", confidence: 0.92 }
)

# Tool call span
PromptTracker::Span.create!(
  trace: trace_6,
  name: "lookup_customer",
  span_type: "tool",
  input: '{"email": "customer@email.com"}',
  output: '{"customer_id": "cust_123", "name": "John Smith", "tier": "premium"}',
  status: "completed",
  started_at: trace_6_started + 1.6.seconds,
  ended_at: trace_6_started + 2.seconds,
  duration_ms: 400,
  metadata: { tool: "customer_lookup", api_version: "v2" }
)

# Generate reply span
PromptTracker::Span.create!(
  trace: trace_6,
  name: "generate_reply",
  span_type: "function",
  input: "Customer: premium, Issue: account_access, Priority: high",
  output: "Dear John, We're sorry to hear about the account access issue...",
  status: "completed",
  started_at: trace_6_started + 2.1.seconds,
  ended_at: trace_6_started + 4.5.seconds,
  duration_ms: 2400,
  metadata: { template: "premium_support", personalized: true }
)

puts "  ✓ Created traces and spans"
puts "    - #{PromptTracker::Trace.count} traces (across 5 sessions)"
puts "    - #{PromptTracker::Span.count} spans (including #{PromptTracker::Span.where.not(parent_span_id: nil).count} nested)"
