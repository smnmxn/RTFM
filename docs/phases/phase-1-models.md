# Phase 1: Core Data Models

**Status:** Complete

## Overview

Created the foundational data models for the application: User, Project, and Update with proper associations, validations, and helper methods.

## Data Models

### User
Represents an account holder who can own projects.

| Field | Type | Notes |
|-------|------|-------|
| email | string | Required, unique |
| name | string | Display name |
| github_uid | string | Unique, for OAuth |
| github_username | string | GitHub handle |
| github_token | string | OAuth token for API calls |

### Project
Represents a GitHub repository being tracked.

| Field | Type | Notes |
|-------|------|-------|
| user_id | reference | Required, belongs_to User |
| name | string | Required, display name |
| slug | string | Required, unique, URL-friendly |
| github_repo | string | Required, "owner/repo" format |
| webhook_secret | string | For verifying GitHub payloads |

**Behavior:**
- Slug is auto-generated from name if not provided
- Validates github_repo format (owner/repo)

### Update
Represents a changelog entry generated from a PR.

| Field | Type | Notes |
|-------|------|-------|
| project_id | reference | Required, belongs_to Project |
| title | string | Required |
| content | text | Markdown changelog content |
| social_snippet | text | Short social media version |
| status | string | "draft" or "published", default: "draft" |
| pull_request_number | integer | Source PR number |
| pull_request_url | string | Link to PR |
| published_at | datetime | When made public |

**Behavior:**
- Status enum with `draft?` and `published?` methods
- `publish!` method sets status and published_at
- Scopes: `published`, `drafts`

## Associations

```
User
  └── has_many :projects (dependent: :destroy)

Project
  ├── belongs_to :user
  └── has_many :updates (dependent: :destroy)

Update
  └── belongs_to :project
```

## Files Created

| File | Purpose |
|------|---------|
| `app/models/user.rb` | User model with validations |
| `app/models/project.rb` | Project model with slug generation |
| `app/models/update.rb` | Update model with status enum |
| `db/migrate/*_create_users.rb` | Users table migration |
| `db/migrate/*_create_projects.rb` | Projects table migration |
| `db/migrate/*_create_updates.rb` | Updates table migration |
| `test/models/user_test.rb` | User model tests |
| `test/models/project_test.rb` | Project model tests |
| `test/models/update_test.rb` | Update model tests |
| `test/fixtures/*.yml` | Test fixtures for all models |

## Testing

```bash
# Run all model tests
bin/rails test test/models/

# Run specific model test
bin/rails test test/models/user_test.rb
```

25 tests, 58 assertions, all passing.

## Usage Examples

```ruby
# Create a user
user = User.create!(email: "dev@example.com", name: "Developer")

# Create a project (slug auto-generated)
project = user.projects.create!(
  name: "My App",
  github_repo: "myorg/myapp"
)
project.slug # => "my-app"

# Create an update
update = project.updates.create!(
  title: "Add dark mode",
  content: "We've added dark mode support...",
  pull_request_number: 42
)
update.draft? # => true

# Publish it
update.publish!
update.published? # => true
update.published_at # => current time

# Query updates
project.updates.published  # published updates, newest first
project.updates.drafts     # draft updates, newest first
```

## Next Phase

**Phase 2: GitHub Auth & Webhook Ingest** - Devise + OmniAuth GitHub authentication and webhook endpoint for PR events.
