#!/bin/bash
# Usage: /render_mockup.sh <step_number> <html_file_path>
#
# Renders HTML to a PNG image at /output/images/step_<N>.png
# The HTML file should contain complete markup with embedded styles.
#
# Process:
# 1. Validates HTML structure before rendering
# 2. Renders HTML to PNG using Puppeteer
# 3. Generates diagnostics JSON with quality metrics
#
# Example:
#   /render_mockup.sh 0 /tmp/mockup_0.html

set -e

if [ "$#" -ne 2 ]; then
    echo "Error: Usage: /render_mockup.sh <step_number> <html_file_path>"
    exit 1
fi

STEP_NUM="$1"
HTML_FILE="$2"

# Validate step number is numeric
if ! [[ "$STEP_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: step_number must be a positive integer"
    exit 1
fi

if [ ! -f "$HTML_FILE" ]; then
    echo "Error: HTML file not found: $HTML_FILE"
    exit 1
fi

OUTPUT_PATH="/output/images/step_${STEP_NUM}.png"
HTML_OUTPUT_PATH="/output/html/step_${STEP_NUM}.html"
VALIDATION_PATH="/output/html/step_${STEP_NUM}_validation.json"

# Ensure output directories exist
mkdir -p /output/images /output/html /output/mockup_assets

# Copy HTML source to output for debugging (preserved when KEEP_ANALYSIS_OUTPUT=true)
# Skip copy if source and destination are the same (e.g., HTML already in /output/html/)
if [ "$(realpath "$HTML_FILE")" != "$(realpath "$HTML_OUTPUT_PATH")" ]; then
    cp "$HTML_FILE" "$HTML_OUTPUT_PATH"
fi

# Step 1: Validate HTML before rendering
echo "Validating HTML for step ${STEP_NUM}..."
VALIDATION_RESULT=$(node /validate_html.js "$HTML_FILE" 2>&1) || true
echo "$VALIDATION_RESULT" > "$VALIDATION_PATH"

# Parse validation result
if echo "$VALIDATION_RESULT" | grep -q '"valid":false'; then
    echo "Warning: HTML validation found errors:"
    echo "$VALIDATION_RESULT" | grep -o '"errors":\[[^]]*\]' || true
    # Continue anyway - render what we can for debugging
fi

if echo "$VALIDATION_RESULT" | grep -q '"warnings":\['; then
    WARNINGS=$(echo "$VALIDATION_RESULT" | grep -o '"warnings":\[[^]]*\]')
    if [ "$WARNINGS" != '"warnings":[]' ]; then
        echo "HTML validation warnings: $WARNINGS"
    fi
fi

# Step 2: Run the Node.js renderer with quality detection
# Render from /output/html/ so relative paths to ../mockup_assets/ resolve correctly
echo "Rendering mockup for step ${STEP_NUM}..."
node /render_mockup.js "$OUTPUT_PATH" "$HTML_OUTPUT_PATH"

# Step 3: Check results
if [ -f "$OUTPUT_PATH" ]; then
    # Check if diagnostics indicate poor quality
    DIAGNOSTICS_PATH="/output/images/step_${STEP_NUM}_diagnostics.json"
    if [ -f "$DIAGNOSTICS_PATH" ]; then
        QUALITY_RATING=$(grep -o '"rating":"[^"]*"' "$DIAGNOSTICS_PATH" | head -1 | cut -d'"' -f4)
        QUALITY_SCORE=$(grep -o '"score":[0-9]*' "$DIAGNOSTICS_PATH" | head -1 | cut -d':' -f2)

        if [ "$QUALITY_RATING" = "poor" ]; then
            echo "Warning: Render quality is poor (score: ${QUALITY_SCORE})"
        elif [ "$QUALITY_RATING" = "acceptable" ]; then
            echo "Note: Render quality is acceptable (score: ${QUALITY_SCORE})"
        else
            echo "Render quality: ${QUALITY_RATING} (score: ${QUALITY_SCORE})"
        fi
    fi

    echo "Success: Image saved to $OUTPUT_PATH"
    echo "  HTML source: $HTML_OUTPUT_PATH"
    echo "  Validation: $VALIDATION_PATH"
    [ -f "$DIAGNOSTICS_PATH" ] && echo "  Diagnostics: $DIAGNOSTICS_PATH"
else
    echo "Error: Failed to generate image"
    exit 1
fi
