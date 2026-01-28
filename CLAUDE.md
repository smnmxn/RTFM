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

RTFM is a developer-first platform that automatically converts code changes into user-facing product communication. When a PR is merged on GitHub, the system analyzes the diff and generates changelog entries and social media snippets using AI.

## Tech Stack

- **Backend**: Ruby 3.3.6, Rails 8.1, SQLite (dev), Sidekiq (Redis)
- **Frontend**: Tailwind CSS, Hotwire (Turbo & Stimulus), ERB
- **Auth**: Devise + OmniAuth GitHub (Phase 2)
- **AI**: Claude Code CLI (in Docker), Anthropic API
- **VCS**: GitHub API via Octokit
- **Image Generation**: Puppeteer + Chromium (in Docker)
- **Testing**: Minitest, Playwright (E2E)

## Development Commands

```bash
# Install dependencies
bundle install

# Database setup
rails db:create db:migrate

# Start all services (Rails server, Tailwind watcher, Sidekiq)
bin/dev

# Run tests (see Testing section below for details)
rails test              # Unit/integration tests
rails test:e2e          # E2E browser tests

# Rebuild Docker analyzer image (after changing docker/claude-analyzer/*)
docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/
```

## Testing

The project uses **Minitest** for unit/integration tests and **Playwright** for E2E browser tests.

### Test Commands

```bash
# Run all unit and integration tests
rails test

# Run a single test file
rails test test/path/to/test_file.rb

# Run a specific test by line number
rails test test/path/to/test_file.rb:LINE_NUMBER

# Run E2E tests (headless browser)
rails test:e2e

# Run E2E tests with visible browser (for debugging)
HEADLESS=false rails test:e2e

# Run E2E tests in slow motion (milliseconds delay between actions)
SLOW_MO=500 rails test:e2e
```

### Test Directory Structure

```
test/
├── models/              # Model unit tests
├── controllers/         # Controller integration tests
├── services/            # Service object tests
├── jobs/                # Sidekiq job tests
├── constraints/         # Route constraint tests
├── e2e/                 # Playwright E2E tests
│   ├── flows/           # User journey tests
│   ├── pages/           # Page Object models
│   └── support/         # E2E helpers (auth, wait, etc.)
├── fixtures/            # Test data (YAML)
├── test_helper.rb       # Unit test configuration
└── e2e_test_helper.rb   # E2E test configuration
```

### E2E Test Infrastructure

E2E tests use Playwright to automate a real browser against a running Rails server:

- **Server**: Puma starts automatically on a random port
- **Browser**: Headless Chromium (configurable via `HEADLESS=false`)
- **Screenshots**: Automatically captured on test failure in `tmp/screenshots/`

**Writing E2E Tests:**

```ruby
require "e2e_test_helper"

class MyFlowTest < E2ETestCase
  test "user can visit login page" do
    visit "/login"
    assert_path "/login"
    assert has_text?("Sign in")
  end
end
```

**Available Helpers:**
- `visit(path)` - Navigate to a URL
- `assert_path(path)` - Assert current URL contains path
- `has_text?(text)` - Check if text is visible
- `click_button(text)` / `click_link(text)` - Click elements
- `fill_in(selector, with: value)` - Fill form fields
- `wait_for_turbo` - Wait for Turbo navigation to complete

### Test Fixtures

Test data is defined in `test/fixtures/*.yml`. Key fixtures:
- `users.yml` - Test users with GitHub OAuth credentials
- `projects.yml` - Test projects with webhook secrets
- `articles.yml` - Draft and published articles

OmniAuth is configured in test mode (`test_helper.rb`) with a `sign_in_as(user)` helper for controller tests.

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
- `docker/claude-analyzer/` - Docker image with Claude Code CLI for codebase analysis and article generation
- `docs/phases/` - Phase-by-phase implementation documentation
- `test/` - Test suite (Minitest + Playwright E2E)
- `test/e2e/` - End-to-end browser tests with Playwright

## Environment Variables

Required in `.env`:
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` - OAuth for GitHub App
- `REDIS_URL` - For Sidekiq (default: `redis://localhost:6379/1`)
- `HOST_URL` - Webhook callback URL (use ngrok for local dev)

### Claude Code Authentication

The Docker analyzer container needs Claude API access. You have two options:

**Option 1: Max Subscription (recommended for development)**

Use your Claude Max subscription credits instead of API credits:

```bash
# 1. Set up a long-lived token on your host machine
claude setup-token

# 2. Extract the token from macOS Keychain
security find-generic-password -s "claude-code" -w

# 3. Add to .env.docker
CLAUDE_CODE_OAUTH_TOKEN=<token-from-step-2>
```

**Option 2: API Key**

Use a standard Anthropic API key (uses API credits):

```bash
# Add to .env or .env.docker
ANTHROPIC_API_KEY=sk-ant-...
```

**Testing authentication:**

```bash
docker-compose run --rm web bin/rails claude:test_auth
```

The system uses `CLAUDE_CODE_OAUTH_TOKEN` if present, otherwise falls back to `ANTHROPIC_API_KEY`.

### Custom Domain Support (Cloudflare for SaaS)

For custom domain functionality (e.g., `help.yourdomain.com`):

- `CLOUDFLARE_ZONE_ID` - Cloudflare zone ID for the base domain
- `CLOUDFLARE_API_TOKEN` - API token with Custom Hostnames permissions
- `CLOUDFLARE_FALLBACK_ORIGIN` - Fallback origin (default: `supportpages.io`)

**Cloudflare API Token Permissions:**
- Zone > SSL and Certificates > Edit
- Zone > Custom Hostnames > Edit

The Cloudflare for SaaS feature must be enabled on the zone (requires Business/Enterprise plan, or add-on).
