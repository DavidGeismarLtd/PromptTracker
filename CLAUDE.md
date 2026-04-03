# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this project?

PromptTracker is a **mountable Rails 7.2 engine** (not a standalone app) for managing, tracking, and evaluating LLM prompts. It provides version control for prompts, A/B testing, automated evaluation, dataset/test management, a playground, and analytics dashboards. It supports OpenAI, Anthropic, Google, and 6 other LLM providers via the `ruby_llm` gem.

## Development Commands

### Running the dummy app (for development)

```bash
cd test/dummy
bin/rails db:create && bin/rails db:migrate && bin/rails db:seed
bin/rails server          # http://localhost:3000/prompt_tracker
bundle exec sidekiq       # separate terminal for background jobs
```

### Testing

```bash
# Both suites (Minitest + RSpec)
bin/test_all

# Individual suites
bundle exec rails test              # Minitest
bundle exec rspec                   # RSpec

# Single test file
bundle exec rails test test/models/prompt_tracker/prompt_test.rb
bundle exec rspec spec/models/prompt_tracker/evaluator_config_spec.rb

# Single test by line
bundle exec rails test test/models/prompt_tracker/prompt_test.rb:10
```

### Linting

```bash
bin/rubocop -f github
```

### Docker (alternative)

```bash
make help       # list all commands
make up         # start services
make test       # run all tests
make console    # Rails console
```

## Architecture

### Engine structure

This is an **isolated Rails engine** under the `PromptTracker` namespace. The engine is mounted in host apps at a configurable path (typically `/prompt_tracker`). The test/dummy app serves as the development host.

### Three main UI sections (defined in config/routes.rb)

1. **Testing** (`/testing/`) - Pre-deployment: playground, agent/version management, datasets, test runs
2. **Monitoring** (`/monitoring/`) - Runtime: tracked LLM calls, evaluations, performance metrics
3. **Functions** (`/functions/`) - Code-based agent functions with AWS Lambda deployment

### Key domain model chain

`Agent` -> `AgentVersion` (system_prompt, model_config, variables_schema) -> `LlmResponse` (tracked API call) -> `Evaluation` (score/feedback)

Supporting models: `AbTest`, `Test`/`TestRun`, `Dataset`/`DatasetRow`, `EvaluatorConfig`, `DeployedAgent`, `FunctionDefinition`

### Services layer (`app/services/prompt_tracker/`)

- `LlmCallService` - main orchestrator for tracking LLM calls
- `LlmClientService` - provider-agnostic LLM client
- `EvaluatorRegistry` - discovers and runs evaluators
- `AutoEvaluationService` - automatic evaluation after responses
- 13 evaluator types in `services/evaluators/` (ExactMatch, LlmJudge, PatternMatch, JsonSchema, etc.)
- Test runners in `services/test_runners/`

### Frontend

- Hotwire stack: Turbo Streams + Stimulus controllers (40+ controllers in `app/javascript/prompt_tracker/`)
- Importmap for JS module loading (also supports Webpacker)
- ERB views with ActionCable for real-time updates

### Configuration

The engine is configured via `PromptTracker.configure` in a host app initializer. Supports both static config and dynamic per-request configuration (multi-tenant). See `lib/prompt_tracker/configuration.rb`.

### CI

GitHub Actions runs RuboCop lint + RSpec against PostgreSQL 14 on Ruby 3.3.5.

## Coding Guidelines

### Small, testable classes
- Create small classes with a single responsibility
- Create tests for all classes using RSpec

### No defensive programming
- Do not rescue `StandardError` broadly — let errors surface
- Do not use defensive hash access patterns with fallbacks to string keys:
  ```ruby
  # Bad
  provider = model_config[:provider] || model_config["provider"] || "openai"

  # Good — use only symbol keys
  provider = model_config[:provider]
  ```

### No backward compatibility code
- Do not maintain backward compatibility for legacy data formats
- If data format changes, migrate the data — don't add dual-read logic

## Naming convention in progress

The codebase is being renamed from `Prompt`/`PromptVersion` to `Agent`/`AgentVersion`. Both terms may appear; the canonical names going forward are Agent/AgentVersion.
