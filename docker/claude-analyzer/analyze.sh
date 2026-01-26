#!/bin/bash
set -e

# Required environment variables:
# - GITHUB_REPOS_JSON: JSON array of {repo, directory, token} objects
#   OR (legacy single repo mode):
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code

echo "Starting codebase analysis..."

# Determine if we're in multi-repo or single-repo mode
if [ -n "${GITHUB_REPOS_JSON}" ]; then
    REPO_COUNT=$(echo "$GITHUB_REPOS_JSON" | jq 'length')
    echo "Multi-repo mode: ${REPO_COUNT} repositories"
    MULTI_REPO=true
else
    echo "Single-repo mode: ${GITHUB_REPO}"
    REPO_COUNT=1
    MULTI_REPO=false
fi

# Create repos directory
mkdir -p /repos

if [ "$MULTI_REPO" = true ]; then
    # Clone each repository from JSON
    for i in $(seq 0 $((REPO_COUNT - 1))); do
        REPO=$(echo "$GITHUB_REPOS_JSON" | jq -r ".[$i].repo")
        DIR=$(echo "$GITHUB_REPOS_JSON" | jq -r ".[$i].directory")
        TOKEN=$(echo "$GITHUB_REPOS_JSON" | jq -r ".[$i].token")

        echo "Cloning $REPO to /repos/$DIR..."
        if ! git clone --depth 1 "https://x-access-token:${TOKEN}@github.com/${REPO}.git" "/repos/$DIR" 2>&1; then
            echo "ERROR: Failed to clone repository $REPO"
            exit 1
        fi

        if [ ! -d "/repos/$DIR/.git" ]; then
            echo "ERROR: Repository clone failed - /repos/$DIR/.git not found"
            exit 1
        fi
    done

    # Get commit SHA from primary repo (first one)
    PRIMARY_DIR=$(echo "$GITHUB_REPOS_JSON" | jq -r '.[0].directory')
    cd "/repos/$PRIMARY_DIR"
else
    # Legacy single-repo mode
    echo "Cloning repository..."
    DIR=$(echo "${GITHUB_REPO}" | sed 's/\//-/g')
    if ! git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "/repos/$DIR" 2>&1; then
        echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
        exit 1
    fi

    if [ ! -d "/repos/$DIR/.git" ]; then
        echo "ERROR: Repository clone failed - /repos/$DIR/.git not found"
        exit 1
    fi

    cd "/repos/$DIR"
fi

# Get the current commit SHA
COMMIT_SHA=$(git rev-parse HEAD)
echo "Commit SHA: ${COMMIT_SHA}"
echo "${COMMIT_SHA}" > /output/commit_sha.txt

# Change to repos parent directory for analysis
cd /repos

# Run Claude Code to analyze the codebase
echo "Running Claude Code analysis..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

# Build the prompt based on single/multi repo mode
if [ "$MULTI_REPO" = true ] && [ "$REPO_COUNT" -gt 1 ]; then
    # List the repos for the prompt
    REPO_LIST=""
    for i in $(seq 0 $((REPO_COUNT - 1))); do
        DIR=$(echo "$GITHUB_REPOS_JSON" | jq -r ".[$i].directory")
        REPO_LIST="${REPO_LIST}- /repos/${DIR}\n"
    done

    MULTI_REPO_INTRO="You have access to multiple repositories in this workspace. Each repository is in its own subdirectory under /repos/:

${REPO_LIST}
Analyze ALL repositories as a unified codebase. Consider how they work together and document their relationships.

"
    REPO_RELATIONSHIPS_SECTION="
10. THEN, output the delimiter: ---REPOSITORY_RELATIONSHIPS---

11. Output a JSON object describing each repository and their relationships:
{
  \"repositories\": [
    {
      \"directory\": \"owner-repo1\",
      \"name\": \"repo1\",
      \"role\": \"Brief role description (e.g., Backend API server)\",
      \"description\": \"What this repository does and its main purpose\"
    }
  ],
  \"relationships\": [
    {
      \"from\": \"directory-name\",
      \"to\": \"directory-name\",
      \"type\": \"consumes|provides|extends|shares\",
      \"description\": \"How these repositories relate to each other\"
    }
  ],
  \"architecture_summary\": \"A 2-3 sentence summary of how all repositories work together as a system\"
}

Relationship types:
- consumes: One repo uses/calls another (e.g., frontend calls backend API)
- provides: One repo provides services/data to another
- extends: One repo extends/builds upon another
- shares: Repos share common code, data, or configuration
"
else
    MULTI_REPO_INTRO=""
    REPO_RELATIONSHIPS_SECTION=""
fi

cat <<PROMPT | claude -p --output-format json --allowedTools "Read,Glob,Grep,Bash" > /tmp/claude_main_output.json
${MULTI_REPO_INTRO}Analyze this codebase and provide:

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
${REPO_RELATIONSHIPS_SECTION}
Be thorough but concise. Focus on what would help someone understand this codebase quickly.
PROMPT

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_main_output.json > /output/analysis_raw.txt

# Extract usage data for main analysis
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_main_output.json > /output/usage_main.json

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

# Check if we have repository relationships section
if grep -q '---REPOSITORY_RELATIONSHIPS---' /output/analysis_raw.txt; then
    # Extract contextual questions (between ---CONTEXTUAL_QUESTIONS--- and ---REPOSITORY_RELATIONSHIPS---)
    sed -n '/---CONTEXTUAL_QUESTIONS---/,/---REPOSITORY_RELATIONSHIPS---/p' /output/analysis_raw.txt | sed '1d;$d' > /output/contextual_questions.json

    # Extract repository relationships (everything after ---REPOSITORY_RELATIONSHIPS---)
    sed -n '/---REPOSITORY_RELATIONSHIPS---/,$p' /output/analysis_raw.txt | tail -n +2 > /output/repository_relationships.json
    echo "Repository relationships extracted!"
else
    # Extract contextual questions (everything after ---CONTEXTUAL_QUESTIONS---)
    sed -n '/---CONTEXTUAL_QUESTIONS---/,$p' /output/analysis_raw.txt | tail -n +2 > /output/contextual_questions.json
fi

echo "Main analysis complete!"

# Extract style context for UI mockup generation
echo "Extracting style context..."

cat <<'STYLE_PROMPT' | claude -p --output-format json --allowedTools "Read,Glob,Grep" > /tmp/claude_style_output.json
Analyze this codebase and extract a comprehensive visual style context for generating accurate UI mockups.

STEP 1: Determine the application type:
- "web": Has routes, views/templates, CSS files, web framework (Rails, React, Vue, Django, etc.)
- "tui": Has TUI (Text User Interface) framework for interactive terminal apps with rich UI
  * Python: textual, rich (with Live/Layout), urwid, blessed, npyscreen
  * Go: bubbletea, lipgloss, tview, gocui, termui
  * Rust: ratatui, crossterm (with UI), cursive, tui-rs
  * Node.js: ink, blessed, neo-blessed
  * Ruby: tty-prompt (interactive), curses
  * Check: package.json, go.mod, Cargo.toml, pyproject.toml, requirements.txt, Gemfile
- "cli": Simple command-line tool with argument parsing, outputs to stdout, no interactive UI
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

FOR TUI APPS:
- Set app_type to "tui"
- Identify the specific TUI framework used
- Extract theme/colors if available:
  * Textual (Python): Parse .tcss files for CSS variables and colors
  * Lipgloss (Go): Find lipgloss.NewStyle() calls, extract .Foreground(), .Background(), .Border() values
  * Ratatui (Rust): Find Style::default().fg() patterns, Color::Rgb() definitions
  * Ink (Node.js): Parse JSX color props from components
- Add tui_context object with:
  * framework: The detected TUI framework name
  * language: python|go|rust|nodejs|ruby
  * has_custom_theme: true if custom colors found
  * layout_style: full_screen|list_view|form|dashboard|split_pane (based on component usage)
  * components_detected: Array of UI components found (DataTable, ListView, Input, Button, etc.)
- Use TUI-appropriate colors (defaults if no theme found):
  - Dark background (#161b22)
  - Light foreground (#c9d1d9)
  - Primary accent (#388bfd)
  - Border color (#30363d)
  - Selection background (#388bfd33)

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
  "app_type": "web|tui|cli|desktop",
  "framework": "tailwind|bootstrap|none",
  "tui_context": {
    "framework": "textual|bubbletea|ratatui|ink|tview|blessed|null",
    "language": "python|go|rust|nodejs|ruby|null",
    "has_custom_theme": false,
    "layout_style": "full_screen|list_view|form|dashboard|split_pane|null",
    "components_detected": ["component names or empty array"]
  },
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

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_style_output.json > /output/style_context.json

# Extract usage data for style analysis
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_style_output.json > /output/usage_style.json

echo "Style context extraction complete!"

echo "Output files:"
ls -la /output/
