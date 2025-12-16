# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding PromptTracker database..."

# Clean up existing data (order matters due to foreign key constraints)
puts "  Cleaning up existing data..."
PromptTracker::Evaluation.delete_all
PromptTracker::PromptTestRun.delete_all  # Delete test runs before LLM responses
PromptTracker::PromptTest.delete_all
PromptTracker::LlmResponse.delete_all
PromptTracker::Span.delete_all
PromptTracker::Trace.delete_all
PromptTracker::AbTest.delete_all
PromptTracker::EvaluatorConfig.delete_all
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
  tags: [ "customer-facing", "greeting", "high-priority" ],
  created_by: "support-team@example.com"
)

# Version 1 - Original
support_greeting_v1 = support_greeting.prompt_versions.create!(
  user_prompt: "Hello {{customer_name}}! Thank you for contacting support. How can I help you with {{issue_category}} today?",
  status: "deprecated",
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
  user_prompt: "Hi {{customer_name}}! 👋 Thanks for reaching out. What can I help you with today?",
  status: "deprecated",
  variables_schema: [
    { "name" => "customer_name", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.8, "max_tokens" => 100 },
  notes: "Tested in web UI - more casual tone",
  created_by: "sarah@example.com"
)

# Version 3 - Current active version
support_greeting_v3 = support_greeting.prompt_versions.create!(
  user_prompt: "Hi {{customer_name}}! Thanks for contacting us. I'm here to help with your {{issue_category}} question. What's going on?",
  status: "active",
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
  user_prompt: "Hey {{customer_name}}! What's up with {{issue_category}}?",
  status: "draft",
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
  user_prompt: "Hi {{customer_name}}, I understand you're having an issue with {{issue_category}}. I'm here to help you resolve this. Can you tell me more about what's happening?",
  status: "draft",
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
  tags: [ "productivity", "summarization" ],
  created_by: "product-team@example.com"
)

email_summary_v1 = email_summary.prompt_versions.create!(
  user_prompt: "Summarize the following email thread in 2-3 sentences:\n\n{{email_thread}}",
  status: "active",
  variables_schema: [
    { "name" => "email_thread", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.3, "max_tokens" => 200 },
  created_by: "alice@example.com"
)

# Version 2 - Draft: Bullet point format
email_summary_v2 = email_summary.prompt_versions.create!(
  user_prompt: "Summarize the following email thread as bullet points (3-5 key points):\n\n{{email_thread}}",
  status: "draft",
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
  tags: [ "code-quality", "engineering" ],
  created_by: "engineering@example.com"
)

code_review_v1 = code_review.prompt_versions.create!(
  user_prompt: <<~TEMPLATE,
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
  variables_schema: [
    { "name" => "language", "type" => "string", "required" => true },
    { "name" => "code", "type" => "string", "required" => true }
  ],
  model_config: { "temperature" => 0.4, "max_tokens" => 500 },
  created_by: "bob@example.com"
)

# ============================================================================
# 4. Create Sample Tests
# ============================================================================

puts "  Creating sample tests..."

# Tests for support greeting v3 (active version)
test_greeting_premium = support_greeting_v3.prompt_tests.create!(
  name: "Premium Customer Greeting",
  description: "Test greeting for premium customers with billing issues",
<<<<<<< HEAD
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  tags: [ "premium", "billing" ],
  enabled: true
)

# Add pattern match evaluator
test_greeting_premium.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: { patterns: [ "John Smith", "billing" ], match_all: true }
)

# Create evaluator config for this test
test_greeting_premium.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",
  config: { "min_length" => 10, "max_length" => 500 },
=======
  template_variables: { "customer_name" => "John Smith", "issue_category" => "billing" },
  expected_patterns: [ "John Smith", "billing" ],
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 0,
      "config" => { "min_length" => 10, "max_length" => 500 }
    }
  ],
  tags: [ "premium", "billing" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

test_greeting_technical = support_greeting_v3.prompt_tests.create!(
  name: "Technical Support Greeting",
  description: "Test greeting for technical support inquiries",
<<<<<<< HEAD
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  tags: [ "technical" ],
  enabled: true
)

test_greeting_technical.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: { patterns: [ "Sarah Johnson", "technical" ], match_all: true }
)

test_greeting_technical.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",
  config: { "min_length" => 10, "max_length" => 500 },
=======
  template_variables: { "customer_name" => "Sarah Johnson", "issue_category" => "technical" },
  expected_patterns: [ "Sarah Johnson", "technical" ],
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 0,
      "config" => { "min_length" => 10, "max_length" => 500 }
    }
  ],
  tags: [ "technical" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

test_greeting_account = support_greeting_v3.prompt_tests.create!(
  name: "Account Issue Greeting",
  description: "Test greeting for account-related questions",
<<<<<<< HEAD
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  tags: [ "account" ],
  enabled: true
)

test_greeting_account.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: { patterns: [ "Mike Davis", "account" ], match_all: true }
)

test_greeting_account.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",
  config: { "min_length" => 10, "max_length" => 500 },
=======
  template_variables: { "customer_name" => "Mike Davis", "issue_category" => "account" },
  expected_patterns: [ "Mike Davis", "account" ],
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 0,
      "config" => { "min_length" => 10, "max_length" => 500 }
    }
  ],
  tags: [ "account" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

test_greeting_general = support_greeting_v3.prompt_tests.create!(
  name: "General Inquiry Greeting",
  description: "Test greeting for general customer inquiries",
<<<<<<< HEAD
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  tags: [ "general" ],
  enabled: true
)

test_greeting_general.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: { patterns: [ "Emily Chen", "general" ], match_all: true }
)

test_greeting_general.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",
  config: { "min_length" => 10, "max_length" => 500 },
=======
  template_variables: { "customer_name" => "Emily Chen", "issue_category" => "general" },
  expected_patterns: [ "Emily Chen", "general" ],
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 0,
      "config" => { "min_length" => 10, "max_length" => 500 }
    }
  ],
  tags: [ "general" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

# Disabled test for edge case
test_greeting_edge = support_greeting_v3.prompt_tests.create!(
  name: "Edge Case - Very Long Name",
  description: "Test greeting with unusually long customer name",
<<<<<<< HEAD
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
=======
  template_variables: { "customer_name" => "Alexander Maximilian Christopher Wellington III", "issue_category" => "billing" },
  expected_patterns: [ "Alexander", "billing" ],
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
  evaluator_configs: [],
>>>>>>> 9f13033 (WIP)
  tags: [ "edge-case" ],
  enabled: false
)

test_greeting_edge.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: { patterns: [ "Alexander", "billing" ], match_all: true }
)

# ============================================================================
# Advanced Tests with Multiple Evaluators
# ============================================================================

puts "  Creating advanced tests with multiple evaluators..."

# Test 1: Comprehensive Quality Check with Multiple Evaluators
test_comprehensive_quality = support_greeting_v3.prompt_tests.create!(
  name: "Comprehensive Quality Check",
  description: "Tests greeting quality with multiple evaluators including LLM judge, length, and keyword checks",
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
<<<<<<< HEAD
  tags: [ "comprehensive", "quality", "critical" ],
  enabled: true
)

# Add pattern match evaluator (binary mode)
test_comprehensive_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: {
    patterns: [
      "Jennifer",
      "refund",
      "\\b(help|assist|support)\\b",  # Must contain help/assist/support
      "^Hi\\s+\\w+"  # Must start with "Hi" followed by a name
    ],
    match_all: true
  }
)

test_comprehensive_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",

  config: {
    "min_length" => 50,
    "max_length" => 200
  },
  enabled: true
)

test_comprehensive_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator",

  config: {
    "required_keywords" => [ "help", "refund" ],
    "forbidden_keywords" => [ "unfortunately", "cannot", "unable" ],
    "case_sensitive" => false
  },
  enabled: true
)

test_comprehensive_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",

  config: {
    "judge_model" => "gpt-4o",
    "custom_instructions" => "Evaluate if the greeting is warm, professional, and acknowledges the customer's refund request appropriately. Consider helpfulness, professionalism, clarity, and tone."
  },
=======
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 80,
      "weight" => 0.2,
      "config" => {
        "min_length" => 50,
        "max_length" => 200,
        "ideal_min" => 80,
        "ideal_max" => 150
      }
    },
    {
      "evaluator_key" => "keyword_check",
      "threshold" => 90,
      "weight" => 0.3,
      "config" => {
        "required_keywords" => [ "help", "refund" ],
        "forbidden_keywords" => [ "unfortunately", "cannot", "unable" ],
        "case_sensitive" => false
      }
    },
    {
      "evaluator_key" => "gpt4_judge",
      "threshold" => 85,
      "weight" => 0.5,
      "config" => {
        "judge_model" => "gpt-4o",
        "criteria" => [ "helpfulness", "professionalism", "clarity", "tone" ],
        "custom_instructions" => "Evaluate if the greeting is warm, professional, and acknowledges the customer's refund request appropriately.",
        "score_min" => 0,
        "score_max" => 100
      }
    }
  ],
  tags: [ "comprehensive", "quality", "critical" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

# Test 2: Complex Pattern Matching for Email Format
test_email_format = email_summary_v1.prompt_tests.create!(
  name: "Email Summary Format Validation",
  description: "Validates email summary format with complex regex patterns",
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.3 },
<<<<<<< HEAD
  tags: [ "format", "validation", "email" ],
  enabled: true
)

# Add pattern match evaluator (binary mode)
test_email_format.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: {
    patterns: [
      "\\b(discuss|planning|goals?)\\b",  # Must mention discussion/planning/goals
      "\\b(Q4|quarter|fourth quarter)\\b",  # Must reference Q4
      "^[A-Z]",  # Must start with capital letter
      "\\.$",  # Must end with period
      "\\b\\d{1,2}\\s+(sentences?|points?)\\b"  # Should mention number of sentences/points
    ],
    match_all: true
  }
)

test_email_format.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",

  config: {
    "min_length" => 100,
    "max_length" => 400
  },
  enabled: true
)

test_email_format.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FormatEvaluator",

  config: {
    "expected_format" => "plain",
    "strict" => false
  },
  enabled: true
)

test_email_format.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",

  config: {
    "judge_model" => "gpt-4o",
    "custom_instructions" => "Evaluate if the summary captures the key points of the email thread concisely and accurately. Consider accuracy, conciseness, and completeness."
  },
=======
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 75,
      "weight" => 0.25,
      "config" => {
        "min_length" => 100,
        "max_length" => 400,
        "ideal_min" => 150,
        "ideal_max" => 300
      }
    },
    {
      "evaluator_key" => "format_check",
      "threshold" => 80,
      "weight" => 0.25,
      "config" => {
        "expected_format" => "plain",
        "strict" => false
      }
    },
    {
      "evaluator_key" => "gpt4_judge",
      "threshold" => 80,
      "weight" => 0.5,
      "config" => {
        "judge_model" => "gpt-4o",
        "criteria" => [ "accuracy", "conciseness", "completeness" ],
        "custom_instructions" => "Evaluate if the summary captures the key points of the email thread concisely and accurately.",
        "score_min" => 0,
        "score_max" => 100
      }
    }
  ],
  tags: [ "format", "validation", "email" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

# Test 3: Code Review Quality with LLM Judge
test_code_review_quality = code_review_v1.prompt_tests.create!(
  name: "Code Review Quality Assessment",
  description: "Tests code review feedback quality with LLM judge and keyword validation",
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.4 },
<<<<<<< HEAD
  tags: [ "code-review", "quality", "technical" ],
  enabled: true
)

# Add pattern match evaluator (binary mode)
test_code_review_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: {
    patterns: [
      "\\b(quality|readability|performance|best practice)\\b",  # Must mention quality aspects
      "\\b(bug|edge case|error|exception)\\b",  # Must mention potential issues
      "\\b(consider|suggest|recommend|improve)\\b",  # Must provide suggestions
      "```ruby",  # Must include code block
      "\\bsum\\b"  # Must reference the sum method
    ],
    match_all: true
  }
)

test_code_review_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",

  config: {
    "min_length" => 200,
    "max_length" => 1000
  },
  enabled: true
)

test_code_review_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator",

  config: {
    "required_keywords" => [ "code", "quality", "readability" ],
    "forbidden_keywords" => [ "terrible", "awful", "stupid" ],
    "case_sensitive" => false
  },
  enabled: true
)

test_code_review_quality.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",

  config: {
    "judge_model" => "gpt-4o",
    "custom_instructions" => "Evaluate if the code review is constructive, technically accurate, and provides actionable feedback. The review should identify potential issues and suggest improvements. Consider helpfulness, technical accuracy, professionalism, and completeness."
  },
=======
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 70,
      "weight" => 0.15,
      "config" => {
        "min_length" => 200,
        "max_length" => 1000,
        "ideal_min" => 300,
        "ideal_max" => 700
      }
    },
    {
      "evaluator_key" => "keyword_check",
      "threshold" => 85,
      "weight" => 0.25,
      "config" => {
        "required_keywords" => [ "code", "quality", "readability" ],
        "forbidden_keywords" => [ "terrible", "awful", "stupid" ],
        "case_sensitive" => false
      }
    },
    {
      "evaluator_key" => "gpt4_judge",
      "threshold" => 90,
      "weight" => 0.6,
      "config" => {
        "judge_model" => "gpt-4o",
        "criteria" => [ "helpfulness", "technical_accuracy", "professionalism", "completeness" ],
        "custom_instructions" => "Evaluate if the code review is constructive, technically accurate, and provides actionable feedback. The review should identify potential issues and suggest improvements.",
        "score_min" => 0,
        "score_max" => 100
      }
    }
  ],
  tags: [ "code-review", "quality", "technical" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

# Test 4: Exact Output Match with Multiple Evaluators
test_exact_match = support_greeting_v3.prompt_tests.create!(
  name: "Exact Output Validation",
  description: "Tests for exact expected output with additional quality checks",
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.7 },
<<<<<<< HEAD
  tags: [ "exact-match", "critical", "smoke" ],
  enabled: true
)

# Add exact match evaluator (binary mode)
test_exact_match.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::ExactMatchEvaluator",
  enabled: true,
  config: {
    expected_text: "Hi Alice! Thanks for contacting us. I'm here to help with your password reset question. What's going on?",
    case_sensitive: false,
    trim_whitespace: true
  }
)

# Add pattern match evaluator (binary mode)
test_exact_match.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: {
    patterns: [
      "^Hi Alice!",
      "password reset",
      "What's going on\\?$"
    ],
    match_all: true
  }
)

test_exact_match.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",

  config: {
    "min_length" => 50,
    "max_length" => 150
  },
  enabled: true
)

test_exact_match.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",

  config: {
    "judge_model" => "gpt-4o",
    "custom_instructions" => "Evaluate if the greeting matches the expected format and tone for a password reset inquiry. Consider accuracy, tone, and clarity."
  },
=======
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 90,
      "weight" => 0.3,
      "config" => {
        "min_length" => 50,
        "max_length" => 150,
        "ideal_min" => 80,
        "ideal_max" => 120
      }
    },
    {
      "evaluator_key" => "gpt4_judge",
      "threshold" => 95,
      "weight" => 0.7,
      "config" => {
        "judge_model" => "gpt-4o",
        "criteria" => [ "accuracy", "tone", "clarity" ],
        "custom_instructions" => "Evaluate if the greeting matches the expected format and tone for a password reset inquiry.",
        "score_min" => 0,
        "score_max" => 100
      }
    }
  ],
  tags: [ "exact-match", "critical", "smoke" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

# Test 5: Complex Regex Patterns for Technical Content
test_technical_patterns = code_review_v1.prompt_tests.create!(
  name: "Technical Content Pattern Validation",
  description: "Validates technical content with complex regex patterns for code snippets, technical terms, and formatting",
  model_config: { "provider" => "openai", "model" => "gpt-4o", "temperature" => 0.4 },
<<<<<<< HEAD
  tags: [ "technical", "complex-patterns", "code-review" ],
  enabled: true
)

# Add pattern match evaluator (binary mode)
test_technical_patterns.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::PatternMatchEvaluator",
  enabled: true,
  config: {
    patterns: [
      "```python[\\s\\S]*```",  # Must contain Python code block
      "\\b(list comprehension|comprehension)\\b",  # Must mention list comprehension
      "\\b(filter|filtering|condition)\\b",  # Must mention filtering
      "\\b(performance|efficiency|optimization)\\b",  # Must discuss performance
      "\\b(edge case|edge-case|boundary)\\b",  # Must mention edge cases
      "\\b(empty|None|null|zero)\\b",  # Must consider empty/null cases
      "(?i)\\b(test|testing|unit test)\\b",  # Must mention testing (case insensitive)
      "\\b[A-Z][a-z]+\\s+[a-z]+\\s+[a-z]+",  # Must have proper sentences
      "\\d+",  # Must contain at least one number
      "\\b(could|should|might|consider|recommend)\\b"  # Must use suggestive language
    ],
    match_all: true
  }
)

test_technical_patterns.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",

  config: {
    "min_length" => 250,
    "max_length" => 1200
  },
  enabled: true
)

test_technical_patterns.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator",

  config: {
    "required_keywords" => [ "comprehension", "performance", "edge case" ],
    "forbidden_keywords" => [],
    "case_sensitive" => false
  },
  enabled: true
)

test_technical_patterns.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FormatEvaluator",

  config: {
    "expected_format" => "markdown",
    "strict" => false
  },
  enabled: true
)

test_technical_patterns.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",

  config: {
    "judge_model" => "gpt-4o",
    "custom_instructions" => "Evaluate the technical accuracy and completeness of the code review. It should identify the list comprehension, discuss performance implications, mention edge cases, and suggest testing. Consider technical accuracy, completeness, helpfulness, and professionalism."
  },
=======
  evaluator_configs: [
    {
      "evaluator_key" => "length_check",
      "threshold" => 75,
      "weight" => 0.2,
      "config" => {
        "min_length" => 250,
        "max_length" => 1200,
        "ideal_min" => 400,
        "ideal_max" => 800
      }
    },
    {
      "evaluator_key" => "keyword_check",
      "threshold" => 80,
      "weight" => 0.2,
      "config" => {
        "required_keywords" => [ "comprehension", "performance", "edge case" ],
        "forbidden_keywords" => [],
        "case_sensitive" => false
      }
    },
    {
      "evaluator_key" => "format_check",
      "threshold" => 85,
      "weight" => 0.1,
      "config" => {
        "expected_format" => "markdown",
        "strict" => false
      }
    },
    {
      "evaluator_key" => "gpt4_judge",
      "threshold" => 88,
      "weight" => 0.5,
      "config" => {
        "judge_model" => "gpt-4o",
        "criteria" => [ "technical_accuracy", "completeness", "helpfulness", "professionalism" ],
        "custom_instructions" => "Evaluate the technical accuracy and completeness of the code review. It should identify the list comprehension, discuss performance implications, mention edge cases, and suggest testing.",
        "score_min" => 0,
        "score_max" => 100
      }
    }
  ],
  tags: [ "technical", "complex-patterns", "code-review" ],
>>>>>>> 9f13033 (WIP)
  enabled: true
)

# ============================================================================
# 5. Create Sample LLM Responses
# ============================================================================

puts "  Creating sample LLM responses..."

# Successful responses for support greeting v3
5.times do |i|
  response = support_greeting_v3.llm_responses.create!(
    rendered_prompt: "Hi John! Thanks for contacting us. I'm here to help with your billing question. What's going on?",
    variables_used: { "customer_name" => "John", "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4o",
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
  model: "gpt-4o",
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
    model: "gpt-4o",
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
  # Keyword evaluation
  score = rand(70..100)
  response.evaluations.create!(
<<<<<<< HEAD
    score: score,
    score_max: 100,
    passed: score >= 80,
    evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator",
    feedback: [ "Great response!", "Very helpful", "Could be more concise", "Perfect tone" ][i % 4],
    metadata: {
      "required_found" => rand(2..3),
      "forbidden_found" => 0,
      "total_keywords" => 3
    }
=======
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
    feedback: [ "Great response!", "Very helpful", "Could be more concise", "Perfect tone" ][i % 4]
>>>>>>> 9f13033 (WIP)
  )

  # Length evaluation
  score = rand(70..95)
  response.evaluations.create!(
    score: score,
    score_max: 100,
    passed: score >= 80,
    evaluator_type: "PromptTracker::Evaluators::LengthEvaluator",
    metadata: {
      "actual_length" => rand(80..150),
      "min_length" => 50,
      "max_length" => 200
    }
  )

  # LLM judge evaluation (for some responses)
  if i.even?
    score = rand(70..95)
    response.evaluations.create!(
      score: score,
      score_max: 100,
      passed: score >= 80,
      evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
      feedback: "The response is helpful and maintains a professional yet friendly tone.",
      metadata: {
        "judge_model" => "gpt-4o",
        "custom_instructions" => "Evaluate helpfulness and professionalism",
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
    rendered_prompt: "Hi #{[ 'Alice', 'Bob', 'Charlie' ][i % 3]}! Thanks for contacting us. I'm here to help with your billing question. What's going on?",
    variables_used: { "customer_name" => [ "Alice", "Bob", "Charlie" ][i % 3], "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4o",
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
    score: rand(80..95),
    score_max: 100,
    passed: rand > 0.2,  # 80% pass rate
    evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
    metadata: { "judge_model" => "gpt-4o" }
  )
end

# Variant B responses (casual version)
8.times do |i|
  response = support_greeting_v4.llm_responses.create!(
    rendered_prompt: "Hey #{[ 'Dave', 'Eve', 'Frank' ][i % 3]}! What's up with billing?",
    variables_used: { "customer_name" => [ "Dave", "Eve", "Frank" ][i % 3], "issue_category" => "billing" },
    provider: "openai",
    model: "gpt-4o",
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
    score: rand(75..90),
    score_max: 100,
    passed: rand > 0.3,  # 70% pass rate
    evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
    metadata: { "judge_model" => "gpt-4o" }
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
# 7. Create Tracing Data (Sessions, Traces, Spans)
# ============================================================================

puts "  Creating tracing data (sessions, traces, spans)..."

# Session 1: Customer Support Chat - Simple workflow
# ============================================================================
session_1 = "support_chat_abc123"

# Trace 1: Simple greeting (no spans, just direct LLM call)
trace_1_greeting = PromptTracker::Trace.create!(
  name: "customer_greeting",
  session_id: session_1,
  user_id: "user_alice",
  input: "New customer inquiry - billing issue",
  output: "Greeting sent successfully",
  status: "completed",
  started_at: 10.minutes.ago,
  ended_at: 10.minutes.ago + 1.2.seconds,
  metadata: { "channel" => "web_chat", "priority" => "high" }
)

# Link one of the existing successful responses to this trace
support_greeting_v3.llm_responses.successful.first&.update!(
  trace: trace_1_greeting,
  session_id: session_1,
  user_id: "user_alice"
)

# Trace 2: Follow-up question (simple)
trace_2_followup = PromptTracker::Trace.create!(
  name: "customer_greeting",
  session_id: session_1,
  user_id: "user_alice",
  input: "Follow-up question about refund",
  output: "Response provided",
  status: "completed",
  started_at: 8.minutes.ago,
  ended_at: 8.minutes.ago + 1.5.seconds,
  metadata: { "channel" => "web_chat", "priority" => "high" }
)

support_greeting_v3.llm_responses.successful.second&.update!(
  trace: trace_2_followup,
  session_id: session_1,
  user_id: "user_alice"
)

# Session 2: RAG Q&A Workflow - Multi-span workflow
# ============================================================================
session_2 = "rag_session_xyz789"

# Trace 3: RAG workflow with 2 spans
trace_3_rag = PromptTracker::Trace.create!(
  name: "rag_qa_workflow",
  session_id: session_2,
  user_id: "user_bob",
  input: "How do I reset my password?",
  output: "To reset your password, go to Settings > Security > Reset Password. You'll receive an email with instructions.",
  status: "completed",
  started_at: 5.minutes.ago,
  ended_at: 5.minutes.ago + 3.5.seconds,
  metadata: { "channel" => "api", "kb_version" => "v2.1" }
)

# Span 1: Search knowledge base
span_3_search = trace_3_rag.spans.create!(
  name: "search_knowledge_base",
  span_type: "retrieval",
  input: "password reset",
  output: "Found 3 relevant articles: [KB-101, KB-205, KB-312]",
  status: "completed",
  started_at: 5.minutes.ago,
  ended_at: 5.minutes.ago + 0.8.seconds,
  metadata: { "search_engine" => "elasticsearch", "results_count" => 3 }
)

# Span 2: Generate answer
span_3_generate = trace_3_rag.spans.create!(
  name: "generate_answer",
  span_type: "function",
  input: "Articles: KB-101, KB-205, KB-312 | Question: How do I reset my password?",
  output: "To reset your password, go to Settings > Security > Reset Password...",
  status: "completed",
  started_at: 5.minutes.ago + 0.8.seconds,
  ended_at: 5.minutes.ago + 3.5.seconds,
  metadata: { "model_used" => "gpt-4o", "temperature" => 0.7 }
)

# Link email summary response to this span
email_summary_v1.llm_responses.successful.first&.update!(
  trace: trace_3_rag,
  span: span_3_generate,
  session_id: session_2,
  user_id: "user_bob"
)

# Trace 4: Another RAG query in same session
trace_4_rag = PromptTracker::Trace.create!(
  name: "rag_qa_workflow",
  session_id: session_2,
  user_id: "user_bob",
  input: "What are your refund policies?",
  output: "Our refund policy allows returns within 30 days...",
  status: "completed",
  started_at: 3.minutes.ago,
  ended_at: 3.minutes.ago + 2.8.seconds,
  metadata: { "channel" => "api", "kb_version" => "v2.1" }
)

span_4_search = trace_4_rag.spans.create!(
  name: "search_knowledge_base",
  span_type: "retrieval",
  input: "refund policy",
  output: "Found 2 relevant articles: [KB-450, KB-451]",
  status: "completed",
  started_at: 3.minutes.ago,
  ended_at: 3.minutes.ago + 0.6.seconds,
  metadata: { "search_engine" => "elasticsearch", "results_count" => 2 }
)

span_4_generate = trace_4_rag.spans.create!(
  name: "generate_answer",
  span_type: "function",
  input: "Articles: KB-450, KB-451 | Question: What are your refund policies?",
  output: "Our refund policy allows returns within 30 days...",
  status: "completed",
  started_at: 3.minutes.ago + 0.6.seconds,
  ended_at: 3.minutes.ago + 2.8.seconds,
  metadata: { "model_used" => "gpt-4o", "temperature" => 0.7 }
)

email_summary_v1.llm_responses.successful.second&.update!(
  trace: trace_4_rag,
  span: span_4_generate,
  session_id: session_2,
  user_id: "user_bob"
)

# Session 3: Code Review Workflow - Complex multi-step
# ============================================================================
session_3 = "code_review_def456"

# Trace 5: Code review with 3 spans
trace_5_review = PromptTracker::Trace.create!(
  name: "code_review_workflow",
  session_id: session_3,
  user_id: "user_charlie",
  input: "def calculate_total(items)\n  items.map { |i| i[:price] }.sum\nend",
  output: "Code review completed with 3 suggestions",
  status: "completed",
  started_at: 15.minutes.ago,
  ended_at: 15.minutes.ago + 8.5.seconds,
  metadata: { "language" => "ruby", "file" => "app/models/order.rb" }
)

# Span 1: Analyze code
span_5_analyze = trace_5_review.spans.create!(
  name: "analyze_code",
  span_type: "function",
  input: "def calculate_total(items)...",
  output: "Analysis complete: 2 potential issues found",
  status: "completed",
  started_at: 15.minutes.ago,
  ended_at: 15.minutes.ago + 2.0.seconds,
  metadata: { "analyzer" => "rubocop", "issues_found" => 2 }
)

# Span 2: Generate suggestions (child of analyze)
span_5_suggest = span_5_analyze.create_child_span(
  name: "generate_suggestions",
  span_type: "function",
  input: "Issues: nil handling, edge cases",
  output: "Generated 3 improvement suggestions",
  status: "completed",
  started_at: 15.minutes.ago + 2.0.seconds,
  ended_at: 15.minutes.ago + 6.5.seconds,
  metadata: { "model_used" => "gpt-4o" }
)

code_review_v1.llm_responses.successful.first&.update!(
  trace: trace_5_review,
  span: span_5_suggest,
  session_id: session_3,
  user_id: "user_charlie"
)

# Span 3: Validate suggestions
span_5_validate = trace_5_review.spans.create!(
  name: "validate_suggestions",
  span_type: "function",
  input: "Suggestions: 1. Add nil check, 2. Handle empty array, 3. Add tests",
  output: "All suggestions validated and approved",
  status: "completed",
  started_at: 15.minutes.ago + 6.5.seconds,
  ended_at: 15.minutes.ago + 8.5.seconds,
  metadata: { "validator" => "human", "approved" => true }
)

# Session 4: Failed Trace Example
# ============================================================================
session_4 = "error_session_ghi789"

# Trace 6: Failed trace with error
trace_6_error = PromptTracker::Trace.create!(
  name: "rag_qa_workflow",
  session_id: session_4,
  user_id: "user_diana",
  input: "Complex query that causes timeout",
  status: "error",
  started_at: 20.minutes.ago,
  ended_at: 20.minutes.ago + 30.seconds,
  metadata: { "error" => "Request timeout after 30 seconds", "channel" => "api" }
)

span_6_search = trace_6_error.spans.create!(
  name: "search_knowledge_base",
  span_type: "retrieval",
  input: "complex query",
  status: "error",
  started_at: 20.minutes.ago,
  ended_at: 20.minutes.ago + 30.seconds,
  metadata: { "error" => "Elasticsearch timeout" }
)

# Link the timeout response to this trace
timeout_response.update!(
  trace: trace_6_error,
  span: span_6_search,
  session_id: session_4,
  user_id: "user_diana"
)

# Session 5: Long conversation session
# ============================================================================
session_5 = "long_chat_jkl012"

# Create 8 simple traces in this session
8.times do |i|
  trace = PromptTracker::Trace.create!(
    name: "customer_greeting",
    session_id: session_5,
    user_id: "user_eve",
    input: "Message #{i + 1} in conversation",
    output: "Response #{i + 1}",
    status: "completed",
    started_at: (30 - i * 3).minutes.ago,
    ended_at: (30 - i * 3).minutes.ago + rand(1.0..2.5).seconds,
    metadata: { "message_number" => i + 1, "channel" => "web_chat" }
  )

  # Link some responses to these traces
  if i < 3
    support_greeting_v3.llm_responses.successful.offset(i + 2).first&.update!(
      trace: trace,
      session_id: session_5,
      user_id: "user_eve"
    )
  end
end

# Session 6: Multi-user collaboration session
# ============================================================================
session_6 = "team_collab_mno345"

# Trace by user 1
trace_7_collab = PromptTracker::Trace.create!(
  name: "code_review_workflow",
  session_id: session_6,
  user_id: "user_frank",
  input: "Initial code review request",
  output: "Review completed",
  status: "completed",
  started_at: 1.hour.ago,
  ended_at: 1.hour.ago + 5.seconds,
  metadata: { "role" => "developer" }
)

# Trace by user 2 in same session
trace_8_collab = PromptTracker::Trace.create!(
  name: "code_review_workflow",
  session_id: session_6,
  user_id: "user_grace",
  input: "Follow-up review",
  output: "Additional suggestions provided",
  status: "completed",
  started_at: 55.minutes.ago,
  ended_at: 55.minutes.ago + 4.seconds,
  metadata: { "role" => "senior_developer" }
)

# Session 7: Email processing workflow
# ============================================================================
session_7 = "email_proc_pqr678"

trace_9_email = PromptTracker::Trace.create!(
  name: "email_processing_workflow",
  session_id: session_7,
  user_id: "user_henry",
  input: "Process incoming email from customer",
  output: "Email categorized and summarized",
  status: "completed",
  started_at: 2.hours.ago,
  ended_at: 2.hours.ago + 6.5.seconds,
  metadata: { "email_id" => "email_12345", "from" => "customer@example.com" }
)

# Span 1: Parse email
span_9_parse = trace_9_email.spans.create!(
  name: "parse_email",
  span_type: "function",
  input: "Raw email content",
  output: "Extracted: subject, body, attachments",
  status: "completed",
  started_at: 2.hours.ago,
  ended_at: 2.hours.ago + 0.5.seconds,
  metadata: { "parser" => "mail_parser_v2" }
)

# Span 2: Summarize email
span_9_summarize = trace_9_email.spans.create!(
  name: "summarize_email",
  span_type: "function",
  input: "Email body: Long email thread...",
  output: "Summary: Customer requesting refund for order #12345",
  status: "completed",
  started_at: 2.hours.ago + 0.5.seconds,
  ended_at: 2.hours.ago + 3.5.seconds,
  metadata: { "model_used" => "gpt-4o" }
)

email_summary_v1.llm_responses.successful.third&.update!(
  trace: trace_9_email,
  span: span_9_summarize,
  session_id: session_7,
  user_id: "user_henry"
)

# Span 3: Categorize email
span_9_categorize = trace_9_email.spans.create!(
  name: "categorize_email",
  span_type: "function",
  input: "Summary: Customer requesting refund...",
  output: "Category: refund_request, Priority: high",
  status: "completed",
  started_at: 2.hours.ago + 3.5.seconds,
  ended_at: 2.hours.ago + 6.5.seconds,
  metadata: { "classifier" => "ml_classifier_v3", "confidence" => 0.95 }
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
puts "  - #{PromptTracker::PromptTest.count} prompt tests"
puts "    - #{PromptTracker::PromptTest.enabled.count} enabled"
puts "  - #{PromptTracker::LlmResponse.count} LLM responses"
puts "    - #{PromptTracker::LlmResponse.successful.count} successful"
puts "    - #{PromptTracker::LlmResponse.failed.count} failed"
puts "  - #{PromptTracker::Evaluation.count} evaluations"
puts "    - #{PromptTracker::Evaluation.where("evaluator_type LIKE ?", "%LlmJudgeEvaluator").count} LLM judge"
puts "    - #{PromptTracker::Evaluation.where("evaluator_type LIKE ?", "%KeywordEvaluator").count} keyword"
puts "    - #{PromptTracker::Evaluation.where("evaluator_type LIKE ?", "%LengthEvaluator").count} length"
puts "    - #{PromptTracker::Evaluation.where("evaluator_type LIKE ?", "%PatternMatchEvaluator").count} pattern match"
puts "    - #{PromptTracker::Evaluation.where("evaluator_type LIKE ?", "%ExactMatchEvaluator").count} exact match"
puts "    - #{PromptTracker::Evaluation.where("evaluator_type LIKE ?", "%FormatEvaluator").count} format"
puts "  - #{PromptTracker::AbTest.count} A/B tests"
puts "    - #{PromptTracker::AbTest.draft.count} draft"
puts "    - #{PromptTracker::AbTest.running.count} running"
puts "    - #{PromptTracker::AbTest.completed.count} completed"
puts "  - #{PromptTracker::Trace.count} traces"
puts "    - #{PromptTracker::Trace.completed.count} completed"
puts "    - #{PromptTracker::Trace.with_errors.count} with errors"
puts "  - #{PromptTracker::Span.count} spans"
puts "  - #{PromptTracker::Trace.where.not(session_id: nil).distinct.count(:session_id)} unique sessions"
puts "\nTotal cost: $#{PromptTracker::LlmResponse.sum(:cost_usd).round(4)}"
puts "Average response time: #{PromptTracker::LlmResponse.successful.average(:response_time_ms).to_i}ms"
puts "\n🎉 Ready to explore!"
puts "\n💡 Tips:"
puts "  - Visit /prompt_tracker to see all prompts"
puts "  - Check out the running A/B test: '#{ab_test_greeting_running.name}'"
puts "  - View tests for customer_support_greeting v3 (#{support_greeting_v3.prompt_tests.count} tests)"
puts "  - Advanced tests include:"
puts "    • Comprehensive Quality Check (3 evaluators: length, keyword, LLM judge)"
puts "    • Email Summary Format Validation (complex regex patterns)"
puts "    • Code Review Quality Assessment (LLM judge + keyword validation)"
puts "    • Exact Output Validation (exact match + quality checks)"
puts "    • Technical Content Pattern Validation (10 complex regex patterns + 4 evaluators)"
puts "  - Create new A/B tests with draft versions v4 and v5"
puts "\n🔍 Tracing Examples:"
puts "  - Session 'support_chat_abc123' - Simple customer support chat (2 traces)"
puts "  - Session 'rag_session_xyz789' - RAG Q&A workflow with search + generate spans (2 traces)"
puts "  - Session 'code_review_def456' - Complex code review with nested spans (1 trace)"
puts "  - Session 'long_chat_jkl012' - Long conversation with 8 traces"
puts "  - Session 'email_proc_pqr678' - Email processing workflow (parse → summarize → categorize)"
puts "  - Visit /prompt_tracker/sessions to browse all sessions"
puts "  - Visit /prompt_tracker/traces to browse all traces"
