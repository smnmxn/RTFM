#!/bin/bash
set -e

# Run all three approaches on the same topic and compare results
# Usage: run_all.sh "How to reset your password"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARTICLE_TOPIC="${1:?Usage: run_all.sh \"Article topic\"}"

echo "╔════════════════════════════════════════════════════╗"
echo "║  Article Generation Benchmark                      ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Topic: $(printf '%-42s' "$ARTICLE_TOPIC")║"
echo "║  Repo:  $(printf '%-42s' "$(basename "$(pwd)")")║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Clean previous results
rm -rf benchmark_output

echo "━━━ Running Approach A: Baseline (single prompt) ━━━"
echo ""
"$SCRIPT_DIR/a_baseline.sh" "$ARTICLE_TOPIC"

echo ""
echo "━━━ Running Approach B: Pre-extracted CSS ━━━"
echo ""
"$SCRIPT_DIR/b_with_css.sh" "$ARTICLE_TOPIC"

echo ""
echo "━━━ Running Approach C: Screen Library ━━━"
echo ""
"$SCRIPT_DIR/c_with_screens.sh" "$ARTICLE_TOPIC"

# Summary comparison
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  Comparison Summary                                ║"
echo "╠════════════════════════════════════════════════════╣"

for approach in a b c; do
    label=""
    case $approach in
        a) label="A: Baseline" ;;
        b) label="B: With CSS" ;;
        c) label="C: Screen Library" ;;
    esac

    timing_file="benchmark_output/$approach/timing.json"
    if [ -f "$timing_file" ]; then
        total_ms=$(jq -r '.total_duration_ms // 0' "$timing_file")
        total_s=$(echo "scale=1; $total_ms / 1000" | bc 2>/dev/null || echo "?")
        tokens=$(jq -r '.total_tokens // "?"' "$timing_file")
        cost=$(jq -r '.total_cost_usd // "?"' "$timing_file")
        images=$(ls benchmark_output/$approach/images/step_*.png 2>/dev/null | wc -l || echo 0)

        printf "║  %-16s %6ss  %6s tokens  \$%-6s  %d img ║\n" "$label" "$total_s" "$tokens" "$cost" "$images"
    else
        printf "║  %-16s FAILED                              ║\n" "$label"
    fi
done

echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Compare mockups visually:"
echo "  open benchmark_output/a/images/"
echo "  open benchmark_output/b/images/"
echo "  open benchmark_output/c/images/"
echo ""
echo "Compare article content:"
echo "  diff benchmark_output/a/article.json benchmark_output/b/article.json"
echo ""
echo "Inspect HTML mockups:"
echo "  open benchmark_output/*/html/step_0.html"
