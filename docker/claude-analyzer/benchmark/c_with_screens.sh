#!/bin/bash
set -e

# Approach C: Pre-extract screen library, then generate article
# Phase 1: Claude extracts every significant screen as static HTML with real CSS
# Phase 2: Claude writes the article, picking screens from the library and customizing them
# Tests whether upfront screen extraction speeds up per-article generation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_shared.sh"

ARTICLE_TOPIC="${1:?Usage: c_with_screens.sh \"Article topic e.g. How to reset your password\"}"

setup_output_dir "c"
SCREENS_DIR="$OUTPUT_DIR/screens"
mkdir -p "$SCREENS_DIR"

echo "=== Approach C: Screen Library → Article ==="
echo "Topic: $ARTICLE_TOPIC"
echo "Repo: $REPO_DIR"
echo ""

# ─── Phase 1: Extract Screen Library ─────────────────────────────────────────

echo "Phase 1: Extracting screen library..."
start_timer

cat <<PROMPT | run_claude_streaming "$OUTPUT_DIR/screens_raw.json" --max-turns 30 --allowedTools "Read,Glob,Grep,Bash,Write"
Analyze this codebase and extract a library of UI screens as static HTML files.

STEP 1: Identify the CSS setup:
- Find CSS/SCSS files, Tailwind config, CDN links, font imports
- Read the actual CSS content so you can embed it in mockups

STEP 2: Find ALL significant user-facing screens by examining:
- Route definitions (routes.rb, router files, page directories)
- View templates (.erb, .jsx, .tsx, .vue, .svelte, .html)
- Layout files (application layout, nav, sidebar, footer)

STEP 3: For each screen, create a complete static HTML file:
- Copy the REAL HTML structure and class names from the template files
- Inline any partials/components (resolve includes, partials, component imports)
- Convert framework syntax to static HTML:
  - ERB: <%= variable %> → realistic placeholder text
  - JSX: {variable} → placeholder, map() → 2-3 example items
  - Vue: {{ variable }} → placeholder, v-for → 2-3 items
- Embed the project's actual CSS in a <style> tag
- Include CDN links for fonts and icon libraries
- Fill in realistic placeholder data (user names, emails, sample content)
- Each file must be a complete standalone HTML document

STEP 4: Write each screen to ${SCREENS_DIR}/<name>.html using descriptive names:
- dashboard.html, settings.html, login.html, user_profile.html, etc.
- Use snake_case names that describe the page

STEP 5: Write a manifest file to ${SCREENS_DIR}/manifest.json:
{
  "screens": [
    {
      "name": "settings",
      "file": "settings.html",
      "description": "User settings/preferences page",
      "route": "/settings",
      "key_elements": ["profile form", "password change", "notification toggles"]
    }
  ]
}

Extract ALL significant screens — aim for completeness. Include:
- Authentication screens (login, signup, forgot password)
- Main dashboard/home
- Settings/profile pages
- Key feature pages
- Forms, modals, and dialogs (as separate files)

Your final output must be ONLY the manifest JSON object.
PROMPT

record_phase "screen_extraction"

# Extract manifest
extract_result "$OUTPUT_DIR/screens_raw.json" "$SCREENS_DIR/manifest.json"

# Count screens
SCREEN_COUNT=$(ls "$SCREENS_DIR"/*.html 2>/dev/null | wc -l | tr -d ' ' || echo "0")
echo "  Extracted $SCREEN_COUNT screen(s)"

if [ -f "$SCREENS_DIR/manifest.json" ]; then
    echo "  Manifest:"
    jq -r '.screens[]? | "    - \(.name): \(.description)"' "$SCREENS_DIR/manifest.json" 2>/dev/null || true
fi

# ─── Phase 2: Article Generation from Screen Library ─────────────────────────

echo ""
echo "Phase 2: Generating article from screen library..."
start_timer

# Build screen list for the prompt
SCREEN_LIST=""
if [ -f "$SCREENS_DIR/manifest.json" ]; then
    SCREEN_LIST=$(jq -r '.screens[]? | "- \(.name) (\(.file)): \(.description). Elements: \(.key_elements | join(", "))"' "$SCREENS_DIR/manifest.json" 2>/dev/null || echo "No screens available")
fi

cat <<PROMPT | run_claude_streaming "$OUTPUT_DIR/article_raw.json" --max-turns 15 --allowedTools "Read,Write"
You are a technical writer creating a help article for end users.

ARTICLE TOPIC: ${ARTICLE_TOPIC}

You have a library of pre-extracted UI screens available. Use these for mockups instead of
exploring the codebase yourself.

AVAILABLE SCREENS:
${SCREEN_LIST}

Screen files are at: ${SCREENS_DIR}/

STEP 1: Write a help article as JSON:
{
  "introduction": "1-2 sentences explaining what users will learn",
  "prerequisites": ["Things users need before starting"],
  "steps": [
    {"title": "Step title", "content": "Detailed instructions", "has_image": true},
    {"title": "Next step", "content": "More instructions", "has_image": false}
  ],
  "tips": ["Helpful tips"],
  "summary": "1-2 sentence wrap-up"
}

STEP 2: For each step that needs an image:
1. Read the most relevant screen file from ${SCREENS_DIR}/
2. Customize it for this specific step:
   - Adjust placeholder data to match the article context
   - Show the relevant state (e.g., form filled in, error message visible, success state)
   - You can modify the HTML to show a specific UI state, but keep all the original CSS classes
3. Write the customized HTML to ${OUTPUT_DIR}/html/step_N.html (N is 0-based)

IMPORTANT:
- Write for END USERS, not developers
- Use clear, simple language
- Do NOT explore the codebase — use only the pre-extracted screens
- Generate 1-4 mockup images total
- Allowed tools are Read (to read screens) and Write (to write mockups + output)

Your final output must be ONLY the JSON article object.
PROMPT

record_phase "article_generation"

# Extract article content
extract_result "$OUTPUT_DIR/article_raw.json" "$OUTPUT_DIR/article.json"

start_timer

render_mockups

record_phase "mockup_rendering"

finalize_timing

echo ""
echo "Article: $OUTPUT_DIR/article.json"
echo "Screens: $SCREENS_DIR/ ($SCREEN_COUNT screens)"
echo "Images:  $OUTPUT_DIR/images/"
echo "HTML:    $OUTPUT_DIR/html/"
