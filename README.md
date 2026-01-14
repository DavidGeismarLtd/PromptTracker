# PromptTracker

A comprehensive Rails 7.2 engine for managing, tracking, and analyzing LLM prompts with evaluation, A/B testing, and analytics.

## What is PromptTracker?

PromptTracker is a Rails engine that helps you:

- **Manage Prompts**: Version control your LLM prompts with full history and playground for testing
- **Track LLM Calls**: Log all LLM API calls with metadata, tokens, and response times
- **Evaluate Responses**: Automatically evaluate LLM responses using configurable evaluators (length checks, pattern matching, LLM-as-judge, conversational evaluators etc.)
- **A/B Testing**: Run experiments comparing different prompt versions
- **Testing & Datasets**: Create datasets and run tests against your prompts before deployment
- **Compatible with**: OpenAI Assistants, ChatCompletion, Response API.
- **Analytics Dashboard**: Monitor response quality, costs, and performance

## Installation

### Prerequisites

- Ruby 3.3+
- Rails 7.2+
- PostgreSQL
- Redis (for Sidekiq background jobs)

### Add to your Gemfile

```ruby
gem "prompt_tracker", git: "https://github.com/DavidGeismarLtd/PromptTracker.git"
```

### Install dependencies

```bash
bundle install
```

### Mount the engine

Add to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount PromptTracker::Engine, at: "/prompt_tracker"
end
```

### Install and run migrations

```bash
# Copy migrations from the engine
bin/rails prompt_tracker:install:migrations

# Run migrations
bin/rails db:migrate
```

### Configure API keys (optional)

Create `.env` file in your app root:

```bash
OPENAI_API_KEY=your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
```

## Development Setup (Local)

### 1. Clone and setup

```bash
git clone git@github.com:DavidGeismarLtd/PromptTracker.git
cd PromptTracker
bundle install
```

### 2. Database setup

Make sure PostgreSQL is running locally, then:

```bash
cd test/dummy

# Create and migrate the database
bin/rails db:create
bin/rails db:migrate

# Seed with sample data (optional but recommended)
bin/rails db:seed
```

### 3. Start the development server

```bash
cd test/dummy
bin/rails server
```

Visit [http://localhost:3000/prompt_tracker](http://localhost:3000/prompt_tracker)

### 4. Start Sidekiq (for background jobs)

In a separate terminal:

```bash
bundle exec sidekiq -C config/sidekiq.yml -r ./test/dummy/config/environment.rb
```

## Docker Setup

### Quick Start with Docker

```bash
# Build and start all services
make up

# Or in detached mode
make up-d
```

This starts:
- **PostgreSQL** on port 5432
- **Redis** on port 6380
- **Rails app** on port 3000
- **Sidekiq** worker

Visit [http://localhost:3000/prompt_tracker](http://localhost:3000/prompt_tracker)

### Docker Commands (via Makefile)

```bash
make help         # Show all available commands

# Container management
make build        # Build Docker images
make up           # Start all services
make up-d         # Start in detached mode
make down         # Stop all services
make down-v       # Stop and remove volumes
make restart      # Restart all services
make rebuild      # Rebuild from scratch

# Development
make shell        # Open bash in web container
make console      # Open Rails console
make logs         # Show logs from all services
make logs-web     # Show web logs only
make logs-sidekiq # Show Sidekiq logs only

# Database
make db-migrate   # Run migrations
make db-reset     # Reset database
make db-seed      # Seed database

# Testing
make test         # Run all tests
make rspec        # Run RSpec only
```

## Running Tests

### Local development

```bash
# Run all tests (Minitest + RSpec)
bin/test_all

# Run RSpec only
bundle exec rspec

# Run Minitest only
bundle exec rails test

# Run specific spec file
bundle exec rspec spec/models/prompt_tracker/prompt_spec.rb

# Run specs with a specific tag
bundle exec rspec --tag focus
```

### In Docker

```bash
make test    # Run all tests
make rspec   # Run RSpec only
```

## Usage

### Track LLM calls in your application

```ruby
result = PromptTracker::LlmCallService.track(
  prompt_name: "customer_support",
  variables: { query: "How do I reset my password?" },
  provider: "openai",
  model: "gpt-4o"
) do |rendered_prompt|
  # Your LLM API call here
  openai_client.chat(rendered_prompt)
end

# Access the results
result[:response_text]  # The LLM's response
result[:tracking_id]    # Unique tracking ID
result[:llm_response]   # Full LlmResponse record
```

### Use the Trackable module

```ruby
class CustomerSupportController < ApplicationController
  include PromptTracker::Trackable

  def ask
    result = track_llm_call("customer_support", variables: { query: params[:query] }) do |prompt|
      openai_client.chat(prompt)
    end

    render json: { answer: result[:response_text] }
  end
end
```

## Project Structure

```
prompt_tracker/
├── app/
│   ├── controllers/prompt_tracker/  # Engine controllers
│   ├── models/prompt_tracker/        # Core models (Prompt, PromptVersion, LlmResponse, etc.)
│   ├── services/prompt_tracker/      # Business logic (evaluators, LLM services)
│   ├── views/prompt_tracker/         # UI templates
│   └── javascript/prompt_tracker/    # Stimulus controllers
├── config/routes.rb                  # Engine routes
├── db/migrate/                       # Migrations
├── lib/prompt_tracker/               # Engine configuration
├── spec/                             # RSpec tests
└── test/dummy/                       # Test Rails application
```

## License

MIT License - see [MIT-LICENSE](MIT-LICENSE)
