# Claude Analyzer

A Docker-based pipeline that uses [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) to analyze codebases and generate user-facing documentation — help articles with accurate UI mockups, changelogs, and article recommendations.

## Architecture

Every script runs inside a Docker container with a consistent interface:

- **Inputs**: environment variables + files mounted at `/input/`
- **Outputs**: written to `/output/`
- **Repository**: cloned to `/repo/` (or `/repos/` for multi-repo)
- **Authentication**: `CLAUDE_CODE_OAUTH_TOKEN` env var, set up by `entrypoint.sh`

```
┌─────────────────────────────────────────────────┐
│  Docker Container                               │
│                                                 │
│  /input/           /repo/           /output/    │
│  ├── context.json  (cloned repo)   ├── *.json   │
│  ├── compiled_css  ├── app/        ├── html/    │
│  ├── images.json   ├── src/        └── images/  │
│  └── ...           └── ...                      │
│                                                 │
│  Claude Code CLI ──► analyze / generate ──► out │
└─────────────────────────────────────────────────┘
```

## Building

```bash
docker build -t claude-analyzer .
```

## Scripts

### Article Generation Pipeline

The article pipeline runs in three stages: **CSS compilation**, **image extraction** (both once per project), then **article generation** (per article).

#### 1. `generate_css.sh` — CSS Detection & Compilation

Detects the project's CSS framework and compiles production CSS. Uses Claude only for detection (read-only), then deterministic tools for compilation.

```bash
docker run \
  -e CLAUDE_CODE_OAUTH_TOKEN=... \
  -e GITHUB_REPO=owner/repo \
  -e GITHUB_TOKEN=... \
  -v /tmp/output:/output \
  claude-analyzer /generate_css.sh
```

| | |
|---|---|
| **Env vars** | `GITHUB_REPO`, `GITHUB_TOKEN`, `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` |
| **Optional** | `CLAUDE_MODEL` (default: `sonnet`) |
| **Output** | `/output/compiled_css.txt`, `/output/css_detect_parsed.json`, `/output/usage.json` |

**How it works:**
1. Claude detects framework, entry points, theme colors (read-only tools: `Read`, `Glob`, `Grep`)
2. Attempts source compilation: `npm install --ignore-scripts` → `npx sass` / `npx tailwindcss` / `npx postcss`
3. Falls back to CDN fetch + theme overrides if compilation fails
4. Appends additional CDN links, plain CSS files, and font `@import` rules

**Supported frameworks:** Tailwind CSS, Bootstrap, Bulma, Foundation, SCSS/Sass, PostCSS, plain CSS.

#### 2. `extract_images.sh` — Image Extraction

Extracts brand and UI images from the repository as base64 data URIs. No Claude calls — pure filesystem walk.

```bash
docker run \
  -e GITHUB_REPO=owner/repo \
  -e GITHUB_TOKEN=... \
  -v /tmp/output:/output \
  claude-analyzer /extract_images.sh
```

| | |
|---|---|
| **Env vars** | `GITHUB_REPO`, `GITHUB_TOKEN` |
| **Output** | `/output/images_base64.json`, `/output/images_manifest.txt` |

**How it works:**
- Walks the entire repo, skipping `node_modules`, `.git`, `vendor`, `dist`, `build`, etc.
- Prioritises brand images: files named `logo`, `brand`, `favicon`, `icon`, `hero`, etc.
- Per-file limit: 50KB, total budget: 500KB
- Deduplicates by content, skips fingerprinted assets (Rails-style hashed filenames)
- Maps each image under multiple keys (filename, repo path, common web prefixes) for flexible lookup

**`images_base64.json` format:**
```json
{
  "count": 3,
  "total_b64_bytes": 45000,
  "images": {
    "logo.png": "data:image/png;base64,iVBOR...",
    "/assets/logo.png": "data:image/png;base64,iVBOR...",
    "app/assets/images/logo.png": "data:image/png;base64,iVBOR..."
  }
}
```

#### 3. `generate_article.sh` — Article Generation with Mockups

Generates a help article with HTML/PNG mockups. Requires pre-compiled CSS and images as inputs.

```bash
docker run \
  -e CLAUDE_CODE_OAUTH_TOKEN=... \
  -e GITHUB_REPO=owner/repo \
  -e GITHUB_TOKEN=... \
  -v /tmp/input:/input \
  -v /tmp/output:/output \
  claude-analyzer /generate_article.sh
```

| | |
|---|---|
| **Env vars** | `GITHUB_REPO`, `GITHUB_TOKEN`, `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` |
| **Optional** | `CLAUDE_MODEL` (default: `opus`), `CLAUDE_MAX_TURNS` (default: `30`) |
| **Input** | `/input/context.json` (required), `/input/compiled_css.txt`, `/input/images_base64.json`, `/input/existing_articles/` |
| **Output** | `/output/article.json`, `/output/html/step_N.html`, `/output/images/step_N.png`, `/output/usage.json`, `/output/timing.json` |

**`/input/context.json` format:**
```json
{
  "article_title": "How to reset your password",
  "article_description": "Guide users through the password reset flow",
  "writing_style": "warm and friendly",
  "instruction": "focus on password complexity requirements"
}
```

All fields except `article_title` are optional.

**How it works:**
1. Loads pre-compiled CSS and images from `/input/`
2. Claude explores the codebase and writes article JSON + HTML mockups
3. Mockups use placeholders: `<!-- INJECT_CSS -->` for styles, `{{img:filename.png}}` for images
4. Post-processing injects real CSS and base64 images into the HTML
5. Puppeteer renders HTML to PNG screenshots via `render_mockup.sh`

**Typical workflow:**
```bash
# Step 1: Compile CSS (once per project)
docker run -e GITHUB_REPO=owner/repo -e GITHUB_TOKEN=... -e CLAUDE_CODE_OAUTH_TOKEN=... \
  -v /tmp/css_output:/output claude-analyzer /generate_css.sh

# Step 2: Extract images (once per project)
docker run -e GITHUB_REPO=owner/repo -e GITHUB_TOKEN=... \
  -v /tmp/images_output:/output claude-analyzer /extract_images.sh

# Step 3: Generate article (per article — reuse CSS + images from steps 1-2)
mkdir -p /tmp/article_input
cp /tmp/css_output/compiled_css.txt /tmp/article_input/compiled_css.txt
cp /tmp/images_output/images_base64.json /tmp/article_input/images_base64.json
echo '{"article_title":"How to reset your password","writing_style":"warm and friendly"}' \
  > /tmp/article_input/context.json

docker run -e GITHUB_REPO=owner/repo -e GITHUB_TOKEN=... -e CLAUDE_CODE_OAUTH_TOKEN=... \
  -v /tmp/article_input:/input -v /tmp/article_output:/output \
  claude-analyzer /generate_article.sh
```

### Codebase Analysis

#### `analyze.sh` — Project Analysis

Analyzes a codebase and produces a structured project overview.

```bash
docker run \
  -e CLAUDE_CODE_OAUTH_TOKEN=... \
  -e GITHUB_REPO=owner/repo \
  -e GITHUB_TOKEN=... \
  -v /tmp/output:/output \
  claude-analyzer /analyze.sh
```

| | |
|---|---|
| **Env vars** | `GITHUB_REPO` + `GITHUB_TOKEN` (single-repo) or `GITHUB_REPOS_JSON` (multi-repo) |
| **Output** | `/output/summary.md`, `/output/metadata.json`, `/output/overview.txt`, `/output/target_users.json`, `/output/contextual_questions.json`, `/output/style_context.json`, `/output/usage.json` |

Supports multi-repo mode via `GITHUB_REPOS_JSON`:
```json
[
  {"repo": "owner/frontend", "directory": "frontend", "token": "ghp_..."},
  {"repo": "owner/backend", "directory": "backend", "token": "ghp_..."}
]
```

#### `analyze_pr.sh` — PR Changelog Generation

Generates a user-facing changelog entry and article recommendations from a PR diff.

| | |
|---|---|
| **Env vars** | Same as `analyze.sh` |
| **Input** | `/input/diff.patch`, `/input/context.json` |
| **Output** | `/output/title.txt`, `/output/content.md`, `/output/articles.json`, `/output/usage.json` |

#### `analyze_commit.sh` — Commit Changelog Generation

Same as `analyze_pr.sh` but for individual commits.

| | |
|---|---|
| **Input** | `/input/diff.patch`, `/input/context.json` |
| **Output** | `/output/title.txt`, `/output/content.md`, `/output/articles.json`, `/output/usage.json` |

### Help Centre Structure

#### `suggest_sections.sh` — Suggest Help Centre Sections

Analyzes the codebase and suggests 3-8 help centre sections based on user personas and features.

| | |
|---|---|
| **Input** | `/input/context.json` |
| **Output** | `/output/sections.json`, `/output/usage.json` |

#### `generate_section_recommendations.sh` — Articles for a Section

Recommends up to 10 "How to..." articles for a specific help centre section.

| | |
|---|---|
| **Input** | `/input/context.json` (with `section_name`, `section_slug`) |
| **Output** | `/output/recommendations.json`, `/output/usage.json` |

#### `generate_all_recommendations.sh` — Articles for All Sections

Generates article recommendations for all accepted sections in one pass.

| | |
|---|---|
| **Input** | `/input/context.json` (with all accepted sections) |
| **Output** | `/output/recommendations.json`, `/output/usage.json` |

#### `generate_project_recommendations.sh` — Project-wide Recommendations

Generates article recommendations across the entire project.

| | |
|---|---|
| **Input** | `/input/context.json` |
| **Output** | `/output/recommendations.json`, `/output/usage.json` |

### Article Maintenance

#### `check_article_updates.sh` — Detect Stale Articles

Checks which existing articles need updating based on code changes between two commits.

| | |
|---|---|
| **Env vars** | `TARGET_COMMIT`, `BASE_COMMIT` (optional) |
| **Input** | `/input/context.json`, `/input/articles.json` |
| **Output** | `/output/suggestions.json`, `/output/usage.json` |

### Rendering

#### `render_mockup.sh` / `render_mockup.js` — HTML to PNG

Renders an HTML mockup to a PNG screenshot using Puppeteer with quality detection.

```bash
/render_mockup.sh <step_number> <html_file_path>
```

- Validates HTML structure via `validate_html.js`
- Renders with Chromium (Puppeteer)
- Generates diagnostics JSON with quality ratings (excellent/good/acceptable/poor)
- Supports viewport presets: `wide` (1200x800), `desktop` (800x600), `mobile` (375x667), `tablet` (768x1024), `terminal` (600x400)

Set viewport via HTML attribute: `<html data-viewport="mobile">`

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes* | OAuth token for Claude Code CLI authentication |
| `ANTHROPIC_API_KEY` | Yes* | Alternative: Anthropic API key |
| `GITHUB_REPO` | Yes | Repository in `owner/repo` format |
| `GITHUB_TOKEN` | Yes | GitHub access token for cloning |
| `GITHUB_REPOS_JSON` | No | Multi-repo mode: JSON array of `{repo, directory, token}` |
| `CLAUDE_MODEL` | No | Model selection: `opus`, `sonnet`, `haiku` (defaults vary per script) |
| `CLAUDE_MAX_TURNS` | No | Max Claude conversation turns (default: 30) |

\* One of `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` is required.

## How Mockups Work

The mockup pipeline avoids passing large CSS or image data through Claude's context:

1. **Claude writes placeholders**: `<!-- INJECT_CSS -->` in `<head>`, `{{img:logo.png}}` for images
2. **Post-processing injects real data**: CSS is embedded in `<style>` tags, images become base64 data URIs
3. **Puppeteer renders**: HTML → PNG with quality diagnostics

This approach means Claude never reads the compiled CSS (which can be 2MB+) or image data, avoiding context limits and API errors.

