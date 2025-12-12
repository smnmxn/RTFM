# Phase 2.5: Codebase Understanding

## Overview

Phase 2.5 adds the ability to analyze a connected repository using Claude Code running in a Docker container. Users can manually trigger analysis to generate a CLAUDE.md-style project summary and structured metadata, which will be used to improve changelog generation quality.

## What Was Built

### Database Changes

Added columns to `projects` table:
- `analysis_summary` (text) - CLAUDE.md-style project summary
- `analysis_metadata` (json) - Structured metadata about the codebase
- `analysis_status` (string) - pending/running/completed/failed
- `analyzed_at` (datetime) - Timestamp of last analysis
- `analysis_commit_sha` (string) - Git commit that was analyzed

### Docker Container

Created a Docker image (`rtfm/claude-analyzer:latest`) that:
1. Clones the repository using the user's GitHub token
2. Runs Claude Code CLI to analyze the codebase
3. Outputs a summary markdown file and structured JSON metadata
4. Records the commit SHA for reference

### Background Job

`AnalyzeCodebaseJob` handles:
- Building Docker image if not present
- Running the container with appropriate environment variables
- Parsing output files (summary.md, metadata.json, commit_sha.txt)
- Updating project record with results

### UI Changes

Project show page now includes a "Codebase Understanding" section:
- "Analyze Codebase" button to trigger analysis
- Status indicators (Queued, Analyzing, Failed)
- Rendered markdown summary when complete
- Timestamp and commit SHA of last analysis
- "Re-analyze" button to update analysis

## Files Created/Modified

| Action | File |
|--------|------|
| Create | `db/migrate/20251210115633_add_analysis_to_projects.rb` |
| Create | `docker/claude-analyzer/Dockerfile` |
| Create | `docker/claude-analyzer/analyze.sh` |
| Create | `app/jobs/analyze_codebase_job.rb` |
| Modify | `app/controllers/projects_controller.rb` (added `analyze` action) |
| Modify | `config/routes.rb` (added `post :analyze` route) |
| Modify | `app/views/projects/show.html.erb` (added analysis UI) |
| Modify | `app/helpers/application_helper.rb` (added `markdown` helper) |
| Modify | `Gemfile` (added `redcarpet` gem) |

## Configuration

### Environment Variables

Required in `.env`:
- `ANTHROPIC_API_KEY` - For Claude Code in the Docker container

### Docker

The Docker image is automatically built on first use. To manually build:

```bash
cd docker/claude-analyzer
docker build -t rtfm/claude-analyzer:latest .
```

## How It Works

1. User clicks "Analyze Codebase" on project page
2. `AnalyzeCodebaseJob` is enqueued
3. Job builds Docker image if needed
4. Docker container runs with:
   - `GITHUB_REPO` - Repository to analyze
   - `GITHUB_TOKEN` - User's GitHub token for cloning
   - `ANTHROPIC_API_KEY` - For Claude Code API access
   - Output volume mounted at `/output`
5. Container clones repo and runs Claude Code analysis
6. Job parses output files and updates project record
7. User refreshes page to see results

## Output Format

### analysis_summary (text)

```markdown
# Project: Example App

## Overview
A Rails application for...

## Architecture
- Rails 8 + Hotwire frontend
- SQLite database
- Sidekiq for background jobs

## Key Components
- `app/services/` - Business logic
- `app/jobs/` - Async processing
...
```

### analysis_metadata (JSON)

```json
{
  "tech_stack": ["ruby", "rails", "sqlite", "redis"],
  "components": [
    {"name": "Authentication", "description": "...", "files": ["app/controllers/sessions_controller.rb"]},
    {"name": "Webhooks", "description": "...", "files": ["app/controllers/webhooks/github_controller.rb"]}
  ],
  "entrypoints": ["config/routes.rb"],
  "test_framework": "minitest",
  "package_manager": "bundler",
  "key_patterns": ["MVC", "Service Objects", "Background Jobs"]
}
```

## Testing

Run the analysis job test:

```bash
rails test test/jobs/analyze_codebase_job_test.rb
```

## Notes

- **Security**: Repository clone uses the user's GitHub token, runs in isolated Docker container
- **Cost**: Each analysis uses the Anthropic API (Claude Code)
- **Cleanup**: Docker container and cloned repo are destroyed after analysis
- **Timeout**: Analysis has a 10-minute timeout to handle large repositories
