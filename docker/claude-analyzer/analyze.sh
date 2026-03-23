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
        CLONE_URL=$(echo "$GITHUB_REPOS_JSON" | jq -r ".[$i].clone_url // empty")
        BRANCH=$(echo "$GITHUB_REPOS_JSON" | jq -r ".[$i].branch // empty")

        # Use clone_url from JSON if provided, otherwise fall back to GitHub format
        if [ -z "$CLONE_URL" ]; then
            CLONE_URL="https://x-access-token:${TOKEN}@github.com/${REPO}.git"
        fi

        BRANCH_ARGS=""
        if [ -n "$BRANCH" ]; then
            BRANCH_ARGS="--branch ${BRANCH}"
            echo "Cloning $REPO ($BRANCH) to /repos/$DIR..."
        else
            echo "Cloning $REPO to /repos/$DIR..."
        fi
        if ! git clone --depth 1 $BRANCH_ARGS "$CLONE_URL" "/repos/$DIR" 2>&1; then
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

# Generate file tree for article generation context
echo "Generating file tree..."
{
  find /repos -maxdepth 6 \
    -name node_modules -prune -o \
    -name .git -prune -o \
    -name vendor -prune -o \
    -name build -prune -o \
    -name dist -prune -o \
    -name __pycache__ -prune -o \
    -name .next -prune -o \
    -name .nuxt -prune -o \
    -name coverage -prune -o \
    -name tmp -prune -o \
    -name log -prune -o \
    -name logs -prune -o \
    -name '.cache' -prune -o \
    -type f -print -o -type d -print | \
    sort | \
    sed 's|^/repos/||'
} > /tmp/file_tree_raw.txt

head -n 2000 /tmp/file_tree_raw.txt > /output/file_tree.txt
TREE_LINES=$(wc -l < /output/file_tree.txt)
echo "File tree generated: ${TREE_LINES} lines"

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
6. THEN, output the delimiter: ---REPOSITORY_RELATIONSHIPS---

7. Output a JSON object describing each repository and their relationships:
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

cat <<PROMPT | claude -p --output-format json --allowedTools "Read,Write,Edit,Glob,Grep,Bash,Agent" > /tmp/claude_main_output.json
${MULTI_REPO_INTRO}Analyze this codebase and provide:

1. FIRST, output a comprehensive project summary in markdown format including:
   - Project overview (what it does)
   - Tech stack (languages, frameworks, libraries)
   - Architecture overview
   - Key directories and their purposes
   - Important files
   - Development patterns used
   - Key components and what they do

2. THEN, output the delimiter: ---PROJECT_OVERVIEW---

3. Output a 2-3 sentence overview describing what this project does for END USERS (not developers). Focus on the user-facing functionality and value proposition. Do not mention technical implementation details like frameworks, databases, or architecture. Write it as if explaining to a non-technical person what the software helps them accomplish.

4. THEN, output the delimiter: ---CONTEXTUAL_QUESTIONS---

5. Based on your analysis, generate 2-3 contextual questions to ask the user about their documentation needs. These questions should:
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

# Extract usage data
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_main_output.json > /output/usage_main.json

# Parse the output into separate files
echo "Parsing analysis output..."

# Extract summary (everything before ---PROJECT_OVERVIEW---)
sed -n '1,/---PROJECT_OVERVIEW---/p' /output/analysis_raw.txt | sed '$d' > /output/summary.md

# Extract project overview (between ---PROJECT_OVERVIEW--- and ---CONTEXTUAL_QUESTIONS---)
sed -n '/---PROJECT_OVERVIEW---/,/---CONTEXTUAL_QUESTIONS---/p' /output/analysis_raw.txt | sed '1d;$d' > /output/overview.txt

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

echo "Analysis complete!"
echo "Output files:"
ls -la /output/
