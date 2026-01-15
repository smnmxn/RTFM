#!/bin/bash
set -e

# Required environment variables:
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token
# - ANTHROPIC_API_KEY: Anthropic API key

echo "Starting CSS generation..."
echo "Repository: ${GITHUB_REPO}"

# Clone the repository
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

echo "Analyzing codebase and generating CSS..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<'CSS_PROMPT' | claude -p --allowedTools "Read,Glob,Grep" > /output/compiled_css.txt
Analyze this codebase and generate the CSS needed to render accurate UI mockups.

STEP 1: Find web fonts used by this project:
- Look in layout templates (application.html.erb, _document.tsx, index.html, app.html, etc.)
- Search for Google Fonts links: <link href="https://fonts.googleapis.com/...">
- Search for other font CDNs (Adobe Fonts, Bunny Fonts, fonts.bunny.net, etc.)
- Check CSS files for @import or @font-face declarations
- Note which font families are used (Inter, Roboto, Open Sans, etc.)

STEP 2: Explore how this project handles styling:
- Look for CSS framework configs (tailwind.config.js, postcss.config.js, etc.)
- Check package.json or Gemfile for CSS-related dependencies
- Find existing CSS/SCSS/SASS files
- Examine view templates to see how styles are applied

STEP 3: Based on what you find, generate CSS that will make mockups look like the real app:
- If utility classes are used (Tailwind, etc.): Generate CSS rules for the classes found in templates
- If component CSS exists: Extract and include relevant styles
- If custom CSS files exist: Include the key styles (colors, typography, buttons, forms, layout)
- Use any theme/config values you find (custom colors, fonts, spacing)

STEP 4: Focus on styles that matter for UI mockups:
- Colors (backgrounds, text, borders)
- Typography (fonts, sizes, weights)
- Spacing (padding, margins)
- Layout (flexbox, grid basics)
- Components (buttons, inputs, cards)

OUTPUT FORMAT - Your output must be valid CSS only:

1. START with @import statements for any web fonts found:
   @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

2. THEN include base styles:
   *, *::before, *::after { box-sizing: border-box; }
   html { font-family: 'Inter', system-ui, -apple-system, sans-serif; }
   body { margin: 0; line-height: 1.5; }

3. THEN include all other CSS rules

IMPORTANT:
- @import statements MUST be at the very top of the CSS (before any other rules)
- Use the actual font family names found in the project
- No markdown code fences, no explanations, no comments - just valid CSS
CSS_PROMPT

CSS_SIZE=$(wc -c < /output/compiled_css.txt 2>/dev/null || echo "0")
echo "Generated CSS: ${CSS_SIZE} bytes"
echo "CSS generation complete!"
