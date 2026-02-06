# RTFM MVP Summary

**Last Updated:** February 2026

## Overview

RTFM is a developer-first platform that automatically converts code changes into user-facing documentation. When a PR is merged, the system analyzes the diff and generates changelog entries, article recommendations, and full help articles using AI.

**Current Status:** 8 of 10 phases complete

**Core Workflow:**
```
PR Merge → Webhook → AI Analysis → Draft Content → Human Review → Publish to Help Centre
```

---

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 0 | Project Bootstrap & Config | ✓ Complete |
| 1 | Core Data Models | ✓ Complete |
| 2 | GitHub Auth & Webhook Ingest | ✓ Complete |
| 2.5 | Codebase Understanding | ✓ Complete |
| 3 | AI-Powered PR Analysis | ✓ Complete |
| 3.5 | Support Article Recommendations | ✓ Complete |
| 3.6 | AI-Generated UI Mockups | ✓ Complete |
| 4 | Custom Domain Support | ✓ Complete |
| 5 | Public Changelog Page | ⏳ Pending |
| 6 | Polish & Deployment | ⏳ Pending |

---

## Working Features

### Authentication & Projects
- GitHub OAuth login (Devise + OmniAuth)
- Multi-repository project support
- 5-step onboarding wizard (connect repos → setup → analyze → sections → recommendations)
- GitHub App installation management with JWT tokens
- Invite-based user signup

### AI Pipeline (Docker-based)
- **Codebase Analysis**: Generates tech stack summary, patterns, styling context
- **PR/Commit Analysis**: Processes diffs to understand changes
- **Changelog Generation**: Creates user-focused summaries of changes
- **Article Recommendations**: Suggests documentation articles with justifications (max 3 per PR)
- **Article Generation**: Produces structured content (intro, prerequisites, steps, tips, summary)
- **Mockup Rendering**: Puppeteer generates UI screenshots for article steps
- Configurable Claude model selection and max turns

### Help Centre
- Public site at subdomain (`*.supportpages.io`)
- Custom domain support via Cloudflare for SaaS (`help.yourdomain.com`)
- Section-based article organization
- AI-powered chat/ask feature with streaming responses
- Dark mode support
- Mobile-responsive design

### Content Management
- Inbox for reviewing AI-generated recommendations and articles
- Structured article editor with inline editing
- Section management (templates + custom)
- Publish/draft workflow with approval states
- Branding customization (logo, colors, contact info)
- Article reordering and section assignment

### Background Jobs (Sidekiq)
| Job | Purpose |
|-----|---------|
| `AnalyzeCodebaseJob` | Full repository analysis |
| `AnalyzePullRequestJob` | PR diff analysis |
| `GenerateArticleJob` | Article content + mockups |
| `SuggestSectionsJob` | AI section recommendations |
| `SetupCustomDomainJob` | Cloudflare domain setup |
| `CheckCustomDomainStatusJob` | DNS/SSL verification |
| `RemoveCustomDomainJob` | Domain cleanup |

---

## Key Integrations

| Integration | Purpose |
|-------------|---------|
| GitHub API (Octokit) | OAuth, webhooks, diff fetching, installation tokens |
| Claude AI (Docker CLI) | All analysis and content generation |
| Cloudflare for SaaS | Custom domain SSL provisioning |
| Puppeteer/Chromium | Mockup image rendering in Docker |
| ActionCable | Real-time UI updates via Turbo Streams |
| Redis | Sidekiq jobs, token caching, user status |

---

## Data Models

| Model | Purpose |
|-------|---------|
| `User` | GitHub-authenticated users with notification prefs |
| `Project` | Documentation projects with branding/settings |
| `ProjectRepository` | Multi-repo support per project |
| `GithubAppInstallation` | GitHub App auth tracking |
| `Update` | PR/commit analysis results (changelog content) |
| `Recommendation` | AI-suggested article topics |
| `Article` | Generated documentation with structured content |
| `Section` | Article categories (Getting Started, etc.) |
| `StepImage` | Mockup screenshots for article steps |
| `ClaudeUsage` | API usage tracking and metrics |

---

## Tech Stack

- **Backend:** Ruby 3.3.6, Rails 8.1, SQLite (dev), Sidekiq + Redis
- **Frontend:** Tailwind CSS, Hotwire (Turbo + Stimulus), ERB
- **Auth:** Devise + OmniAuth GitHub
- **AI:** Claude API via Claude Code CLI (Docker)
- **Testing:** Minitest + Playwright E2E

---

## What's Missing

### Phase 5: Public Changelog Page
- Public-facing changelog view at `/:project_slug`
- Shows published updates in timeline format

### Phase 6: Polish & Deployment
- Production deployment configuration
- Monitoring and observability
- UI refinements and edge case handling

---

## Quick Reference

```bash
# Start development
bin/dev

# Run tests
rails test              # Unit/integration
rails test:e2e          # Browser tests

# Rebuild analyzer image
docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/

# Test Claude auth
docker-compose run --rm web bin/rails claude:test_auth
```

---

## Documentation

- Phase details: `docs/phases/phase-*.md`
- Project setup: `CLAUDE.md`
- Test infrastructure: `test/` directory
