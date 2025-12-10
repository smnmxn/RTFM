# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation Requirements

**After completing each development phase**, update the documentation:

1. Create/update `docs/phases/phase-N-name.md` with:
   - What was built
   - Files created/modified
   - Configuration changes
   - Any new environment variables
   - How to test the new functionality

2. Update `docs/README.md` phase status table

3. Update this file (`CLAUDE.md`) if:
   - New directories are added to "Key Directories"
   - New environment variables are required
   - Tech stack changes

## Project Overview

Ship & Shout is a developer-first platform that automatically converts code changes into user-facing product communication. When a PR is merged on GitHub, the system analyzes the diff and generates changelog entries and social media snippets using AI.

## Tech Stack

- **Backend**: Ruby 3.3.6, Rails 8.1, SQLite (dev), Sidekiq (Redis)
- **Frontend**: Tailwind CSS, Hotwire (Turbo & Stimulus), ERB
- **Auth**: Devise + OmniAuth GitHub (Phase 2)
- **AI**: Anthropic API (Claude 3.5 Sonnet)
- **VCS**: GitHub API via Octokit

## Development Commands

```bash
# Install dependencies
bundle install

# Database setup
rails db:create db:migrate

# Start all services (Rails server, Tailwind watcher, Sidekiq)
bin/dev

# Run tests
rails test

# Run a single test file
rails test test/path/to/test_file.rb

# Run a specific test
rails test test/path/to/test_file.rb:LINE_NUMBER
```

## Architecture

The application follows a **Webhook → Worker → Service** pattern:

1. **Webhooks::GithubController** receives GitHub webhook payloads
2. **AnalyzePullRequestJob** (Sidekiq) processes valid PRs asynchronously
3. **ChangelogGeneratorService** fetches diff via Octokit, sends to Anthropic API
4. Creates **Update** record with `status: draft` for human review
5. User reviews/publishes via dashboard, visible at `/:project_slug`

## Key Directories

- `app/services/` - Business logic (GitHub fetching, AI prompting)
- `app/jobs/` - Sidekiq workers for async processing
- `app/controllers/webhooks/` - Incoming API events from GitHub
- `docs/phases/` - Phase-by-phase implementation documentation

## Environment Variables

Required in `.env`:
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` - OAuth for GitHub App
- `ANTHROPIC_API_KEY` - Claude API access
- `REDIS_URL` - For Sidekiq (default: `redis://localhost:6379/1`)
- `HOST_URL` - Webhook callback URL (use ngrok for local dev)
