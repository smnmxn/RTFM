# Phase 3.5: Support Article Recommendations

**Status:** Complete

## Overview

Phase 3.5 replaces social snippet generation with AI-powered support article recommendations. When a PR is analyzed, Claude now recommends whether any how-to guide documentation is needed based on the changes, helping teams identify user-facing documentation requirements automatically.

## What Was Built

### Database Changes

Added column to `updates` table:
- `recommended_articles` (json) - Stores article recommendations or reason why none are needed

### Docker Container Updates

Modified `analyze_pr.sh` to:
- Replace `---SOCIAL_SNIPPET---` section with `---RECOMMENDED_ARTICLES---`
- Generate JSON output with article recommendations
- Output `articles.json` instead of `social.txt`

### Background Job Updates

Modified `AnalyzePullRequestJob` to:
- Parse `articles.json` output file
- Store parsed JSON in `recommended_articles` column
- Handle JSON parsing errors gracefully

### UI Changes

Updated `_card.html.erb` to display:
- List of recommended how-to guides with titles, descriptions, and justifications
- "No support articles needed" message with reason when none are recommended

## Files Created/Modified

| Action | File |
|--------|------|
| Create | `db/migrate/20251211140418_add_recommended_articles_to_updates.rb` |
| Modify | `docker/claude-analyzer/analyze_pr.sh` |
| Modify | `app/jobs/analyze_pull_request_job.rb` |
| Modify | `app/views/updates/_card.html.erb` |
| Modify | `test/jobs/analyze_pull_request_job_test.rb` |

## JSON Schema

### recommended_articles column

```json
{
  "articles": [
    {
      "title": "How to Enable Dark Mode",
      "description": "A step-by-step guide showing users how to toggle dark mode in settings",
      "justification": "This PR adds a new dark mode toggle that users will need instructions to find and use"
    }
  ],
  "no_articles_reason": null
}
```

When no articles are needed:

```json
{
  "articles": [],
  "no_articles_reason": "Internal refactoring with no user-facing changes"
}
```

## AI Guidelines for Recommendations

The AI follows these guidelines when recommending articles:
- Focus on NEW features or significantly changed behavior
- Title should start with "How to" and describe the user's goal
- Each article covers ONE specific task
- Maximum 3 article recommendations per PR
- Bug fixes rarely need guides unless they change user workflow
- Internal code changes (refactors, performance improvements) need no guides

## Testing

```bash
# Run all tests
bin/rails test

# Run specific job tests
bin/rails test test/jobs/analyze_pull_request_job_test.rb
```

## Example Output

### PR adding new feature

```json
{
  "articles": [
    {
      "title": "How to Export Your Data to CSV",
      "description": "Learn how to export your project data in CSV format for use in spreadsheets",
      "justification": "This PR adds a new export button to the dashboard that users need to know about"
    }
  ],
  "no_articles_reason": null
}
```

### PR with internal changes

```json
{
  "articles": [],
  "no_articles_reason": "Performance optimization of database queries - no user-facing changes"
}
```

## Notes

- **Backward Compatibility**: The `social_snippet` column remains in the database but is no longer populated
- **Graceful Degradation**: If JSON parsing fails, `recommended_articles` is set to nil
- **Docker Rebuild**: After deployment, rebuild the Docker image:
  ```bash
  docker build -t rtfm/claude-analyzer:latest docker/claude-analyzer/
  ```
