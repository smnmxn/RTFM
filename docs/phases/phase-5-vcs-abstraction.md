# Phase 5: VCS Provider Abstraction Layer

## What Was Built

A provider abstraction layer (`Vcs::` module) that wraps all VCS-specific code behind a common interface. This decouples the application from GitHub-specific APIs, enabling future support for Bitbucket, Azure DevOps, GitLab, etc.

### Architecture

- **`Vcs::Base`** — Abstract base class defining the adapter contract (auth, repos, diffs, listing, webhooks, URLs)
- **`Vcs::Provider`** — Factory with registry: `Vcs::Provider.for(:github)` returns the GitHub adapter
- **`Vcs::Error`** hierarchy — Provider-agnostic errors (`AuthenticationError`, `NotFoundError`, `RateLimitError`, `ProviderError`)
- **`Vcs::Github::Adapter`** — Full GitHub implementation wrapping Octokit, with error mapping
- **`Vcs::Github::AppService`** — Extracted from `GithubAppService` (JWT, tokens, webhook verification)
- **`Vcs::Github::Normalizer`** — Centralizes Octokit response → plain hash conversion
- **`Vcs::Github::WebhookHandler`** — Extracts event parsing from webhook controller

### Migration

- Added `provider` column (default: `"github"`) to `project_repositories` with index
- No column renames — `repo_identifier` and `vcs_installation_id` are aliases on the model

## Files Created

- `app/services/vcs/error.rb` — Error hierarchy
- `app/services/vcs/base.rb` — Abstract adapter interface
- `app/services/vcs/provider.rb` — Factory/registry
- `app/services/vcs/github/adapter.rb` — GitHub adapter implementation
- `app/services/vcs/github/app_service.rb` — GitHub App JWT/token logic
- `app/services/vcs/github/normalizer.rb` — Response normalization
- `app/services/vcs/github/webhook_handler.rb` — Webhook event parsing
- `db/migrate/XXXX_add_provider_to_project_repositories.rb`

## Files Modified

- `app/models/project_repository.rb` — Added `provider`, `vcs_adapter`, `vcs_client`, aliases
- `app/models/project.rb` — Added `vcs_client`, `github_client` as alias, `Vcs::Error` rescue
- `app/services/github_app_service.rb` — Now delegates to `Vcs::Github::AppService`
- `app/services/github_branches_service.rb` — Uses adapter via `Vcs::Provider.for(provider)`
- `app/services/github_pull_requests_service.rb` — Uses adapter for listing
- `app/services/github_commits_service.rb` — Uses adapter for listing
- `app/services/github_repositories_service.rb` — Uses `Normalizer.repository` for formatting
- `app/jobs/analyze_pull_request_job.rb` — Added `Vcs::Error` retry, adapter for clone URLs
- `app/jobs/analyze_codebase_job.rb` — Adapter for clone URLs in repos JSON
- `app/jobs/analyze_commit_job.rb` — Added `Vcs::Error` retry, adapter for clone URLs
- `app/controllers/webhooks/github_controller.rb` — Delegates to `WebhookHandler`
- `app/controllers/onboarding/projects_controller.rb` — Sets `provider`, passes to services, uses adapter
- `docker/claude-analyzer/analyze_pr.sh` — Accepts `VCS_REPOS_JSON` + `clone_url` field
- `docker/claude-analyzer/analyze.sh` — Same
- `docker/claude-analyzer/analyze_commit.sh` — Same
- `docker/claude-analyzer/check_article_updates.sh` — Accepts `CLONE_URL` env var

## Configuration Changes

- New `provider` column on `project_repositories` (default: `"github"`)
- Docker scripts accept `VCS_REPOS_JSON` as primary env var (with `GITHUB_REPOS_JSON` fallback)
- Docker scripts accept `clone_url` field in repos JSON (falls back to GitHub URL construction)

## How to Test

```bash
# Run migration
bin/rails db:migrate

# Run unit/integration tests
bin/rails test

# Console smoke test
adapter = Vcs::Provider.for(:github)
adapter.provider_name # => :github
adapter.class # => Vcs::Github::Adapter

# Adding a new provider (future):
# 1. Create app/services/vcs/bitbucket/adapter.rb implementing Vcs::Base
# 2. Add to Vcs::Provider::ADAPTERS hash
# 3. Set provider: "bitbucket" on ProjectRepository records
```
