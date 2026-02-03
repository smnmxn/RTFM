# SupportPages: Features & Benefits

**AI-powered documentation that stays in sync with your code.**

Stop writing documentation manually. SupportPages automatically generates and maintains user-facing help articles whenever your code changes.

---

## The Problem

Documentation gets outdated the moment you ship new code. Engineering teams face a constant choice: spend time writing docs, or let them fall behind. Most teams choose the latter, leaving users frustrated and support tickets piling up.

## The Solution

SupportPages connects to your GitHub repository and watches for code changes. When you merge a PR, AI analyzes what changed and generates user-friendly documentation automatically. You review and publish with one click.

---

## Features

### Automatic Documentation Generation

- **GitHub Integration**: Webhook triggers automatically when PRs are merged
- **Intelligent Analysis**: AI understands what changed and why it matters to users
- **User-Focused Content**: Generates how-to guides, not developer changelogs
- **Smart Recommendations**: Suggests which articles your users actually need based on feature impact

### AI-Powered Intelligence

- **Deep Code Understanding**: Full codebase analysis learns your project's structure and patterns
- **Context-Aware**: Understands your tech stack, conventions, and documentation style
- **User Impact Focus**: Prioritizes changes that affect end users, not internal refactors
- **Configurable Models**: Choose between Claude Opus, Sonnet, or Haiku based on your needs

### Beautiful Public Help Centre

- **Modern Interface**: Clean, searchable knowledge base your users will love
- **AI Chat Assistant**: Users ask questions and get instant answers from your docs
- **Organized Sections**: Pre-built categories (Getting Started, Daily Tasks, Advanced Usage, Troubleshooting)
- **Custom Branding**: Your logo, colors, and messaging
- **Custom Domains**: Serve from `help.yourcompany.com` with automatic SSL

### Human-in-the-Loop Workflow

- **Inbox Review**: All AI-generated articles queue for your approval
- **One-Click Publishing**: Approve to publish, reject to discard
- **Rich Editor**: Edit titles, steps, and content before publishing
- **Quality Control**: Maintain high standards without writing from scratch

### Multi-Repository Support

- **Unified Documentation**: Connect multiple repos to one Help Centre
- **Cross-Repo Tracking**: See changes across your entire codebase
- **Mono-Repo Ready**: Works with complex repository structures

### Visual Documentation

- **AI-Generated Mockups**: Automatic UI screenshots for visual guides
- **Step-by-Step Images**: Attach images to individual instruction steps
- **Custom Uploads**: Add your own screenshots when needed

---

## Benefits

### Save Time
No more manual documentation writing. AI handles the heavy lifting while you focus on shipping features.

### Stay Current
Documentation updates automatically with every code change. No more outdated help articles.

### Quality Content
AI generates structured, user-friendly guides with prerequisites, step-by-step instructions, and tips.

### Brand Consistency
Customize your Help Centre to match your brand with logos, colors, and custom domains.

### Developer-Focused
Built for engineering teams. Integrates with your existing GitHub workflow.

### Scalable
Handles multiple repositories and large codebases without slowing down.

---

## How It Works

1. **Connect** your GitHub repository
2. **Analyze** your codebase with AI to understand the project
3. **Merge** a pull request
4. **Review** AI-generated documentation recommendations
5. **Publish** to your branded Help Centre

---

## Technical Overview

| Component | Technology |
|-----------|------------|
| Backend | Ruby 3.3, Rails 8.1 |
| Frontend | Tailwind CSS, Hotwire (Turbo & Stimulus) |
| AI | Anthropic Claude API |
| Queue | Sidekiq + Redis |
| Database | PostgreSQL |
| Custom Domains | Cloudflare for SaaS |
| Image Generation | Puppeteer + Chromium |

---

## Get Started

Connect your first repository and let AI analyze your codebase. Within minutes, you'll have documentation recommendations ready for review.
