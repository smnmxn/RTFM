# Phase 6: Bitbucket Cloud Integration

## What Was Built

Added Bitbucket Cloud as a second VCS provider with full parity alongside GitHub:
- OAuth 2.0 Consumer authentication flow
- VCS adapter layer (adapter, client, normalizer, webhook handler, webhook manager, token manager)
- Webhook controller for receiving Bitbucket events
- Repository listing service for onboarding
- Per-repo webhook registration on connect
- UI updates showing both GitHub and Bitbucket repos in the onboarding picker
- Provider-agnostic refactoring of jobs and services

## Files Created

### Models
- `app/models/bitbucket_connection.rb` — OAuth token storage per workspace

### VCS Adapter Layer
- `app/services/vcs/bitbucket/adapter.rb` — Full `Vcs::Base` implementation
- `app/services/vcs/bitbucket/client.rb` — Faraday HTTP client for Bitbucket API v2.0
- `app/services/vcs/bitbucket/token_manager.rb` — OAuth token refresh logic
- `app/services/vcs/bitbucket/normalizer.rb` — API response normalization
- `app/services/vcs/bitbucket/webhook_handler.rb` — Webhook event parsing
- `app/services/vcs/bitbucket/webhook_manager.rb` — Per-repo webhook CRUD

### Controllers
- `app/controllers/bitbucket_app_controller.rb` — OAuth install/callback
- `app/controllers/webhooks/bitbucket_controller.rb` — Webhook receiver

### Services
- `app/services/bitbucket_repositories_service.rb` — Lists repos from Bitbucket workspaces

### Migrations
- `db/migrate/*_create_bitbucket_connections.rb`
- `db/migrate/*_add_webhook_uuid_to_project_repositories.rb`

### Tests
- `test/models/bitbucket_connection_test.rb`
- `test/services/vcs/bitbucket/adapter_test.rb`
- `test/services/vcs/bitbucket/normalizer_test.rb`
- `test/services/vcs/bitbucket/webhook_handler_test.rb`
- `test/controllers/webhooks/bitbucket_controller_test.rb`
- `test/fixtures/bitbucket_connections.yml`

## Files Modified

### Models
- `app/models/user_identity.rb` — Added `"bitbucket"` to provider validation
- `app/models/project_repository.rb` — Added `installation_record`, `cleanup_webhook` callback

### Adapter Registration
- `app/services/vcs/provider.rb` — Added `bitbucket` to `ADAPTERS` hash

### Controllers
- `app/controllers/projects_controller.rb` — Merged GitHub + Bitbucket repo listing
- `app/controllers/onboarding/projects_controller.rb` — Provider-aware connect logic

### Jobs (Provider-Agnostic Refactoring)
- `app/jobs/analyze_pull_request_job.rb` — Uses adapter instead of direct Octokit
- `app/jobs/analyze_commit_job.rb` — Uses adapter instead of direct Octokit
- `app/jobs/generate_article_job.rb` — Uses adapter for PR diff fetching
- `app/jobs/weekly_analysis_job.rb` — Uses adapter for PR listing

### Services
- `app/services/github_pull_requests_service.rb` — Provider-aware fallback
- `app/services/github_commits_service.rb` — Provider-aware fallback

### Views
- `app/views/projects/_repository_list.html.erb` — Provider icons, dual CTAs

### Config
- `config/routes.rb` — Bitbucket webhook and OAuth routes
- `Gemfile` — Added `faraday` gem

## New Environment Variables

- `BITBUCKET_CLIENT_ID` — OAuth Consumer Key
- `BITBUCKET_CLIENT_SECRET` — OAuth Consumer Secret
- `BITBUCKET_WEBHOOK_SECRET` — Shared secret for webhook HMAC verification

## How to Test

1. **Unit tests**: `rails test test/models/bitbucket_connection_test.rb test/services/vcs/bitbucket/ test/controllers/webhooks/bitbucket_controller_test.rb`
2. **Manual OAuth**: Set `BITBUCKET_CLIENT_ID`/`BITBUCKET_CLIENT_SECRET`, click "Connect Bitbucket" in onboarding
3. **Manual webhook**: Send a test `pullrequest:fulfilled` payload to `/webhooks/bitbucket` with valid HMAC signature
4. **Full suite**: `rails test` (27 new tests, no regressions)
