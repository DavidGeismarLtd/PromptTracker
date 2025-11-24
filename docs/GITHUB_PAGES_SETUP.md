# GitHub Pages Setup for PromptTracker

This guide will help you publish the PromptTracker presentation page using GitHub Pages.

## Quick Setup (5 minutes)

### 1. Enable GitHub Pages

1. Go to your repository on GitHub: https://github.com/DavidGeismarLtd/PromptTracker
2. Click on **Settings** (top right)
3. Scroll down to **Pages** in the left sidebar
4. Under **Source**, select:
   - **Branch**: `master` (or `main`)
   - **Folder**: `/docs`
5. Click **Save**

### 2. Wait for Deployment

GitHub will automatically build and deploy your site. This usually takes 1-2 minutes.

You'll see a message like:
```
Your site is ready to be published at https://davidgeismarlltd.github.io/PromptTracker/
```

### 3. Visit Your Site

Once deployed, your presentation page will be available at:
```
https://davidgeismarlltd.github.io/PromptTracker/
```

## Custom Domain (Optional)

If you want to use a custom domain like `prompttracker.io`:

1. In the GitHub Pages settings, add your custom domain
2. Add a `CNAME` file to the `docs/` folder with your domain
3. Configure your DNS provider to point to GitHub Pages

## Local Preview

To preview the page locally before pushing:

```bash
# Option 1: Simple Python server
cd docs
python3 -m http.server 8000
# Visit http://localhost:8000

# Option 2: Using Ruby
cd docs
ruby -run -ehttpd . -p8000
# Visit http://localhost:8000
```

## Updating the Page

Simply edit `docs/index.html` and push to GitHub. The page will automatically update within 1-2 minutes.

## Troubleshooting

### Page not showing up?
- Check that GitHub Pages is enabled in Settings → Pages
- Verify the branch and folder are set correctly
- Wait a few minutes for the initial deployment

### Changes not appearing?
- GitHub Pages can take 1-2 minutes to rebuild
- Try a hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
- Check the Actions tab to see if the deployment succeeded

### 404 Error?
- Make sure the file is named `index.html` (lowercase)
- Verify it's in the `docs/` folder
- Check that the branch is correct

## What's Included

The presentation page includes:

- ✅ Beautiful, modern design with gradient header
- ✅ Feature showcase with icons and cards
- ✅ Code examples with syntax highlighting
- ✅ Installation instructions
- ✅ Links to documentation
- ✅ Responsive design (mobile-friendly)
- ✅ Smooth scrolling and animations
- ✅ Copy-to-clipboard functionality
- ✅ Stats bar with key metrics

## Next Steps

After publishing:

1. Share the URL on social media
2. Add the URL to your gem's homepage in `prompt_tracker.gemspec`
3. Include it in your README.md
4. Add it to RubyGems.org when you publish the gem

Enjoy your new presentation page! 🎉

