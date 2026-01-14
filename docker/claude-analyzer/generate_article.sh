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
You can generate stylized UI mockup images for steps that involve visual interfaces.

To create a mockup for a step, use Bash to call:
/render_mockup.sh <step_index> '<html_content>'

The step_index is 0-based (first step is 0, second is 1, etc.).
The image will be saved to /output/images/step_<N>.png

Example:
/render_mockup.sh 1 '<div class="mockup-container"><h3 class="mb-4">Settings</h3><div class="mb-4"><label class="label">Email notifications</label><div class="flex items-center gap-2"><input type="checkbox" checked class="checkbox"> <span class="text-sm text-gray">Send me updates</span></div></div><button class="btn btn-primary">Save Changes</button></div>'

Available CSS classes in mockups:
- .mockup-container - White card with shadow (wrap your content in this)
- .btn, .btn-primary, .btn-secondary, .btn-danger, .btn-success - Button styles
- .input - Text input styling
- .label - Form label styling
- .card - Bordered card
- .heading, .subheading - Title styles
- .alert, .alert-info, .alert-success, .alert-warning, .alert-error - Alert boxes
- .badge, .badge-gray, .badge-blue, .badge-green, .badge-red - Status badges
- .avatar, .avatar-lg - User avatar circles
- .tabs, .tab, .tab.active - Tab navigation
- .dropdown, .dropdown-item - Dropdown menus
- .table, th, td - Table styling
- .checkbox, .toggle, .toggle.active - Form controls
- .text-gray, .text-dark, .text-sm, .text-xs, .text-lg - Text utilities
- .font-medium, .font-bold - Font weight
- .mt-1 to .mt-4, .mb-1 to .mb-4, .p-2, .p-4 - Spacing utilities
- .flex, .inline-flex, .items-center, .justify-between, .gap-2, .gap-4, .flex-col - Flexbox

WHEN TO CREATE MOCKUPS:
- Steps that reference clicking buttons, toggles, or UI elements
- Steps showing forms, dialogs, or settings panels
- Steps where a visual would clarify the instruction
- NOT needed for: simple navigation, conceptual explanations, or text-only interactions

Keep mockups simple and stylized - they illustrate the concept, not pixel-perfect screenshots.
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
