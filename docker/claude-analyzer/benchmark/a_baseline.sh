#!/bin/bash
set -e

# Approach A: Baseline — single prompt, no pre-work
# Claude explores the codebase, writes the article, AND generates mockups all in one go.
# This is the simplest approach. It measures the "floor" — how good is a single prompt?

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_shared.sh"

ARTICLE_TOPIC="${1:?Usage: a_baseline.sh \"Article topic e.g. How to reset your password\"}"

setup_output_dir "a"

echo "=== Approach A: Baseline (single prompt) ==="
echo "Topic: $ARTICLE_TOPIC"
echo "Repo: $REPO_DIR"
echo ""

start_timer

cat <<PROMPT | run_claude_streaming "$OUTPUT_DIR/article_raw.json" --max-turns 30 --allowedTools "Read,Glob,Grep,Bash,Write"
You are a technical writer creating a help article for end users of this software project.

ARTICLE TOPIC: ${ARTICLE_TOPIC}

STEP 1: Explore the codebase to understand this feature. Look at:
- Routes, controllers, views related to this topic
- UI templates (.erb, .jsx, .tsx, .vue, .svelte, .html files)
- CSS/styling (tailwind config, stylesheets, component styles)
- Any relevant models, services, or configuration

STEP 2: Write a help article as JSON:
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

STEP 3: For each step where has_image is true, generate an HTML mockup.

For mockups:
- Find the REAL template/component files for this screen in the codebase
- Copy the actual HTML structure and CSS classes from those files
- Convert any framework syntax (JSX, ERB, Vue, etc.) to static HTML
- If the project uses Tailwind, find the tailwind.config.js and include relevant styles
- If CSS files exist, embed them in a <style> tag
- Fill in realistic placeholder data relevant to the article topic
- Include CDN links for any icon libraries the project uses (FontAwesome, etc.)

Write each mockup to: ${OUTPUT_DIR}/html/step_N.html (where N is 0-based step index)

IMPORTANT:
- Write for END USERS, not developers
- Use clear, simple language
- Focus on what users DO, not how it works internally
- Generate 1-4 mockup images total
- Each mockup should be a complete standalone HTML file

Your final output must be ONLY the JSON article object.
PROMPT

record_phase "article_generation"

# Extract article content
extract_result "$OUTPUT_DIR/article_raw.json" "$OUTPUT_DIR/article.json"

start_timer

# Render any mockups that were written
render_mockups

record_phase "mockup_rendering"

finalize_timing

echo ""
echo "Article: $OUTPUT_DIR/article.json"
echo "Images:  $OUTPUT_DIR/images/"
echo "HTML:    $OUTPUT_DIR/html/"
