#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token

echo "Starting section-specific recommendation generation..."
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

SECTION_NAME=$(cat /input/context.json | grep -o '"section_name":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
SECTION_SLUG=$(cat /input/context.json | grep -o '"section_slug":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "Generating recommendations for section: ${SECTION_NAME} (${SECTION_SLUG})"

echo "Running Claude Code analysis..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<'PROMPT' | claude -p --output-format json --allowedTools "Read,Glob,Grep,Bash" > /tmp/claude_output.json
You are a help centre content strategist. Your job is to suggest how-to guide articles for END USERS.

CRITICAL: These articles are for END USERS, not developers.
- End users = People who USE this software to accomplish their goals (customers, operators, admins)
- NOT developers = People who BUILD, maintain, or contribute code to this project

STEP 1: Read the project context file:
/input/context.json

This file contains:
- project_name, project_overview, analysis_summary, tech_stack, key_patterns, components
- all_sections: ALL sections in the help centre (name, slug, description for each)
- section_name: The SPECIFIC section you are generating recommendations for
- section_slug: The section identifier
- section_description: What this section should contain
- target_users: The identified end-user personas and their jobs-to-be-done
- existing_article_titles: ALL articles that already exist (avoid duplicates)
- existing_recommendation_titles: ALL pending recommendations (avoid duplicates)

STEP 2: Understand the FULL help centre structure from all_sections.
Each section serves a different purpose. Articles for OTHER sections will be generated separately.

STEP 3: Explore the codebase at /repo to find END USER features relevant to THIS SPECIFIC SECTION ONLY.
Focus on what END USERS can DO with the software:
- User interface elements and screens
- User-facing features and workflows
- Actions users can take (create, edit, share, export, etc.)
- Settings and preferences users can configure

STEP 4: Based on target_users and features found, suggest up to 10 how-to articles for THIS SECTION ONLY.

CRITICAL RULES:
- You are generating articles ONLY for section_name - NOT for other sections in all_sections
- If an article would fit better in another section from all_sections, do NOT suggest it here
- Articles are for END USERS based on target_users personas
- ONLY suggest articles for user-facing features you found in the codebase
- Articles MUST clearly belong in this section, not another
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

OUTPUT FORMAT - Return ONLY a valid JSON object:
{
  "articles": [
    {
      "title": "How to [user goal]",
      "description": "One sentence describing what this guide covers",
      "justification": "Why users would need this guide, referencing code you found"
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
