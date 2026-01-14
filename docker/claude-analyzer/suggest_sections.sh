#!/bin/bash
set -e

# Required environment variables:
# - ANTHROPIC_API_KEY: Anthropic API key for Claude Code
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token

echo "Starting section suggestion..."
echo "Repository: ${GITHUB_REPO}"

if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

# Clone the repository for full code context
echo "Cloning repository..."
git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>/dev/null
cd /repo

PROJECT_NAME=$(cat /input/context.json | grep -o '"project_name":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "Suggesting sections for: ${PROJECT_NAME}"

echo "Running Claude Code analysis..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"

cat <<'PROMPT' | claude -p --allowedTools "Read,Glob,Grep,Bash" > /output/sections_raw.json
You are a help centre strategist. Analyze this project and suggest the COMPLETE set of help centre sections for END USERS.

CRITICAL: These sections are for END USERS, not developers.
- End users = People who USE this software to accomplish their goals (customers, operators, admins)
- NOT developers = People who BUILD, maintain, or contribute code to this project

STEP 1: Read the project context file:
/input/context.json

This file contains:
- project_name, project_overview, analysis_summary
- tech_stack, key_patterns, components
- existing_section_slugs: Any sections that already exist (avoid duplicates)
- target_users: The identified end-user personas and their jobs-to-be-done

STEP 2: Explore the codebase at /repo to understand what END USERS can DO with this product.
Focus on:
- User-facing features and workflows (not internal implementation)
- Different end-user personas from target_users
- Distinct user goals or jobs-to-be-done
- Features that serve specific user needs

STEP 3: Suggest the COMPLETE set of help centre sections for this project.

STANDARD SECTION PATTERNS (use if appropriate for this project):
- "Getting Started" (slug: getting-started) - First-time setup, onboarding, initial configuration
- "Daily Tasks" (slug: daily-tasks) - Common everyday workflows, regular operations
- "Advanced Usage" (slug: advanced-usage) - Power user features, customization, integrations
- "Troubleshooting" (slug: troubleshooting) - Problem solving, FAQs, common issues

You may use these standard patterns, adapt them, skip them, or create entirely custom sections based on what makes sense for this specific project and its target_users.

GUIDELINES:
- Suggest 3-8 sections total
- Each section should have enough potential content for 3+ articles
- Focus on END USER needs from target_users
- Sections should be distinct and not overlap significantly
- Skip the slug if it's in existing_section_slugs

DO NOT suggest sections that:
- Are developer-focused (API docs, architecture, deployment, contributing)
- Are too narrow (only 1-2 articles)
- Are generic (e.g., "features", "help", "guides", "overview")

OUTPUT FORMAT - Return ONLY a valid JSON object:
{
  "sections": [
    {
      "name": "Section Name",
      "slug": "section-name",
      "description": "Brief description of what articles belong in this section",
      "justification": "Why this section would be valuable for the target users"
    }
  ]
}

Output ONLY the JSON object. No markdown, no commentary - just valid JSON.
PROMPT

echo "Section suggestion complete!"

# Move output to final location
mv /output/sections_raw.json /output/sections.json

echo "Output files:"
ls -la /output/
echo "Sections length: $(wc -c < /output/sections.json) chars"
