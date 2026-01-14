# Phase 3.6: AI-Generated UI Mockups for Articles

## Overview

Added the ability for Claude Code to automatically generate stylized UI mockup images during article generation. When writing how-to guides, Claude can create visual representations of UI elements (buttons, forms, dialogs) that get embedded directly into article steps.

## What Was Built

### Architecture

```
GenerateArticleJob
    │
    ├── Runs Docker container (rtfm/claude-analyzer)
    │
    └── Claude Code generates article JSON
            │
            ├── For visual steps, calls /render_mockup.sh
            │       │
            │       └── Puppeteer renders HTML → PNG
            │
            └── Outputs article.json + /output/images/step_N.png
                    │
                    └── Job attaches images to StepImage records
```

### How It Works

1. **During article generation**, Claude Code has access to a new Bash tool: `/render_mockup.sh`

2. **Claude decides** which steps need visual mockups based on the content (forms, buttons, settings panels, etc.)

3. **For each mockup**, Claude writes HTML using predefined CSS utility classes and calls:
   ```bash
   /render_mockup.sh <step_index> '<html_content>'
   ```

4. **Puppeteer** (running inside Docker) renders the HTML to a PNG at `/output/images/step_N.png`

5. **The article JSON** includes `"has_image": true/false` for each step

6. **GenerateArticleJob** reads the images and attaches them to `StepImage` records via ActiveStorage

## Files Created

| File | Purpose |
|------|---------|
| `docker/claude-analyzer/render_mockup.js` | Puppeteer script with 40+ CSS utility classes |
| `docker/claude-analyzer/render_mockup.sh` | Bash wrapper for Claude to call |

## Files Modified

| File | Changes |
|------|---------|
| `docker/claude-analyzer/Dockerfile` | Added Chromium, Puppeteer, font packages, `NODE_PATH` |
| `docker/claude-analyzer/generate_article.sh` | Updated prompt with mockup generation instructions |
| `app/jobs/generate_article_job.rb` | Added `collect_generated_images` and `attach_generated_images` methods |

## Available CSS Classes for Mockups

Claude can use these classes when generating mockup HTML:

### Layout
- `.mockup-container` - White card with shadow (wrap content in this)
- `.card` - Bordered card
- `.flex`, `.flex-col`, `.items-center`, `.justify-between`, `.gap-2`, `.gap-4`

### Buttons
- `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-success`

### Forms
- `.input` - Text input styling
- `.label` - Form label
- `.checkbox` - Checkbox input
- `.toggle`, `.toggle.active` - Toggle switch

### Text
- `.heading`, `.subheading`
- `.text-gray`, `.text-dark`, `.text-sm`, `.text-xs`, `.text-lg`
- `.font-medium`, `.font-bold`

### Components
- `.alert`, `.alert-info`, `.alert-success`, `.alert-warning`, `.alert-error`
- `.badge`, `.badge-gray`, `.badge-blue`, `.badge-green`, `.badge-red`
- `.avatar`, `.avatar-lg`
- `.tabs`, `.tab`, `.tab.active`
- `.dropdown`, `.dropdown-item`
- `.table`

### Spacing
- `.mt-1` to `.mt-4`, `.mb-1` to `.mb-4`
- `.p-2`, `.p-4`

## Example Mockup

Claude might generate:

```html
<div class="mockup-container">
  <h3 class="heading mb-4">Add Team Member</h3>
  <div class="mb-4">
    <label class="label">Email address</label>
    <input type="email" class="input" placeholder="colleague@example.com">
  </div>
  <button class="btn btn-primary">Send Invitation</button>
</div>
```

Which renders as a clean, stylized UI card.

## Configuration

### Docker Image

The Docker image must be rebuilt after changes:

```bash
docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/
```

### Environment Variables

No new environment variables required. Uses existing:
- `ANTHROPIC_API_KEY` - For Claude Code
- `GITHUB_TOKEN` - For repo cloning (via GitHub App installation)

## Testing

### Test render script directly:

```bash
docker run --rm -v /tmp/output:/output --entrypoint /bin/bash \
  rtfm/claude-analyzer:latest -c \
  '/render_mockup.sh 0 "<div class=\"mockup-container\"><button class=\"btn btn-primary\">Click</button></div>"'

open /tmp/output/images/step_0.png
```

### Test via Rails:

```ruby
# Reset an article to regenerate with mockups
article = Article.find(ID)
article.update!(generation_status: :generation_pending, structured_content: nil)
GenerateArticleJob.perform_later(article_id: article.id)

# Check results
article.reload
article.step_images.count
```

## Design Decisions

### Why Stylized Mockups (Not Screenshots)?

1. **Don't become outdated** - Real screenshots break when UI changes slightly
2. **Consistent style** - All mockups match regardless of actual app design
3. **Faster to generate** - No need to run the actual app
4. **Claude can customize** - Generates exactly what's needed for the instruction

### Why Puppeteer in Docker?

1. **Isolation** - Chromium runs in container, not on host
2. **Consistency** - Same rendering environment in dev and production
3. **Security** - Sandboxed execution

### Why Read File to Memory?

ActiveStorage's `attach` with `File.open` block caused "closed stream" errors. Reading via `File.binread` + `StringIO` ensures the data persists until upload completes.

## Future Improvements

- [ ] Add more CSS components (modals, sidebars, navigation)
- [ ] Allow custom color schemes per project
- [ ] Cache commonly used mockups
- [ ] Add dark mode variant support
