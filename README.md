# SupportPages

A developer-first platform that automatically generates and maintains help documentation from your codebase. Connect your GitHub repos, and SupportPages uses AI to create and keep your Help Centre articles up to date.

## Features

- **AI-Powered Documentation**: Analyzes your codebase to generate help articles
- **GitHub Integration**: Connects via GitHub App to monitor your repositories
- **Help Centre**: Public-facing help centre with search and AI chat
- **Custom Domains**: Serve your Help Centre from your own domain (e.g., `help.yourcompany.com`)
- **Multi-Repository**: Connect multiple repos to a single project

## Quick Start

```bash
cp .env.example .env    # Configure environment
bundle install          # Install dependencies
bin/rails db:migrate    # Set up database
bin/dev                 # Start all services
```

Visit http://localhost:3000

## Custom Domains

SupportPages supports custom domains for Help Centres, allowing you to serve your documentation from your own domain instead of `yourproject.supportpages.io`.

### How It Works

1. **Add your domain** in Project Settings → Custom Domain
2. **Configure DNS** by adding a CNAME record:
   ```
   Type: CNAME
   Name: help (or your subdomain)
   Target: yourproject.supportpages.io
   ```
3. **Wait for verification** - SSL is automatically provisioned via Cloudflare
4. **Done!** Your Help Centre is now accessible at your custom domain

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

## Tech Stack

- **Backend**: Ruby 3.3, Rails 8.1, PostgreSQL, Sidekiq (Redis)
- **Frontend**: Tailwind CSS, Hotwire (Turbo & Stimulus)
- **AI**: Anthropic Claude API
- **Infrastructure**: Kamal, Cloudflare

## Documentation

See [docs/README.md](docs/README.md) for detailed development documentation.

## License

Proprietary - All rights reserved.
