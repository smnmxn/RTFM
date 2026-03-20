#!/bin/bash
set -e

# generate_css.sh — Detect and compile CSS from a repository
#
# Uses Claude only for detection (outputs JSON build plan), then compiles
# deterministically using npm tools (sass, tailwindcss, postcss) or CDN fetch.
# Falls back to CDN + theme overrides if source compilation fails.
#
# Required environment variables:
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token
# - ANTHROPIC_API_KEY: Anthropic API key
#
# Optional:
# - CLAUDE_MODEL: Model for detection (default: sonnet)
#
# Output:
# - /output/compiled_css.txt — Compiled CSS
# - /output/css_detect_parsed.json — Detection metadata
# - /output/usage.json — API usage tracking

echo "Starting CSS generation..."
echo "Repository: ${GITHUB_REPO}"

CLAUDE_MODEL="${CLAUDE_MODEL:-sonnet}"

# ─── Helpers ─────────────────────────────────────────────────────────────────

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

# ─── Clone ───────────────────────────────────────────────────────────────────

if [ ! -d /repo/.git ]; then
    echo "Cloning repository..."
    if ! git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>&1; then
        echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
        exit 1
    fi
fi
cd /repo

# ─── Phase 1: Detection ─────────────────────────────────────────────────────

echo "Phase 1: Detecting CSS framework..."
echo "API Key set: ${ANTHROPIC_API_KEY:+yes}"
echo "Model: ${CLAUDE_MODEL}"

set +e
cat <<'DETECT_PROMPT' | claude -p --model "$CLAUDE_MODEL" --output-format json --allowedTools "Read,Glob,Grep" > /output/css_detect_raw.json
Analyze this codebase to detect its CSS build setup.

CHECK (in order):
1. package.json / Gemfile / composer.json for CSS dependencies
2. Config files: tailwind.config.js, postcss.config.js, webpack.config.js, vite.config.ts
3. CSS/SCSS/Less entry files — find the MAIN entry point that imports everything
4. package.json "scripts" — look for build commands that reference sass, tailwindcss, postcss
5. Layout templates for CDN links and font imports
6. SCSS variable files — extract theme color values

For Tailwind: determine the MAJOR VERSION (3 or 4):
- Check package.json "tailwindcss" dependency version
- If the CSS entry uses @import "tailwindcss" or @import 'tailwindcss' → v4
- If the CSS entry uses @tailwind base; @tailwind components; @tailwind utilities; → v3
Report the version accurately (e.g. "4.1.0" or "3.4.17").

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
set -e

# Extract usage
jq '{session_id, total_cost_usd, duration_ms, num_turns, usage}' /output/css_detect_raw.json > /output/usage.json 2>/dev/null || true

# Parse detection result
CSS_DETECT=$(jq -r '.result // empty' /output/css_detect_raw.json 2>/dev/null | sed '/^```json$/d; /^```$/d' | sed -n '/^{/,/^}/p')
echo "$CSS_DETECT" > /output/css_detect_parsed.json

if [ -z "$CSS_DETECT" ]; then
    echo "ERROR: CSS detection failed — no result"
    echo "" > /output/compiled_css.txt
    exit 1
fi

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

# ─── Phase 2: Source Compilation ─────────────────────────────────────────────

CSS_FILE="/output/compiled_css.txt"
> "$CSS_FILE"
COMPILE_METHOD="none"

echo ""
echo "Phase 2: Compiling CSS..."

try_source_compile() {
    echo "  Attempting source compilation..."

    if [ "$HAS_PKG" = "true" ] && [ -f /repo/package.json ]; then
        local install_cmd="npm install"
        if [ "$PKG_MGR" = "yarn" ] && command -v yarn &>/dev/null; then
            install_cmd="yarn install"
        elif [ "$PKG_MGR" = "pnpm" ] && command -v pnpm &>/dev/null; then
            install_cmd="pnpm install"
        fi
        echo "  Running $install_cmd --ignore-scripts..."
        cd /repo
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
            if [ -n "$TW_ENTRY" ] && [ -f "/repo/$TW_ENTRY" ]; then
                # Detect Tailwind version
                local tw_ver
                tw_ver=$(node -e "try{console.log(require('/repo/node_modules/tailwindcss/package.json').version)}catch(e){}" 2>/dev/null || echo "")
                local tw_major="${tw_ver%%.*}"

                # Also detect v4 by entry file syntax if version check failed
                if [ -z "$tw_major" ] && grep -q '@import.*tailwindcss' "/repo/$TW_ENTRY" 2>/dev/null; then
                    tw_major="4"
                fi

                if [ "$tw_major" = "4" ]; then
                    echo "  Compiling Tailwind v4: npx @tailwindcss/cli..."
                    # Ensure @tailwindcss/cli is available
                    if ! npm ls @tailwindcss/cli 2>/dev/null | grep -q '@tailwindcss/cli'; then
                        echo "  Installing @tailwindcss/cli..."
                        npm install --no-save @tailwindcss/cli 2>/dev/null || true
                    fi
                    if _timeout 120 npx @tailwindcss/cli -i "/repo/$TW_ENTRY" -o "$CSS_FILE" 2>/tmp/compile_error.log; then
                        COMPILE_METHOD="tailwind_v4_npx"
                        return 0
                    fi
                    echo "  Tailwind v4 compilation failed"
                    tail -5 /tmp/compile_error.log
                    # Fall through to try v3 as last resort
                fi

                echo "  Compiling Tailwind v3: npx tailwindcss..."
                local tw_args="-i /repo/$TW_ENTRY -o $CSS_FILE"
                [ -n "$TW_CONFIG" ] && [ -f "/repo/$TW_CONFIG" ] && tw_args="-c /repo/$TW_CONFIG $tw_args"
                if _timeout 120 npx tailwindcss $tw_args 2>/tmp/compile_error.log; then
                    COMPILE_METHOD="tailwind_v3_npx"
                    return 0
                fi
                echo "  Tailwind v3 compilation failed"
                tail -5 /tmp/compile_error.log
            fi
            return 1
            ;;
        bootstrap|bulma|foundation|scss)
            if [ -n "$SCSS_ENTRY" ] && [ -f "/repo/$SCSS_ENTRY" ]; then
                echo "  Compiling SCSS: npx sass..."
                if _timeout 120 npx sass "/repo/$SCSS_ENTRY" "$CSS_FILE" \
                    --load-path=/repo/node_modules \
                    --load-path=/repo \
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
                if [ -n "$pc_entry" ] && [ -f "/repo/$pc_entry" ]; then
                    echo "  Compiling PostCSS: npx postcss..."
                    if _timeout 120 npx postcss "/repo/$pc_entry" -o "$CSS_FILE" \
                        --config "/repo/$POSTCSS_CONFIG" 2>/tmp/compile_error.log; then
                        COMPILE_METHOD="postcss_npx"
                        return 0
                    fi
                    echo "  PostCSS compilation failed"
                    tail -5 /tmp/compile_error.log
                fi
            fi
            return 1
            ;;
        plain_css)
            # Concatenate plain CSS files
            local css_files
            css_files=$(echo "$CSS_DETECT" | jq -r '.css_files[]? // empty' 2>/dev/null)
            if [ -n "$css_files" ]; then
                while IFS= read -r css_path; do
                    if [ -f "/repo/$css_path" ]; then
                        echo "  Including: $css_path"
                        cat "/repo/$css_path" >> "$CSS_FILE"
                        echo "" >> "$CSS_FILE"
                    fi
                done <<< "$css_files"
                if [ -s "$CSS_FILE" ]; then
                    COMPILE_METHOD="plain_css"
                    return 0
                fi
            fi
            return 1
            ;;
        *)
            echo "  No source compilation strategy for: $FRAMEWORK"
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
        tailwind)
            echo "  Generating Tailwind utility fallback CSS..."
            python3 /tailwind_fallback.py >> "$CSS_FILE" 2>/dev/null
            echo "" >> "$CSS_FILE"
            ;;
    esac

    # Generate theme overrides from detected SCSS variables
    DETECT_TMP=$(mktemp)
    echo "$CSS_DETECT" > "$DETECT_TMP"

    python3 - "$DETECT_TMP" "$FRAMEWORK" >> "$CSS_FILE" 2>/dev/null <<'PYEOF'
import json, sys, re

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

def is_valid(val):
    return val and val != "null"

body_font = fonts.get("body")
heading_font = fonts.get("heading")

lines = ["", "/* Theme overrides from project variables */", ":root {"]

if framework in ("bootstrap",):
    # Bootstrap-style: --bs-* variables and .btn-* classes
    for name, val in colors.items():
        if is_valid(val):
            r, g, b = hex_to_rgb(val)
            lines.append(f"  --bs-{name}: {val};")
            lines.append(f"  --bs-{name}-rgb: {r}, {g}, {b};")
    if is_valid(body_font):
        lines.append(f"  --bs-body-font-family: {body_font};")
    if is_valid(heading_font):
        lines.append(f"  --bs-heading-font-family: {heading_font};")
    if is_valid(radius):
        lines.append(f"  --bs-border-radius: {radius};")
    lines.append("}")

    for name, val in custom.items():
        if is_valid(val):
            safe = name.replace("_", "-")
            lines.append(f".text-{safe} {{ color: {val} !important; }}")
            lines.append(f".bg-{safe} {{ background-color: {val} !important; }}")

    primary = colors.get("primary")
    secondary = colors.get("secondary")
    if is_valid(primary):
        lines.append(f".btn-primary {{ background-color: {primary}; border-color: {primary}; }}")
        lines.append(f".btn-primary:hover {{ background-color: {primary}; border-color: {primary}; opacity: 0.9; }}")
        lines.append(f".btn-outline-primary {{ color: {primary}; border-color: {primary}; }}")
        lines.append(f".btn-outline-primary:hover {{ background-color: {primary}; border-color: {primary}; color: #fff; }}")
        lines.append(f"a {{ color: {primary}; }}")
        lines.append(f".text-primary {{ color: {primary} !important; }}")
        lines.append(f".bg-primary {{ background-color: {primary} !important; }}")
    if is_valid(secondary):
        lines.append(f".btn-secondary {{ background-color: {secondary}; border-color: {secondary}; }}")

elif framework in ("tailwind",):
    # Tailwind-style: generic CSS variables and utility overrides
    for name, val in colors.items():
        if is_valid(val):
            lines.append(f"  --color-{name}: {val};")
    if is_valid(body_font):
        lines.append(f"  font-family: {body_font};")
    if is_valid(heading_font):
        lines.append(f"  --font-heading: {heading_font};")
    if is_valid(radius):
        lines.append(f"  --radius: {radius};")
    lines.append("}")

    if is_valid(heading_font):
        lines.append(f"h1, h2, h3, h4, h5, h6 {{ font-family: {heading_font}; }}")

    for name, val in {**colors, **custom}.items():
        if is_valid(val):
            safe = name.replace("_", "-")
            lines.append(f".text-{safe} {{ color: {val}; }}")
            lines.append(f".bg-{safe} {{ background-color: {val}; }}")

else:
    # Generic: plain CSS custom properties
    for name, val in colors.items():
        if is_valid(val):
            lines.append(f"  --color-{name}: {val};")
    if is_valid(body_font):
        lines.append(f"  font-family: {body_font};")
    if is_valid(heading_font):
        lines.append(f"  --font-heading: {heading_font};")
    if is_valid(radius):
        lines.append(f"  --border-radius: {radius};")
    lines.append("}")

    for name, val in custom.items():
        if is_valid(val):
            safe = name.replace("_", "-")
            lines.append(f".text-{safe} {{ color: {val} !important; }}")
            lines.append(f".bg-{safe} {{ background-color: {val} !important; }}")

print("\n".join(lines))

# Sanitize extra_css: strip framework directives that browsers cannot parse
extra = overrides.get("extra_css", "")
if is_valid(extra):
    BAD_PATTERNS = [
        r'^@tailwind\b', r'^@theme\b', r'^@plugin\b', r'^@custom-variant\b',
        r'^@apply\b', r'^@config\b', r'^@source\b', r'^@utility\b', r'^@layer\b',
        r"^@import\s+[\"']tailwindcss",
    ]
    sanitized = []
    for line in extra.split('\n'):
        stripped = line.strip()
        if any(re.match(pat, stripped) for pat in BAD_PATTERNS):
            continue
        sanitized.append(line)
    clean = '\n'.join(sanitized).strip()
    if clean:
        print(f"\n/* Extra project overrides */\n{clean}")
PYEOF

    rm -f "$DETECT_TMP"
    COMPILE_METHOD="cdn_fallback"
}

# Execute: try source first, then CDN fallback
if try_source_compile; then
    echo "  Source compilation succeeded ($COMPILE_METHOD)"
else
    try_cdn_fallback
    echo "  Using CDN fallback ($COMPILE_METHOD)"
fi

# ─── Phase 3: Post-processing ───────────────────────────────────────────────

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

# Append plain CSS files not already included (only for fallback builds —
# if source compilation succeeded, these are already compiled into the output)
if [ "$COMPILE_METHOD" = "cdn_fallback" ] || [ "$COMPILE_METHOD" = "none" ]; then
    CSS_FILES=$(echo "$CSS_DETECT" | jq -r '.css_files[]? // empty' 2>/dev/null)
    if [ -n "$CSS_FILES" ]; then
        while IFS= read -r css_path; do
            case "$css_path" in
                *.css)
                    if [ -f "/repo/$css_path" ]; then
                        echo "  Including: $css_path"
                        cat "/repo/$css_path" >> "$CSS_FILE"
                        echo "" >> "$CSS_FILE"
                    fi
                    ;;
            esac
        done <<< "$CSS_FILES"
    fi
fi

# Font @imports (must be at top of file per CSS spec)
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

# Clean markdown fences if present
if head -1 "$CSS_FILE" | grep -q '^\`\`\`'; then
    echo "Warning: CSS contains markdown — cleaning"
    sed -i 's/^```css//; s/^```//' "$CSS_FILE"
fi

# ─── CSS Sanitization ────────────────────────────────────────────────────────
# Safety net: strip any un-compilable framework directives from the final output

echo ""
echo "Sanitizing output CSS..."

python3 - "$CSS_FILE" <<'SANITIZE_PY'
import re, sys

css_file = sys.argv[1]
with open(css_file) as f:
    css = f.read()

original_len = len(css)

BAD_DIRECTIVES = [
    r'^@tailwind\b[^;]*;?\s*$',
    r'^@theme\b',
    r'^@plugin\b[^;]*;?\s*$',
    r'^@custom-variant\b[^;]*;?\s*$',
    r'^@apply\b[^;]*;?\s*$',
    r'^@config\b[^;]*;?\s*$',
    r'^@source\b[^;]*;?\s*$',
    r'^@utility\b',
    r"^@import\s+[\"']tailwindcss[^;]*;?\s*$",
]

lines = css.split('\n')
cleaned = []
removed = 0
# Track brace depth for multi-line blocks like @theme { ... }
skip_depth = 0
for line in lines:
    stripped = line.strip()

    # If we're inside a block being skipped, track braces
    if skip_depth > 0:
        skip_depth += stripped.count('{') - stripped.count('}')
        removed += 1
        continue

    if any(re.match(pat, stripped) for pat in BAD_DIRECTIVES):
        removed += 1
        # If this line opens a block, skip until it closes
        if '{' in stripped:
            skip_depth = stripped.count('{') - stripped.count('}')
        continue
    cleaned.append(line)

if removed > 0:
    css = '\n'.join(cleaned)
    with open(css_file, 'w') as f:
        f.write(css)
    print(f"  Removed {removed} un-compilable directive line(s) ({original_len} -> {len(css)} bytes)")
else:
    print(f"  CSS clean — no directives to remove")
SANITIZE_PY

# ─── Summary ─────────────────────────────────────────────────────────────────

CSS_SIZE=$(wc -c < "$CSS_FILE" 2>/dev/null || echo "0")
echo ""
echo "CSS generation complete!"
echo "  Framework: $FRAMEWORK $VERSION"
echo "  Method: $COMPILE_METHOD"
echo "  Size: ${CSS_SIZE} bytes"
echo ""
echo "Output files:"
ls -la /output/compiled_css.txt /output/css_detect_parsed.json /output/usage.json 2>/dev/null || true
