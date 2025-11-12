# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding PromptTracker database..."

# Clean up existing data
puts "  Cleaning up existing data..."
PromptTracker::Evaluation.delete_all
PromptTracker::LlmResponse.delete_all
PromptTracker::AbTest.delete_all
PromptTracker::PromptVersion.delete_all
PromptTracker::Prompt.delete_all

# ============================================================================
# 1. Customer Support Prompts
# ============================================================================

puts "  Creating customer support prompts..."

support_greeting = PromptTracker::Prompt.create!(
  name: "customer_support_greeting",
  description: "Initial greeting for customer support interactions",
  category: "support",
  tags: ["customer-facing", "greeting", "high-priority"],
  created_by: "support-team@example.com"
)

# Version 1 - Original
support_greeting_v1 = support_greeting.prompt_versions.create!(
  template: "Hello {{customer_name}}! Thank you for contacting support. How can I help you with {{issue_category}} today?",
  status: "deprecated",
  source: "file",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true },
    { "name" => "issue_category", "type" => "string", "required" => false }
  ],
  model_config: { "temperature" => 0.7, "max_tokens" => 150 },
  notes: "Original version - too formal",
  created_by: "john@example.com"
)

# Version 2 - More casual
support_greeting_v2 = support_greeting.prompt_versions.create!(
  template: "Hi {{customer_name}}! 👋 Thanks for reaching out. What can I help you with today?",
  status: "deprecated",
  source: "web_ui",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.8, "max_tokens" => 100 },
  notes: "Tested in web UI - more casual tone",
  created_by: "sarah@example.com"
)

# Version 3 - Current active version
support_greeting_v3 = support_greeting.prompt_versions.create!(
  template: "Hi {{customer_name}}! Thanks for contacting us. I'm here to help with your {{issue_category}} question. What's going on?",
  status: "active",
  source: "file",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true },
    { "name" => "issue_category", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.7, "max_tokens" => 120 },
  notes: "Best performing version - friendly but professional",
  created_by: "john@example.com"
)

# Version 4 - Draft: Even shorter version for testing
support_greeting_v4 = support_greeting.prompt_versions.create!(
  template: "Hey {{customer_name}}! What's up with {{issue_category}}?",
  status: "draft",
  source: "web_ui",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true },
    { "name" => "issue_category", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.9, "max_tokens" => 80 },
  notes: "Testing very casual tone - might be too informal",
  created_by: "sarah@example.com"
)

# Version 5 - Draft: More empathetic version
support_greeting_v5 = support_greeting.prompt_versions.create!(
  template: "Hi {{customer_name}}, I understand you're having an issue with {{issue_category}}. I'm here to help you resolve this. Can you tell me more about what's happening?",
  status: "draft",
  source: "web_ui",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true },
    { "name" => "issue_category", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.6, "max_tokens" => 150 },
  notes: "Testing more empathetic approach - might be too long",
  created_by: "alice@example.com"
)

# ============================================================================
# 2. Email Generation Prompts
# ============================================================================

puts "  Creating email generation prompts..."

email_summary = PromptTracker::Prompt.create!(
  name: "email_summary_generator",
  description: "Generates concise summaries of long email threads",
  category: "email",
  tags: ["productivity", "summarization"],
  created_by: "product-team@example.com"
)

email_summary_v1 = email_summary.prompt_versions.create!(
  template: "Summarize the following email thread in 2-3 sentences:\n\n{{email_thread}}",
  status: "active",
  source: "file",
  variables_schema: [
    { "name" => "email_thread", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.3, "max_tokens" => 200 },
  created_by: "alice@example.com"
)

# Version 2 - Draft: Bullet point format
email_summary_v2 = email_summary.prompt_versions.create!(
  template: "Summarize the following email thread as bullet points (3-5 key points):\n\n{{email_thread}}",
  status: "draft",
  source: "web_ui",
  variables_schema: [
    { "name" => "email_thread", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.3, "max_tokens" => 250 },
  notes: "Testing bullet point format for easier scanning",
  created_by: "bob@example.com"
)

# ============================================================================
# 3. Code Review Prompts
# ============================================================================

puts "  Creating code review prompts..."

code_review = PromptTracker::Prompt.create!(
  name: "code_review_assistant",
  description: "Provides constructive code review feedback",
  category: "development",
  tags: ["code-quality", "engineering"],
  created_by: "engineering@example.com"
)

code_review_v1 = code_review.prompt_versions.create!(
  template: <<~TEMPLATE,
    Review the following {{language}} code and provide constructive feedback:

    ```{{language}}
    {{code}}
    ```

    Focus on:
    - Code quality and readability
    - Potential bugs or edge cases
    - Performance considerations
    - Best practices

    Be constructive and specific.
  TEMPLATE
  status: "active",
  source: "file",
  variables_schema: [
    { "name" => "language", "type" => "string", "required" => true },
    { "name" => "code", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.4, "max_tokens" => 500 },
  created_by: "bob@example.com"
)

# ============================================================================
# 4. Create Sample LLM Responses
# ============================================================================

puts "  Creating sample LLM responses..."

# Successful responses for support greeting v3
5.times do |i|
  response = support_greeting_v3.llm_responses.create!(
    rendered_prompt: "Hi John! Thanks for contacting us. I'm here to help with your billing question. What's going on?",
    variables_used: { "customer_name" => "John", "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4",
    user_id: "user_#{i + 1}",
    session_id: "session_#{i + 1}",
    environment: "production"
  )

  response.mark_success!(
    response_text: "I'd be happy to help you with your billing question. Could you please provide more details about the specific issue you're experiencing?",
    response_time_ms: rand(800..1500),
    tokens_prompt: 25,
    tokens_completion: rand(20..30),
    tokens_total: rand(45..55),
    cost_usd: rand(0.0008..0.0015).round(6),
    response_metadata: { "finish_reason" => "stop", "model" => "gpt-4-0125-preview" }
  )
end

# Failed response
failed_response = support_greeting_v3.llm_responses.create!(
  rendered_prompt: "Hi Jane! Thanks for contacting us. I'm here to help with your technical question. What's going on?",
  variables_used: { "customer_name" => "Jane", "issue_category" => "technical" },
  provider: "openai",
  model: "gpt-4",
  user_id: "user_6",
  session_id: "session_6",
  environment: "production"
)

failed_response.mark_error!(
  error_type: "OpenAI::RateLimitError",
  error_message: "Rate limit exceeded. Please try again in 20 seconds.",
  response_time_ms: 450
)

# Timeout response
timeout_response = support_greeting_v3.llm_responses.create!(
  rendered_prompt: "Hi Bob! Thanks for contacting us. I'm here to help with your account question. What's going on?",
  variables_used: { "customer_name" => "Bob", "issue_category" => "account" },
  provider: "anthropic",
  model: "claude-3-opus",
  user_id: "user_7",
  session_id: "session_7",
  environment: "production"
)

timeout_response.mark_timeout!(
  response_time_ms: 30000,
  error_message: "Request timed out after 30 seconds"
)

# Responses for older versions (v1 and v2)
2.times do |i|
  response = support_greeting_v1.llm_responses.create!(
    rendered_prompt: "Hello Sarah! Thank you for contacting support. How can I help you with billing today?",
    variables_used: { "customer_name" => "Sarah", "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-3.5-turbo",
    user_id: "user_old_#{i + 1}",
    environment: "production"
  )

  response.mark_success!(
    response_text: "I would be pleased to assist you with your billing inquiry.",
    response_time_ms: rand(600..1000),
    tokens_total: rand(30..40),
    cost_usd: rand(0.0003..0.0006).round(6)
  )
end

# Email summary responses
3.times do |i|
  response = email_summary_v1.llm_responses.create!(
    rendered_prompt: "Summarize the following email thread in 2-3 sentences:\n\nLong email thread here...",
    variables_used: { "email_thread" => "Long email thread here..." },
    provider: "openai",
    model: "gpt-4",
    user_id: "user_email_#{i + 1}",
    environment: "production"
  )

  response.mark_success!(
    response_text: "The email thread discusses the upcoming product launch. The team agrees on a March 15th release date. Action items include finalizing the marketing materials and scheduling a press release.",
    response_time_ms: rand(1000..2000),
    tokens_total: rand(60..80),
    cost_usd: rand(0.0015..0.0025).round(6)
  )
end

# ============================================================================
# 5. Create Sample Evaluations
# ============================================================================

puts "  Creating sample evaluations..."

# Get successful responses
successful_responses = PromptTracker::LlmResponse.successful.limit(5)

successful_responses.each_with_index do |response, i|
  # Human evaluation
  response.evaluations.create!(
    score: rand(3.5..5.0).round(1),
    score_max: 5,
    criteria_scores: {
      "helpfulness" => rand(4..5),
      "tone" => rand(3..5),
      "accuracy" => rand(4..5),
      "conciseness" => rand(3..5)
    },
    evaluator_type: "human",
    evaluator_id: "manager@example.com",
    feedback: ["Great response!", "Very helpful", "Could be more concise", "Perfect tone"][i % 4]
  )

  # Automated evaluation
  response.evaluations.create!(
    score: rand(70..95),
    score_max: 100,
    evaluator_type: "automated",
    evaluator_id: "sentiment_analyzer_v1",
    metadata: {
      "confidence" => rand(0.8..0.99).round(2),
      "processing_time_ms" => rand(50..200)
    }
  )

  # LLM judge evaluation (for some responses)
  if i.even?
    response.evaluations.create!(
      score: rand(3.5..4.8).round(1),
      score_max: 5,
      criteria_scores: {
        "helpfulness" => rand(4..5),
        "professionalism" => rand(4..5)
      },
      evaluator_type: "llm_judge",
      evaluator_id: "gpt-4",
      feedback: "The response is helpful and maintains a professional yet friendly tone.",
      metadata: {
        "reasoning" => "Good balance of professionalism and warmth",
        "evaluation_cost_usd" => 0.0002
      }
    )
  end
end

# ============================================================================
# 6. Create Sample A/B Tests
# ============================================================================

puts "  Creating sample A/B tests..."

# A/B Test 1: Draft - Testing casual vs empathetic greeting
ab_test_greeting_draft = support_greeting.ab_tests.create!(
  name: "Casual vs Empathetic Greeting",
  description: "Testing if a more empathetic greeting improves customer satisfaction",
  hypothesis: "More empathetic greeting will increase satisfaction scores by 15%",
  status: "draft",
  metric_to_optimize: "quality_score",
  optimization_direction: "maximize",
  traffic_split: { "A" => 50, "B" => 50 },
  variants: [
    { "name" => "A", "version_id" => support_greeting_v4.id, "description" => "Casual version" },
    { "name" => "B", "version_id" => support_greeting_v5.id, "description" => "Empathetic version" }
  ],
  confidence_level: 0.95,
  minimum_sample_size: 100,
  created_by: "sarah@example.com"
)

# A/B Test 2: Running - Testing current vs casual greeting
ab_test_greeting_running = support_greeting.ab_tests.create!(
  name: "Current vs Casual Greeting",
  description: "Testing if casual greeting reduces response time while maintaining quality",
  hypothesis: "Casual greeting will reduce response time by 20% without hurting satisfaction",
  status: "running",
  metric_to_optimize: "response_time",
  optimization_direction: "minimize",
  traffic_split: { "A" => 70, "B" => 30 },
  variants: [
    { "name" => "A", "version_id" => support_greeting_v3.id, "description" => "Current active version" },
    { "name" => "B", "version_id" => support_greeting_v4.id, "description" => "Casual version" }
  ],
  confidence_level: 0.95,
  minimum_sample_size: 200,
  minimum_detectable_effect: 0.15,
  started_at: 3.days.ago,
  created_by: "john@example.com"
)

# Create some responses for the running A/B test
puts "  Creating A/B test responses..."

# Variant A responses (current version)
15.times do |i|
  response = support_greeting_v3.llm_responses.create!(
    rendered_prompt: "Hi #{['Alice', 'Bob', 'Charlie'][i % 3]}! Thanks for contacting us. I'm here to help with your billing question. What's going on?",
    variables_used: { "customer_name" => ['Alice', 'Bob', 'Charlie'][i % 3], "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4",
    user_id: "ab_test_user_a_#{i + 1}",
    session_id: "ab_test_session_a_#{i + 1}",
    environment: "production",
    ab_test_id: ab_test_greeting_running.id,
    ab_variant: "A"
  )

  response.mark_success!(
    response_text: "I'd be happy to help you with your billing question. Could you please provide more details?",
    response_time_ms: rand(1000..1400),
    tokens_prompt: 25,
    tokens_completion: rand(20..30),
    tokens_total: rand(45..55),
    cost_usd: rand(0.0008..0.0015).round(6),
    response_metadata: { "finish_reason" => "stop", "model" => "gpt-4-0125-preview" }
  )

  # Add evaluation
  response.evaluations.create!(
    score: rand(4.0..4.8).round(1),
    score_max: 5,
    evaluator_type: "human",
    evaluator_id: "evaluator@example.com"
  )
end

# Variant B responses (casual version)
8.times do |i|
  response = support_greeting_v4.llm_responses.create!(
    rendered_prompt: "Hey #{['Dave', 'Eve', 'Frank'][i % 3]}! What's up with billing?",
    variables_used: { "customer_name" => ['Dave', 'Eve', 'Frank'][i % 3], "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4",
    user_id: "ab_test_user_b_#{i + 1}",
    session_id: "ab_test_session_b_#{i + 1}",
    environment: "production",
    ab_test_id: ab_test_greeting_running.id,
    ab_variant: "B"
  )

  response.mark_success!(
    response_text: "Sure thing! What's the issue with your billing?",
    response_time_ms: rand(800..1100),
    tokens_prompt: 15,
    tokens_completion: rand(10..20),
    tokens_total: rand(25..35),
    cost_usd: rand(0.0005..0.0010).round(6),
    response_metadata: { "finish_reason" => "stop", "model" => "gpt-4-0125-preview" }
  )

  # Add evaluation
  response.evaluations.create!(
    score: rand(3.8..4.5).round(1),
    score_max: 5,
    evaluator_type: "human",
    evaluator_id: "evaluator@example.com"
  )
end

# A/B Test 3: Completed - Email summary format test
ab_test_email_completed = email_summary.ab_tests.create!(
  name: "Paragraph vs Bullet Points",
  description: "Testing if bullet point format is preferred over paragraph format",
  hypothesis: "Bullet points will be easier to scan and increase user satisfaction",
  status: "completed",
  metric_to_optimize: "quality_score",
  optimization_direction: "maximize",
  traffic_split: { "A" => 50, "B" => 50 },
  variants: [
    { "name" => "A", "version_id" => email_summary_v1.id, "description" => "Paragraph format" },
    { "name" => "B", "version_id" => email_summary_v2.id, "description" => "Bullet points" }
  ],
  confidence_level: 0.95,
  minimum_sample_size: 50,
  started_at: 10.days.ago,
  completed_at: 2.days.ago,
  results: {
    "winner" => "B",
    "is_significant" => true,
    "p_value" => 0.003,
    "improvement" => 18.5,
    "recommendation" => "Promote variant B to production",
    "A" => { "count" => 50, "mean" => 4.2, "std_dev" => 0.5 },
    "B" => { "count" => 50, "mean" => 4.8, "std_dev" => 0.4 }
  },
  created_by: "alice@example.com"
)

# ============================================================================
# Summary
# ============================================================================

puts "\n✅ Seeding complete!"
puts "\nCreated:"
puts "  - #{PromptTracker::Prompt.count} prompts"
puts "  - #{PromptTracker::PromptVersion.count} prompt versions"
puts "    - #{PromptTracker::PromptVersion.active.count} active"
puts "    - #{PromptTracker::PromptVersion.draft.count} draft"
puts "    - #{PromptTracker::PromptVersion.deprecated.count} deprecated"
puts "  - #{PromptTracker::LlmResponse.count} LLM responses"
puts "    - #{PromptTracker::LlmResponse.successful.count} successful"
puts "    - #{PromptTracker::LlmResponse.failed.count} failed"
puts "  - #{PromptTracker::Evaluation.count} evaluations"
puts "    - #{PromptTracker::Evaluation.by_humans.count} human"
puts "    - #{PromptTracker::Evaluation.automated.count} automated"
puts "    - #{PromptTracker::Evaluation.by_llm_judge.count} LLM judge"
puts "  - #{PromptTracker::AbTest.count} A/B tests"
puts "    - #{PromptTracker::AbTest.draft.count} draft"
puts "    - #{PromptTracker::AbTest.running.count} running"
puts "    - #{PromptTracker::AbTest.completed.count} completed"
puts "\nTotal cost: $#{PromptTracker::LlmResponse.sum(:cost_usd).round(4)}"
puts "Average response time: #{PromptTracker::LlmResponse.successful.average(:response_time_ms).to_i}ms"
puts "\n🎉 Ready to explore!"
puts "\n💡 Tips:"
puts "  - Visit /prompt_tracker to see all prompts"
puts "  - Check out the running A/B test: '#{ab_test_greeting_running.name}'"
puts "  - Create new A/B tests with draft versions v4 and v5"
