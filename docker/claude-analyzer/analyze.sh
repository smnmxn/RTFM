#!/bin/bash
set -e

# Required environment variables:
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code

echo "Starting codebase analysis..."
echo "Repository: ${GITHUB_REPO}"

# Clone the repository (x-access-token format works for both OAuth and GitHub App tokens)
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

# Get the current commit SHA
COMMIT_SHA=$(git rev-parse HEAD)
echo "Commit SHA: ${COMMIT_SHA}"
echo "${COMMIT_SHA}" > /output/commit_sha.txt

# Run Claude Code to analyze the codebase
echo "Running Claude Code analysis..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<'PROMPT' | claude -p --allowedTools "Read,Glob,Grep,Bash" > /output/analysis_raw.txt
Analyze this codebase and provide:

1. FIRST, output a CLAUDE.md-style project summary in markdown format including:
   - Project overview (what it does)
   - Tech stack
   - Architecture overview
   - Key directories and their purposes
   - Important files
   - Development patterns used

2. THEN, output the delimiter: ---JSON_METADATA---

3. Output a JSON object (valid JSON only, no markdown) with this structure:
{
  "tech_stack": ["language", "framework", ...],
  "components": [
    {"name": "Component Name", "description": "What it does", "files": ["path/to/file.rb"]}
  ],
  "entrypoints": ["main entry files"],
  "test_framework": "framework name or null",
  "package_manager": "npm/bundler/pip/etc",
  "key_patterns": ["MVC", "Service Objects", etc]
}

4. THEN, output the delimiter: ---PROJECT_OVERVIEW---

5. Output a 2-3 sentence overview describing what this project does for END USERS (not developers). Focus on the user-facing functionality and value proposition. Do not mention technical implementation details like frameworks, databases, or architecture. Write it as if explaining to a non-technical person what the software helps them accomplish.

6. THEN, output the delimiter: ---TARGET_USERS---

7. Output a JSON array identifying the TARGET END USERS of this software.
IMPORTANT: End users are people who USE the software, NOT developers who BUILD or maintain it.

Think about:
- Who would pay for or use this product?
- What roles or job titles would they have?
- What are they trying to accomplish?

Format (valid JSON only, no markdown):
[
  {
    "persona": "Short label (e.g., 'Marketing Manager', 'Small Business Owner', 'Content Creator')",
    "description": "Brief description of how they use the software",
    "jobs_to_be_done": ["Primary task they accomplish", "Secondary task", "etc"]
  }
]

Identify 1-3 distinct user personas. If this appears to be a developer tool (CLI, library, framework), the end users are still the DEVELOPERS WHO USE IT, not contributors to the project.

8. THEN, output the delimiter: ---CONTEXTUAL_QUESTIONS---

9. Based on your analysis, generate 2-3 contextual questions to ask the user about their documentation needs. These questions should:
   - Reference specific components, features, or technologies you found in the codebase
   - Help prioritize which areas to document first
   - Identify user pain points that code analysis can't reveal

Output valid JSON only (no markdown):
{
  "questions": [
    {
      "id": "q1",
      "type": "prioritization",
      "question": "We found [specific components] - which do your users interact with most?",
      "context": "Brief explanation of why we're asking (10-15 words)",
      "options": [
        {"value": "key1", "label": "Component/feature name"}
      ],
      "multi_select": true
    },
    {
      "id": "q2",
      "type": "gap_filling",
      "question": "What aspects of [feature] confuse users most?",
      "context": "Help us focus documentation on pain points",
      "options": [
        {"value": "setup", "label": "Initial setup"},
        {"value": "advanced", "label": "Advanced features"},
        {"value": "integration", "label": "Integrations"}
      ],
      "multi_select": true
    }
  ]
}

Types: "prioritization" (which to focus on) or "gap_filling" (what's confusing/missing)
Make questions SPECIFIC to this codebase - reference actual components, APIs, or features you found.

Be thorough but concise. Focus on what would help someone understand this codebase quickly.
PROMPT

# Parse the output into separate files
echo "Parsing analysis output..."

# Extract summary (everything before ---JSON_METADATA---)
sed -n '1,/---JSON_METADATA---/p' /output/analysis_raw.txt | sed '$d' > /output/summary.md

# Extract JSON (between ---JSON_METADATA--- and ---PROJECT_OVERVIEW---)
sed -n '/---JSON_METADATA---/,/---PROJECT_OVERVIEW---/p' /output/analysis_raw.txt | sed '1d;$d' > /output/metadata.json

# Extract project overview (between ---PROJECT_OVERVIEW--- and ---TARGET_USERS---)
sed -n '/---PROJECT_OVERVIEW---/,/---TARGET_USERS---/p' /output/analysis_raw.txt | sed '1d;$d' > /output/overview.txt

# Extract target users (between ---TARGET_USERS--- and ---CONTEXTUAL_QUESTIONS---)
sed -n '/---TARGET_USERS---/,/---CONTEXTUAL_QUESTIONS---/p' /output/analysis_raw.txt | sed '1d;$d' > /output/target_users.json

# Extract contextual questions (everything after ---CONTEXTUAL_QUESTIONS---)
sed -n '/---CONTEXTUAL_QUESTIONS---/,$p' /output/analysis_raw.txt | tail -n +2 > /output/contextual_questions.json

echo "Main analysis complete!"

# Extract style context for UI mockup generation
echo "Extracting style context..."

cat <<'STYLE_PROMPT' | claude -p --allowedTools "Read,Glob,Grep" > /output/style_context.json
Analyze this codebase and extract a comprehensive visual style context for generating accurate UI mockups.

STEP 1: Determine the application type:
- "web": Has routes, views/templates, CSS files, web framework (Rails, React, Vue, Django, etc.)
- "cli": Has command parsers (argparse, commander, clap), outputs to stdout, no web UI
- "desktop": Has Electron, Qt, GTK, Tauri, or native UI framework

STEP 2: Extract styling information based on app type.

FOR WEB APPS, examine these sources:
- tailwind.config.js - theme colors, fonts, spacing, border radius
- CSS files - :root variables, component classes
- SCSS/SASS files - variables, mixins
- Layout templates - CDN links (Google Fonts, FontAwesome, Bootstrap)
- Component files - actual button, input, card implementations

Extract:
1. COLORS: Find actual hex values for primary buttons, backgrounds, text, borders, links, success/error states
2. FONTS: Font families from CSS or Google Fonts, including weights used
3. TYPOGRAPHY: Base font size, heading weights
4. SPACING: Button padding, input padding, card padding (look at actual components)
5. BORDERS: Border radius values used on buttons, inputs, cards (look for rounded-*, border-radius)
6. SHADOWS: Box shadows used on cards, dropdowns
7. BUTTONS: Full button styles including background, color, border, radius, padding
8. INPUTS: Input field styles including background, border, radius, padding, focus states
9. CDN LINKS: Any external stylesheets or fonts to include

FOR CLI APPS:
- Set app_type to "cli"
- Use standard terminal styling:
  - Dark background (#1e1e1e)
  - Light text (#d4d4d4)
  - Green for success (#4ec9b0)
  - Red for errors (#f14c4c)
  - Monospace font

FOR DESKTOP APPS:
- Identify the UI framework (Electron, Qt, GTK, etc.)
- Extract theme colors if available
- Note any custom styling

STEP 3: Output a JSON object matching this structure exactly:
{
  "app_type": "web|cli|desktop",
  "framework": "tailwind|bootstrap|none",
  "colors": {
    "primary": "#hex",
    "primary_hover": "#hex",
    "primary_text": "#hex",
    "secondary": "#hex",
    "background": "#hex",
    "surface": "#hex",
    "text": "#hex",
    "text_muted": "#hex",
    "border": "#hex",
    "input_border": "#hex",
    "input_focus": "#hex",
    "link": "#hex",
    "link_hover": "#hex",
    "success": "#hex",
    "error": "#hex",
    "warning": "#hex"
  },
  "fonts": {
    "sans": "Font, fallbacks",
    "mono": "Mono Font, fallbacks",
    "heading": "Heading Font, fallbacks"
  },
  "typography": {
    "base_size": "16px",
    "heading_weight": "600",
    "body_weight": "400"
  },
  "spacing": {
    "button_padding": "Xpx Ypx",
    "input_padding": "Xpx Ypx",
    "card_padding": "Xpx",
    "container_padding": "Xpx"
  },
  "borders": {
    "radius_sm": "Xpx",
    "radius_md": "Xpx",
    "radius_lg": "Xpx",
    "radius_full": "9999px",
    "button_radius": "Xpx",
    "input_radius": "Xpx",
    "card_radius": "Xpx",
    "width": "1px"
  },
  "shadows": {
    "card": "CSS shadow value",
    "button": "CSS shadow value or none",
    "dropdown": "CSS shadow value"
  },
  "buttons": {
    "primary": {
      "background": "#hex",
      "color": "#hex",
      "border": "CSS border or none",
      "radius": "Xpx",
      "padding": "Xpx Ypx",
      "font_weight": "500"
    },
    "secondary": {
      "background": "#hex",
      "color": "#hex",
      "border": "CSS border",
      "radius": "Xpx",
      "padding": "Xpx Ypx",
      "font_weight": "500"
    }
  },
  "inputs": {
    "background": "#hex",
    "border": "CSS border",
    "radius": "Xpx",
    "padding": "Xpx Ypx",
    "focus_ring": "CSS outline/ring"
  },
  "cdn_links": [
    "<link href='...' rel='stylesheet'>",
    "<script src='...'></script>"
  ]
}

CRITICAL: Use ACTUAL values extracted from the codebase.
- Look at real button implementations, not just config files
- If Tailwind, translate classes like "rounded-lg" to actual px values (sm=2px, md=6px, lg=8px, xl=12px)
- Include ALL CDN links found in layout/head templates

Output ONLY valid JSON, no markdown or commentary.
STYLE_PROMPT

echo "Style context extraction complete!"

echo "Output files:"
ls -la /output/
