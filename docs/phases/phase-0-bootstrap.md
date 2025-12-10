# Phase 0: Project Bootstrap & Config

**Status:** Complete

## Overview

Initial project setup with Rails 8.1, SQLite, Sidekiq, and Tailwind CSS.

## What Was Built

### Core Framework
- **Rails 8.1** application with Propshaft asset pipeline
- **Ruby 3.3.6** (managed via mise, see `.tool-versions`)
- **SQLite** for development/test databases (stored in `storage/`)

### Background Jobs
- **Sidekiq 8.0.10** configured as Active Job adapter
- Redis connection via `REDIS_URL` environment variable
- Queue configuration in `config/sidekiq.yml`

### Frontend
- **Tailwind CSS** with watch mode in development
- **Hotwire** (Turbo + Stimulus) for SPA-like interactivity
- **Importmap** for JavaScript module loading

### Development Environment
- **Procfile.dev** runs all services via foreman:
  - `web`: Rails server on port 3000
  - `css`: Tailwind CSS watcher
  - `worker`: Sidekiq background processor
- **dotenv-rails** loads `.env` in development/test

## Files Created

| File | Purpose |
|------|---------|
| `config/sidekiq.yml` | Queue names and concurrency settings |
| `config/initializers/sidekiq.rb` | Redis connection configuration |
| `config/database.yml` | SQLite database configuration |
| `.env.example` | Template for required environment variables |
| `Procfile.dev` | Multi-process development runner |

## Configuration Changes

### `config/application.rb`
```ruby
config.active_job.queue_adapter = :sidekiq
```

### `Gemfile` additions
```ruby
gem "sqlite3", ">= 2.1"
gem "sidekiq"
gem "dotenv-rails", groups: [:development, :test]
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis connection for Sidekiq | `redis://localhost:6379/1` |
| `HOST_URL` | App URL for webhooks | `http://localhost:3000` |
| `GITHUB_CLIENT_ID` | GitHub OAuth (Phase 2) | - |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth (Phase 2) | - |
| `ANTHROPIC_API_KEY` | Claude API (Phase 3) | - |

## Running the Application

```bash
# First time setup
cp .env.example .env
bundle install
bin/rails db:create db:migrate

# Start all services
bin/dev

# Or run individually
bin/rails server           # Web only
bundle exec sidekiq        # Worker only
bin/rails tailwindcss:watch  # CSS only
```

## Prerequisites

- Ruby 3.3.6 (install via `mise install`)
- Redis server running locally
- Node.js (for Tailwind CSS)

## Next Phase

**Phase 1: Core Data Models** - User, Project, and Update models with associations.
