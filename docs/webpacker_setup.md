# PromptTracker with Webpacker/Shakapacker

PromptTracker supports both **importmap-rails** (default) and **Webpacker/Shakapacker** for JavaScript asset management.

## Automatic Detection

PromptTracker automatically detects which asset pipeline your Rails application uses:

- **Importmap** (default): No additional configuration needed
- **Webpacker/Shakapacker**: Requires manual JavaScript import
- **Sprockets only**: Falls back to `javascript_include_tag`

## Setup for Webpacker/Shakapacker Projects

If your Rails application uses Webpacker or Shakapacker instead of importmap, follow these steps:

### 1. Install the gem

Add to your `Gemfile`:

```ruby
gem "prompt_tracker", git: "https://github.com/DavidGeismarLtd/PromptTracker.git"
```

Then run:

```bash
bundle install
```

### 2. Install importmap-rails (optional but recommended)

Even though your main app uses Webpacker, PromptTracker works best with importmap for its internal assets:

```bash
bundle add importmap-rails
```

This allows PromptTracker to manage its own JavaScript dependencies independently.

### 3. Import PromptTracker JavaScript (if not using importmap)

If you choose NOT to install importmap-rails, you need to manually import PromptTracker's JavaScript in your Webpacker pack.

Add to `app/javascript/packs/application.js`:

```javascript
// Import PromptTracker engine assets
import "@hotwired/turbo-rails"
import "prompt_tracker/application"
```

### 4. Configure Webpacker to find engine assets

Add to `config/webpacker.yml`:

```yaml
default: &default
  # ... existing config ...
  resolved_paths:
    - app/javascript
    - node_modules
    # Add PromptTracker engine JavaScript path
    - ../../gems/prompt_tracker/app/javascript
```

Or if using Shakapacker, add to `config/shakapacker.yml`:

```yaml
default: &default
  # ... existing config ...
  additional_paths:
    - app/javascript
    # Add PromptTracker engine JavaScript path
    - ../../gems/prompt_tracker/app/javascript
```

### 5. Mount the engine

Add to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount PromptTracker::Engine, at: "/prompt_tracker"
end
```

### 6. Run migrations

```bash
bin/rails prompt_tracker:install:migrations
bin/rails db:migrate
```

## Recommended Approach

**We strongly recommend installing `importmap-rails`** even in Webpacker projects. This allows:

- PromptTracker to manage its own JavaScript dependencies
- No conflicts with your main application's Webpacker setup
- Easier upgrades and maintenance
- No need to configure Webpacker paths

With importmap installed, PromptTracker's JavaScript is completely isolated and works out of the box.

## Troubleshooting

### Error: `undefined local variable or method 'javascript_importmap_tags'`

This error occurs when:
1. Your app uses Webpacker
2. `importmap-rails` was installed as a dependency
3. But importmap is trying to inject tags into your layouts

**Solution**: Install importmap-rails explicitly:

```bash
bundle add importmap-rails
bin/rails importmap:install
```

This creates the necessary configuration files and prevents the error.

### PromptTracker JavaScript not loading

If you see JavaScript errors or Stimulus controllers not working:

1. **Check if importmap is installed**: `bundle list | grep importmap`
2. **If using Webpacker without importmap**: Make sure you've added the import to your pack (see step 3 above)
3. **Check browser console**: Look for 404 errors on JavaScript files
4. **Verify Webpacker paths**: Ensure `config/webpacker.yml` includes the engine path

### Stimulus controllers not registering

PromptTracker uses Stimulus controllers. Make sure:

1. `@hotwired/stimulus` is installed in your app
2. Turbo is loaded before PromptTracker assets
3. If using Webpacker, the import order is correct:

```javascript
import "@hotwired/turbo-rails"
import "controllers" // Your app's controllers
import "prompt_tracker/application" // Engine controllers
```

## Need Help?

If you encounter issues with Webpacker/Shakapacker setup, please:

1. Check this documentation first
2. Open an issue on GitHub with:
   - Your Rails version
   - Your asset pipeline (Webpacker/Shakapacker version)
   - Full error message
   - Relevant configuration files

We're here to help! 🚀

