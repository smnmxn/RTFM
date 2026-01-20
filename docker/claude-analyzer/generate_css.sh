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

cat <<'CSS_PROMPT' | claude -p --output-format json --allowedTools "Read,Glob,Grep" > /tmp/claude_output.json
Analyze this codebase and generate comprehensive CSS for accurate UI mockup rendering.

=== STEP 1: DETECT THE CSS FRAMEWORK ===

Check for these frameworks in order of priority:

A) UTILITY-FIRST FRAMEWORKS (Tailwind CSS, UnoCSS, Windi CSS)
   Detection:
   - tailwind.config.js, tailwind.config.ts
   - uno.config.ts, windi.config.js
   - @tailwind directives in CSS files
   - Utility classes in templates: flex, pt-4, bg-blue-500, text-lg, etc.

   Strategy: Generate CSS rules for ALL utility classes found in templates.
   Scan .erb, .html, .jsx, .tsx, .vue, .svelte files for class attributes.
   For each class like "px-4", generate: .px-4 { padding-left: 1rem; padding-right: 1rem; }

B) COMPONENT FRAMEWORKS (Bootstrap, Bulma, Foundation)
   Detection:
   - package.json: "bootstrap", "bulma", "foundation-sites"
   - CDN links: cdn.jsdelivr.net/npm/bootstrap, cdnjs.cloudflare.com/ajax/libs/bulma
   - Class patterns: .btn, .container, .row, .col- (Bootstrap)
   - Class patterns: .button, .columns, .column (Bulma)

   Strategy: Include the CDN @import URL AND generate common component CSS as fallback.

   Bootstrap CDN:
   @import url('https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css');

   Bulma CDN:
   @import url('https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css');

   Foundation CDN:
   @import url('https://cdn.jsdelivr.net/npm/foundation-sites@6.8.1/dist/css/foundation.min.css');

C) REACT COMPONENT LIBRARIES (Material UI, Chakra UI, Ant Design, shadcn/ui)
   Detection:
   - package.json: "@mui/material", "@chakra-ui/react", "antd"
   - Import patterns in .tsx/.jsx files
   - components/ui/*.tsx with cn() function (shadcn)

   Strategy: Generate CSS that mimics the library's default theme appearance.

   For Material UI: Generate CSS for .MuiButton-root, .MuiTextField-root, etc.
   For Chakra: Generate CSS using their default blue color scheme
   For Ant Design: Generate CSS for .ant-btn, .ant-input, etc.
   For shadcn/ui: Copy the EXACT class names from components/ui/*.tsx files

D) CSS-IN-JS (styled-components, Emotion)
   Detection:
   - package.json: "styled-components", "@emotion/react", "@emotion/styled"
   - Import patterns: import styled from 'styled-components'
   - css`` template literals

   Strategy: Find style objects/template literals and convert to CSS classes.

E) TRADITIONAL CSS/SCSS/SASS/LESS
   Detection:
   - .css, .scss, .sass, .less files in the project
   - No CSS framework detected

   Strategy: Copy relevant styles directly from source files.

F) NO CSS FRAMEWORK
   Detection:
   - No CSS dependencies in package.json/Gemfile
   - Only inline styles used

   Strategy: Generate sensible defaults based on inline styles found.

=== STEP 2: FIND WEB FONTS ===

Search these locations:
- Layout templates: application.html.erb, _document.tsx, index.html, app.html, layout.html
- CSS files: @import or @font-face declarations
- CDN links: fonts.googleapis.com, fonts.bunny.net, use.typekit.net

Common fonts to look for: Inter, Roboto, Open Sans, Lato, Poppins, Montserrat, Source Sans Pro

=== STEP 3: SCAN ALL TEMPLATES FOR CLASSES ===

CRITICAL: Scan ALL template files and extract EVERY class name used:
- .erb files (Rails)
- .html files
- .jsx/.tsx files (React)
- .vue files (Vue)
- .svelte files (Svelte)

For EACH class found, generate the corresponding CSS rule.

Example: If you find class="flex items-center justify-between px-4 py-2 bg-white rounded-lg shadow-md"

Generate:
.flex { display: flex; }
.items-center { align-items: center; }
.justify-between { justify-content: space-between; }
.px-4 { padding-left: 1rem; padding-right: 1rem; }
.py-2 { padding-top: 0.5rem; padding-bottom: 0.5rem; }
.bg-white { background-color: #ffffff; }
.rounded-lg { border-radius: 0.5rem; }
.shadow-md { box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); }

=== STEP 4: GENERATE COMPLETE CSS ===

OUTPUT FORMAT - Valid CSS only, no markdown, no explanations:

1. @import statements FIRST (fonts and CDN frameworks):
   @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
   @import url('https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css');

2. CSS Reset/Base styles:
   *, *::before, *::after { box-sizing: border-box; }
   html { font-family: 'Inter', system-ui, -apple-system, sans-serif; }
   body { margin: 0; line-height: 1.5; }

3. Framework-specific utility classes (if Tailwind/utility-first)

4. Component styles (buttons, inputs, cards, etc.)

5. Layout utilities (flexbox, grid)

6. Color utilities (text colors, backgrounds, borders)

7. Spacing utilities (padding, margin)

8. Typography utilities (font sizes, weights)

=== IMPORTANT RULES ===

- @import statements MUST be at the very top (CSS requirement)
- Generate CSS for EVERY class found in templates
- Use actual values from tailwind.config.js or theme files if present
- Include hover states: .hover\:bg-blue-700:hover { background-color: #1d4ed8; }
- Include focus states: .focus\:ring-2:focus { box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5); }
- Include responsive prefixes if found: .md\:flex { display: flex; } at appropriate breakpoint
- Output ONLY valid CSS - no markdown code fences, no comments, no explanations
CSS_PROMPT

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_output.json > /output/compiled_css.txt

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

CSS_SIZE=$(wc -c < /output/compiled_css.txt 2>/dev/null || echo "0")
echo "Generated CSS: ${CSS_SIZE} bytes"

# Validate the CSS output starts correctly (basic check)
if head -1 /output/compiled_css.txt | grep -q "^\`\`\`"; then
    echo "Warning: CSS output contains markdown - attempting to clean"
    # Remove markdown code fences if present
    sed -i 's/^```css//; s/^```//' /output/compiled_css.txt
fi

echo "CSS generation complete!"
