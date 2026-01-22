# frozen_string_literal: true

# ============================================================================
# Tests with Web Search, Code Interpreter, and Function Call Evaluators
# ============================================================================

puts "  Creating tests for prompts with tool evaluators..."

# ============================================================================
# 1. Research Assistant Tests (WebSearchEvaluator)
# ============================================================================

research_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "research_assistant" })
  .where(status: "active")
  .first!

test_research_basic = research_version.tests.create!(
  name: "Web Search Usage",
  description: "Verifies the assistant uses web search for research queries",
  tags: [ "web-search", "research" ],
  enabled: true
)

test_research_basic.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::WebSearchEvaluator",
  enabled: true,
  config: {
    "require_web_search" => true,
    "min_sources" => 2,
    "threshold_score" => 80
  }
)

test_research_basic.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate if the response properly cites sources and provides accurate research."
  }
)

puts "  ✓ Created research assistant test with WebSearchEvaluator"

# ============================================================================
# 2. Competitive Intelligence Tests (WebSearchEvaluator + Domain Validation)
# ============================================================================

competitor_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "competitive_intelligence" })
  .where(status: "active")
  .first!

test_competitor_sources = competitor_version.tests.create!(
  name: "Authoritative Source Validation",
  description: "Ensures the assistant uses authoritative business sources",
  tags: [ "web-search", "business", "sources" ],
  enabled: true
)

test_competitor_sources.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::WebSearchEvaluator",
  enabled: true,
  config: {
    "require_web_search" => true,
    "expected_domains" => [ "bloomberg.com", "reuters.com", "techcrunch.com", "wsj.com", "forbes.com" ],
    "require_all_domains" => false,
    "min_sources" => 3,
    "threshold_score" => 75
  }
)

test_competitor_sources.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate the competitive analysis for accuracy, use of authoritative sources, and actionable insights."
  }
)

puts "  ✓ Created competitive intelligence test with domain validation"

# ============================================================================
# 3. Data Analysis Tests (CodeInterpreterEvaluator)
# ============================================================================

data_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "data_analyst" })
  .where(status: "active")
  .first!

test_data_execution = data_version.tests.create!(
  name: "Code Execution for Analysis",
  description: "Verifies the assistant executes Python code for data analysis",
  tags: [ "code-interpreter", "statistics" ],
  enabled: true
)

test_data_execution.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::CodeInterpreterEvaluator",
  enabled: true,
  config: {
    "require_code_execution" => true,
    "expected_language" => "python",
    "output_patterns" => [ "mean", "std", "median" ],
    "require_all_patterns" => false,
    "min_code_lines" => 3,
    "threshold_score" => 80
  }
)

test_data_execution.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate the data analysis for statistical accuracy and clear explanations."
  }
)

puts "  ✓ Created data analysis test with CodeInterpreterEvaluator"

# ============================================================================
# 4. Financial Modeling Tests (CodeInterpreterEvaluator + File Output)
# ============================================================================

finance_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "financial_modeler" })
  .where(status: "active")
  .first!

test_finance_viz = finance_version.tests.create!(
  name: "Financial Visualization Quality",
  description: "Evaluates code execution and chart generation for financial models",
  tags: [ "code-interpreter", "finance", "visualization" ],
  enabled: true
)

test_finance_viz.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::CodeInterpreterEvaluator",
  enabled: true,
  config: {
    "require_code_execution" => true,
    "expected_language" => "python",
    "expect_files_created" => true,
    "min_code_lines" => 5,
    "threshold_score" => 75
  }
)

test_finance_viz.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate the financial model for calculation accuracy and visualization quality."
  }
)

puts "  ✓ Created financial modeling test with file output evaluation"

# ============================================================================
# 5. Travel Booking Tests (FunctionCallEvaluator)
# ============================================================================

travel_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "travel_booking_assistant" })
  .where(status: "active")
  .first!

test_travel_functions = travel_version.tests.create!(
  name: "Travel Function Usage",
  description: "Verifies the assistant correctly uses travel-related functions",
  tags: [ "functions", "travel" ],
  enabled: true
)

test_travel_functions.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FunctionCallEvaluator",
  enabled: true,
  config: {
    "expected_functions" => [ "search_flights", "search_hotels", "get_weather" ],
    "require_all" => false,
    "check_arguments" => false,
    "threshold_score" => 80
  }
)

test_travel_functions.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate the travel assistance for helpfulness and appropriate function usage."
  }
)

# Additional test for argument validation
test_travel_args = travel_version.tests.create!(
  name: "Flight Search Arguments",
  description: "Validates that flight search function arguments are correct",
  tags: [ "functions", "travel", "arguments" ],
  enabled: true
)

test_travel_args.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FunctionCallEvaluator",
  enabled: true,
  config: {
    "expected_functions" => [ "search_flights" ],
    "require_all" => true,
    "check_arguments" => true,
    "expected_arguments" => {
      "search_flights" => {
        "origin" => "JFK"
      }
    },
    "threshold_score" => 80
  }
)

puts "  ✓ Created travel booking tests with FunctionCallEvaluator"

# ============================================================================
# 6. E-commerce Tests (FunctionCallEvaluator)
# ============================================================================

ecommerce_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "ecommerce_assistant" })
  .where(status: "active")
  .first!

test_ecommerce_product = ecommerce_version.tests.create!(
  name: "Product Search Function",
  description: "Verifies the assistant uses search_products function for product queries",
  tags: [ "functions", "ecommerce", "product-search" ],
  enabled: true
)

test_ecommerce_product.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FunctionCallEvaluator",
  enabled: true,
  config: {
    "expected_functions" => [ "search_products" ],
    "require_all" => true,
    "check_arguments" => false,
    "threshold_score" => 90
  }
)

test_ecommerce_product.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate the product recommendation for relevance and helpfulness."
  }
)

test_ecommerce_order = ecommerce_version.tests.create!(
  name: "Order Status Function",
  description: "Verifies the assistant uses get_order_status for order inquiries",
  tags: [ "functions", "ecommerce", "orders" ],
  enabled: true
)

test_ecommerce_order.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FunctionCallEvaluator",
  enabled: true,
  config: {
    "expected_functions" => [ "get_order_status" ],
    "require_all" => true,
    "check_arguments" => true,
    "expected_arguments" => {
      "get_order_status" => {
        "order_id" => "ORD-12345"
      }
    },
    "threshold_score" => 85
  }
)

test_ecommerce_return = ecommerce_version.tests.create!(
  name: "Return Process Function",
  description: "Verifies the assistant correctly initiates returns",
  tags: [ "functions", "ecommerce", "returns" ],
  enabled: true
)

test_ecommerce_return.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::FunctionCallEvaluator",
  enabled: true,
  config: {
    "expected_functions" => [ "initiate_return" ],
    "require_all" => true,
    "check_arguments" => true,
    "expected_arguments" => {
      "initiate_return" => {
        "order_id" => "ORD-12345"
      }
    },
    "threshold_score" => 85
  }
)

test_ecommerce_return.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::KeywordEvaluator",
  enabled: true,
  config: {
    "required_keywords" => [ "return", "refund" ],
    "forbidden_keywords" => [ "unfortunately", "cannot" ],
    "case_sensitive" => false
  }
)

puts "  ✓ Created e-commerce tests with FunctionCallEvaluator"

# ============================================================================
# 7. News Analyst Tests (WebSearchEvaluator + Query Validation)
# ============================================================================

news_version = PromptTracker::PromptVersion.joins(:prompt)
  .where(prompt_tracker_prompts: { name: "news_analyst" })
  .where(status: "active")
  .first!

test_news_search = news_version.tests.create!(
  name: "News Search Quality",
  description: "Validates search queries and source diversity for news analysis",
  tags: [ "web-search", "news" ],
  enabled: true
)

test_news_search.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::WebSearchEvaluator",
  enabled: true,
  config: {
    "require_web_search" => true,
    "expected_queries" => [ "AI", "regulation", "policy" ],
    "min_sources" => 3,
    "threshold_score" => 70
  }
)

test_news_search.evaluator_configs.create!(
  evaluator_type: "PromptTracker::Evaluators::LlmJudgeEvaluator",
  enabled: true,
  config: {
    "judge_model" => "gpt-4o-mini",
    "custom_instructions" => "Evaluate the news analysis for objectivity, source diversity, and balanced reporting."
  }
)

puts "  ✓ Created news analyst test with query validation"

puts "\n  ✅ Created 10 tests with WebSearch, CodeInterpreter, and FunctionCall evaluators"
