# PRD: LlmResponse Schema Changes for Response API

## Overview

This document describes the schema changes needed for the `LlmResponse` model to store Response API-specific data, including `response_id` for conversation continuity and `tools_used` for tracking built-in tool usage.

## Background

### Current Schema

```ruby
# Current LlmResponse columns
create_table :prompt_tracker_llm_responses do |t|
  t.references :responseable, polymorphic: true  # PromptVersion, Assistant, etc.
  t.text :prompt                                  # Rendered prompt sent
  t.text :response                                # LLM response text
  t.jsonb :metadata                               # Flexible metadata storage
  t.string :model                                 # Model used (gpt-4o, etc.)
  t.integer :input_tokens
  t.integer :output_tokens
  t.float :latency_ms
  t.timestamps
end
```

### Problem Statement

Response API returns additional data that needs to be stored:
1. **`response_id`**: Required for continuing conversations
2. **`tools_used`**: Array of tools invoked (web_search, file_search, code_interpreter)
3. **`tool_outputs`**: Detailed tool execution results (search results, code output)
4. **`conversation_id`**: Optional grouping for multi-turn conversations

### Goals

1. Add columns for Response API-specific data
2. Maintain backward compatibility with existing Chat Completions responses
3. Enable querying by response_id for conversation continuity
4. Track tool usage for analytics and debugging

## Technical Design

### Database Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_response_api_fields_to_llm_responses.rb
class AddResponseApiFieldsToLlmResponses < ActiveRecord::Migration[7.1]
  def change
    # Response API specific fields
    add_column :prompt_tracker_llm_responses, :response_id, :string
    add_column :prompt_tracker_llm_responses, :tools_used, :jsonb, default: []
    add_column :prompt_tracker_llm_responses, :tool_outputs, :jsonb, default: {}

    # Conversation grouping
    add_column :prompt_tracker_llm_responses, :conversation_id, :string
    add_column :prompt_tracker_llm_responses, :turn_number, :integer
    add_column :prompt_tracker_llm_responses, :previous_response_id, :string

    # Provider tracking
    add_column :prompt_tracker_llm_responses, :provider, :string, default: 'openai'

    # Indexes
    add_index :prompt_tracker_llm_responses, :response_id, unique: true, where: "response_id IS NOT NULL"
    add_index :prompt_tracker_llm_responses, :conversation_id
    add_index :prompt_tracker_llm_responses, :provider
    add_index :prompt_tracker_llm_responses, [:conversation_id, :turn_number]
  end
end
```

### Model Changes

```ruby
# app/models/prompt_tracker/llm_response.rb
module PromptTracker
  class LlmResponse < ApplicationRecord
    # Existing associations
    belongs_to :responseable, polymorphic: true

    # New: Conversation chain
    belongs_to :previous_response, class_name: "LlmResponse", optional: true
    has_one :next_response, class_name: "LlmResponse", foreign_key: :previous_response_id

    # Provider enum
    enum :provider, { openai: 'openai', openai_responses: 'openai_responses', anthropic: 'anthropic' }

    # Scopes
    scope :response_api, -> { where(provider: :openai_responses) }
    scope :chat_completions, -> { where(provider: :openai) }
    scope :with_tool_usage, -> { where.not(tools_used: []) }
    scope :in_conversation, ->(conv_id) { where(conversation_id: conv_id).order(:turn_number) }

    # Validations
    validates :response_id, uniqueness: true, allow_nil: true

    # Callbacks
    before_create :set_turn_number, if: :conversation_id?

    # Instance methods
    def response_api?
      provider == 'openai_responses'
    end

    def used_tool?(tool_name)
      tools_used.include?(tool_name)
    end

    def conversation_chain
      return [] unless conversation_id
      self.class.in_conversation(conversation_id).to_a
    end

    def previous_responses
      return [] unless conversation_id
      self.class.in_conversation(conversation_id).where("turn_number < ?", turn_number)
    end

    private

    def set_turn_number
      last_turn = self.class.where(conversation_id: conversation_id).maximum(:turn_number) || 0
      self.turn_number = last_turn + 1
    end
  end
end
```

### Schema Details

#### `response_id` (string)
- OpenAI Response API's unique identifier for the response
- Format: `resp_abc123...`
- Used to continue conversations via `previous_response_id` parameter
- Indexed for fast lookups

#### `tools_used` (jsonb array)
- Array of tool names that were invoked
- Example: `["web_search", "file_search"]`
- Empty array `[]` if no tools used

#### `tool_outputs` (jsonb object)
- Detailed outputs from each tool
- Structure varies by tool type:

```json
{
  "web_search": {
    "query": "latest pricing for Acme Corp",
    "results": [
      { "title": "Acme Pricing Page", "url": "https://...", "snippet": "..." }
    ]
  },
  "file_search": {
    "query": "return policy",
    "file_ids": ["file_abc123"],
    "results": [
      { "file_name": "policies.pdf", "content": "...", "score": 0.95 }
    ]
  },
  "code_interpreter": {
    "code": "import pandas as pd\n...",
    "output": "Result: 42",
    "files_created": ["file_xyz789"]
  }
}
```

#### `conversation_id` (string)
- Groups related responses in a multi-turn conversation
- Generated UUID when starting a new conversation
- Passed through when continuing a conversation

#### `turn_number` (integer)
- Position in the conversation (1, 2, 3, ...)
- Auto-incremented within a conversation_id

#### `previous_response_id` (string)
- References the `response_id` of the previous turn
- Used to link conversation chain
- Null for first turn in conversation

#### `provider` (string)
- Identifies which API was used
- Values: `openai`, `openai_responses`, `anthropic`
- Enables filtering and analytics by provider

## Service Integration

### OpenaiResponseService Updates

```ruby
# app/services/prompt_tracker/openai_response_service.rb
module PromptTracker
  class OpenaiResponseService
    def call(model:, system_prompt:, user_prompt:, tools: [], temperature: 0.7)
      response = client.responses.create(
        model: model,
        instructions: system_prompt,
        input: user_prompt,
        tools: format_tools(tools),
        temperature: temperature
      )

      build_result(response)
    end

    private

    def build_result(response)
      {
        text: extract_text(response),
        response_id: response.id,
        model: response.model,
        input_tokens: response.usage&.input_tokens,
        output_tokens: response.usage&.output_tokens,
        tools_used: extract_tools_used(response),
        tool_outputs: extract_tool_outputs(response)
      }
    end

    def extract_tools_used(response)
      response.output
        .select { |item| item.type != "message" }
        .map(&:type)
        .uniq
    end

    def extract_tool_outputs(response)
      outputs = {}

      response.output.each do |item|
        case item.type
        when "web_search_call"
          outputs["web_search"] = extract_web_search_output(item)
        when "file_search_call"
          outputs["file_search"] = extract_file_search_output(item)
        when "code_interpreter_call"
          outputs["code_interpreter"] = extract_code_output(item)
        end
      end

      outputs
    end
  end
end
```

### LlmResponse Creation

```ruby
# When saving a Response API result
def save_response(result, responseable:, prompt:, conversation_id: nil, previous_response_id: nil)
  LlmResponse.create!(
    responseable: responseable,
    prompt: prompt,
    response: result[:text],
    model: result[:model],
    input_tokens: result[:input_tokens],
    output_tokens: result[:output_tokens],
    provider: 'openai_responses',
    response_id: result[:response_id],
    tools_used: result[:tools_used],
    tool_outputs: result[:tool_outputs],
    conversation_id: conversation_id,
    previous_response_id: previous_response_id
  )
end
```

## UI Display

### Response Detail View

Show Response API-specific information:

```
┌─────────────────────────────────────────────────────────────────────┐
│ LLM Response #1234                                                  │
│ Provider: Response API | Model: gpt-4o                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Response ID: resp_abc123def456                                      │
│ Conversation: conv_xyz789 (Turn 3 of 5)                             │
│                                                                     │
│ ── Prompt ──────────────────────────────────────────────────────────│
│ What is your return policy for electronics?                         │
│                                                                     │
│ ── Response ────────────────────────────────────────────────────────│
│ Our return policy for electronics allows returns within 30 days...  │
│                                                                     │
│ ── Tools Used ──────────────────────────────────────────────────────│
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ 🔍 web_search                                                   │ │
│ │ Query: "Acme Corp electronics return policy"                    │ │
│ │ Results: 3 sources                                              │ │
│ │ [View Details]                                                  │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ── Metrics ─────────────────────────────────────────────────────────│
│ Input Tokens: 150 | Output Tokens: 200 | Latency: 1.2s              │
│                                                                     │
│ ── Conversation Chain ──────────────────────────────────────────────│
│ [Turn 1] → [Turn 2] → [Turn 3 (current)] → [Turn 4] → [Turn 5]      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Conversation View

For multi-turn conversations, show the full chain:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Conversation: conv_xyz789                                           │
│ PromptVersion: Customer Support v3                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Turn 1 (resp_001)                                                   │
│ ├─ User: Hello, I need help with my order                           │
│ └─ Assistant: Hi! I'd be happy to help. What's your order number?   │
│                                                                     │
│ Turn 2 (resp_002)                                                   │
│ ├─ User: Order #12345                                               │
│ └─ Assistant: I found your order. It shipped yesterday...           │
│    [🔍 file_search used]                                            │
│                                                                     │
│ Turn 3 (resp_003)                                                   │
│ ├─ User: When will it arrive?                                       │
│ └─ Assistant: Based on tracking, it should arrive by Friday...      │
│    [🔍 web_search used]                                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Analytics Queries

### Tool Usage Analytics

```ruby
# Most used tools
LlmResponse.response_api
  .where.not(tools_used: [])
  .group("jsonb_array_elements_text(tools_used)")
  .count

# Responses using web_search
LlmResponse.response_api
  .where("tools_used @> ?", '["web_search"]')
  .count

# Average tokens by tool usage
LlmResponse.response_api
  .select("
    CASE WHEN tools_used = '[]' THEN 'no_tools' ELSE 'with_tools' END as tool_usage,
    AVG(input_tokens) as avg_input,
    AVG(output_tokens) as avg_output
  ")
  .group("tool_usage")
```

### Conversation Analytics

```ruby
# Average conversation length
LlmResponse.response_api
  .where.not(conversation_id: nil)
  .group(:conversation_id)
  .maximum(:turn_number)
  .values
  .then { |turns| turns.sum.to_f / turns.size }

# Conversations by responseable
LlmResponse.response_api
  .where.not(conversation_id: nil)
  .group(:responseable_type, :responseable_id)
  .distinct
  .count(:conversation_id)
```

## Testing Strategy

### Model Tests

```ruby
# spec/models/prompt_tracker/llm_response_spec.rb
RSpec.describe PromptTracker::LlmResponse do
  describe "response_api fields" do
    it "stores response_id" do
      response = create(:llm_response,
        provider: 'openai_responses',
        response_id: 'resp_abc123'
      )
      expect(response.response_id).to eq('resp_abc123')
    end

    it "stores tools_used as array" do
      response = create(:llm_response,
        provider: 'openai_responses',
        tools_used: ['web_search', 'file_search']
      )
      expect(response.tools_used).to eq(['web_search', 'file_search'])
    end

    it "stores tool_outputs as hash" do
      outputs = { 'web_search' => { 'query' => 'test', 'results' => [] } }
      response = create(:llm_response,
        provider: 'openai_responses',
        tool_outputs: outputs
      )
      expect(response.tool_outputs).to eq(outputs)
    end
  end

  describe "#used_tool?" do
    it "returns true if tool was used" do
      response = create(:llm_response, tools_used: ['web_search'])
      expect(response.used_tool?('web_search')).to be true
      expect(response.used_tool?('file_search')).to be false
    end
  end

  describe "conversation chain" do
    it "auto-increments turn_number within conversation" do
      conv_id = SecureRandom.uuid

      r1 = create(:llm_response, conversation_id: conv_id)
      r2 = create(:llm_response, conversation_id: conv_id)
      r3 = create(:llm_response, conversation_id: conv_id)

      expect(r1.turn_number).to eq(1)
      expect(r2.turn_number).to eq(2)
      expect(r3.turn_number).to eq(3)
    end

    it "returns conversation chain in order" do
      conv_id = SecureRandom.uuid
      r1 = create(:llm_response, conversation_id: conv_id)
      r2 = create(:llm_response, conversation_id: conv_id)

      expect(r2.conversation_chain).to eq([r1, r2])
    end
  end

  describe "scopes" do
    it "filters by provider" do
      response_api = create(:llm_response, provider: 'openai_responses')
      chat = create(:llm_response, provider: 'openai')

      expect(LlmResponse.response_api).to include(response_api)
      expect(LlmResponse.response_api).not_to include(chat)
    end

    it "filters by tool usage" do
      with_tools = create(:llm_response, tools_used: ['web_search'])
      without_tools = create(:llm_response, tools_used: [])

      expect(LlmResponse.with_tool_usage).to include(with_tools)
      expect(LlmResponse.with_tool_usage).not_to include(without_tools)
    end
  end
end
```

### Migration Tests

```ruby
# spec/migrations/add_response_api_fields_to_llm_responses_spec.rb
RSpec.describe "AddResponseApiFieldsToLlmResponses" do
  it "adds all required columns" do
    expect(LlmResponse.column_names).to include(
      'response_id',
      'tools_used',
      'tool_outputs',
      'conversation_id',
      'turn_number',
      'previous_response_id',
      'provider'
    )
  end

  it "sets default values correctly" do
    response = LlmResponse.new
    expect(response.tools_used).to eq([])
    expect(response.tool_outputs).to eq({})
    expect(response.provider).to eq('openai')
  end
end
```

## Migration Path

### Existing Data

Existing LlmResponses will have:
- `provider: 'openai'` (default)
- `response_id: nil`
- `tools_used: []`
- `tool_outputs: {}`
- `conversation_id: nil`
- `turn_number: nil`

No data migration needed - defaults handle existing records.

### Backward Compatibility

- All existing code continues to work
- New fields are optional with sensible defaults
- Provider defaults to 'openai' for existing records

## Rollout Plan

### Phase 1: Migration (Day 1)
1. Create and run migration
2. Verify indexes created
3. Verify defaults applied

### Phase 2: Model Updates (Day 2)
1. Add new columns to model
2. Add scopes and methods
3. Add validations
4. Unit tests

### Phase 3: Service Integration (Day 3)
1. Update OpenaiResponseService to return new fields
2. Update response saving logic
3. Integration tests

### Phase 4: UI (Day 4-5)
1. Response detail view updates
2. Conversation chain view
3. Tool usage display

## Success Metrics

| Metric | Target |
|--------|--------|
| Migration runs without errors | 100% |
| Existing responses unaffected | 100% |
| New Response API responses stored correctly | 100% |
| Conversation chains queryable | 100% |

## Dependencies

- **PRD-01**: OpenaiResponseService (provides data to store)
- Existing: LlmResponse model

## Open Questions

1. **Tool output storage**: Should we store full tool outputs or just summaries? Full outputs could be large.

2. **Conversation cleanup**: Should we add a TTL for conversation data? Old conversations may not need response_id.

3. **Indexing strategy**: Do we need additional indexes for analytics queries?

## References

- PRD-01: OpenAI Response API Service Integration
- OpenAI Response API documentation
- `app/models/prompt_tracker/llm_response.rb`
