#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token
# - CLAUDE_MODEL: Claude model to use (e.g., claude-sonnet-4-5)

# Required input files (mounted at /input):
# - context.json: Project context and article details
# - diff.patch (optional): Source PR diff if available

echo "Starting article generation..."
echo "Repository: ${GITHUB_REPO}"

# Verify input files exist
if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

# Clone the repository for full code context
echo "Cloning repository..."
if ! git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>&1; then
    echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
    exit 1
fi

if [ ! -d /repo/.git ]; then
    echo "ERROR: Repository clone failed - /repo/.git not found"
    exit 1
fi

cd /repo

# Read article title from context for logging
ARTICLE_TITLE=$(cat /input/context.json | grep -o '"article_title":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "Generating article: ${ARTICLE_TITLE}"

# Check for style context (pre-extracted during project analysis)
if [ -f /input/style_context.json ]; then
    echo "Style context found at /input/style_context.json"
else
    echo "WARNING: No style_context.json found - mockups may use default styling"
fi

# Check for compiled CSS (for accurate mockup generation)
if [ -f /input/compiled_css.txt ] && [ -s /input/compiled_css.txt ]; then
    CSS_SIZE=$(wc -c < /input/compiled_css.txt)
    echo "Compiled CSS found (${CSS_SIZE} bytes) - mockups will use real CSS and class names"
else
    echo "No compiled CSS - mockups will use style context fallback"
fi

# Check if diff is available
HAS_DIFF="false"
if [ -f /input/diff.patch ] && [ -s /input/diff.patch ]; then
    HAS_DIFF="true"
    echo "Source PR diff available"
fi

# Check for existing articles corpus
if [ -f /input/existing_articles/manifest.json ]; then
    ARTICLE_COUNT=$(jq -r '.total_count // 0' /input/existing_articles/manifest.json 2>/dev/null || echo "0")
    echo "Existing articles corpus found (${ARTICLE_COUNT} articles)"
else
    echo "No existing articles corpus"
fi

# Run Claude Code to generate the article
echo "Running Claude Code article generation..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

# Use default model if not specified
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5}"
echo "Using model: ${CLAUDE_MODEL}"

# Build max-turns argument (default to 30 for article generation which needs many steps)
CLAUDE_MAX_TURNS="${CLAUDE_MAX_TURNS:-30}"
MAX_TURNS_ARG="--max-turns ${CLAUDE_MAX_TURNS}"
echo "Max turns: ${CLAUDE_MAX_TURNS}"

# Run Claude and capture exit status (don't fail on error due to set -e)
set +e
cat <<'PROMPT' | claude -p --model "${CLAUDE_MODEL}" ${MAX_TURNS_ARG} --output-format json --allowedTools "Read,Glob,Grep,Bash" > /tmp/claude_output.json
You are a technical writer creating a how-to guide article for end users of a software product.

STEP 1: Read the context file to understand what article you need to write:
/input/context.json

This file contains:
- project_name: The name of the product
- project_overview: What the product does
- article_title: The title of the how-to guide you need to write
- article_description: A brief description of what the guide should cover
- article_justification: Why this guide is needed (based on recent code changes)
- source_pr_title/content: Information about the PR that triggered this recommendation (if available)
- regeneration_guidance: (optional) User-provided instructions for improving this regeneration

STEP 1.5: Check if there is regeneration guidance from the user.
If the context.json contains a "regeneration_guidance" field with content, you MUST carefully follow these instructions while generating the article. The user is providing this guidance because a previous generation didn't meet their expectations. Treat their feedback as high-priority requirements.

Examples of regeneration guidance and how to handle them:
- "Make the tone more friendly and conversational" -> Adjust your writing style accordingly
- "Focus more on the mobile app workflow" -> Emphasize mobile-specific steps and screenshots
- "Include a step about configuring notifications" -> Add this specific step
- "The images don't match our UI - use accurate mockups" -> Pay extra attention to mockup accuracy
- "Fix the prerequisites section" -> Update the prerequisites appropriately

STEP 2: If a diff file exists, read it to understand the specific code changes:
/input/diff.patch

STEP 3: Check for compiled CSS (preferred) and style context (fallback):
- /input/compiled_css.txt - The actual compiled CSS from the project (if available)
- /input/style_context.json - Extracted style values as fallback

STEP 4: Explore the full codebase at /repo to understand the feature in detail. Use Glob, Grep, and Read tools to find relevant code, UI components, configuration, and related functionality. This will help you write accurate, specific instructions.

STEP 4.5: Check for existing articles to reference for consistency:
/input/existing_articles/manifest.json - Lists all completed articles for this project
/input/existing_articles/{slug}/content.json - Article structured content
/input/existing_articles/{slug}/images/step_N.html - Mockup HTML source

If existing articles are available:
- Match their writing tone and style for consistency
- Reuse HTML patterns from existing mockups for similar UI elements
- Use consistent terminology across articles

STEP 5: Write a comprehensive how-to guide article as a JSON object.

IMPORTANT GUIDELINES:
- Write for END USERS, not developers
- Use clear, simple language - avoid technical jargon
- Focus on what users can DO, not how it works internally
- Do NOT include code snippets unless absolutely necessary for users
- Do NOT mention internal file names, functions, or architecture

=== UI MOCKUP GENERATION ===
You can generate UI mockup images for steps that involve visual interfaces.

FIRST, determine which approach to use:
1. Read /input/compiled_css.txt - if it has content (not empty), use the CSS EMBEDDING approach
2. If compiled_css.txt is empty, fall back to the INLINE STYLES approach using /input/style_context.json

=== VIEWPORT HINTS ===
Add a data-viewport attribute to your HTML to specify the ideal viewport size:

<html data-viewport="wide">     <!-- 1200x800, DEFAULT for most web UIs -->
<html data-viewport="desktop">  <!-- 800x600 for smaller dialogs/modals -->
<html data-viewport="mobile">   <!-- 375x667 for mobile app mockups -->
<html data-viewport="tablet">   <!-- 768x1024 for tablet layouts -->
<html data-viewport="terminal"> <!-- 600x400 for CLI output -->

Choose based on what the UI represents:
- Most web app screens -> "wide" (default, no attribute needed)
- Settings dialogs/modals -> "desktop"
- Mobile app screens -> "mobile"
- CLI output -> "terminal"

=== FRAMEWORK-SPECIFIC TEMPLATE CONVERSION ===
When copying HTML from project templates, convert framework syntax to static HTML:

ERB (Ruby on Rails):
- <%= content %> -> Replace with realistic placeholder text
- <% if condition %> -> Include the content (pick the most common branch)
- <%= link_to "Text", path %> -> <a href="#">Text</a>
- <%= button_to "Text", path %> -> <button type="button">Text</button>
- <%= form_with ... %> -> <form>...</form>
- <%= render partial: "..." %> -> Find and inline the partial content
- class="<%= dynamic_class %>" -> Use realistic static classes

JSX/TSX (React/Next.js):
- {variable} -> Replace with placeholder text matching variable name
- {user.name} -> "John Smith"
- {items.length} -> "5"
- className={styles.foo} -> class="foo"
- className={cn("base", condition && "extra")} -> class="base extra"
- {condition && <Element>} -> Include the element
- {items.map(item => <Item />)} -> Show 2-3 example items
- <Component prop="val" /> -> Expand to actual HTML from component file

Vue SFC:
- {{ variable }} -> Replace with placeholder text
- v-if, v-show -> Include content (pick most common branch)
- v-for="item in items" -> Show 2-3 example iterations
- :class="[base, conditional]" -> Include all classes
- :class="{ active: isActive }" -> Include the class
- @click, v-on:* -> Remove (not needed for static mockup)
- <slot /> -> Include realistic slot content

Svelte:
- {variable} -> Replace with placeholder text
- {#if condition}...{:else}...{/if} -> Include primary branch
- {#each items as item}...{/each} -> Show 2-3 examples
- class:active={condition} -> Include the class

Angular:
- {{ variable }} -> Replace with placeholder text
- *ngIf -> Include the content
- *ngFor -> Show 2-3 examples
- [class.active]="condition" -> Include the class
- (click) -> Remove

CRITICAL: The goal is VISUAL FIDELITY. Include ALL styling classes from every element.
If you see class="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600"
You MUST include EVERY class, not just some of them.

CRITICAL: Do NOT replace icons with emojis. If you see <i class="fas fa-camera">, do NOT replace it with 📷.
Icons must be rendered using the proper icon library CSS/JS (see ICON LIBRARIES section below).

=== APPROACH A: CSS EMBEDDING (PREFERRED) ===
Use this when /input/compiled_css.txt has content.

This approach produces mockups that look IDENTICAL to the real application because you use:
- The ACTUAL compiled CSS from the project
- REAL class names from the project's view templates
- The exact HTML structure used in the codebase

STEPS:
1. Read the compiled CSS from /input/compiled_css.txt
2. Find relevant view templates in /repo (*.erb, *.jsx, *.vue, *.html, *.tsx, *.svelte)
3. Copy the REAL HTML structure and class names from those templates
4. Convert framework syntax to static HTML (see above)
5. Create mockup HTML that embeds the CSS and uses real classes

Example mockup with embedded CSS:
```html
<!DOCTYPE html>
<html data-viewport="desktop">
<head>
  <style>
/* Paste the ENTIRE compiled CSS content here */
/* This includes all the utility classes, component styles, etc. */
  </style>
  <!-- Include CDN links for icons if project uses them -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
</head>
<body class="bg-gray-100 min-h-screen">
  <!-- Copy REAL HTML structure and classes from the project's templates -->
  <div class="max-w-md mx-auto p-6">
    <div class="bg-white rounded-lg shadow-md p-6">
      <h2 class="text-xl font-semibold text-gray-900 mb-4">Settings</h2>
      <label class="block text-sm font-medium text-gray-700 mb-2">Project Name</label>
      <input type="text" value="My Project" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500">
      <button class="mt-4 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
        Save Changes
      </button>
    </div>
  </div>
</body>
</html>
```

CRITICAL FOR CSS EMBEDDING:
- Embed the ENTIRE compiled CSS in the <style> tag - do not skip any of it
- Use the EXACT class names you find in the project's view templates
- COPY ALL CLASSES FROM EACH ELEMENT - missing classes break styling
- Look at actual components in /repo to see how they structure HTML
- The mockup should be indistinguishable from a screenshot of the real app

=== CSS FRAMEWORK-SPECIFIC NOTES ===

For BOOTSTRAP projects:
- Include Bootstrap CDN if detected: <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
- Use Bootstrap classes: btn, btn-primary, form-control, card, container, row, col-*

For BULMA projects:
- Include Bulma CDN if detected: <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
- Use Bulma classes: button, is-primary, input, card, columns, column

For TAILWIND projects:
- The compiled CSS contains all utility classes - embed it fully
- Copy exact class combinations from templates

For MATERIAL UI projects:
- Generate CSS that mimics MUI default styling
- Use similar color scheme (blue primary, etc.)

For CHAKRA UI projects:
- Generate CSS that mimics Chakra default styling
- Use their default blue color palette

=== APPROACH B: INLINE STYLES (FALLBACK) ===
Use this when /input/compiled_css.txt is empty. Read /input/style_context.json for values.

Create HTML with inline styles on every element using the extracted values:
```html
<!DOCTYPE html>
<html data-viewport="desktop">
<head>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
</head>
<body style="font-family: -apple-system, sans-serif; background-color: #f8fafc; padding: 24px;">
  <div style="background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
    <label style="font-size: 14px; font-weight: 500; color: #374151; display: block; margin-bottom: 6px;">Project Name</label>
    <input type="text" value="My Project" style="width: 100%; padding: 10px; border: 1px solid #d1d5db; border-radius: 6px;">
    <button style="background: #4f46e5; color: white; padding: 10px 20px; border: none; border-radius: 6px; margin-top: 16px; cursor: pointer;">Save</button>
  </div>
</body>
</html>
```

=== FOR CLI/TERMINAL TOOLS ===
Use terminal styling with terminal viewport:
```html
<!DOCTYPE html>
<html data-viewport="terminal">
<head>
  <style>
    body { margin: 0; padding: 24px; background: #f8fafc; }
    .terminal { background: #1e1e1e; border-radius: 8px; overflow: hidden; font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace; font-size: 13px; max-width: 600px; }
    .terminal-header { background: #323232; padding: 8px 12px; display: flex; align-items: center; gap: 8px; }
    .dot { width: 12px; height: 12px; border-radius: 50%; }
    .red { background: #ff5f56; }
    .yellow { background: #ffbd2e; }
    .green { background: #27ca40; }
    .terminal-body { padding: 16px; color: #d4d4d4; line-height: 1.6; }
    .prompt { color: #6a9955; }
    .command { color: #dcdcaa; }
    .flag { color: #9cdcfe; }
    .output { color: #d4d4d4; }
    .success { color: #4ec9b0; }
    .error { color: #f14c4c; }
    .path { color: #ce9178; }
  </style>
</head>
<body>
  <div class="terminal">
    <div class="terminal-header">
      <span class="dot red"></span>
      <span class="dot yellow"></span>
      <span class="dot green"></span>
    </div>
    <div class="terminal-body">
      <div><span class="prompt">$</span> <span class="command">mycommand</span> <span class="flag">--flag</span> value</div>
      <div class="output">Processing...</div>
      <div class="success">Done!</div>
    </div>
  </div>
</body>
</html>
```

=== FOR TUI (Text User Interface) APPLICATIONS ===

If style_context.json shows app_type: "tui", create mockups that accurately replicate the TUI framework's appearance.

Use viewport: <html data-viewport="tui">

Check tui_context.framework to determine the specific TUI framework and adapt styling accordingly:

TEXTUAL (Python):
- Modern look with rounded corners, subtle gradients
- Uses CSS-like styling (.tcss files)
- Common components: DataTable, ListView, Button, Input, Footer, Header
- Default colors: Dark background, bright accents

BUBBLETEA/LIPGLOSS (Go):
- Bold, vibrant colors (often pink/purple accents like #ff69b4, #7e57c2)
- Clean borders, modern aesthetic
- Common patterns: List with selection indicator, viewport scrolling, help text footer
- Charm branding style

RATATUI (Rust):
- Heavy use of Unicode box-drawing characters (─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼)
- Split panes, tabs, status bars
- Often uses terminal default colors
- Block-style widgets

INK (Node.js):
- React-like component structure
- Colorful output, often with emoji support
- Flexbox-like layouts
- Interactive prompts and spinners

Base TUI template:
```html
<!DOCTYPE html>
<html data-viewport="tui">
<head>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&display=swap');
    body { margin: 0; padding: 16px; background: #0d1117; min-height: 100vh; }
    .tui-app {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 6px;
      font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Monaco, monospace;
      font-size: 13px;
      line-height: 1.5;
      color: #c9d1d9;
      overflow: hidden;
      max-width: 700px;
    }
    .tui-header {
      background: #21262d;
      padding: 8px 16px;
      border-bottom: 1px solid #30363d;
      font-weight: 600;
      color: #f0f6fc;
    }
    .tui-content { padding: 16px; }
    .tui-footer {
      background: #21262d;
      padding: 6px 16px;
      border-top: 1px solid #30363d;
      font-size: 12px;
      color: #8b949e;
    }
    /* Selection highlighting */
    .tui-selected {
      background: #388bfd33;
      border-left: 2px solid #388bfd;
      padding-left: 14px;
    }
    .tui-item { padding: 4px 16px; }
    /* Keybinding hints */
    .tui-key {
      background: #30363d;
      padding: 2px 6px;
      border-radius: 3px;
      font-size: 11px;
      margin-right: 8px;
      color: #c9d1d9;
    }
    .tui-key-label { color: #8b949e; margin-right: 16px; }
    /* Box drawing for ratatui-style borders */
    .tui-box {
      border: 1px solid #30363d;
      border-radius: 4px;
      margin: 8px 0;
    }
    .tui-box-title {
      background: #21262d;
      padding: 4px 12px;
      border-bottom: 1px solid #30363d;
      font-weight: 500;
    }
    .tui-box-content { padding: 12px; }
    /* Status indicators */
    .tui-success { color: #3fb950; }
    .tui-error { color: #f85149; }
    .tui-warning { color: #d29922; }
    .tui-info { color: #58a6ff; }
    /* Progress bar */
    .tui-progress {
      background: #21262d;
      border-radius: 4px;
      height: 8px;
      overflow: hidden;
    }
    .tui-progress-bar {
      background: #388bfd;
      height: 100%;
      transition: width 0.3s;
    }
  </style>
</head>
<body>
  <div class="tui-app">
    <div class="tui-header">Application Title</div>
    <div class="tui-content">
      <div class="tui-item tui-selected">Selected item</div>
      <div class="tui-item">Another item</div>
      <div class="tui-item">Third item</div>
    </div>
    <div class="tui-footer">
      <span class="tui-key">↑↓</span><span class="tui-key-label">Navigate</span>
      <span class="tui-key">Enter</span><span class="tui-key-label">Select</span>
      <span class="tui-key">q</span><span class="tui-key-label">Quit</span>
    </div>
  </div>
</body>
</html>
```

IMPORTANT FOR TUI MOCKUPS:
- Always use monospace fonts exclusively
- Include keyboard shortcut hints in footer
- Show selection state for interactive elements (highlighted row, cursor position)
- Use the tui_context.colors if custom theme was detected
- Match the specific framework's visual style when known

=== ICON LIBRARIES ===

CRITICAL: Do NOT replace icon elements with emojis. Icons must render using the proper icon library.

STEP: Detect which icon library the project uses by searching for:
- Heroicons: Look for imports from "@heroicons/react" or "heroicons" in package.json, or SVG icons with heroicon class names
- Bootstrap Icons: Look for "bootstrap-icons" in package.json or classes like "bi bi-*"
- FontAwesome: Look for "@fortawesome" in package.json or classes like "fa fa-*", "fas fa-*", "far fa-*"
- Lucide: Look for "lucide-react" or "lucide" in package.json
- Tabler Icons: Look for "@tabler/icons" in package.json
- Material Icons: Look for "material-icons" class or "@mui/icons-material"
- Phosphor Icons: Look for "phosphor-react" or "@phosphor-icons"

Include the appropriate CDN in your mockup HTML <head>:

```html
<!-- FontAwesome -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">

<!-- Bootstrap Icons -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">

<!-- Material Icons -->
<link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">

<!-- Heroicons (use inline SVG - no CDN, copy SVGs from https://heroicons.com) -->

<!-- Lucide (use inline SVG or) -->
<script src="https://unpkg.com/lucide@latest"></script>
<script>lucide.createIcons();</script>

<!-- Tabler Icons -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css">
```

ICON USAGE EXAMPLES:
- FontAwesome: <i class="fas fa-check"></i> or <i class="fa-solid fa-check"></i>
- Bootstrap Icons: <i class="bi bi-check"></i>
- Material Icons: <span class="material-icons">check</span>
- Heroicons: Use inline SVG copied from the project or heroicons.com
- Lucide: <i data-lucide="check"></i> (with lucide.createIcons() call)
- Tabler: <i class="ti ti-check"></i>

If the project uses Heroicons or another SVG-based library without a CDN:
1. Find the actual SVG code in the project's node_modules or components
2. Inline the SVG directly in your HTML mockup
3. Example: <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">...</svg>

=== HANDLING IMAGES IN MOCKUPS ===

For logos, icons, or screenshots from the project:

1. Copy the image to the assets folder:
   cp /repo/public/logo.png /output/mockup_assets/logo.png

2. Reference it with a relative path in your HTML:
   <img src="../mockup_assets/logo.png" alt="Logo">

   (Use ../ because HTML is in /output/html/ and assets are in /output/mockup_assets/)

For icon libraries:
- Use CDN links (FontAwesome is recommended):
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
  <i class="fas fa-check"></i>

IMPORTANT:
- Do NOT use base64 encoding
- Do NOT use absolute file:// URLs
- Use relative paths: ../mockup_assets/filename.png

=== TO RENDER A MOCKUP ===
1. Write complete HTML to: /tmp/mockup_<step_index>.html
2. Run: /render_mockup.sh <step_index> /tmp/mockup_<step_index>.html

The step_index is 0-based (first step is 0, second is 1, etc.).

=== WHEN TO CREATE MOCKUPS ===
IMAGE REQUIREMENTS:
- Minimum: 1 image per article (required except in exceptional circumstances like purely conceptual topics)
- Maximum: 4 images per article (do not exceed this)
- Ideal: 2-3 images for most articles

WHICH STEPS SHOULD HAVE IMAGES:
- Steps involving buttons, forms, dialogs, or settings panels
- Steps showing UI elements the user needs to interact with
- The most important/complex step that benefits from visual guidance
- Steps where users might get confused without seeing the interface

SKIP IMAGES FOR:
- Simple text descriptions or conceptual explanations
- Steps that are obvious or don't involve visual interfaces
- Redundant views (don't show the same screen multiple times)

Generate mockups BEFORE outputting your final JSON response.

OUTPUT FORMAT - Return ONLY a valid JSON object with this exact structure:
{
  "introduction": "1-2 sentences explaining what users will learn in this guide",
  "prerequisites": ["First thing users need before starting", "Second requirement if any"],
  "steps": [
    {"title": "Short step title", "content": "Detailed instructions for this step.", "has_image": true},
    {"title": "Next step title", "content": "Instructions for the next step.", "has_image": false}
  ],
  "tips": ["Helpful tip or best practice", "Another useful tip"],
  "summary": "1-2 sentences summarizing what users learned or suggesting next steps"
}

IMPORTANT: Set "has_image": true for steps where you generated a mockup, false otherwise.

CONTENT GUIDELINES:
- introduction: Brief, engaging intro (1-2 sentences)
- prerequisites: Array of strings. Include 1-3 items, or empty array [] if none needed
- steps: Array of objects with "title", "content", and "has_image". Include 3-7 steps typically
- tips: Array of strings. Include 1-3 helpful tips
- summary: Brief closing (1-2 sentences)

Output ONLY the JSON object. No markdown, no commentary, no explanations - just valid JSON.
PROMPT
CLAUDE_EXIT_STATUS=$?
set -e

echo "Claude exit status: ${CLAUDE_EXIT_STATUS}"

# Check if output file exists and has content
if [ ! -f /tmp/claude_output.json ] || [ ! -s /tmp/claude_output.json ]; then
    echo "ERROR: Claude did not produce output"
    exit 1
fi

echo "Article generation complete!"

# Debug: show the structure of the JSON output
echo "JSON output structure:"
jq 'keys' /tmp/claude_output.json 2>/dev/null || echo "Failed to parse JSON"
echo "Result type:"
jq -r '.result | type' /tmp/claude_output.json 2>/dev/null || echo "No result field"

# Copy raw output for debugging
cp /tmp/claude_output.json /output/claude_raw_output.json

# Show full structure for debugging
echo "Full JSON output:"
cat /tmp/claude_output.json | head -c 5000

# Extract the result content from JSON output
# The result field contains the text output from Claude
jq -r '.result // empty' /tmp/claude_output.json > /output/article.json

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

# Log size for debugging
echo "Article length: $(wc -c < /output/article.json) chars"
echo "Output files:"
ls -la /output/

# List generated images if any
if [ -d /output/images ] && [ "$(ls -A /output/images 2>/dev/null)" ]; then
    echo "Generated images:"
    ls -la /output/images/
fi
