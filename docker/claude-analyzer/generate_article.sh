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

STEP 3: Check for compiled CSS (preferred) and style context (fallback):
- /input/compiled_css.txt - The actual compiled CSS from the project (if available)
- /input/style_context.json - Extracted style values as fallback

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
