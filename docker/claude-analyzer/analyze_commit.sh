#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPOS_JSON: JSON array of {repo, directory, token} objects
#   OR (legacy single repo mode):
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token

# Required input files (mounted at /input):
# - diff.patch: The commit diff
# - context.json: Project context and commit metadata (includes repository_relationships for multi-repo)

echo "Starting commit analysis..."

# Verify input files exist
if [ ! -f /input/diff.patch ]; then
    echo "Error: /input/diff.patch not found"
    exit 1
fi

if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

# Create repos directory
mkdir -p /repos

# Determine if we're in multi-repo or single-repo mode
if [ -n "${GITHUB_REPOS_JSON}" ]; then
    REPO_COUNT=$(echo "$GITHUB_REPOS_JSON" | jq 'length')
    echo "Multi-repo mode: ${REPO_COUNT} repositories"
    MULTI_REPO=true

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
else
    echo "Single-repo mode: ${GITHUB_REPO}"
    MULTI_REPO=false

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
fi

# Change to repos directory for analysis
cd /repos

# Read commit SHA from context for logging
COMMIT_SHA=$(cat /input/context.json | grep -o '"commit_sha":"[^"]*"' | grep -o '[a-f0-9]\{7,40\}' | head -1 || echo "unknown")
echo "Analyzing commit ${COMMIT_SHA}"

# Build multi-repo context for prompt if applicable
if [ "$MULTI_REPO" = true ] && [ "$REPO_COUNT" -gt 1 ]; then
    # Check if context.json has repository_relationships
    HAS_RELATIONSHIPS=$(cat /input/context.json | jq -r 'if .repository_relationships then "yes" else "no" end')

    if [ "$HAS_RELATIONSHIPS" = "yes" ]; then
        MULTI_REPO_CONTEXT="
IMPORTANT: This project consists of multiple related repositories:

$(cat /input/context.json | jq -r '.repository_relationships.architecture_summary // empty')

Repositories:
$(cat /input/context.json | jq -r '.repository_relationships.repositories[]? | "- \(.directory): \(.role) - \(.description)"')

This commit affects the repository: $(cat /input/context.json | jq -r '.source_repo // .github_repo // "unknown"')

When analyzing this commit, consider how changes might affect other repositories in this project.
"
    else
        MULTI_REPO_CONTEXT="Note: This project has multiple repositories. The diff is from one of them."
    fi
else
    MULTI_REPO_CONTEXT=""
fi

# Run Claude Code to analyze the commit diff
echo "Running Claude Code analysis..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<PROMPT | claude -p --output-format json --allowedTools "Read,Glob,Grep,Bash" > /tmp/claude_output.json
You are a changelog writer for a software product. Your job is to convert technical code changes into user-facing release notes that help users understand what's new and how it benefits them.
${MULTI_REPO_CONTEXT}
STEP 1: Read the project context file to understand what this project does:
/input/context.json

STEP 2: Read the commit diff to understand what code changed:
/input/diff.patch

STEP 3: If needed, explore the full codebase at /repos to understand the broader context of the changes. Use Glob, Grep, and Read tools to find related code.

STEP 4: Based on the project context and the code changes, generate the following output:

First, output a user-friendly changelog TITLE (one line only):
- Focus on what users can now DO or what problem is solved
- Avoid technical jargon - write for end users, not developers
- Use active voice (e.g., "Export reports to PDF" not "Added PDF export functionality")
- Keep it concise (under 60 characters ideally)

Then output this exact delimiter on its own line:
---CHANGELOG_CONTENT---

Then output the CONTENT section (2-4 paragraphs in markdown):
- Start with a brief summary of what changed from the user's perspective
- Explain the benefit or impact to users
- If it's a new feature, describe how to use it
- If it's a bug fix, explain what was wrong and that it's now fixed
- If it's an improvement, highlight what's better now
- Do NOT include code snippets or technical implementation details
- Do NOT mention file names, function names, or internal architecture
- Write in a friendly, professional tone

Then output this exact delimiter on its own line:
---RECOMMENDED_ARTICLES---

Then output RECOMMENDED_ARTICLES as valid JSON on a single line:

If the changes have NO user-facing impact (internal refactors, dev tooling, tests, dependency updates), output:
{"articles":[],"no_articles_reason":"Brief explanation of why no guides are needed"}

If users would benefit from how-to documentation, output:
{"articles":[{"title":"How to [do the thing]","description":"One sentence describing what this guide would cover","justification":"Why this guide is needed based on the commit changes"}],"no_articles_reason":null}

Guidelines for recommendations:
- Focus on NEW features or significantly changed behavior users need to learn
- Title should start with "How to" and describe the user's goal
- Each article should cover ONE specific task
- Maximum 3 article recommendations per commit
- Bug fixes rarely need guides unless the fix changes user workflow
- Internal code changes (refactors, performance improvements) need no guides

Remember: Your audience is END USERS, not developers. Focus on VALUE and BENEFITS, not implementation.
PROMPT

echo "Parsing analysis output..."

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_output.json > /output/analysis_raw.txt

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

# Check if analysis produced output
if [ ! -s /output/analysis_raw.txt ]; then
    echo "Error: Claude Code produced no output"
    exit 1
fi

# Extract title (everything before ---CHANGELOG_CONTENT---)
sed -n '1,/---CHANGELOG_CONTENT---/p' /output/analysis_raw.txt | sed '$d' | sed '/^$/d' > /output/title.txt

# Extract content (between ---CHANGELOG_CONTENT--- and ---RECOMMENDED_ARTICLES---)
sed -n '/---CHANGELOG_CONTENT---/,/---RECOMMENDED_ARTICLES---/p' /output/analysis_raw.txt | sed '1d;$d' > /output/content.md

# Extract recommended articles JSON (everything after ---RECOMMENDED_ARTICLES---)
sed -n '/---RECOMMENDED_ARTICLES---/,$p' /output/analysis_raw.txt | tail -n +2 | sed '/^$/d' | tr -d '\n' > /output/articles.json

# Verify outputs were created
echo "Commit analysis complete!"
echo "Output files:"
ls -la /output/

# Log sizes for debugging
echo "Title length: $(wc -c < /output/title.txt) chars"
echo "Content length: $(wc -c < /output/content.md) chars"
echo "Articles JSON length: $(wc -c < /output/articles.json) chars"
