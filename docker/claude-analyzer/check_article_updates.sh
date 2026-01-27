#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN: Claude authentication
# - GITHUB_REPO: owner/repo format (primary repository)
# - GITHUB_TOKEN: GitHub access token
# - TARGET_COMMIT: The commit to analyze against
# - BASE_COMMIT: The starting commit for diff (optional, defaults to project's analysis commit)

# Required input files (mounted at /input):
# - context.json: Project context
# - articles.json: Array of existing articles with their metadata

echo "Starting article update check..."
echo "Repository: ${GITHUB_REPO}"
echo "Target commit: ${TARGET_COMMIT}"
echo "Base commit: ${BASE_COMMIT:-'(default branch HEAD)'}"

# Verify input files exist
if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

if [ ! -f /input/articles.json ]; then
    echo "Error: /input/articles.json not found"
    exit 1
fi

# Clone the repository
echo "Cloning repository..."
if ! git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>&1; then
    echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
    exit 1
fi

cd /repo

# Fetch all commits if we need to compare
git fetch --all 2>/dev/null || true

# Checkout target commit
echo "Checking out target commit: ${TARGET_COMMIT}"
if ! git checkout "${TARGET_COMMIT}" 2>/dev/null; then
    echo "ERROR: Failed to checkout target commit ${TARGET_COMMIT}"
    exit 1
fi

# Generate the diff
if [ -n "${BASE_COMMIT}" ]; then
    echo "Generating diff from ${BASE_COMMIT} to ${TARGET_COMMIT}..."
    git diff "${BASE_COMMIT}..${TARGET_COMMIT}" > /tmp/changes.diff 2>/dev/null || {
        echo "Warning: Could not generate diff, using empty diff"
        touch /tmp/changes.diff
    }
else
    # If no base commit, get a reasonable diff (last 50 commits or from initial)
    echo "Generating diff for recent changes..."
    COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "1")
    if [ "$COMMIT_COUNT" -gt 50 ]; then
        git diff HEAD~50..HEAD > /tmp/changes.diff 2>/dev/null || touch /tmp/changes.diff
    else
        # Get diff from initial commit
        INITIAL=$(git rev-list --max-parents=0 HEAD 2>/dev/null | head -1)
        if [ -n "$INITIAL" ]; then
            git diff "${INITIAL}..HEAD" > /tmp/changes.diff 2>/dev/null || touch /tmp/changes.diff
        else
            touch /tmp/changes.diff
        fi
    fi
fi

DIFF_SIZE=$(wc -c < /tmp/changes.diff)
echo "Diff size: ${DIFF_SIZE} bytes"

# Copy articles info
cp /input/articles.json /tmp/articles.json

# Count articles
ARTICLE_COUNT=$(jq 'length' /tmp/articles.json 2>/dev/null || echo "0")
echo "Articles to check: ${ARTICLE_COUNT}"

# Use default model if not specified
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5}"
echo "Using model: ${CLAUDE_MODEL}"

# Run Claude to analyze which articles need updates
echo "Running Claude Code to analyze article updates..."

set +e
cat <<'PROMPT' | claude -p --model "${CLAUDE_MODEL}" --max-turns 15 --output-format json --allowedTools "Read,Glob,Grep" > /tmp/claude_output.json
You are analyzing code changes to determine which documentation articles need to be updated.

STEP 1: Read the context file to understand the project:
/input/context.json

STEP 2: Read the list of existing articles:
/tmp/articles.json

Each article has:
- id: The article's database ID
- title: The article title
- description: What the article covers
- section: The documentation section
- source_commit_sha: The commit when the article was generated (may be null for older articles)
- introduction: The article introduction
- steps: List of step titles in the guide

STEP 3: Read the code changes diff:
/tmp/changes.diff

STEP 4: Explore the codebase at /repo to understand how the changes affect user-facing functionality.

STEP 5: For each article, analyze whether the code changes affect the functionality that article documents.

Consider:
- Do the changes modify UI elements described in the article?
- Do the changes add/remove/modify features covered by the article?
- Do the changes affect the workflow or steps described?
- Do the changes introduce new configuration options or settings?
- Are there error messages or edge cases that should be documented?

STEP 6: Also identify if any NEW articles should be created based on the changes:
- New features that need user documentation
- New configuration options users need to know about
- New workflows or capabilities

OUTPUT FORMAT - Return ONLY a valid JSON array of suggestions:

[
  {
    "type": "update_needed",
    "article_id": 123,
    "priority": "high",
    "reason": "The settings page has been redesigned with new options...",
    "affected_files": ["app/views/settings/index.html.erb", "app/controllers/settings_controller.rb"],
    "suggested_changes": {
      "update_steps": [1, 3],
      "add_prerequisite": false,
      "update_introduction": true,
      "notes": "Step 1 needs to show the new navigation path, Step 3 has a different button label"
    }
  },
  {
    "type": "new_article",
    "priority": "medium",
    "reason": "A new export feature has been added that users need to learn about",
    "affected_files": ["app/controllers/exports_controller.rb"],
    "suggested_changes": {
      "suggested_title": "How to Export Your Data",
      "suggested_section": "Data Management",
      "key_features": ["CSV export", "JSON export", "Date range filtering"]
    }
  }
]

PRIORITY LEVELS:
- "critical": Core functionality changed, article is now incorrect/misleading
- "high": Significant changes that users will notice
- "medium": Minor changes or improvements
- "low": Cosmetic or trivial changes

IMPORTANT:
- Only suggest updates for articles that are ACTUALLY affected by the changes
- Be specific about what needs to change in each article
- Include relevant file paths in affected_files
- For new articles, provide a suggested title and section
- If no updates are needed, return an empty array: []

Output ONLY the JSON array. No markdown, no commentary - just valid JSON.
PROMPT
CLAUDE_EXIT_STATUS=$?
set -e

echo "Claude exit status: ${CLAUDE_EXIT_STATUS}"

# Check if output file exists
if [ ! -f /tmp/claude_output.json ] || [ ! -s /tmp/claude_output.json ]; then
    echo "ERROR: Claude did not produce output"
    # Return empty suggestions array on failure
    echo "[]" > /output/suggestions.json
    exit 1
fi

echo "Analysis complete!"

# Copy raw output for debugging
cp /tmp/claude_output.json /output/claude_raw_output.json

# Extract the result content from JSON output
jq -r '.result // empty' /tmp/claude_output.json > /output/suggestions.json

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

# Validate the output is valid JSON array
if ! jq -e 'type == "array"' /output/suggestions.json > /dev/null 2>&1; then
    echo "Warning: Output is not a valid JSON array, attempting to extract..."
    # Try to find a JSON array in the output
    if jq -e '.' /output/suggestions.json > /dev/null 2>&1; then
        # It's valid JSON but not an array - wrap it or handle specially
        CONTENT=$(cat /output/suggestions.json)
        if [[ "$CONTENT" == "null" ]] || [[ -z "$CONTENT" ]]; then
            echo "[]" > /output/suggestions.json
        fi
    else
        # Try to extract JSON array from the content
        grep -o '\[.*\]' /output/suggestions.json > /tmp/extracted.json 2>/dev/null || echo "[]" > /tmp/extracted.json
        mv /tmp/extracted.json /output/suggestions.json
    fi
fi

SUGGESTION_COUNT=$(jq 'length' /output/suggestions.json 2>/dev/null || echo "0")
echo "Generated ${SUGGESTION_COUNT} suggestions"

echo "Output files:"
ls -la /output/
