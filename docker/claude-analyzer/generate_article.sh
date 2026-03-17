#!/bin/bash
set -e

# generate_article.sh — Generate a help article with UI mockups
#
# Expects pre-compiled CSS and images as inputs (from generate_css.sh / extract_images.sh).
# Does NOT do CSS detection or compilation — that's generate_css.sh's job.
#
# Docker interface:
#   Env vars: GITHUB_REPO, GITHUB_TOKEN, ANTHROPIC_API_KEY, CLAUDE_CODE_OAUTH_TOKEN
#   Optional: CLAUDE_MODEL (default: opus), CLAUDE_MAX_TURNS (default: 30)
#   Input:    /input/context.json (article_title, article_description, writing_style, instruction, etc.)
#             /input/compiled_css.txt (required — from generate_css.sh)
#             /input/images_base64.json (required — pre-extracted images)
#             /input/existing_articles/ (optional, for consistency)
#   Output:   /output/article.json, /output/html/step_N.html, /output/images/step_N.png
#             /output/usage.json, /output/timing.json
#
# Usage:
#   docker run -e GITHUB_REPO=owner/repo -e GITHUB_TOKEN=... -e ANTHROPIC_API_KEY=... \
#     -v /path/to/input:/input -v /path/to/output:/output \
#     claude-analyzer /generate_article.sh

echo "Starting article generation..."

# ─── Helpers ─────────────────────────────────────────────────────────────────

now_ms() {
    if command -v gdate &>/dev/null; then
        gdate +%s%3N
    else
        python3 -c 'import time; print(int(time.time()*1000))'
    fi
}

TIMING_FILE="/output/timing.json"
echo '{"phases":[]}' > "$TIMING_FILE"
PHASE_START=$(now_ms)

record_phase() {
    local phase_name="$1"
    local phase_end
    phase_end=$(now_ms)
    local duration_ms=$(( phase_end - PHASE_START ))

    echo "  $phase_name: $((duration_ms / 1000))s"

    local tmp
    tmp=$(mktemp)
    jq --arg name "$phase_name" --argjson ms "$duration_ms" \
        '.phases += [{"name": $name, "duration_ms": $ms}]' \
        "$TIMING_FILE" > "$tmp" && mv "$tmp" "$TIMING_FILE"

    PHASE_START=$(now_ms)
}

finalize_timing() {
    local total_ms=0
    total_ms=$(jq '[.phases[].duration_ms] | add // 0' "$TIMING_FILE" 2>/dev/null || echo 0)

    # Collect token usage from claude output
    local total_input=0 total_output=0 total_cost="0"
    for f in /output/*_raw.json; do
        if [ -f "$f" ]; then
            local inp outp cost
            inp=$(jq -r '(.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)' "$f" 2>/dev/null || echo 0)
            outp=$(jq -r '.usage.output_tokens // 0' "$f" 2>/dev/null || echo 0)
            cost=$(jq -r '.total_cost_usd // 0' "$f" 2>/dev/null || echo 0)
            total_input=$((total_input + inp))
            total_output=$((total_output + outp))
            total_cost=$(python3 -c "print($total_cost + $cost)" 2>/dev/null || echo "$total_cost")
        fi
    done

    local tmp
    tmp=$(mktemp)
    jq --argjson total_ms "$total_ms" \
       --argjson total_tokens "$((total_input + total_output))" \
       --argjson input_tokens "$total_input" \
       --argjson output_tokens "$total_output" \
       --arg total_cost "$total_cost" \
       '. + {total_duration_ms: $total_ms, total_tokens: $total_tokens, input_tokens: $input_tokens, output_tokens: $output_tokens, total_cost_usd: $total_cost}' \
       "$TIMING_FILE" > "$tmp" && mv "$tmp" "$TIMING_FILE"
}

# ─── Read inputs ─────────────────────────────────────────────────────────────

if [ ! -f /input/context.json ]; then
    echo "Error: /input/context.json not found"
    exit 1
fi

ARTICLE_TITLE=$(jq -r '.article_title // .title // empty' /input/context.json)
ARTICLE_DESC=$(jq -r '.article_description // .description // empty' /input/context.json)
WRITING_STYLE=$(jq -r '.writing_style // empty' /input/context.json)
INSTRUCTION=$(jq -r '.instruction // .regeneration_guidance // empty' /input/context.json)
ANALYSIS_SUMMARY=$(jq -r '.analysis_summary // empty' /input/context.json)
PROJECT_OVERVIEW=$(jq -r '.project_overview // empty' /input/context.json)

ARTICLE_TOPIC="${ARTICLE_TITLE}"
[ -n "$ARTICLE_DESC" ] && ARTICLE_TOPIC="${ARTICLE_TITLE}: ${ARTICLE_DESC}"

if [ -z "$ARTICLE_TITLE" ]; then
    echo "Error: context.json must contain article_title"
    exit 1
fi

CLAUDE_MODEL="${CLAUDE_MODEL:-opus}"
CLAUDE_MAX_TURNS="${CLAUDE_MAX_TURNS:-50}"

echo "Repository: ${GITHUB_REPO}"
echo "Article:    ${ARTICLE_TITLE}"
echo "Model:      ${CLAUDE_MODEL}"
[ -n "$WRITING_STYLE" ] && echo "Style:      ${WRITING_STYLE}"
[ -n "$INSTRUCTION" ]   && echo "Instruction: ${INSTRUCTION}"
echo ""

# ─── Clone repository ────────────────────────────────────────────────────────

if [ ! -d /repo/.git ]; then
    echo "Cloning repository..."
    if ! git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>&1; then
        echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
        exit 1
    fi
fi
cd /repo

# ─── Load pre-compiled CSS and images ────────────────────────────────────────

CSS_FILE="/output/compiled.css"
IMAGES_JSON="/output/images_base64.json"
IMAGE_MANIFEST="/output/images_manifest.txt"

mkdir -p /output/html /output/images

# CSS — required input from generate_css.sh
if [ -f /input/compiled_css.txt ] && [ -s /input/compiled_css.txt ]; then
    cp /input/compiled_css.txt "$CSS_FILE"
    CSS_SIZE=$(wc -c < "$CSS_FILE")
    echo "CSS loaded: ${CSS_SIZE} bytes"
else
    echo "WARNING: /input/compiled_css.txt not found or empty — mockups will have no styling"
    > "$CSS_FILE"
fi

# Images — required input
if [ -f /input/images_base64.json ] && [ -s /input/images_base64.json ]; then
    cp /input/images_base64.json "$IMAGES_JSON"
    IMAGE_COUNT=$(jq -r '.count // 0' "$IMAGES_JSON" 2>/dev/null || echo "0")
    echo "Images loaded: ${IMAGE_COUNT}"
else
    echo "WARNING: /input/images_base64.json not found — mockups will have no images"
    echo '{"count":0,"total_b64_bytes":0,"images":{}}' > "$IMAGES_JSON"
fi

# Build image manifest (just filenames, no data)
jq -r '.images | keys[]' "$IMAGES_JSON" 2>/dev/null | sort -u > "$IMAGE_MANIFEST"

# Load file tree if available
FILE_TREE=""
if [ -f /input/file_tree.txt ] && [ -s /input/file_tree.txt ]; then
    FILE_TREE=$(cat /input/file_tree.txt)
    TREE_LINES=$(wc -l < /input/file_tree.txt)
    echo "File tree loaded: ${TREE_LINES} lines"
fi

# ─── Article Generation ──────────────────────────────────────────────────────

echo ""
echo "Generating article..."
PHASE_START=$(now_ms)

# Build the prompt
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" <<PROMPT_HEADER
You are a technical writer creating a help article for end users of this software project.

ARTICLE TOPIC: ${ARTICLE_TOPIC}
PROMPT_HEADER

if [ -n "$WRITING_STYLE" ]; then
    cat >> "$PROMPT_FILE" <<STYLE_SECTION

WRITING STYLE: ${WRITING_STYLE}
Write the entire article in this style. Let it influence your tone, word choice, and how you address the reader.
STYLE_SECTION
fi

if [ -n "$INSTRUCTION" ]; then
    cat >> "$PROMPT_FILE" <<INSTRUCTION_SECTION

SPECIAL INSTRUCTION: ${INSTRUCTION}
Follow this instruction carefully when writing the article content.
INSTRUCTION_SECTION
fi

# Add project context (analysis summary, overview, file tree)
if [ -n "$PROJECT_OVERVIEW" ] || [ -n "$ANALYSIS_SUMMARY" ] || [ -n "$FILE_TREE" ]; then
    cat >> "$PROMPT_FILE" <<'CONTEXT_HEADER'

=== PROJECT CONTEXT ===
Use this context to quickly locate relevant files. Do NOT explore broadly — go directly to the files you need.
CONTEXT_HEADER

    if [ -n "$PROJECT_OVERVIEW" ]; then
        printf "\nPROJECT OVERVIEW:\n%s\n" "$PROJECT_OVERVIEW" >> "$PROMPT_FILE"
    fi

    if [ -n "$ANALYSIS_SUMMARY" ]; then
        printf "\nCODEBASE ANALYSIS SUMMARY:\n%s\n" "$ANALYSIS_SUMMARY" >> "$PROMPT_FILE"
    fi

    if [ -n "$FILE_TREE" ]; then
        printf "\nFILE TREE:\n%s\n" "$FILE_TREE" >> "$PROMPT_FILE"
    fi

    echo "" >> "$PROMPT_FILE"
    echo "=== END PROJECT CONTEXT ===" >> "$PROMPT_FILE"
fi

# Check for existing articles to reference
EXISTING_ARTICLES_CONTEXT=""
if [ -f /input/existing_articles/manifest.json ]; then
    ARTICLE_COUNT=$(jq -r '.total_count // 0' /input/existing_articles/manifest.json 2>/dev/null || echo "0")
    if [ "$ARTICLE_COUNT" -gt 0 ] 2>/dev/null; then
        EXISTING_ARTICLES_CONTEXT="
Existing articles for consistency are at: /input/existing_articles/manifest.json
Read it to see completed articles, then match their tone and HTML patterns."
    fi
fi

cat >> "$PROMPT_FILE" <<PROMPT_BODY

PRE-COMPILED CSS AND IMAGES will be injected automatically via post-processing.
You do NOT need to read or embed the CSS file yourself.

Available image paths are listed in: ${IMAGE_MANIFEST}
${EXISTING_ARTICLES_CONTEXT}

STEP 1: Locate the relevant code for this feature.
A file tree and analysis summary are provided above in PROJECT CONTEXT. Use these to jump directly to the relevant files rather than exploring broadly.
- Open routes, controllers, views related to this topic
- Find the ACTUAL template files for screens related to this article
- Check relevant models, services, or configuration
Do NOT use Glob or Grep to discover project structure — the file tree already gives you that. Use Read to open specific files you've identified.

STEP 2: Write a help article as JSON:
{
  "title": "Article title",
  "introduction": "1-2 sentences explaining what users will learn",
  "prerequisites": ["Things users need before starting"],
  "steps": [
    {"title": "Step title", "content": "Detailed instructions", "has_image": true},
    {"title": "Next step", "content": "More instructions", "has_image": false}
  ],
  "tips": ["Helpful tips"],
  "summary": "1-2 sentence wrap-up"
}

STEP 3: For each step where has_image is true, generate an HTML mockup.

For mockups:
- Find the REAL template/component files for this screen in the codebase
- Copy the actual HTML structure and class names from those templates
- Convert framework syntax (JSX, ERB, Vue, etc.) to static HTML
- Use the REAL class names from the templates — they will be styled by the injected CSS
- For CSS: add exactly this placeholder in the <head>: <!-- INJECT_CSS -->
- For images: use src="{{img:filename.png}}" (e.g. src="{{img:togetherlylogo.png}}")
  Read the image manifest file to see what filenames are available.
  If no matching image exists, use a colored placeholder div with the alt text instead.
- Fill in realistic placeholder data relevant to the article topic
- Include CDN links for icon libraries the project uses
- Each mockup must be a complete standalone HTML file

Write each mockup to: /output/html/step_N.html (N is 0-based)

IMPORTANT:
- Write for END USERS, not developers
- Use clear, simple language
- Do NOT read the compiled CSS file — it will be injected automatically
- Do NOT read the images JSON file — use {{img:filename}} placeholders
- Generate 1-4 mockup images total

Your final output must be ONLY the JSON article object.
PROMPT_BODY

echo "  Calling Claude ($CLAUDE_MODEL)..."

set +e
if [ "${KEEP_ANALYSIS_OUTPUT}" = "true" ]; then
    echo "  Streaming mode (debug) — turn log at /output/article_raw.turns.log"
    cat "$PROMPT_FILE" | claude -p --verbose --model "$CLAUDE_MODEL" --max-turns "$CLAUDE_MAX_TURNS" \
        --output-format stream-json --allowedTools "Read,Glob,Grep,Bash,Write" | \
        python3 /stream_filter.py /output/article_raw.json
    CLAUDE_EXIT=${PIPESTATUS[1]}
else
    cat "$PROMPT_FILE" | claude -p --model "$CLAUDE_MODEL" --max-turns "$CLAUDE_MAX_TURNS" \
        --output-format json --allowedTools "Read,Glob,Grep,Bash,Write" > /output/article_raw.json
    CLAUDE_EXIT=$?
fi
set -e
rm -f "$PROMPT_FILE"

echo "  Claude exit status: $CLAUDE_EXIT"

record_phase "article_generation"

# Extract article JSON from result
jq -r '.result // empty' /output/article_raw.json 2>/dev/null | \
    sed '/^```json$/d; /^```$/d' > /output/article.json || true

# Extract usage data
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /output/article_raw.json > /output/usage.json 2>/dev/null || true

# ─── Post-processing (inject CSS + images, render PNGs) ──────────────────────

echo ""
echo "Post-processing mockups..."
PHASE_START=$(now_ms)

# Inject CSS and image placeholders into HTML files
python3 - /output/html "$CSS_FILE" "$IMAGES_JSON" <<'PYEOF'
import sys, os, re, json

html_dir, css_file, images_json = sys.argv[1], sys.argv[2], sys.argv[3]

css_content = ""
if os.path.isfile(css_file):
    with open(css_file) as f:
        css_content = f.read()

images = {}
if os.path.isfile(images_json):
    with open(images_json) as f:
        images = json.load(f).get("images", {})

filename_lookup = {}
for path, uri in images.items():
    fname = os.path.basename(path)
    if fname not in filename_lookup:
        filename_lookup[fname] = uri

count = 0
for fname in sorted(os.listdir(html_dir)):
    if not fname.startswith("step_") or not fname.endswith(".html"):
        continue
    fpath = os.path.join(html_dir, fname)
    with open(fpath) as f:
        html = f.read()

    css_tag = f"<style>\n{css_content}\n</style>"
    if "<!-- INJECT_CSS -->" in html:
        html = html.replace("<!-- INJECT_CSS -->", css_tag)
    elif "</head>" in html:
        html = html.replace("</head>", f"{css_tag}\n</head>")
    elif "<body" in html:
        html = html.replace("<body", f"{css_tag}\n<body", 1)

    def replace_img(match):
        img_name = match.group(1)
        for key in [img_name, "/" + img_name, "/assets/" + img_name]:
            if key in images:
                return images[key]
        return filename_lookup.get(img_name, match.group(0))

    html = re.sub(r'\{\{img:([^}]+)\}\}', replace_img, html)

    with open(fpath, 'w') as f:
        f.write(html)
    count += 1
    print(f"  Post-processed: {fname}", file=sys.stderr)

print(f"  {count} file(s) post-processed", file=sys.stderr)
PYEOF

# Render HTML mockups to PNG
MOCKUP_COUNT=0
for html_file in /output/html/step_*.html; do
    if [ -f "$html_file" ]; then
        step_num=$(basename "$html_file" | sed 's/step_//;s/\.html//')
        if [ -f /render_mockup.sh ]; then
            echo "  Rendering step_${step_num}..."
            /render_mockup.sh "$step_num" "$html_file" || echo "  Warning: failed to render step_${step_num}"
        elif command -v node &>/dev/null && node -e "require('puppeteer')" 2>/dev/null; then
            echo "  Rendering step_${step_num} (puppeteer)..."
            node -e "
                const puppeteer = require('puppeteer');
                const path = require('path');
                (async () => {
                    const browser = await puppeteer.launch({headless: 'new', args: ['--no-sandbox']});
                    const page = await browser.newPage();
                    await page.setViewport({width: 1200, height: 800, deviceScaleFactor: 2});
                    await page.goto('file://' + path.resolve('$html_file'), {waitUntil: 'networkidle0', timeout: 15000}).catch(() => {});
                    await page.screenshot({path: '/output/images/step_${step_num}.png', type: 'png'});
                    await browser.close();
                })();
            " 2>/dev/null || echo "  Warning: failed to render step_${step_num}"
        else
            echo "  Puppeteer not available — skipping PNG rendering"
            echo "  HTML mockups are in: /output/html/"
            break
        fi
        MOCKUP_COUNT=$((MOCKUP_COUNT + 1))
    fi
done
echo "  Rendered $MOCKUP_COUNT mockup(s)"

record_phase "mockup_rendering"

# Save commit SHA for tracking
COMMIT_SHA=$(cd /repo && git rev-parse HEAD 2>/dev/null || echo "")
[ -n "$COMMIT_SHA" ] && echo "$COMMIT_SHA" > /output/commit_sha.txt

finalize_timing

echo ""
echo "=== Article generation complete ==="
echo "Article:  /output/article.json"
echo "HTML:     /output/html/"
echo "Images:   /output/images/"
echo "Timing:   /output/timing.json"
echo "Usage:    /output/usage.json"
echo ""
echo "Output files:"
ls -la /output/
