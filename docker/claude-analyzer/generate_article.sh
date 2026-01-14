#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token

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

# Check if diff is available
HAS_DIFF="false"
if [ -f /input/diff.patch ] && [ -s /input/diff.patch ]; then
    HAS_DIFF="true"
    echo "Source PR diff available"
fi

# Run Claude Code to generate the article
echo "Running Claude Code article generation..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<'PROMPT' | claude -p --allowedTools "Read,Glob,Grep,Bash" > /output/article_raw.json
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

STEP 2: If a diff file exists, read it to understand the specific code changes:
/input/diff.patch

STEP 3: Explore the full codebase at /repo to understand the feature in detail. Use Glob, Grep, and Read tools to find relevant code, UI components, configuration, and related functionality. This will help you write accurate, specific instructions.

STEP 4: Write a comprehensive how-to guide article as a JSON object.

IMPORTANT GUIDELINES:
- Write for END USERS, not developers
- Use clear, simple language - avoid technical jargon
- Focus on what users can DO, not how it works internally
- Do NOT include code snippets unless absolutely necessary for users
- Do NOT mention internal file names, functions, or architecture

=== UI MOCKUP GENERATION ===
You can generate UI mockup images for steps that involve visual interfaces.
The goal is to show users what they will ACTUALLY see in the real application.

CRITICAL: First determine the application type, then follow ONLY the matching section below.

### DETERMINING APP TYPE
Look at the codebase structure to determine the app type:
- Web app: Has routes, views/templates, CSS/SCSS files, frontend framework (Rails, Django, React, Vue, etc.)
- CLI tool: Has command parsers (argparse, commander, clap), no web UI, outputs to stdout/stderr
- Desktop app: Has Electron, Qt, GTK, native UI framework code

### FOR WEB APPLICATIONS (Rails, React, Vue, Django, Express, etc.)
DO NOT use terminal styling for web apps. Web apps have graphical UIs, not terminal interfaces.

1. Find the project's CSS/styles:
   - Look for: *.css, *.scss, *.sass, tailwind.config.*, styled-components, CSS modules
   - Read the main stylesheet to understand colors, fonts, button styles, form styles

2. Find relevant view templates:
   - Look for the views/components related to the feature you're documenting
   - Note the actual HTML structure, class names, and UI patterns used

3. Generate a COMPLETE HTML document with the project's actual styles:
<!DOCTYPE html>
<html>
<head>
  <style>
    /* Extract and paste the relevant CSS from the project */
    /* Include: colors, fonts, button styles, form inputs, cards, etc. */
  </style>
</head>
<body style="background: #f8fafc; padding: 24px;">
  <!-- Recreate the UI using the project's actual markup patterns -->
  <!-- Use the same class names and structure as the real views -->
</body>
</html>

4. FALLBACK: If you cannot find project styles, use these generic classes:
   .mockup-container, .btn, .btn-primary, .btn-secondary, .input, .label,
   .card, .heading, .alert, .badge, .tabs, .table, .checkbox, .toggle,
   plus utilities: .flex, .items-center, .gap-2, .mt-4, .mb-4, .p-4

### FOR CLI/TERMINAL TOOLS ONLY
ONLY use terminal styling for actual command-line tools - NOT for web apps, NOT for desktop apps.

Use the terminal container format:
<div class="terminal">
  <div class="terminal-header">
    <div class="terminal-dots">
      <span class="terminal-dot red"></span>
      <span class="terminal-dot yellow"></span>
      <span class="terminal-dot green"></span>
    </div>
    Terminal
  </div>
  <div class="terminal-body">
    <div class="terminal-line"><span class="prompt">$</span> command --flag value</div>
    <div class="terminal-line terminal-output">Output from the command</div>
    <div class="terminal-line terminal-success">✓ Success message</div>
    <div class="terminal-line terminal-error">✗ Error message</div>
  </div>
</div>

### FOR DESKTOP APPLICATIONS
Match the look and feel of the desktop framework (Electron, Qt, native, etc.).
Extract styles from the app's theme/styling system and create appropriate mockups.

---

TO RENDER A MOCKUP:
1. Write your HTML to a temp file: /tmp/mockup_<step_index>.html
2. Call: /render_mockup.sh <step_index> --file /tmp/mockup_<step_index>.html

The step_index is 0-based (first step is 0, second is 1, etc.).

WHEN TO CREATE MOCKUPS:
- Steps involving buttons, forms, dialogs, or settings panels
- Steps showing UI elements the user needs to interact with
- NOT needed for: conceptual explanations or simple text descriptions

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

echo "Article generation complete!"

# Move the output to the expected location
mv /output/article_raw.json /output/article.json

# Log size for debugging
echo "Article length: $(wc -c < /output/article.json) chars"
echo "Output files:"
ls -la /output/

# List generated images if any
if [ -d /output/images ] && [ "$(ls -A /output/images 2>/dev/null)" ]; then
    echo "Generated images:"
    ls -la /output/images/
fi
