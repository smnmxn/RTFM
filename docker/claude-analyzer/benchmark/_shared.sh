#!/bin/bash
# Shared helpers for benchmark scripts

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(pwd)"

now_ms() {
    # macOS date doesn't support %N — use gdate (brew install coreutils) or python
    if command -v gdate &>/dev/null; then
        gdate +%s%3N
    else
        python3 -c 'import time; print(int(time.time()*1000))'
    fi
}

setup_output_dir() {
    local approach="$1"
    OUTPUT_DIR="$REPO_DIR/benchmark_output/$approach"
    # Clean previous results for this approach
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/images" "$OUTPUT_DIR/html"
    echo "Output: $OUTPUT_DIR"
}

start_timer() {
    PHASE_START=$(now_ms)
}

record_phase() {
    local phase_name="$1"
    local phase_end
    phase_end=$(now_ms)
    local duration_ms=$(( phase_end - PHASE_START ))
    local duration_s
    duration_s=$(python3 -c "print(f'{$duration_ms / 1000:.1f}')" 2>/dev/null || echo "${duration_ms}ms")

    echo "  $phase_name: ${duration_s}s"

    # Append to timing array
    if [ ! -f "$OUTPUT_DIR/timing.json" ]; then
        echo '{"phases":[]}' > "$OUTPUT_DIR/timing.json"
    fi

    local tmp
    tmp=$(mktemp)
    jq --arg name "$phase_name" --argjson ms "$duration_ms" \
        '.phases += [{"name": $name, "duration_ms": $ms}]' \
        "$OUTPUT_DIR/timing.json" > "$tmp" && mv "$tmp" "$OUTPUT_DIR/timing.json"

    PHASE_START=$(now_ms)
}

finalize_timing() {
    if [ ! -f "$OUTPUT_DIR/timing.json" ]; then
        echo '{"phases":[], "error": "no phases recorded"}' > "$OUTPUT_DIR/timing.json"
    fi

    # Add total and token usage from claude output files
    local total_ms=0
    total_ms=$(jq '[.phases[].duration_ms] | add // 0' "$OUTPUT_DIR/timing.json" 2>/dev/null || echo 0)

    # Collect token usage from any claude raw output files
    local total_input=0
    local total_output=0
    local total_cost="0"
    for f in "$OUTPUT_DIR"/*_raw.json; do
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
    local total_tokens=$((total_input + total_output))

    local tmp
    tmp=$(mktemp)
    jq --argjson total_ms "$total_ms" \
       --argjson total_tokens "$total_tokens" \
       --argjson input_tokens "$total_input" \
       --argjson output_tokens "$total_output" \
       --arg total_cost "$total_cost" \
       '. + {total_duration_ms: $total_ms, total_tokens: $total_tokens, input_tokens: $input_tokens, output_tokens: $output_tokens, total_cost_usd: $total_cost}' \
       "$OUTPUT_DIR/timing.json" > "$tmp" && mv "$tmp" "$OUTPUT_DIR/timing.json"

    echo ""
    echo "=== Results ==="
    jq '.' "$OUTPUT_DIR/timing.json"
}

# Run claude with streaming output
# Shows progress (tool calls, assistant text) on stderr while saving full output to a file
# Usage: run_claude_streaming <output_raw_json> [claude args...]
# The prompt is read from stdin.
run_claude_streaming() {
    local output_file="$1"
    shift

    # Run claude with stream-json, pipe through our progress filter
    # The filter shows tool use and text on stderr, saves everything to the raw file
    # Note: stream-json requires --verbose
    cat | claude -p --verbose --output-format stream-json "$@" | \
        python3 "$BENCHMARK_DIR/_stream_filter.py" "$output_file"
}

# Extract .result from claude raw JSON, stripping markdown fences if present
extract_result() {
    local raw_file="$1"
    local out_file="$2"
    jq -r '.result // empty' "$raw_file" 2>/dev/null | \
        sed '/^```json$/d; /^```$/d' > "$out_file" || true
}

# Render HTML mockups to PNG using puppeteer
render_mockups() {
    echo "Rendering mockups..."

    # Check if puppeteer is available
    if ! node -e "require('puppeteer')" 2>/dev/null; then
        echo "  Puppeteer not available — skipping PNG rendering"
        echo "  HTML mockups are in: $OUTPUT_DIR/html/"
        echo "  Open them in a browser to preview"
        return 0
    fi

    local count=0
    for html_file in "$OUTPUT_DIR"/html/step_*.html; do
        if [ -f "$html_file" ]; then
            local step_num
            step_num=$(basename "$html_file" | sed 's/step_//;s/\.html//')
            local png_path="$OUTPUT_DIR/images/step_${step_num}.png"

            # Use the project's render_mockup.js if available, otherwise inline puppeteer
            if [ -f "$BENCHMARK_DIR/../render_mockup.js" ]; then
                node "$BENCHMARK_DIR/../render_mockup.js" "$png_path" "$html_file" 2>/dev/null || echo "  Warning: failed to render $html_file"
            else
                node -e "
                    const puppeteer = require('puppeteer');
                    const path = require('path');
                    (async () => {
                        const browser = await puppeteer.launch({headless: 'new', args: ['--no-sandbox']});
                        const page = await browser.newPage();
                        await page.setViewport({width: 1200, height: 800, deviceScaleFactor: 2});
                        await page.goto('file://' + path.resolve('$html_file'), {waitUntil: 'networkidle0', timeout: 15000}).catch(() => {});
                        await page.screenshot({path: '$png_path', type: 'png'});
                        await browser.close();
                    })();
                " 2>/dev/null || echo "  Warning: failed to render $html_file"
            fi
            count=$((count + 1))
        fi
    done
    echo "  Rendered $count mockup(s)"
}
