# Blog Images

This directory contains static images for blog posts.

## Adding Hero Images

1. Create or export an image at **1200x630px** (optimal for Open Graph/Twitter Cards)
2. Save as PNG or JPG with a descriptive filename: `YYYY-MM-DD-slug.png`
3. Reference in blog post frontmatter:
   ```yaml
   image: "/images/blog/2026-03-03-introducing-rtfm.png"
   ```

## Image Guidelines

- **Hero images**: 1200x630px for social media sharing
- **In-content images**: Any size, but optimize for web (< 500KB recommended)
- **Format**: PNG for graphics/screenshots, JPG for photos
- **Alt text**: Always include descriptive alt text in markdown

## Example Usage

In your markdown file:

```markdown
---
title: "My Blog Post"
image: "/images/blog/2026-03-03-hero.png"
---

# Content

![Screenshot showing the dashboard](/images/blog/2026-03-03-dashboard.png)
```

Images are served directly by the web server for optimal performance.
