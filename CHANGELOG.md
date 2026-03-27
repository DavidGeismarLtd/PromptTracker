# Changelog

All notable changes to PromptTracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **BREAKING**: Made `importmap-rails` an optional dependency instead of required
  - PromptTracker now automatically detects which JavaScript asset pipeline your Rails app uses
  - Supports: importmap-rails (default), Webpacker, Shakapacker, and Sprockets
  - **Migration guide**: See [docs/webpacker_setup.md](docs/webpacker_setup.md)

### Added
- Automatic asset pipeline detection in engine layout
- Support for Webpacker and Shakapacker projects
- Documentation for Webpacker setup ([docs/webpacker_setup.md](docs/webpacker_setup.md))
- Troubleshooting guide for importmap/Webpacker conflicts ([docs/troubleshooting/webpacker_importmap_conflict.md](docs/troubleshooting/webpacker_importmap_conflict.md))

### Fixed
- Fixed `undefined local variable or method 'javascript_importmap_tags'` error when using PromptTracker in Webpacker-based Rails applications
- Engine now gracefully handles missing importmap-rails dependency

## [0.1.0] - 2024-03-24

### Added
- Initial release of PromptTracker
- Prompt management with versioning
- LLM call tracking and monitoring
- Automatic response evaluation
- A/B testing capabilities
- Testing dashboard with datasets
- Support for OpenAI (Chat Completions, Assistants API, Responses API)
- Support for Anthropic Claude
- Support for Google Gemini
- Playground for testing prompts
- Analytics dashboard
- Function definitions for tool calling
- Deployed agents feature
- Multi-provider support (OpenAI, Anthropic, Google, DeepSeek, Mistral, Perplexity, OpenRouter, xAI)

### Dependencies
- Rails >= 7.2.3
- PostgreSQL
- Redis (for Sidekiq)
- Ruby >= 3.3

[Unreleased]: https://github.com/DavidGeismarLtd/PromptTracker/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/DavidGeismarLtd/PromptTracker/releases/tag/v0.1.0

