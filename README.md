# SupportPages

A developer-first platform that automatically generates and maintains help documentation from your codebase. Connect your GitHub repos, and SupportPages uses AI to create and keep your Help Centre articles up to date.

## Features

- **AI-Powered Documentation**: Analyzes your codebase to generate help articles
- **GitHub Integration**: Connects via GitHub App to monitor your repositories
- **Help Centre**: Public-facing help centre with search and AI chat
- **Custom Domains**: Serve your Help Centre from your own domain (e.g., `help.yourcompany.com`)
- **Multi-Repository**: Connect multiple repos to a single project

## Tech Stack

- **Backend**: Ruby 3.3.6, Rails 8.1, PostgreSQL, Sidekiq (Redis)
- **Frontend**: Tailwind CSS, Hotwire (Turbo & Stimulus)
- **AI**: Anthropic Claude API, Claude Code CLI
- **Infrastructure**: Docker, Kamal, Cloudflare

## Prerequisites

### For Local Development
- Ruby 3.3.6
- PostgreSQL 16+
- Redis 7+
- Node.js (for asset compilation)

### For Docker Development (Recommended)
- Docker & Docker Compose

## Development Setup

### Option A: Docker Development (Recommended)

Docker development uses `bin/docker-dev` to manage all services in containers.

**Dependencies:**

The development environment requires two separate Docker components:

1. **Docker Compose services** - PostgreSQL, Redis, Rails, Sidekiq, Tailwind (managed by `docker-compose.yml`)
2. **Claude Analyzer image** - `rtfm/claude-analyzer:latest` (built separately, spawned on-demand by worker)

The `bin/docker-dev setup` command builds both automatically.

**Quick Start:**

```bash
# 1. Copy and configure environment
cp .env.docker.example .env.docker
# Edit .env.docker with your GitHub OAuth credentials

# 2. Initial setup (builds containers, creates claude-analyzer image)
bin/docker-dev setup

# 3. Start all services
bin/docker-dev up

# Visit http://localhost:3000
```

**Available Commands:**

| Command | Description |
|---------|-------------|
| `bin/docker-dev setup` | Initial setup - builds containers, creates .env.docker |
| `bin/docker-dev up` | Start all services (foreground) |
| `bin/docker-dev upd` | Start all services (detached/background) |
| `bin/docker-dev down` | Stop all services |
| `bin/docker-dev restart` | Restart all services |
| `bin/docker-dev rebuild` | Rebuild docker-compose containers (not claude-analyzer) |
| `bin/docker-dev console` | Open Rails console |
| `bin/docker-dev bash` | Open shell in web container |
| `bin/docker-dev logs [service]` | Follow container logs |
| `bin/docker-dev test [path]` | Run tests (optionally specific path) |
| `bin/docker-dev migrate` | Run database migrations |
| `bin/docker-dev bundle` | Install gems |
| `bin/docker-dev reset` | Full reset - removes containers and volumes |
| `bin/docker-dev status` | Show container status |

**Rebuilding the Claude Analyzer:**

If you modify files in `docker/claude-analyzer/`, rebuild the image:

```bash
docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/
```

### Option B: Local Development

```bash
# Install dependencies
bundle install

# Set up database
bin/rails db:create db:migrate

# Start all services (Rails server, Tailwind watcher, Sidekiq)
bin/dev

# Visit http://localhost:3000
```

Requires PostgreSQL and Redis running locally.

## Running Tests

### With Docker

```bash
# Run all tests
bin/docker-dev test

# Run specific test file
bin/docker-dev test test/models/project_test.rb

# Run specific test by line number
bin/docker-dev test test/models/project_test.rb:42
```

### Local

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/project_test.rb

# Run specific test by line number
rails test test/models/project_test.rb:42

# Run tests in parallel (uses all CPU cores)
PARALLEL_WORKERS=4 rails test
```

## Production Deployment with Kamal

SupportPages uses [Kamal](https://kamal-deploy.org/) for zero-downtime deployments.

### Prerequisites

1. **Kamal installed**: `gem install kamal`
2. **Docker registry access**: Push access to `ghcr.io/togetherlyhub/supportpages`
3. **Server SSH access**: SSH key configured for deployment server
4. **Secrets configured**: `.kamal/secrets` file with required credentials

### Secrets Setup

Create `.kamal/secrets` with:

```bash
RAILS_MASTER_KEY=<from config/master.key>
POSTGRES_PASSWORD=<secure password>
DATABASE_URL=postgresql://supportpages:<password>@supportpages-db:5432/supportpages_production

# AI
ANTHROPIC_API_KEY=sk-ant-...
CLAUDE_CODE_OAUTH_TOKEN=<optional, for Claude Max subscription>

# GitHub App
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
GITHUB_APP_ID=...
GITHUB_APP_SLUG=...
GITHUB_APP_PRIVATE_KEY=<base64 encoded>
GITHUB_APP_WEBHOOK_SECRET=...

# Email
POSTMARK_API_TOKEN=...

# Cloudflare (for custom domains)
CLOUDFLARE_ZONE_ID=...
CLOUDFLARE_API_TOKEN=...
```

### Deployment Commands

```bash
# First-time setup (provisions server, sets up containers)
kamal setup

# Deploy new version
kamal deploy

# View application logs
kamal app logs

# Open Rails console on production
kamal console

# Execute command in container
kamal app exec 'bin/rails db:migrate'

# Rollback to previous version
kamal rollback

# Check deployment status
kamal details
```

### Configuration

Deployment configuration is in `config/deploy.yml`. Key settings:

- **Registry**: `ghcr.io`
- **Architecture**: `arm64` (Apple Silicon compatible)
- **Services**: Web server + Sidekiq worker
- **Accessories**: PostgreSQL, Redis

## Architecture & Dependencies

### Development Stack (Docker Compose)

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Compose                        │
├─────────────┬─────────────┬─────────────┬───────────────┤
│    web      │   worker    │     css     │               │
│  (Rails)    │ (Sidekiq)   │ (Tailwind)  │               │
│  :3000      │             │             │               │
├─────────────┴─────────────┴─────────────┤               │
│                                          │               │
│              Shared Volumes              │               │
│                                          │               │
├──────────────────────┬───────────────────┤               │
│         db           │      redis        │               │
│   (PostgreSQL 16)    │    (Redis 7)      │               │
└──────────────────────┴───────────────────┘               │
                                                           │
┌─────────────────────────────────────────────────────────┐
│              claude-analyzer (on-demand)                 │
│  - Claude Code CLI                                       │
│  - Puppeteer + Chromium                                  │
│  - Spawned via Docker socket for code analysis           │
└─────────────────────────────────────────────────────────┘
```

| Service | Description | Port |
|---------|-------------|------|
| `web` | Rails application server | 3000 |
| `worker` | Sidekiq background job processor | - |
| `css` | Tailwind CSS watcher | - |
| `db` | PostgreSQL 16 database | 5432 |
| `redis` | Redis for Sidekiq job queue | 6379 |

### Production Stack (Kamal)

| Service | Description |
|---------|-------------|
| `supportpages` | Main Rails application |
| `supportpages-worker` | Sidekiq worker with Docker socket access |
| `supportpages-db` | PostgreSQL 16 accessory |
| `supportpages-redis` | Redis 7 accessory |

### Claude Analyzer Container

A specialized Docker container spawned on-demand for AI-powered code analysis. This container is **not** part of docker-compose - it's built separately and spawned by the worker when needed.

**What it does:**
- Analyzes pull requests and commits to generate changelog entries
- Generates help articles from codebase context
- Renders HTML mockups to images using Puppeteer/Chromium
- Suggests documentation sections based on code

**Container contents:**
- **Base**: Node 20 with Chromium
- **Tools**: Claude Code CLI, Puppeteer, jsdom
- **Scripts**: `analyze_pr.sh`, `analyze_commit.sh`, `generate_article.sh`, `render_mockup.sh`, and more

**When to rebuild:**

Rebuild the claude-analyzer image when you modify any files in `docker/claude-analyzer/`:
- Analysis scripts (`analyze_pr.sh`, `generate_article.sh`, etc.)
- The Dockerfile itself
- The entrypoint script

**How to rebuild:**

```bash
# Standalone rebuild
docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/

# Or as part of full setup
bin/docker-dev setup
```

**Note:** The `bin/docker-dev rebuild` command only rebuilds docker-compose services, not the claude-analyzer. You must explicitly rebuild it using the commands above.

**How it's spawned:**

The worker container has access to the Docker socket (`/var/run/docker.sock`), allowing it to spawn claude-analyzer containers as siblings. This "Docker-from-Docker" pattern means:
- The worker doesn't run analysis directly
- Each analysis runs in an isolated container
- The `rtfm/claude-analyzer:latest` image must exist locally

## Environment Variables Reference

### Required for Development

| Variable | Description |
|----------|-------------|
| `GITHUB_CLIENT_ID` | GitHub OAuth App client ID |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth App secret |
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Max subscription token (alternative to API key) | - |
| `HOST_URL` | Webhook callback URL | `http://localhost:3000` |
| `DATABASE_URL` | PostgreSQL connection string | Set in docker-compose |
| `REDIS_URL` | Redis connection string | Set in docker-compose |

### Production Only

| Variable | Description |
|----------|-------------|
| `RAILS_MASTER_KEY` | Rails credentials decryption key |
| `BASE_DOMAIN` | Base domain for the application |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID for custom domains |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `CLOUDFLARE_FALLBACK_ORIGIN` | Fallback origin for custom domains |
| `POSTMARK_API_TOKEN` | Postmark email service token |
| `GITHUB_APP_*` | GitHub App credentials (ID, slug, private key, webhook secret) |

## Custom Domains

SupportPages supports custom domains for Help Centres, allowing you to serve your documentation from your own domain instead of `yourproject.supportpages.io`.

### Setup

1. **Add your domain** in Project Settings → Custom Domain
2. **Configure DNS** by adding a CNAME record:
   ```
   Type: CNAME
   Name: help (or your subdomain)
   Target: yourproject.supportpages.io
   ```
3. **Wait for verification** - SSL is automatically provisioned via Cloudflare

### DNS Example

To set up `help.acme.com` for a project with subdomain `acme`:

| Type  | Name | Target                  |
|-------|------|-------------------------|
| CNAME | help | acme.supportpages.io    |

### Notes

- SSL certificates are automatically provisioned (no manual setup required)
- Once active, the subdomain URL redirects to your custom domain
- DNS propagation can take up to 24 hours, but usually completes within minutes
- If using Cloudflare for your domain, keep the record **proxied** (orange cloud)

## Documentation

See [docs/README.md](docs/README.md) for detailed phase-by-phase implementation documentation.

## License

Proprietary - All rights reserved.
