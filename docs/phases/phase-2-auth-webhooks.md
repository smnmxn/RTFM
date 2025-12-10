# Phase 2: GitHub Auth & Webhook Ingest

**Status:** Complete

## Overview

Implemented GitHub OAuth authentication and webhook ingestion to receive PR merge events and create draft changelog updates.

## Features

### GitHub OAuth Authentication
- GitHub-only authentication (no email/password)
- Session-based login with `current_user` helper
- Automatic token refresh on each login
- Protected routes via `require_authentication` before_action

### Webhook Ingestion
- Receives GitHub webhook events at `POST /webhooks/github`
- Verifies webhook signatures using HMAC SHA-256
- Processes merged pull request events only
- Enqueues background job to fetch PR diff and create Update

## Setup Guide

### 1. Create GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click **New OAuth App**
3. Fill in:
   - **Application name**: Ship & Shout (or your app name)
   - **Homepage URL**: `http://localhost:3000` (or your domain)
   - **Authorization callback URL**: `http://localhost:3000/auth/github/callback`
4. Click **Register application**
5. Copy the **Client ID**
6. Generate and copy a **Client Secret**

### 2. Configure Environment Variables

Add to your `.env` file:

```bash
GITHUB_CLIENT_ID=your_client_id_here
GITHUB_CLIENT_SECRET=your_client_secret_here
```

### 3. Create a Project

Start the app and sign in via GitHub, then create a project in Rails console:

```ruby
# In rails console
user = User.first
project = user.projects.create!(
  name: "My Project",
  github_repo: "owner/repo-name"  # Must match exactly
)
puts "Webhook Secret: #{project.webhook_secret}"
```

**Save the webhook secret** - you'll need it for GitHub.

### 4. Configure GitHub Webhook

1. Go to your repo → **Settings** → **Webhooks** → **Add webhook**
2. Fill in:
   - **Payload URL**: `https://your-domain.com/webhooks/github`
   - **Content type**: `application/json`
   - **Secret**: paste the `webhook_secret` from step 3
   - **Events**: Select **"Pull requests"** only
3. Click **Add webhook**

### 5. Local Development with ngrok

For testing webhooks locally:

```bash
# Terminal 1: Start the app
bin/dev

# Terminal 2: Expose via ngrok
ngrok http 3000
```

Use the ngrok HTTPS URL for your webhook payload URL.

### 6. Organization Repositories

If using a GitHub organization repository, an org admin must approve your OAuth app:

1. Go to `https://github.com/organizations/YOUR_ORG/settings/oauth_application_policy`
2. Find your OAuth app
3. Click **Grant** or **Approve**

## Files Created/Modified

| Action | File | Purpose |
|--------|------|---------|
| Add | `Gemfile` | Added omniauth, omniauth-github, octokit gems |
| Create | `config/initializers/omniauth.rb` | OmniAuth configuration |
| Modify | `app/models/user.rb` | Added `find_or_create_from_omniauth` |
| Modify | `app/models/project.rb` | Added webhook secret generation & verification |
| Modify | `app/controllers/application_controller.rb` | Added auth helpers |
| Create | `app/controllers/sessions_controller.rb` | OAuth login/logout |
| Create | `app/controllers/dashboard_controller.rb` | Post-login dashboard |
| Create | `app/controllers/webhooks/github_controller.rb` | Webhook handler |
| Create | `app/jobs/analyze_pull_request_job.rb` | PR processing job |
| Modify | `config/routes.rb` | Auth and webhook routes |
| Create | `app/views/sessions/new.html.erb` | Login page |
| Create | `app/views/dashboard/show.html.erb` | Dashboard view |

## Routes

| Method | Path | Controller | Purpose |
|--------|------|------------|---------|
| GET | `/` | sessions#new | Login page (root) |
| GET | `/login` | sessions#new | Login page |
| GET | `/logout` | sessions#destroy | Logout |
| DELETE | `/logout` | sessions#destroy | Logout |
| GET | `/auth/github/callback` | sessions#create | OAuth callback |
| GET | `/auth/failure` | sessions#failure | OAuth failure |
| GET | `/dashboard` | dashboard#show | User dashboard |
| POST | `/webhooks/github` | webhooks/github#create | Webhook receiver |

## Testing

```bash
# Run all tests
bin/rails test

# Run specific test files
bin/rails test test/controllers/sessions_controller_test.rb
bin/rails test test/controllers/webhooks/github_controller_test.rb
bin/rails test test/jobs/analyze_pull_request_job_test.rb
```

53 tests, 123 assertions, all passing.

## Webhook Flow

```
GitHub PR Merge
     ↓
POST /webhooks/github
     ↓
Verify signature (HMAC SHA-256)
     ↓
Find project by github_repo
     ↓
Check: action == "closed" && merged == true
     ↓
Enqueue AnalyzePullRequestJob
     ↓
Job fetches PR diff via Octokit
     ↓
Create Update record (status: draft)
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_CLIENT_ID` | Yes | OAuth app client ID |
| `GITHUB_CLIENT_SECRET` | Yes | OAuth app client secret |
| `REDIS_URL` | No | Redis for Sidekiq (default: `redis://localhost:6379/1`) |

## Next Phase

**Phase 3: AI Service Integration** - Replace placeholder content with AI-generated changelogs using the Anthropic API.
