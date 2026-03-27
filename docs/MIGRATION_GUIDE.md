# Migration Guide

## Upgrading to Latest Version (importmap-rails now optional)

### What Changed?

In previous versions, PromptTracker required `importmap-rails` as a mandatory dependency. This caused conflicts for applications using Webpacker or Shakapacker.

**Now**: `importmap-rails` is optional and automatically detected.

### Who Needs to Migrate?

You need to take action if:

1. ✅ **You're using importmap-rails**: No action needed! Everything works as before.
2. ⚠️ **You're using Webpacker/Shakapacker**: Follow the steps below.
3. ⚠️ **You're getting the `javascript_importmap_tags` error**: Follow the quick fix below.

### Quick Fix for `javascript_importmap_tags` Error

If you're seeing this error:

```
ActionView::Template::Error (undefined local variable or method 'javascript_importmap_tags')
```

**Solution**: Install importmap-rails explicitly:

```bash
bundle add importmap-rails
bin/rails importmap:install
bin/rails server
```

This is the **recommended approach** for all users, even if you use Webpacker for your main application.

### Why Install importmap-rails Even with Webpacker?

Installing `importmap-rails` alongside Webpacker is perfectly fine and recommended because:

1. **Isolation**: PromptTracker's JavaScript is managed independently from your app
2. **No Conflicts**: Importmap only manages PromptTracker's assets, not your app's
3. **Simplicity**: No need to configure Webpacker paths or imports
4. **Maintenance**: Easier to upgrade PromptTracker in the future

### Alternative: Pure Webpacker Setup (Advanced)

If you prefer NOT to install importmap-rails, you can use pure Webpacker:

#### 1. Update PromptTracker

```bash
bundle update prompt_tracker
```

#### 2. Import PromptTracker JavaScript

Add to `app/javascript/packs/application.js`:

```javascript
import "@hotwired/turbo-rails"
import "prompt_tracker/application"
```

#### 3. Configure Webpacker

Add to `config/webpacker.yml`:

```yaml
default: &default
  resolved_paths:
    - app/javascript
    - node_modules
    - ../../gems/prompt_tracker/app/javascript  # Add this line
```

#### 4. Restart Webpacker

```bash
bin/webpack-dev-server
```

### Verification

After migration, verify everything works:

1. **Start your server**: `bin/rails server`
2. **Visit PromptTracker**: `http://localhost:3000/prompt_tracker`
3. **Check browser console**: No JavaScript errors
4. **Test a feature**: Create a prompt and test it in the playground

### Rollback

If you encounter issues, you can rollback:

```bash
# Rollback to previous version
bundle update prompt_tracker --conservative

# Or pin to a specific commit
# In your Gemfile:
gem "prompt_tracker", git: "https://github.com/DavidGeismarLtd/PromptTracker.git", ref: "PREVIOUS_COMMIT_SHA"
```

### Breaking Changes

None! This is a backward-compatible change:

- ✅ Existing importmap-rails users: No changes needed
- ✅ New Webpacker users: Automatic detection
- ✅ Existing Webpacker users: Install importmap-rails (recommended) or configure Webpacker

### Need Help?

If you encounter issues during migration:

1. Check [Webpacker Setup Guide](webpacker_setup.md)
2. Check [Troubleshooting Guide](troubleshooting/webpacker_importmap_conflict.md)
3. Open an issue on GitHub with:
   - Your Rails version
   - Your asset pipeline (importmap/Webpacker/Shakapacker)
   - Full error message
   - Steps to reproduce

We're here to help! 🚀

### Summary

**Recommended for all users**:

```bash
bundle add importmap-rails
bin/rails importmap:install
bundle update prompt_tracker
bin/rails server
```

This ensures the smoothest experience regardless of your main application's asset pipeline.

