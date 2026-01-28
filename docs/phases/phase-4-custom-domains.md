# Phase 4: Custom Domain Support

## Overview

Implemented full custom domain support for Help Centres, allowing users to serve their help centre from their own domain (e.g., `help.yourdomain.com`) instead of the default subdomain (e.g., `acme.supportpages.io`).

## Features

- Custom domain configuration via Settings UI
- Automatic SSL provisioning via Cloudflare for SaaS
- DNS verification and status tracking
- Background jobs for async domain setup and health checks

## Architecture

**Flow:**
1. User enters custom domain in Settings → Custom Domain
2. `SetupCustomDomainJob` creates custom hostname via Cloudflare API
3. User adds CNAME record pointing to their subdomain (e.g., `acme.supportpages.io`)
4. `CheckCustomDomainStatusJob` polls Cloudflare until verified
5. Domain becomes active and routes to correct Help Centre

## Files Created

| File | Purpose |
|------|---------|
| `db/migrate/20260128122241_add_custom_domain_to_projects.rb` | Database migration for custom domain fields |
| `app/constraints/custom_domain_constraint.rb` | Route constraint for custom domain matching |
| `app/services/cloudflare_custom_hostname_service.rb` | Cloudflare API wrapper |
| `app/jobs/setup_custom_domain_job.rb` | Create hostname in Cloudflare |
| `app/jobs/check_custom_domain_status_job.rb` | Poll Cloudflare for verification |
| `app/jobs/remove_custom_domain_job.rb` | Remove hostname from Cloudflare |
| `app/jobs/refresh_custom_domain_status_job.rb` | Periodic health check |
| `app/views/projects/_custom_domain_form.html.erb` | Settings UI form |
| `test/models/project_custom_domain_test.rb` | Model tests |
| `test/constraints/custom_domain_constraint_test.rb` | Constraint tests |
| `test/services/cloudflare_custom_hostname_service_test.rb` | Service tests |

## Files Modified

| File | Changes |
|------|---------|
| `app/models/project.rb` | Added validations, callbacks, helper methods |
| `app/controllers/projects_controller.rb` | Added custom domain actions |
| `app/controllers/help_centre_controller.rb` | Check custom domains first |
| `app/views/projects/_settings_panel.html.erb` | Added Custom Domain tab |
| `config/routes.rb` | Added custom domain routes and constraint |
| `config/environments/production.rb` | Dynamic host authorization |
| `config/deploy.yml` | Added Cloudflare secrets |
| `CLAUDE.md` | Documented environment variables |

## Database Changes

New columns on `projects` table:
- `custom_domain` (string, unique) - The custom domain
- `custom_domain_status` (string, default: 'pending') - pending → verifying → active | failed
- `custom_domain_cloudflare_id` (string) - Cloudflare custom hostname ID
- `custom_domain_verified_at` (datetime) - When domain was verified
- `custom_domain_ssl_status` (string) - SSL certificate status

## Environment Variables

**Required for custom domains:**
- `CLOUDFLARE_ZONE_ID` - Zone ID from Cloudflare dashboard
- `CLOUDFLARE_API_TOKEN` - API token with Custom Hostnames permissions

**Optional:**
- `CLOUDFLARE_FALLBACK_ORIGIN` - Fallback origin (default: `supportpages.io`)

## Cloudflare Setup

1. Enable "Cloudflare for SaaS" on your zone (requires Business/Enterprise, or add-on)
2. Set fallback origin to your base domain
3. Create API token with permissions:
   - Zone > SSL and Certificates > Edit
   - Zone > Custom Hostnames > Edit
4. Add secrets to `.kamal/secrets`

## Testing

**Model validation:**
```ruby
project.custom_domain = "help.example.com"
project.valid? # => true

project.custom_domain = "test.supportpages.io" # internal domain
project.valid? # => false
```

**Constraint matching:**
```ruby
# Active custom domain matches
request = OpenStruct.new(host: "help.example.com")
CustomDomainConstraint.matches?(request) # => true (if active)

# Subdomains don't match custom domain constraint
request = OpenStruct.new(host: "acme.supportpages.io")
CustomDomainConstraint.matches?(request) # => false
```

**Manual testing:**
1. Go to Settings → Custom Domain
2. Enter a custom domain (e.g., `help.yourcompany.com`)
3. Verify DNS instructions appear
4. Add CNAME record to your DNS provider
5. Wait for status to change to "Active"
6. Visit your custom domain

## Status Flow

```
┌─────────┐     ┌───────────┐     ┌────────┐
│ pending │ ──► │ verifying │ ──► │ active │
└─────────┘     └───────────┘     └────────┘
                      │
                      ▼
                 ┌────────┐
                 │ failed │
                 └────────┘
```

## Notes

- Custom domains are validated to ensure they're not internal domains
- Domain normalization strips protocols, paths, and lowercases
- The `RefreshCustomDomainStatusJob` should be scheduled via cron (every 6 hours recommended)
- Host authorization in production dynamically checks custom domains
