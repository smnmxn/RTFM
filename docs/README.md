# supportpages.io Documentation

## Development Phases

| Phase | Description | Status |
|-------|-------------|--------|
| [Phase 0](phases/phase-0-bootstrap.md) | Project Bootstrap & Config | Complete |
| [Phase 1](phases/phase-1-models.md) | Core Data Models (User, Project, Update) | Complete |
| [Phase 2](phases/phase-2-auth-webhooks.md) | GitHub Auth & Webhook Ingest | Complete |
| [Phase 2.5](phases/phase-2.5-codebase-understanding.md) | Codebase Understanding | Complete |
| [Phase 3](phases/phase-3-ai-pr-analysis.md) | AI Service Integration | Complete |
| [Phase 3.5](phases/phase-3.5-article-recommendations.md) | Support Article Recommendations | Complete |
| [Phase 3.6](phases/phase-3.6-article-mockups.md) | AI-Generated UI Mockups | Complete |
| Phase 4 | Editor Dashboard UI | Pending |
| Phase 5 | Public Changelog Page | Pending |
| Phase 6 | Polish & Deployment | Pending |

## Quick Start

```bash
cp .env.example .env    # Configure environment
bundle install          # Install dependencies
bin/rails db:migrate    # Set up database
bin/dev                 # Start all services
```

Visit http://localhost:3000

## Architecture

See [Phase 0](phases/phase-0-bootstrap.md) for current technical setup.

The application follows a **Webhook → Worker → Service** pattern:
1. GitHub webhook triggers on PR merge
2. Sidekiq job processes the event asynchronously
3. Service fetches diff and generates changelog via AI
4. Draft created for human review before publishing
