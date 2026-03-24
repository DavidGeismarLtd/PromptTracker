# Fixing: `undefined local variable or method 'javascript_importmap_tags'`

## Problem

You're getting this error when starting your Rails server after installing PromptTracker:

```
ActionView::Template::Error (undefined local variable or method
'javascript_importmap_tags' for an instance of #<Class:0x0000000165034f60>)
```

## Root Cause

Your Rails application uses **Webpacker** for JavaScript management, but PromptTracker previously required `importmap-rails` as a dependency. When `importmap-rails` is installed, it automatically tries to inject `javascript_importmap_tags` into layouts, causing a conflict with Webpacker.

## Solution (Quick Fix)

**Option 1: Install importmap-rails (Recommended)**

The easiest solution is to install `importmap-rails` explicitly in your application. This allows PromptTracker to manage its own JavaScript independently from your Webpacker setup:

```bash
bundle add importmap-rails
bin/rails importmap:install
```

This creates:
- `config/importmap.rb` (importmap configuration)
- Initializer files

Restart your server:

```bash
bin/rails server
```

✅ **This is the recommended approach** because:
- PromptTracker's JavaScript is isolated from your app
- No conflicts with Webpacker
- Easier to maintain and upgrade
- Works out of the box

**Option 2: Use latest PromptTracker (importmap is now optional)**

Update to the latest version of PromptTracker where `importmap-rails` is optional:

```bash
bundle update prompt_tracker
```

The latest version automatically detects your asset pipeline and adapts accordingly.

## How It Works Now

PromptTracker now automatically detects which JavaScript asset pipeline you're using:

```erb
<%# In PromptTracker's layout %>
<% if defined?(Importmap) %>
  <%# Using importmap-rails %>
  <%= javascript_importmap_tags %>
  <%= javascript_import_module_tag "prompt_tracker/application" %>
<% elsif defined?(Webpacker) || defined?(Shakapacker) %>
  <%# Using Webpacker/Shakapacker %>
  <%# Host app should include engine assets in their pack %>
<% else %>
  <%# Fallback to Sprockets %>
  <%= javascript_include_tag "prompt_tracker/application" %>
<% end %>
```

## Advanced: Using Webpacker Without Importmap

If you prefer NOT to install importmap and want to use Webpacker exclusively, you need to manually import PromptTracker's JavaScript.

### 1. Add to your Webpacker pack

Edit `app/javascript/packs/application.js`:

```javascript
// Import PromptTracker engine assets
import "@hotwired/turbo-rails"
import "prompt_tracker/application"
```

### 2. Configure Webpacker paths

Edit `config/webpacker.yml`:

```yaml
default: &default
  # ... existing config ...
  resolved_paths:
    - app/javascript
    - node_modules
    # Add PromptTracker engine JavaScript path
    - ../../gems/prompt_tracker/app/javascript
```

### 3. Restart Webpacker

```bash
bin/webpack-dev-server
```

## Why This Happened

Previously, PromptTracker had this in `prompt_tracker.gemspec`:

```ruby
spec.add_dependency "importmap-rails"  # ❌ Required dependency
```

This forced all users to install importmap, even if they used Webpacker.

Now it's optional:

```ruby
# importmap-rails is no longer a required dependency ✅
# It's detected automatically if present
```

## Still Having Issues?

If you're still experiencing problems:

1. **Check your Gemfile.lock**: Make sure you have the latest version of PromptTracker
2. **Clear cache**: `bin/rails tmp:clear`
3. **Restart server**: `bin/rails server`
4. **Check browser console**: Look for JavaScript errors
5. **Open an issue**: Include your Rails version, asset pipeline, and full error message

## Related Documentation

- [Webpacker Setup Guide](../webpacker_setup.md)
- [Installation Guide](../../README.md#installation)

---

**TL;DR**: Run `bundle add importmap-rails && bin/rails importmap:install` and restart your server. This is the easiest and recommended solution.

