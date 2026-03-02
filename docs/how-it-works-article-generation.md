# How It Works: Automated Article & Image Generation

## The Problem

When software teams ship new features, the documentation lags behind. Writing help articles is manual, time-consuming, and requires context-switching between code and prose. Screenshots go stale the moment the UI changes. The result: outdated docs, frustrated users, and support tickets that could have been avoided.

## Our Solution

SupportPages automatically converts code changes into professional, illustrated how-to guides. When a pull request is merged, the platform reads the code, understands what changed, and generates complete articles with step-by-step screenshots — all without human authoring.

---

## End-to-End Pipeline

### 1. Code Understanding (One-Time Setup)

When a project is first connected, SupportPages performs a deep analysis of the entire codebase:

- **Repository cloning** — the codebase is cloned into an isolated Docker container
- **Architecture analysis** — Claude AI reads the code and produces a structured summary: tech stack, components, key patterns, and entry points
- **User persona identification** — the AI identifies who the end users are and what they care about
- **Visual style extraction** — CSS, color schemes, fonts, and icon libraries are catalogued so that generated screenshots match the real product
- **Section suggestions** — based on the codebase structure and user personas, the platform recommends documentation categories (e.g. "Getting Started", "Account Settings", "Integrations")

This analysis becomes the persistent context that makes every subsequent article accurate and consistent.

### 2. Change Detection & Article Recommendations

Every time a pull request is merged (or a commit lands on the default branch):

1. **Diff capture** — the platform fetches the code diff from GitHub, computing cumulative changes since the last analysis
2. **Change interpretation** — Claude AI reads the diff in the context of the full codebase analysis, understanding not just *what* changed but *what it means for users*
3. **Article recommendations** — the AI produces a set of recommended articles, each with a title, description, and justification explaining why this article would help end users

Not every code change warrants documentation. The AI filters out internal refactors, test changes, and infrastructure work, only surfacing changes that affect the user experience.

### 3. Article Generation

When a team member approves a recommendation, the generation engine produces a complete how-to guide:

**Content generation:**
- Claude AI explores the actual codebase — reading view templates, controllers, and routes — to understand exactly how the feature works
- It reviews previously published articles to match the project's established tone and terminology
- The output is a structured article: introduction, prerequisites, numbered steps, tips, and summary

**Screenshot generation:**
- For each step that involves a UI interaction, the AI generates a faithful HTML mockup
- Mockups use the project's real CSS classes and stylesheets, producing screenshots that look like the actual product
- A headless Chromium browser renders each mockup to a high-resolution PNG
- Viewport sizes adapt automatically: wide desktop for web apps, mobile for responsive views, terminal for CLI tools

The result is a publish-ready article with accurate, on-brand screenshots — typically produced in under two minutes.

### 4. Human Review & Publishing

Generated articles enter a review queue where team members can:

- **Edit** content and refine wording
- **Regenerate** with guidance — provide feedback like "focus more on the admin workflow" and the AI will produce a revised version
- **Approve and publish** to the live help centre
- **Reject** recommendations that aren't needed

This keeps humans in the loop for quality control while eliminating the blank-page problem.

---

## Technical Architecture

```
GitHub Webhook
     │
     ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Rails API   │────▶│  Sidekiq Queue   │────▶│ Docker Container │
│  (webhook    │     │  (async jobs)    │     │ (Claude AI +     │
│   receiver)  │     │                  │     │  Chromium)       │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │  Article + PNGs  │
                                              │  (stored in DB   │
                                              │   + object store)│
                                              └─────────────────┘
```

**Key design decisions:**

- **Isolated Docker containers** — each analysis runs in a fresh container with read-only access to input files. No persistent state, no cross-contamination between projects.
- **Codebase-aware generation** — the AI doesn't just read the diff. It has access to the full repository, so it can follow imports, read templates, and understand the complete user flow.
- **Real CSS, real screenshots** — mockups embed the project's actual compiled stylesheet. This means screenshots show real colors, real typography, and real component styling — not generic wireframes.
- **Async job pipeline** — all heavy processing (AI calls, repo cloning, image rendering) runs asynchronously via Sidekiq. The web layer stays responsive.
- **Multi-repository support** — projects that span multiple repositories (e.g. frontend + backend + API) are analysed as a unified system.

---

## Image Generation: How Screenshots Are Created

The screenshot pipeline is a key differentiator. Most documentation tools require manual screenshots that go stale immediately. SupportPages generates them programmatically:

1. **Template reading** — the AI reads the actual view templates (ERB, JSX, Vue, Svelte) from the repository
2. **HTML conversion** — templates are converted to static HTML with all original CSS classes preserved
3. **Style injection** — the project's compiled CSS is embedded directly, so Tailwind utilities, custom properties, and component styles all render correctly
4. **Icon library detection** — FontAwesome, Heroicons, Bootstrap Icons, Lucide, and other libraries are automatically detected and loaded via CDN
5. **Chromium rendering** — Puppeteer launches headless Chromium, sets the appropriate viewport, and captures a 2x (retina) screenshot
6. **Quality validation** — each screenshot is scored on element count, text length, image loading, and blank detection. Failed renders are flagged for review.

This approach means screenshots update automatically when the codebase changes — no manual capture required.

---

## What Makes This Different

| Traditional Docs | SupportPages |
|---|---|
| Writer reads release notes, asks engineers what changed | AI reads the actual code diff and codebase |
| Writer manually captures screenshots | Screenshots generated from real templates + CSS |
| Screenshots go stale after the next deploy | Regenerate articles from the latest code at any time |
| Documentation lags days or weeks behind releases | Articles recommended within minutes of merge |
| Each article starts from scratch | AI maintains consistency with existing articles |
| One-size-fits-all tone | Matches the project's established voice and terminology |

---

## Configuration & Flexibility

Teams can customise the pipeline to fit their workflow:

- **AI model selection** — choose between Claude Opus (most capable), Sonnet (balanced), or Haiku (fastest) per project
- **Update frequency** — trigger on every PR, weekly batches, or manually
- **Branding** — colours, fonts, and logos are extracted automatically but can be overridden
- **Section structure** — AI-suggested categories can be accepted, modified, or replaced entirely
- **Regeneration with guidance** — provide natural language feedback to steer article rewrites

---

## Scale & Performance

| Metric | Typical Value |
|---|---|
| Codebase analysis | ~2-3 minutes (one-time) |
| PR analysis + recommendations | ~1-2 minutes |
| Article generation with screenshots | ~1-3 minutes |
| Concurrent article generation | Unlimited (async queue) |
| Multi-repo projects | Supported (analysed as unified system) |

All processing is asynchronous. Teams receive real-time notifications when articles are ready for review.
