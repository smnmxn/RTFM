# Phase 3: AI-Powered PR Analysis

## Overview

Phase 3 replaces placeholder changelog content with AI-generated content when a pull request is merged. Using the same Docker + Claude Code architecture from Phase 2.5, the system analyzes PR diffs and generates user-focused changelog entries and social media snippets.

## What Was Built

### Database Changes

Added column to `updates` table:
- `analysis_status` (string) - pending/running/completed/failed

### Docker Container Updates

Extended the existing `rtfm/claude-analyzer:latest` image with:
- New script `analyze_pr.sh` for PR analysis
- Input directory `/input` for passing diff and context files

### Background Job

Modified `AnalyzePullRequestJob` to:
1. Fetch PR diff via Octokit
2. Create Update with `analysis_status: running`
3. Pass project context (from Phase 2.5 analysis) to Docker
4. Run Claude Code to generate user-focused content
5. Parse output and update the Update record
6. Fall back to placeholder content on failure

## Files Created/Modified

| Action | File |
|--------|------|
| Create | `db/migrate/XXXXXX_add_analysis_status_to_updates.rb` |
| Create | `docker/claude-analyzer/analyze_pr.sh` |
| Modify | `docker/claude-analyzer/Dockerfile` |
| Modify | `app/jobs/analyze_pull_request_job.rb` |

## Configuration

### Environment Variables

Required in `.env`:
- `ANTHROPIC_API_KEY` - For Claude Code in the Docker container

### Docker

Rebuild the Docker image after Phase 3 deployment:

```bash
cd docker/claude-analyzer
docker build -t rtfm/claude-analyzer:latest .
```

## How It Works

1. GitHub webhook fires when PR is merged
2. `AnalyzePullRequestJob` is enqueued
3. Job fetches PR diff via GitHub API
4. Creates Update record with `analysis_status: running`
5. Prepares input files:
   - `diff.patch` - Raw PR diff
   - `context.json` - Project context and PR metadata
6. Docker container runs with `analyze_pr.sh` entrypoint
7. Claude Code reads inputs and generates:
   - User-friendly title
   - Changelog content (2-4 paragraphs)
   - Twitter/X snippet (max 280 chars)
8. Job parses output and updates the Update record
9. On failure, falls back to placeholder content

## Input Format

### context.json

```json
{
  "project_name": "RTFM",
  "project_overview": "RTFM helps developers automatically...",
  "analysis_summary": "# RTFM\n\n## Overview...",
  "tech_stack": ["ruby", "rails", "sqlite"],
  "key_patterns": ["MVC", "Service Objects"],
  "pr_number": 42,
  "pr_title": "Add dark mode toggle",
  "pr_body": "This PR adds a toggle switch..."
}
```

### diff.patch

Raw unified diff output from the GitHub API.

## Output Format

### title.txt

User-friendly changelog title (one line):
```
Toggle dark mode from settings
```

### content.md

Changelog content in markdown (2-4 paragraphs):
```markdown
You can now switch between light and dark modes directly from your settings page.

The new dark mode reduces eye strain when working in low-light environments and can help save battery on devices with OLED screens.

To enable dark mode, navigate to Settings and click the "Dark Mode" toggle. Your preference will be saved automatically.
```

### social.txt

Twitter/X optimized snippet (max 280 chars):
```
New in RTFM: Dark mode is here! Switch between light and dark themes from your settings page for a more comfortable viewing experience.
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Docker failure | Falls back to placeholder content |
| Timeout (>5 min) | Marks as failed, uses placeholder |
| Missing output files | Uses placeholder content |
| Claude API error | Uses placeholder content |

## Testing

### Manual Testing

1. Ensure Docker image is built with new script:
   ```bash
   docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/
   ```

2. Create a test project with Phase 2.5 analysis completed

3. Trigger a webhook for a merged PR (or use `rails console`):
   ```ruby
   AnalyzePullRequestJob.perform_now(
     project_id: 1,
     pull_request_number: 123,
     pull_request_url: "https://github.com/owner/repo/pull/123",
     pull_request_title: "Add feature X",
     pull_request_body: "Description..."
   )
   ```

4. Check the resulting Update record for AI-generated content

### Test Failure Fallback

Set an invalid `ANTHROPIC_API_KEY` to verify placeholder content is used when AI fails.

## Notes

- **Timeout**: PR analysis has a 5-minute timeout (shorter than codebase analysis)
- **Context**: Works best when project has Phase 2.5 analysis completed
- **Cost**: Each PR analysis uses the Anthropic API
- **Cleanup**: Temporary input/output directories are cleaned up after analysis
- **Queue**: Uses the `analysis` queue (same as codebase analysis)
