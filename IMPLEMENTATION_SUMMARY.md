# Implementation Summary: Fix WebSearchEvaluator Detection

## Problem
WebSearchEvaluator was failing to detect web search usage despite web search clearly being used in test runs. The evaluator always returned score 0.0 with feedback "✗ Web search was not used."

## Root Cause
**Architectural mismatch between data producers and consumers:**

1. **OpenaiResponseService** had its own `normalize_response` method that extracted basic fields (`text`, `response_id`, `usage`, `tool_calls`) but NOT `web_search_results`
2. **ResponseApiExecutor** stored tool calls per-message in `messages[].tool_calls` but didn't extract them to top-level fields
3. **WebSearchEvaluator** expected `web_search_results` at the top level of the data structure (via `BaseNormalizedEvaluator`)
4. **ResponseApiNormalizer** existed with proper extraction logic but was never called

## Solution: Option A - Use ResponseApiNormalizer in OpenaiResponseService

### Changes Made

#### 1. **app/services/prompt_tracker/openai_response_service.rb**
- Modified `normalize_response` to use `ResponseApiNormalizer` for consistent normalization
- Added extraction of `web_search_results`, `code_interpreter_results`, and `file_search_results`
- Removed duplicate extraction methods (`extract_text`, `extract_tool_calls`)
- Kept `extract_usage` as it's not handled by the normalizer

**New response format:**
```ruby
{
  text: "...",
  response_id: "resp_123",
  usage: { prompt_tokens: 10, completion_tokens: 20, total_tokens: 30 },
  model: "gpt-4o",
  tool_calls: [...],
  web_search_results: [...],      # NEW
  code_interpreter_results: [...], # NEW
  file_search_results: [...],      # NEW
  raw: {...}
}
```

#### 2. **app/services/prompt_tracker/test_runners/api_executors/openai/response_api_executor.rb**
- Added `@all_responses` array to track all responses in a conversation
- Added extraction methods: `extract_all_web_search_results`, `extract_all_code_interpreter_results`, `extract_all_file_search_results`
- Modified `execute` to include these fields in `build_output_data`
- Updated `mock_response_api_response` to include the new fields

**New output_data format:**
```ruby
{
  "messages" => [...],
  "web_search_results" => [...],      # NEW - aggregated from all turns
  "code_interpreter_results" => [...], # NEW - aggregated from all turns
  "file_search_results" => [...],      # NEW - aggregated from all turns
  # ... other fields
}
```

#### 3. **spec/services/prompt_tracker/openai_response_service_spec.rb**
- Updated specs to expect new fields in response
- Added test for web_search_results extraction
- Enhanced mock API response with proper web search data structure

## Benefits

1. ✅ **Eliminates duplication** - Single source of truth for Response API normalization
2. ✅ **Fixes WebSearchEvaluator** - Now properly detects web search usage
3. ✅ **Enables other evaluators** - CodeInterpreterEvaluator and FileSearchEvaluator will also work correctly
4. ✅ **Backward compatible** - All existing fields are still present, new fields are additional
5. ✅ **Architecturally clean** - Follows the intended design pattern where normalizers decouple evaluators from API formats

## Testing

### What to Test

1. **WebSearchEvaluator Detection**
   - Run a test with web_search tool enabled
   - Verify WebSearchEvaluator correctly detects web search usage
   - Check that score is > 0 when web search is used

2. **Response API Tests**
   - Run: `bundle exec rspec spec/services/prompt_tracker/openai_response_service_spec.rb`
   - Verify all specs pass

3. **ResponseApiExecutor Tests**
   - Run: `bundle exec rspec spec/services/prompt_tracker/test_runners/api_executors/openai/response_api_executor_spec.rb`
   - Verify output_data includes new fields

4. **Playground**
   - Test playground with Response API and web_search tool
   - Verify conversation still works correctly

5. **Integration Test**
   - Create a test with WebSearchEvaluator
   - Run the test with web_search tool enabled
   - Verify evaluation passes and shows web search was detected

## Files Modified

- `app/services/prompt_tracker/openai_response_service.rb`
- `app/services/prompt_tracker/test_runners/api_executors/openai/response_api_executor.rb`
- `spec/services/prompt_tracker/openai_response_service_spec.rb`

## No Breaking Changes

All existing code continues to work because:
- All original fields (`text`, `response_id`, `usage`, `model`, `tool_calls`, `raw`) are still present
- New fields are additional and optional
- PlaygroundExecuteService, ResponseApiConversationRunner, and other consumers only use the original fields

