#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token

echo "Starting consolidated recommendation generation for all accepted sections..."
echo "Repository: ${GITHUB_REPO}"

if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

# Clone the repository for full code context
if [ -n "${GITHUB_REPOS_JSON}" ]; then
    # Multi-provider mode — use clone_url from JSON (first repo)
    CLONE_URL=$(echo "$GITHUB_REPOS_JSON" | jq -r '.[0].clone_url')
    REPO_NAME=$(echo "$GITHUB_REPOS_JSON" | jq -r '.[0].repo')
    BRANCH=$(echo "$GITHUB_REPOS_JSON" | jq -r '.[0].branch // empty')
    BRANCH_ARGS=""
    if [ -n "$BRANCH" ]; then
        BRANCH_ARGS="--branch ${BRANCH}"
    fi
    echo "Cloning ${REPO_NAME}..."
    if ! git clone --depth 1 $BRANCH_ARGS "$CLONE_URL" /repo 2>&1; then
        echo "ERROR: Failed to clone repository ${REPO_NAME}"
        exit 1
    fi
else
    # Legacy single-repo mode
    echo "Cloning repository..."
    if ! git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>&1; then
        echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
        exit 1
    fi
fi

if [ ! -d /repo/.git ]; then
    echo "ERROR: Repository clone failed - /repo/.git not found"
    exit 1
fi

cd /repo

# Load file tree if available
if [ -f /input/file_tree.txt ] && [ -s /input/file_tree.txt ]; then
    FILE_TREE=$(cat /input/file_tree.txt)
    TREE_LINES=$(wc -l < /input/file_tree.txt)
    echo "File tree loaded: ${TREE_LINES} lines"
else
    FILE_TREE=""
fi

# Read analysis context from context.json
ANALYSIS_SUMMARY=$(jq -r '.analysis_summary // empty' /input/context.json)
PROJECT_OVERVIEW=$(jq -r '.project_overview // empty' /input/context.json)

echo "Running Claude Code analysis for all accepted sections..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

# Build the prompt with context
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" <<'PROMPT_HEADER'
You are a help centre content strategist. Your job is to suggest how-to guide articles for END USERS.

CRITICAL: These articles are for END USERS, not developers.
- End users = People who USE this software to accomplish their goals (customers, operators, admins)
- NOT developers = People who BUILD, maintain, or contribute code to this project
PROMPT_HEADER

# Add project context if available
if [ -n "$PROJECT_OVERVIEW" ] || [ -n "$ANALYSIS_SUMMARY" ] || [ -n "$FILE_TREE" ]; then
    cat >> "$PROMPT_FILE" <<'CONTEXT_HEADER'

=== PROJECT CONTEXT ===
Use this context to understand the project. Go directly to relevant files using Read instead of exploring broadly.
CONTEXT_HEADER

    if [ -n "$PROJECT_OVERVIEW" ]; then
        printf "\nPROJECT OVERVIEW:\n%s\n" "$PROJECT_OVERVIEW" >> "$PROMPT_FILE"
    fi

    if [ -n "$ANALYSIS_SUMMARY" ]; then
        printf "\nCODEBASE ANALYSIS SUMMARY:\n%s\n" "$ANALYSIS_SUMMARY" >> "$PROMPT_FILE"
    fi

    if [ -n "$FILE_TREE" ]; then
        printf "\nFILE TREE:\n%s\n" "$FILE_TREE" >> "$PROMPT_FILE"
    fi

    echo "" >> "$PROMPT_FILE"
    echo "=== END PROJECT CONTEXT ===" >> "$PROMPT_FILE"
fi

cat >> "$PROMPT_FILE" <<'PROMPT_BODY'

STEP 1: Read the project context file:
/input/context.json

This file contains:
- project_name, project_overview, analysis_summary, tech_stack, key_patterns, components
- sections: Array of ACCEPTED sections to generate recommendations for (each has name, slug, description)
- target_users: The identified end-user personas and their jobs-to-be-done
- existing_article_titles: ALL articles that already exist (avoid duplicates)
- existing_recommendation_titles: ALL pending recommendations (avoid duplicates)
- user_context: User-provided context from onboarding

STEP 2: Understand ALL accepted sections from the sections array.
Each section serves a different purpose. You must assign each recommendation to EXACTLY ONE section.

STEP 3: Using the PROJECT CONTEXT above and the codebase at /repo, identify END USER features.
Use the file tree and analysis summary to jump directly to relevant files (routes, views, controllers) rather than exploring broadly.
Focus on what END USERS can DO with the software:
- User interface elements and screens
- User-facing features and workflows
- Actions users can take (create, edit, share, export, etc.)
- Settings and preferences users can configure

STEP 4: For each feature/topic you identify, decide which SINGLE section it best fits into.
Generate up to 10 recommendations PER SECTION, grouped by section slug.

CRITICAL RULES:
- Each recommendation MUST belong to EXACTLY ONE section - NO DUPLICATES across sections
- If a topic could fit multiple sections, pick the BEST match based on section descriptions
- Articles are for END USERS based on target_users personas
- ONLY suggest articles for user-facing features you found in the codebase
- Do NOT suggest articles matching existing_article_titles or existing_recommendation_titles
- The justification MUST reference specific user-facing features you found

BAD examples (developer-focused - DO NOT suggest these):
- "How to configure the database connection"
- "How to set up the development environment"
- "How to use the API endpoints"
- "How to deploy the application"
- "How to run the test suite"

GOOD examples (end-user-focused):
- "How to create your first project"
- "How to invite team members"
- "How to export your data"
- "How to customize your dashboard"
- "How to set up notifications"

GUIDELINES:
- Title should start with "How to" and describe an END USER goal
- Focus on what users can DO, not how the software is built
- Each article should cover ONE specific task from target_users jobs-to-be-done
- Distribute recommendations evenly across sections when possible

OUTPUT FORMAT - Return ONLY a valid JSON object with recommendations grouped by section slug:
{
  "section-slug-1": [
    {
      "title": "How to [user goal]",
      "description": "One sentence describing what this guide covers",
      "justification": "Why users would need this guide, referencing code you found"
    }
  ],
  "section-slug-2": [
    {
      "title": "How to [another user goal]",
      "description": "One sentence describing what this guide covers",
      "justification": "Why users would need this guide, referencing code you found"
    }
  ]
}

Output ONLY the JSON object. No markdown, no commentary - just valid JSON.
PROMPT_BODY

echo "  Calling Claude..."
set +e
if [ "${KEEP_ANALYSIS_OUTPUT}" = "true" ]; then
    echo "  Streaming mode (debug) — turn log at /output/claude_raw.turns.log"
    cat "$PROMPT_FILE" | claude -p --verbose --output-format stream-json \
        --allowedTools "Read,Write,Edit,Glob,Grep,Bash,Agent" | \
        python3 /stream_filter.py /output/claude_raw.json
    CLAUDE_EXIT=${PIPESTATUS[1]}
    cp /output/claude_raw.json /tmp/claude_output.json 2>/dev/null || true
else
    cat "$PROMPT_FILE" | claude -p --output-format json \
        --allowedTools "Read,Write,Edit,Glob,Grep,Bash,Agent" > /tmp/claude_output.json
    CLAUDE_EXIT=$?
fi
set -e
rm -f "$PROMPT_FILE"

echo "  Claude exit status: $CLAUDE_EXIT"
echo "Recommendation generation complete!"

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_output.json > /output/recommendations.json

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

echo "Output files:"
ls -la /output/
echo "Recommendations length: $(wc -c < /output/recommendations.json) chars"
