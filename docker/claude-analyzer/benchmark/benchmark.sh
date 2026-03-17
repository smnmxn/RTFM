#!/bin/bash
set -e

# Benchmark: Pre-extract CSS + images, then generate article across models
#
# Phase 1:  CSS detection (one Claude call, uses default model)
# Phase 1b: Deterministic CSS compilation (no Claude)
# Phase 1c: Image extraction (no Claude)
# Phase 2:  Article generation — runs once per model (opus, sonnet, haiku)
#
# Usage: benchmark.sh "Article topic" [model1,model2,...]
# Default models: claude-opus-4-6,claude-sonnet-4-6,claude-haiku-4-5-20251001

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_shared.sh"

ARTICLE_TOPIC="${1:?Usage: benchmark.sh \"Article topic\" [model1,model2,...]}"
MODELS="${2:-opus,sonnet,haiku}"

# Parse models into array
IFS=',' read -ra MODEL_LIST <<< "$MODELS"

# Short name for display (handles both aliases and full IDs)
model_short_name() {
    case "$1" in
        opus|*opus*)     echo "opus" ;;
        sonnet|*sonnet*) echo "sonnet" ;;
        haiku|*haiku*)   echo "haiku" ;;
        *)               echo "$1" ;;
    esac
}

# Base output dir for shared pre-work
BASE_DIR="$REPO_DIR/benchmark_output"
SHARED_DIR="$BASE_DIR/shared"
rm -rf "$SHARED_DIR"
mkdir -p "$SHARED_DIR"

# Also set OUTPUT_DIR for shared phases (timing, etc.)
OUTPUT_DIR="$SHARED_DIR"

echo "=== Benchmark: Article Generation Across Models ==="
echo "Topic:  $ARTICLE_TOPIC"
echo "Repo:   $REPO_DIR"
echo "Models: ${MODEL_LIST[*]}"
echo ""

# ─── Phase 1: CSS Detection (once) ───────────────────────────────────────────

echo "Phase 1: Detecting CSS framework and entry point..."
start_timer

cat <<'DETECT_PROMPT' | run_claude_streaming "$SHARED_DIR/css_detect_raw.json" --allowedTools "Read,Glob,Grep"
Analyze this codebase to detect its CSS build setup.

CHECK (in order):
1. package.json / Gemfile / composer.json for CSS dependencies
2. Config files: tailwind.config.js, postcss.config.js, webpack.config.js, vite.config.ts
3. CSS/SCSS/Less entry files — find the MAIN entry point that imports everything
4. package.json "scripts" — look for build commands that reference sass, tailwindcss, postcss
5. Layout templates for CDN links and font imports
6. SCSS variable files — extract theme color values

For the SCSS/CSS entry point, find the single file that serves as the root of the CSS build.
This is the file that @imports everything else. Examples:
- app/frontend/packs/application.scss
- src/index.css (with @tailwind directives)
- app/assets/stylesheets/application.scss
- styles/main.scss

Output ONLY this JSON (no preamble text, no explanation before the JSON):
{
  "framework": "tailwind|bootstrap|bulma|foundation|scss|postcss|plain_css|css_in_js|none",
  "version": "version string or null",
  "scss_entry": "path to main SCSS/Sass entry file that @imports everything, or null",
  "tailwind_entry": "path to CSS file with @tailwind directives, or null",
  "tailwind_config": "path to tailwind config, or null",
  "postcss_config": "path to postcss config, or null",
  "css_files": ["paths to plain .css files in dependency order"],
  "cdn_links": ["CDN stylesheet URLs found in layout templates"],
  "font_links": ["Google Fonts or other font CDN URLs"],
  "has_package_json": true,
  "package_manager": "npm|yarn|pnpm|null",
  "theme_overrides": {
    "colors": {
      "primary": "#hex or null",
      "secondary": "#hex or null",
      "success": "#hex or null",
      "danger": "#hex or null",
      "warning": "#hex or null",
      "info": "#hex or null"
    },
    "custom_colors": { "name": "#hex" },
    "fonts": { "body": "font-family or null", "heading": "font-family or null" },
    "border_radius": "value or null",
    "extra_css": "critical non-variable CSS overrides (max 50 lines) or null"
  },
  "notes": "brief explanation"
}

For theme_overrides:
- Resolve SCSS variable chains (e.g., $primary: $brand-green; $brand-green: #004a56 → "#004a56")
- Include ALL custom color variables in custom_colors
DETECT_PROMPT

record_phase "css_detection"

# Extract detection result (strip markdown fences and any preamble text before JSON)
CSS_DETECT=$(jq -r '.result // empty' "$SHARED_DIR/css_detect_raw.json" 2>/dev/null | sed '/^```json$/d; /^```$/d' | sed -n '/^{/,/^}/p')
echo "$CSS_DETECT" > "$SHARED_DIR/css_detect_parsed.json"

# ─── Phase 1b: CSS Compilation (once, deterministic) ─────────────────────────

start_timer

CSS_FILE="$SHARED_DIR/compiled.css"
> "$CSS_FILE"
COMPILE_METHOD="none"

if [ -z "$CSS_DETECT" ]; then
    echo "  Detection failed — no result"
else
    FRAMEWORK=$(echo "$CSS_DETECT" | jq -r '.framework // "none"' 2>/dev/null || echo "none")
    VERSION=$(echo "$CSS_DETECT" | jq -r '.version // ""' 2>/dev/null || echo "")
    SCSS_ENTRY=$(echo "$CSS_DETECT" | jq -r '.scss_entry // empty' 2>/dev/null)
    TW_ENTRY=$(echo "$CSS_DETECT" | jq -r '.tailwind_entry // empty' 2>/dev/null)
    TW_CONFIG=$(echo "$CSS_DETECT" | jq -r '.tailwind_config // empty' 2>/dev/null)
    POSTCSS_CONFIG=$(echo "$CSS_DETECT" | jq -r '.postcss_config // empty' 2>/dev/null)
    HAS_PKG=$(echo "$CSS_DETECT" | jq -r '.has_package_json // false' 2>/dev/null)
    PKG_MGR=$(echo "$CSS_DETECT" | jq -r '.package_manager // "npm"' 2>/dev/null)

    echo "  Framework: $FRAMEWORK $VERSION"
    [ -n "$SCSS_ENTRY" ] && echo "  SCSS entry: $SCSS_ENTRY"
    [ -n "$TW_ENTRY" ] && echo "  Tailwind entry: $TW_ENTRY"

    # macOS doesn't have timeout — use gtimeout or skip
    _timeout() {
        if command -v gtimeout &>/dev/null; then
            gtimeout "$@"
        elif command -v timeout &>/dev/null; then
            timeout "$@"
        else
            shift
            "$@"
        fi
    }

    try_source_compile() {
        echo ""
        echo "  Attempting source compilation..."

        if [ "$HAS_PKG" = "true" ] && [ -f "$REPO_DIR/package.json" ]; then
            local install_cmd="npm install"
            if [ "$PKG_MGR" = "yarn" ] && command -v yarn &>/dev/null; then
                install_cmd="yarn install"
            elif [ "$PKG_MGR" = "pnpm" ] && command -v pnpm &>/dev/null; then
                install_cmd="pnpm install"
            fi
            echo "  Running $install_cmd --ignore-scripts..."
            cd "$REPO_DIR"
            if ! _timeout 120 $install_cmd --ignore-scripts 2>/tmp/npm_error.log; then
                echo "  $install_cmd failed"
                tail -5 /tmp/npm_error.log
                return 1
            fi
            echo "  Install OK"
        else
            echo "  No package.json — skipping install"
            return 1
        fi

        case "$FRAMEWORK" in
            tailwind)
                if [ -n "$TW_ENTRY" ] && [ -f "$REPO_DIR/$TW_ENTRY" ]; then
                    echo "  Compiling Tailwind: npx tailwindcss..."
                    local tw_args="-i $REPO_DIR/$TW_ENTRY -o $CSS_FILE"
                    [ -n "$TW_CONFIG" ] && [ -f "$REPO_DIR/$TW_CONFIG" ] && tw_args="-c $REPO_DIR/$TW_CONFIG $tw_args"
                    if _timeout 120 npx tailwindcss $tw_args 2>/tmp/compile_error.log; then
                        COMPILE_METHOD="tailwind_npx"
                        return 0
                    fi
                    echo "  Tailwind compilation failed"
                    tail -5 /tmp/compile_error.log
                fi
                return 1
                ;;
            bootstrap|bulma|foundation|scss)
                if [ -n "$SCSS_ENTRY" ] && [ -f "$REPO_DIR/$SCSS_ENTRY" ]; then
                    echo "  Compiling SCSS: npx sass..."
                    if _timeout 120 npx sass "$REPO_DIR/$SCSS_ENTRY" "$CSS_FILE" \
                        --load-path="$REPO_DIR/node_modules" \
                        --load-path="$REPO_DIR" \
                        --no-source-map --style=expanded 2>/tmp/compile_error.log; then
                        COMPILE_METHOD="sass_npx"
                        return 0
                    fi
                    echo "  Sass compilation failed"
                    tail -5 /tmp/compile_error.log
                fi
                return 1
                ;;
            postcss)
                if [ -n "$POSTCSS_CONFIG" ]; then
                    local pc_entry="${TW_ENTRY:-${SCSS_ENTRY}}"
                    if [ -n "$pc_entry" ] && [ -f "$REPO_DIR/$pc_entry" ]; then
                        echo "  Compiling PostCSS: npx postcss..."
                        if _timeout 120 npx postcss "$REPO_DIR/$pc_entry" -o "$CSS_FILE" \
                            --config "$REPO_DIR/$POSTCSS_CONFIG" 2>/tmp/compile_error.log; then
                            COMPILE_METHOD="postcss_npx"
                            return 0
                        fi
                        echo "  PostCSS compilation failed"
                        tail -5 /tmp/compile_error.log
                    fi
                fi
                return 1
                ;;
            *)
                echo "  No source compilation strategy for framework: $FRAMEWORK"
                return 1
                ;;
        esac
    }

    try_cdn_fallback() {
        echo ""
        echo "  Falling back to CDN + theme overrides..."
        > "$CSS_FILE"

        case "$FRAMEWORK" in
            bootstrap)
                local bs_ver="${VERSION:-5.3.0}"
                bs_ver=$(echo "$bs_ver" | sed 's/^v//')
                echo "  Fetching Bootstrap $bs_ver from CDN..."
                curl -sL "https://cdn.jsdelivr.net/npm/bootstrap@${bs_ver}/dist/css/bootstrap.min.css" >> "$CSS_FILE" 2>/dev/null || \
                curl -sL "https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" >> "$CSS_FILE" 2>/dev/null || true
                echo "" >> "$CSS_FILE"
                ;;
            bulma)
                local bl_ver="${VERSION:-0.9.4}"
                echo "  Fetching Bulma $bl_ver from CDN..."
                curl -sL "https://cdn.jsdelivr.net/npm/bulma@${bl_ver}/css/bulma.min.css" >> "$CSS_FILE" 2>/dev/null || true
                echo "" >> "$CSS_FILE"
                ;;
            foundation)
                local fd_ver="${VERSION:-6.8.1}"
                echo "  Fetching Foundation $fd_ver from CDN..."
                curl -sL "https://cdn.jsdelivr.net/npm/foundation-sites@${fd_ver}/dist/css/foundation.min.css" >> "$CSS_FILE" 2>/dev/null || true
                echo "" >> "$CSS_FILE"
                ;;
        esac

        DETECT_TMP=$(mktemp)
        echo "$CSS_DETECT" > "$DETECT_TMP"

        python3 - "$DETECT_TMP" "$FRAMEWORK" >> "$CSS_FILE" 2>/dev/null <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    detect = json.load(f)

framework = sys.argv[2]
overrides = detect.get("theme_overrides", {})
colors = overrides.get("colors", {})
custom = overrides.get("custom_colors", {})
fonts = overrides.get("fonts", {})
radius = overrides.get("border_radius")

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) != 6: return (0, 0, 0)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

lines = ["", "/* Theme overrides from project SCSS variables */", ":root {"]

for name, val in colors.items():
    if val and val != "null":
        r, g, b = hex_to_rgb(val)
        lines.append(f"  --bs-{name}: {val};")
        lines.append(f"  --bs-{name}-rgb: {r}, {g}, {b};")

body_font = fonts.get("body")
heading_font = fonts.get("heading")
if body_font and body_font != "null":
    lines.append(f"  --bs-body-font-family: {body_font};")
if heading_font and heading_font != "null":
    lines.append(f"  --bs-heading-font-family: {heading_font};")
if radius and radius != "null":
    lines.append(f"  --bs-border-radius: {radius};")

lines.append("}")

for name, val in custom.items():
    if val and val != "null":
        safe = name.replace("_", "-")
        lines.append(f".text-{safe} {{ color: {val} !important; }}")
        lines.append(f".bg-{safe} {{ background-color: {val} !important; }}")

primary = colors.get("primary")
secondary = colors.get("secondary")
if primary and primary != "null":
    lines.append(f".btn-primary {{ background-color: {primary}; border-color: {primary}; }}")
    lines.append(f".btn-primary:hover {{ background-color: {primary}; border-color: {primary}; opacity: 0.9; }}")
    lines.append(f".btn-outline-primary {{ color: {primary}; border-color: {primary}; }}")
    lines.append(f".btn-outline-primary:hover {{ background-color: {primary}; border-color: {primary}; color: #fff; }}")
    lines.append(f"a {{ color: {primary}; }}")
    lines.append(f".text-primary {{ color: {primary} !important; }}")
    lines.append(f".bg-primary {{ background-color: {primary} !important; }}")
if secondary and secondary != "null":
    lines.append(f".btn-secondary {{ background-color: {secondary}; border-color: {secondary}; }}")

print("\n".join(lines))

extra = overrides.get("extra_css", "")
if extra and extra != "null":
    print(f"\n/* Extra project overrides */\n{extra}")
PYEOF

        rm -f "$DETECT_TMP"
        COMPILE_METHOD="cdn_fallback"
    }

    if try_source_compile; then
        echo "  Source compilation succeeded ($COMPILE_METHOD)"
    else
        try_cdn_fallback
        echo "  Using CDN fallback ($COMPILE_METHOD)"
    fi

    # Append additional CDN links
    CDN_LINKS=$(echo "$CSS_DETECT" | jq -r '.cdn_links[]? // empty' 2>/dev/null)
    if [ -n "$CDN_LINKS" ]; then
        while IFS= read -r url; do
            if [ -n "$url" ] && [ "$url" != "null" ]; then
                echo "  Fetching CDN: $url"
                curl -sL "$url" >> "$CSS_FILE" 2>/dev/null || true
                echo "" >> "$CSS_FILE"
            fi
        done <<< "$CDN_LINKS"
    fi

    # Append plain CSS files
    CSS_FILES=$(echo "$CSS_DETECT" | jq -r '.css_files[]? // empty' 2>/dev/null)
    if [ -n "$CSS_FILES" ]; then
        while IFS= read -r css_path; do
            case "$css_path" in
                *.css)
                    if [ -f "$REPO_DIR/$css_path" ]; then
                        echo "  Including: $css_path"
                        cat "$REPO_DIR/$css_path" >> "$CSS_FILE"
                        echo "" >> "$CSS_FILE"
                    fi
                    ;;
            esac
        done <<< "$CSS_FILES"
    fi

    # Font @imports (must be at top of file)
    FONT_LINKS=$(echo "$CSS_DETECT" | jq -r '.font_links[]? // empty' 2>/dev/null)
    FONT_IMPORTS=""
    if [ -n "$FONT_LINKS" ]; then
        while IFS= read -r url; do
            if [ -n "$url" ] && [ "$url" != "null" ]; then
                FONT_IMPORTS="${FONT_IMPORTS}@import url('${url}');\n"
            fi
        done <<< "$FONT_LINKS"
    fi
    if [ -n "$FONT_IMPORTS" ]; then
        TMP_CSS=$(mktemp)
        printf '%b\n' "$FONT_IMPORTS" > "$TMP_CSS"
        cat "$CSS_FILE" >> "$TMP_CSS"
        mv "$TMP_CSS" "$CSS_FILE"
    fi
fi

CSS_SIZE=$(wc -c < "$CSS_FILE" 2>/dev/null || echo "0")
echo ""
echo "  Compile method: $COMPILE_METHOD"
echo "  Compiled CSS: ${CSS_SIZE} bytes"

record_phase "css_compilation"

# ─── Phase 1c: Image Extraction (once, deterministic) ────────────────────────

echo ""
echo "Phase 1c: Extracting images as base64 data URIs..."
start_timer

IMAGES_JSON="$SHARED_DIR/images_base64.json"

python3 - "$REPO_DIR" "$IMAGES_JSON" <<'PYEOF'
import os, sys, base64, json

repo_dir = sys.argv[1]
output_file = sys.argv[2]

MAX_FILE_SIZE = 50 * 1024
MAX_TOTAL_SIZE = 500 * 1024
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.ico'}
SKIP_DIRS = {'node_modules', '.git', 'vendor', 'tmp', 'log', 'coverage',
             '.bundle', 'dist', 'build', '.next', '.nuxt', '__pycache__',
             '.cache', '.parcel-cache', 'bower_components'}
PRIORITY_NAMES = {'logo', 'brand', 'favicon', 'icon', 'avatar', 'placeholder', 'default', 'hero'}

mime_map = {
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp',
    '.ico': 'image/x-icon',
}

found = []

for root, dirs, files in os.walk(repo_dir):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for fname in files:
        ext = os.path.splitext(fname)[1].lower()
        if ext not in IMAGE_EXTENSIONS:
            continue
        fpath = os.path.join(root, fname)
        try:
            fsize = os.path.getsize(fpath)
        except OSError:
            continue
        if fsize > MAX_FILE_SIZE or fsize == 0:
            continue
        rel_path = os.path.relpath(fpath, repo_dir)
        name_no_ext = os.path.splitext(fname)[0]
        if len(name_no_ext) > 40 and '-' in name_no_ext:
            parts = name_no_ext.rsplit('-', 1)
            if len(parts[1]) > 20:
                continue
        name_lower = name_no_ext.lower()
        is_priority = any(p in name_lower for p in PRIORITY_NAMES)
        found.append({
            'rel_path': rel_path,
            'abs_path': fpath,
            'size': fsize,
            'ext': ext,
            'priority': is_priority,
        })

found.sort(key=lambda x: (not x['priority'], x['size']))

images = {}
unique_data_uris = set()
total_b64_size = 0

for item in found:
    try:
        with open(item['abs_path'], 'rb') as f:
            data = f.read()
        b64 = base64.b64encode(data).decode('ascii')
        b64_size = len(b64)
        if total_b64_size + b64_size > MAX_TOTAL_SIZE:
            continue
        mime = mime_map.get(item['ext'], 'application/octet-stream')
        data_uri = f"data:{mime};base64,{b64}"

        if data_uri in unique_data_uris:
            images[item['rel_path']] = data_uri
            continue
        unique_data_uris.add(data_uri)

        rel = item['rel_path']
        fname = os.path.basename(rel)

        images[rel] = data_uri
        images['/' + rel] = data_uri
        images[fname] = data_uri
        images['/' + fname] = data_uri
        for prefix in ['/assets/', '/images/', '/img/', '/static/']:
            images[prefix + fname] = data_uri

        total_b64_size += b64_size
        print(f"  {item['size']//1024:>3}KB  {rel}", file=sys.stderr)
    except Exception:
        continue

count = len(unique_data_uris)
with open(output_file, 'w') as f:
    json.dump({"count": count, "total_b64_bytes": total_b64_size, "images": images}, f)

print(f"  Total: {count} unique image(s), {total_b64_size // 1024}KB base64", file=sys.stderr)
PYEOF

IMAGE_COUNT=$(jq -r '.count // 0' "$IMAGES_JSON" 2>/dev/null || echo "0")
echo "  Images found: $IMAGE_COUNT"

# Create a manifest of just the available image paths (no base64 data)
IMAGE_MANIFEST="$SHARED_DIR/images_manifest.txt"
jq -r '.images | keys[]' "$IMAGES_JSON" 2>/dev/null | sort -u > "$IMAGE_MANIFEST"

# Create a lookup script that Claude can call via Bash to get a data URI for a path
IMAGE_LOOKUP="$SHARED_DIR/image_lookup.sh"
cat > "$IMAGE_LOOKUP" <<'LOOKUPEOF'
#!/bin/bash
# Usage: image_lookup.sh <images.json> <path>
# Returns the data URI for the given path, or "NOT_FOUND"
jq -r --arg p "$2" '.images[$p] // "NOT_FOUND"' "$1" 2>/dev/null
LOOKUPEOF
chmod +x "$IMAGE_LOOKUP"

record_phase "image_extraction"

# ─── Shared pre-work timing ──────────────────────────────────────────────────

SHARED_TIMING="$SHARED_DIR/timing.json"
echo ""
echo "=== Pre-work complete ==="
jq '.' "$SHARED_TIMING"
echo ""

# ─── Phase 2: Article Generation (per model) ─────────────────────────────────

PROMPT_TEMPLATE="$SHARED_DIR/article_prompt.txt"
cat > "$PROMPT_TEMPLATE" <<PROMPT
You are a technical writer creating a help article for end users of this software project.

ARTICLE TOPIC: ${ARTICLE_TOPIC}

PRE-COMPILED CSS AND IMAGES will be injected automatically via post-processing.
You do NOT need to read or embed the CSS file yourself.

Available image paths are listed in: ${IMAGE_MANIFEST}

STEP 1: Explore the codebase to understand this feature. Look at:
- Routes, controllers, views related to this topic
- UI templates — find the ACTUAL template files for screens related to this article
- Any relevant models, services, or configuration

STEP 2: Write a help article as JSON:
{
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

Write each mockup to: __OUTPUT_DIR__/html/step_N.html (N is 0-based)

IMPORTANT:
- Write for END USERS, not developers
- Use clear, simple language
- Do NOT read the compiled CSS file — it will be injected automatically
- Do NOT read the images JSON file — use {{img:filename}} placeholders
- Generate 1-4 mockup images total
- Each mockup must be a complete standalone HTML file

Your final output must be ONLY the JSON article object.
PROMPT

# Post-processing script: injects CSS and images into HTML mockups
POSTPROCESS="$SHARED_DIR/postprocess.py"
cat > "$POSTPROCESS" <<'PYEOF'
#!/usr/bin/env python3
"""Post-process HTML mockups: inject compiled CSS and resolve image placeholders."""
import sys, os, re, json

html_dir = sys.argv[1]       # directory containing step_N.html files
css_file = sys.argv[2]       # compiled CSS file path
images_json = sys.argv[3]    # images_base64.json path

# Load CSS
css_content = ""
if os.path.isfile(css_file):
    with open(css_file) as f:
        css_content = f.read()

# Load image mapping
images = {}
if os.path.isfile(images_json):
    with open(images_json) as f:
        images = json.load(f).get("images", {})

# Build a filename-only lookup for convenience
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

    # Inject CSS: replace <!-- INJECT_CSS --> or add before </head>
    css_tag = f"<style>\n{css_content}\n</style>"
    if "<!-- INJECT_CSS -->" in html:
        html = html.replace("<!-- INJECT_CSS -->", css_tag)
    elif "</head>" in html:
        html = html.replace("</head>", f"{css_tag}\n</head>")
    elif "<body" in html:
        html = html.replace("<body", f"{css_tag}\n<body", 1)

    # Replace image placeholders: {{img:filename.png}}
    def replace_img(match):
        img_name = match.group(1)
        # Try filename directly, then with path variations
        uri = filename_lookup.get(img_name)
        if not uri:
            uri = images.get(img_name)
        if not uri:
            uri = images.get("/" + img_name)
        if not uri:
            uri = images.get("/assets/" + img_name)
        if uri:
            return uri
        return match.group(0)  # leave as-is if not found

    html = re.sub(r'\{\{img:([^}]+)\}\}', replace_img, html)

    with open(fpath, 'w') as f:
        f.write(html)
    count += 1
    print(f"  Post-processed: {fname}", file=sys.stderr)

print(f"  {count} file(s) post-processed", file=sys.stderr)
PYEOF
chmod +x "$POSTPROCESS"

for MODEL in "${MODEL_LIST[@]}"; do
    SHORT=$(model_short_name "$MODEL")
    MODEL_DIR="$BASE_DIR/$SHORT"
    rm -rf "$MODEL_DIR"
    mkdir -p "$MODEL_DIR/html" "$MODEL_DIR/images"

    # Reset OUTPUT_DIR for this model's timing
    OUTPUT_DIR="$MODEL_DIR"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Model: $MODEL ($SHORT)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    start_timer

    # Substitute the output dir into the prompt and pipe to claude
    sed "s|__OUTPUT_DIR__|$MODEL_DIR|g" "$PROMPT_TEMPLATE" | \
        run_claude_streaming "$MODEL_DIR/article_raw.json" \
        --model "$MODEL" --max-turns 30 --allowedTools "Read,Glob,Grep,Bash,Write"

    record_phase "article_generation"

    extract_result "$MODEL_DIR/article_raw.json" "$MODEL_DIR/article.json"

    # Post-process: inject CSS and images into HTML mockups
    start_timer
    echo "  Post-processing mockups..."
    python3 "$POSTPROCESS" "$MODEL_DIR/html" "$CSS_FILE" "$IMAGES_JSON"
    render_mockups
    record_phase "mockup_rendering"

    finalize_timing

    echo ""
    echo "  Article: $MODEL_DIR/article.json"
    echo "  HTML:    $MODEL_DIR/html/"
    echo ""
done

# ─── Comparison Table ─────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  COMPARISON"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

printf "%-10s %10s %10s %12s %10s %8s\n" "Model" "Time(s)" "Turns" "Tokens" "Cost" "Mockups"
printf "%-10s %10s %10s %12s %10s %8s\n" "─────────" "────────" "────────" "──────────" "────────" "──────"

for MODEL in "${MODEL_LIST[@]}"; do
    SHORT=$(model_short_name "$MODEL")
    MODEL_DIR="$BASE_DIR/$SHORT"
    TIMING="$MODEL_DIR/timing.json"

    if [ -f "$TIMING" ]; then
        DURATION=$(jq -r '(.phases[] | select(.name == "article_generation") | .duration_ms) // 0' "$TIMING" 2>/dev/null)
        DURATION_S=$(python3 -c "print(f'{${DURATION:-0} / 1000:.1f}')" 2>/dev/null || echo "?")
        TOKENS=$(jq -r '.total_tokens // 0' "$TIMING" 2>/dev/null)
        COST=$(jq -r '.total_cost_usd // "?"' "$TIMING" 2>/dev/null)
        COST_FMT=$(python3 -c "print(f'\${float(\"$COST\"):.4f}')" 2>/dev/null || echo "\$$COST")

        # Get turns from the raw output
        TURNS=$(jq -r '.num_turns // "?"' "$MODEL_DIR/article_raw.json" 2>/dev/null)

        # Count mockup files
        MOCKUP_COUNT=$(ls "$MODEL_DIR"/html/step_*.html 2>/dev/null | wc -l | tr -d ' ' || echo "0")

        printf "%-10s %10s %10s %12s %10s %8s\n" "$SHORT" "${DURATION_S}s" "$TURNS" "$TOKENS" "$COST_FMT" "$MOCKUP_COUNT"
    else
        printf "%-10s %10s %10s %12s %10s %8s\n" "$SHORT" "failed" "-" "-" "-" "-"
    fi
done

# Shared pre-work cost
SHARED_COST=$(jq -r '.total_cost_usd // "0"' "$SHARED_TIMING" 2>/dev/null)
SHARED_DURATION=$(jq -r '.total_duration_ms // 0' "$SHARED_TIMING" 2>/dev/null)
SHARED_S=$(python3 -c "print(f'{${SHARED_DURATION} / 1000:.1f}')" 2>/dev/null || echo "?")
SHARED_COST_FMT=$(python3 -c "print(f'\${float(\"$SHARED_COST\"):.4f}')" 2>/dev/null || echo "\$$SHARED_COST")

echo ""
echo "Shared pre-work: ${SHARED_S}s, ${SHARED_COST_FMT} (detection + compilation + images)"
echo "CSS: $COMPILE_METHOD, ${CSS_SIZE} bytes"
echo ""
echo "Output: $BASE_DIR/{$(IFS=,; echo "${MODEL_LIST[*]}" | sed 's/[^,]*/{&}/g' | tr -d '{}')}/"
echo "        open $BASE_DIR/*/html/step_0.html to compare mockups"
