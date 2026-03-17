# Article Generation Benchmarks

Compare three approaches to generating help articles with UI screenshots.

## Usage

Run these scripts from inside a target repository:

```bash
cd /path/to/your/project

# Approach A: Single prompt, no pre-work
/path/to/benchmark/a_baseline.sh "How to reset your password"

# Approach B: Pre-extract CSS, then generate article
/path/to/benchmark/b_with_css.sh "How to reset your password"

# Approach C: Pre-extract screen library, then generate article
/path/to/benchmark/c_with_screens.sh "How to reset your password"
```

Each script outputs to `./benchmark_output/{a,b,c}/` so you can compare side-by-side.

## What to compare

- `article.json` — the article content
- `images/` — rendered screenshots
- `timing.json` — wall clock time and token usage per phase
- `html/` — the raw HTML mockups (inspect for accuracy)

## Requirements

- `claude` CLI installed and authenticated
- `node` with `puppeteer` available (for screenshot rendering)
- Run from inside a git repo you want to document
