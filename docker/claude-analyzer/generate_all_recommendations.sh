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

echo "Running Claude Code analysis for all accepted sections..."
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
- sections: Array of ACCEPTED sections to generate recommendations for (each has name, slug, description)
- target_users: The identified end-user personas and their jobs-to-be-done
- existing_article_titles: ALL articles that already exist (avoid duplicates)
- existing_recommendation_titles: ALL pending recommendations (avoid duplicates)
- user_context: User-provided context from onboarding

STEP 2: Understand ALL accepted sections from the sections array.
Each section serves a different purpose. You must assign each recommendation to EXACTLY ONE section.

STEP 3: Explore the codebase at /repo to find END USER features.
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
PROMPT

echo "Recommendation generation complete!"

# Extract the result content from JSON output
jq -r 'if .result then (if .result | type == "string" then .result else (.result // "") end) else "" end' /tmp/claude_output.json > /output/recommendations.json

# Extract usage data for tracking
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /tmp/claude_output.json > /output/usage.json

echo "Output files:"
ls -la /output/
echo "Recommendations length: $(wc -c < /output/recommendations.json) chars"
