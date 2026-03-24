# Example: Installing PromptTracker in a Webpacker Rails App

This guide shows a complete example of installing PromptTracker in a Rails application that uses Webpacker.

## Scenario

You have an existing Rails 7 application that uses Webpacker for JavaScript management. You want to add PromptTracker for LLM prompt management.

## Step-by-Step Installation

### 1. Check Your Current Setup

First, verify your current JavaScript setup:

```bash
# Check if you're using Webpacker
ls config/webpacker.yml

# Check your package.json
cat package.json | grep webpack
```

If you see `webpacker.yml` and webpack in your package.json, you're using Webpacker.

### 2. Add PromptTracker to Gemfile

```ruby
# Gemfile
gem "prompt_tracker", git: "https://github.com/DavidGeismarLtd/PromptTracker.git"
```

### 3. Install Dependencies

```bash
bundle install
```

At this point, you might see `importmap-rails` being installed as a transitive dependency. **This is expected and OK!**

### 4. Install importmap-rails (Recommended)

Even though your app uses Webpacker, install importmap for PromptTracker:

```bash
bundle add importmap-rails
bin/rails importmap:install
```

This creates:
- `config/importmap.rb`
- `config/initializers/importmap.rb` (if not exists)

**Why?** This allows PromptTracker to manage its own JavaScript independently from your Webpacker setup. No conflicts!

### 5. Mount the Engine

Add to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Your existing routes...
  
  mount PromptTracker::Engine, at: "/prompt_tracker"
end
```

### 6. Install and Run Migrations

```bash
bin/rails prompt_tracker:install:migrations
bin/rails db:migrate
```

### 7. Configure API Keys (Optional)

Create or update `.env`:

```bash
# .env
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
```

Add to `.gitignore` if not already there:

```
.env
```

### 8. Create Initializer

Create `config/initializers/prompt_tracker.rb`:

```ruby
PromptTracker.configure do |config|
  # Basic authentication (optional)
  # config.basic_auth_username = "admin"
  # config.basic_auth_password = "secret"

  # Provider API keys
  config.providers = {
    openai: { api_key: ENV["OPENAI_API_KEY"] },
    anthropic: { api_key: ENV["ANTHROPIC_API_KEY"] }
  }

  # Feature flags (optional)
  config.features = {
    monitoring: true,
    functions: true
  }
end
```

### 9. Start Your Server

```bash
bin/rails server
```

Visit: http://localhost:3000/prompt_tracker

### 10. Verify Installation

1. **Check the UI**: You should see the PromptTracker dashboard
2. **Check browser console**: No JavaScript errors
3. **Create a test prompt**: Go to Testing > New Prompt
4. **Test in playground**: Try the playground feature

## Your Final Setup

After installation, your app will have:

```
your-rails-app/
├── app/
│   └── javascript/
│       └── packs/
│           └── application.js  # Your Webpacker entry point
├── config/
│   ├── webpacker.yml           # Your Webpacker config
│   ├── importmap.rb            # PromptTracker's importmap config
│   ├── routes.rb               # With PromptTracker mounted
│   └── initializers/
│       └── prompt_tracker.rb   # PromptTracker configuration
├── Gemfile
│   ├── gem "webpacker"         # Your JavaScript bundler
│   ├── gem "importmap-rails"   # For PromptTracker
│   └── gem "prompt_tracker"    # The engine
└── .env                        # API keys
```

## How It Works

- **Your app's JavaScript**: Managed by Webpacker (in `app/javascript/packs/`)
- **PromptTracker's JavaScript**: Managed by importmap (isolated in the engine)
- **No conflicts**: Each system manages its own assets independently

## Troubleshooting

### Error: `javascript_importmap_tags` not found

If you see this error, it means importmap-rails wasn't installed properly:

```bash
bundle add importmap-rails
bin/rails importmap:install
bin/rails server
```

### PromptTracker UI loads but no JavaScript works

Check browser console for errors. Make sure:

1. Importmap is installed: `bundle list | grep importmap`
2. Config file exists: `ls config/importmap.rb`
3. No JavaScript errors in console

### Webpacker compilation errors

If Webpacker complains about PromptTracker files:

1. Make sure you're NOT importing PromptTracker in your Webpacker packs
2. PromptTracker uses importmap, not Webpacker
3. Keep them separate!

## Alternative: Pure Webpacker (Not Recommended)

If you absolutely don't want to install importmap, see [Webpacker Setup Guide](../webpacker_setup.md) for advanced configuration.

## Next Steps

- Read the [Configuration Guide](../configuration.md)
- Explore the [Testing Dashboard](../testing_dashboard.md)
- Set up [Monitoring](../monitoring.md)
- Create your first [Deployed Agent](../deployed_agents.md)

---

**Questions?** Open an issue on GitHub or check the [Troubleshooting Guide](../troubleshooting/webpacker_importmap_conflict.md).

