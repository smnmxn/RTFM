#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token

echo "Starting project-wide recommendation generation..."
echo "Repository: ${GITHUB_REPO}"

if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

# Clone the repository for full code context
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

PROJECT_NAME=$(cat /input/context.json | grep -o '"project_name":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "Generating recommendations for: ${PROJECT_NAME}"

echo "Running Claude Code analysis..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<'PROMPT' | claude -p --output-format json --allowedTools "Read,Glob,Grep,Bash" > /tmp/claude_output.json
You are a technical documentation strategist. Your job is to suggest how-to guide articles that would help users of a software product.

STEP 1: Read the project context file:
/input/context.json

This file contains:
- project_name: The name of the product
- project_overview: What the product does
- analysis_summary: Technical summary of the codebase
- tech_stack: Technologies used
- key_patterns: Architecture patterns
- components: Main components/modules
- existing_changelogs: Recent feature releases (to understand what users can do)
- existing_recommendation_titles: Already suggested articles (avoid duplicates)

STEP 2: Explore the full codebase at /repo to discover user-facing features. Use Glob, Grep, and Read tools to find controllers, views, routes, and UI components. Focus on identifying features that users interact with.

STEP 3: Based on the project's SPECIFIC features found in the codebase, suggest how-to guide articles that would help users.

CRITICAL RULES:
- ONLY suggest articles for features you found in the actual codebase at /repo
- Do NOT invent generic features - every recommendation must be backed by code you explored
- If you cannot find specific user-facing features in the codebase, return an empty articles array
- It is better to suggest 0-2 highly relevant articles than 5 generic ones

GUIDELINES:
- Focus on END USER tasks, not developer documentation
- Title should start with "How to" and describe a user goal
- Each article should cover ONE specific task users can actually do with this product
- Do NOT suggest articles that match titles in existing_recommendation_titles
- The justification MUST reference specific files/features you found in the codebase

OUTPUT FORMAT - Return ONLY a valid JSON object:
{
  "articles": [
    {
      "title": "How to [user goal]",
      "description": "One sentence describing what this guide covers",
      "justification": "Why users would need this guide based on the product's features"
    }
  ]
}

Output ONLY the JSON object. No markdown, no commentary - just valid JSON.
PROMPT

echo "Recommendation generation complete!"

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_output.json > /output/recommendations.json

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

echo "Output files:"
ls -la /output/
echo "Recommendations length: $(wc -c < /output/recommendations.json) chars"
