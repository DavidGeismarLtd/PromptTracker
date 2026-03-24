# Quick Fix: Webpacker + PromptTracker Error

## The Error

```
ActionView::Template::Error (undefined local variable or method
'javascript_importmap_tags' for an instance of #<Class:0x0000000165034f60>)
```

## The Problem

Your Rails app uses **Webpacker**, but PromptTracker introduced `importmap-rails` as a dependency. When importmap is installed, it tries to inject `javascript_importmap_tags` into layouts, causing a conflict.

## The Solution (30 seconds)

Run these commands:

```bash
bundle add importmap-rails
bin/rails importmap:install
bin/rails server
```

**Done!** ✅

## Why This Works

Installing `importmap-rails` explicitly creates the necessary configuration files (`config/importmap.rb`) that prevent the error. 

**Important**: This does NOT conflict with Webpacker! Here's why:

- **Your app's JavaScript**: Still managed by Webpacker (no change)
- **PromptTracker's JavaScript**: Managed by importmap (isolated)
- **Result**: Both systems work independently, no conflicts

## Verification

1. Start your server: `bin/rails server`
2. Visit PromptTracker: `http://localhost:3000/prompt_tracker`
3. Check browser console: No errors
4. Test a feature: Create a prompt in the playground

## Alternative Solutions

### Option 2: Update to Latest PromptTracker

The latest version of PromptTracker makes `importmap-rails` optional:

```bash
bundle update prompt_tracker
```

Then follow Option 1 above (still recommended to install importmap).

### Option 3: Pure Webpacker (Advanced)

If you absolutely don't want importmap, see the [full Webpacker guide](webpacker_setup.md).

**Note**: Option 1 is the easiest and recommended approach.

## Still Having Issues?

1. Clear cache: `bin/rails tmp:clear`
2. Restart server: `bin/rails server`
3. Check [Troubleshooting Guide](troubleshooting/webpacker_importmap_conflict.md)
4. Open an issue on GitHub

## Summary

**TL;DR**: Run `bundle add importmap-rails && bin/rails importmap:install` and you're good to go! 🚀

This is the recommended solution for all Webpacker users installing PromptTracker.

