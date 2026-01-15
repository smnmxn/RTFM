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

# Check for style context (pre-extracted during project analysis)
if [ -f /input/style_context.json ]; then
    echo "Style context found at /input/style_context.json"
else
    echo "WARNING: No style_context.json found - mockups may use default styling"
fi

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

STEP 3: Read the style context to get the EXACT styling used by this project:
/input/style_context.json

This file contains comprehensive style information extracted from the project:
- app_type: "web", "cli", or "desktop"
- framework: The CSS framework (tailwind, bootstrap, none)
- colors: All color values (primary, background, text, borders, etc.)
- fonts: Font families for sans, mono, headings
- typography: Base size, font weights
- spacing: Padding values for buttons, inputs, cards
- borders: Border radius and width values
- shadows: Box shadow values
- buttons: Complete button styles (primary/secondary)
- inputs: Form input styling
- cdn_links: External libraries to include (Google Fonts, FontAwesome, etc.)

YOU MUST USE THESE EXACT VALUES when generating mockups. Do not approximate or guess - use the exact hex codes, font names, and measurements from this file.

STEP 4: Explore the full codebase at /repo to understand the feature in detail. Use Glob, Grep, and Read tools to find relevant code, UI components, configuration, and related functionality. This will help you write accurate, specific instructions.

STEP 5: Write a comprehensive how-to guide article as a JSON object.

IMPORTANT GUIDELINES:
- Write for END USERS, not developers
- Use clear, simple language - avoid technical jargon
- Focus on what users can DO, not how it works internally
- Do NOT include code snippets unless absolutely necessary for users
- Do NOT mention internal file names, functions, or architecture

=== UI MOCKUP GENERATION ===
You can generate UI mockup images for steps that involve visual interfaces.

APPROACH:
1. Read /tmp/style_context.json to get the EXACT colors and fonts for this project
2. Include any cdn_links from the style context in your HTML <head>
3. Generate complete HTML using ONLY the colors and fonts from style_context.json
4. Write to /tmp/mockup_<step_index>.html
5. Call /render_mockup.sh to convert to PNG

CRITICAL - USE EXACT STYLE VALUES:
The /tmp/style_context.json file contains the real colors and fonts extracted from this project.
You MUST use these exact values - do not approximate or use generic defaults.

Example style_context.json:
{
  "colors": {"primary": "#4f46e5", "background": "#f8fafc", "text": "#1f2937", ...},
  "fonts": {"sans": "Inter, -apple-system, sans-serif", ...},
  "cdn_links": ["<link href=\"https://fonts.googleapis.com/...\">"]
}

When creating mockups:
- Use colors.background for body background-color
- Use colors.text for text color
- Use colors.primary for buttons and links
- Use fonts.sans for all text elements
- Include all cdn_links in the HTML <head>

USE INLINE STYLES ON ALL ELEMENTS:
Every visible element MUST have a style attribute with the exact values from style_context.json.
- Set font-family on every text element using the exact font from style_context.json
- Set background-color and color on every element using exact hex values from style_context.json
- NEVER use generic fallback fonts or colors - always use the extracted values
- The mockup MUST look identical to what users see in the real application

DETERMINING APP TYPE:
- Web app: Has routes, views/templates, CSS files, frontend framework
- CLI tool: Has command parsers, no web UI, outputs to stdout/stderr
- Desktop app: Has Electron, Qt, GTK, native UI framework

FOR WEB APPLICATIONS:
Create a complete HTML file with embedded styles that matches the app's visual design.

Example mockup file (note: inline styles on EVERY element):
```html
<!DOCTYPE html>
<html>
<head>
  <!-- Include CDN links if the project uses these libraries -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background-color: #f8fafc; color: #1f2937; padding: 24px; margin: 0;">
  <div style="background-color: #ffffff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
    <label style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 14px; font-weight: 500; color: #374151; margin-bottom: 6px; display: block;">Project Name</label>
    <input type="text" value="My Project" style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; width: 100%; padding: 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 14px; background-color: #ffffff; color: #1f2937;">
    <button style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background-color: #4f46e5; color: #ffffff; padding: 10px 20px; border: none; border-radius: 6px; font-weight: 500; cursor: pointer; margin-top: 16px;"><i class="fa-solid fa-save"></i> Save Changes</button>
  </div>
</body>
</html>
```

IMPORTANT: Use inline styles on every element. Do NOT use CSS classes - the mockup must render correctly without any stylesheet.

FOR CLI/TERMINAL TOOLS:
Use terminal styling with a dark background:

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { margin: 0; padding: 24px; background: #f8fafc; }
    .terminal { background: #1e1e1e; border-radius: 8px; overflow: hidden; font-family: 'SF Mono', Monaco, monospace; font-size: 13px; max-width: 600px; }
    .terminal-header { background: #323232; padding: 8px 12px; display: flex; align-items: center; gap: 8px; }
    .dot { width: 12px; height: 12px; border-radius: 50%; }
    .red { background: #ff5f56; }
    .yellow { background: #ffbd2e; }
    .green { background: #27ca40; }
    .terminal-body { padding: 16px; color: #d4d4d4; line-height: 1.6; }
    .prompt { color: #6a9955; }
    .output { color: #9cdcfe; }
    .success { color: #4ec9b0; }
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
      <div><span class="prompt">$</span> mycommand --flag value</div>
      <div class="output">Processing...</div>
      <div class="success">Done!</div>
    </div>
  </div>
</body>
</html>
```

TO RENDER A MOCKUP:
1. Write complete HTML (with embedded styles) to: /tmp/mockup_<step_index>.html
2. Run: /render_mockup.sh <step_index> /tmp/mockup_<step_index>.html

The step_index is 0-based (first step is 0, second is 1, etc.).

WHEN TO CREATE MOCKUPS:
- Each article MUST have at least one image - choose the most visually relevant step
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
