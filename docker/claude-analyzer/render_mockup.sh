#!/bin/bash
# Usage: /render_mockup.sh <step_number> <html_file_path>
#
# Renders HTML to a PNG image at /output/images/step_<N>.png
# The HTML file should contain complete markup with embedded styles.
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

# Ensure output directories exist
mkdir -p /output/images /output/html

# Copy HTML source to output for debugging (preserved when KEEP_ANALYSIS_OUTPUT=true)
cp "$HTML_FILE" "$HTML_OUTPUT_PATH"

# Run the Node.js renderer
node /render_mockup.js "$OUTPUT_PATH" "$HTML_FILE"

if [ -f "$OUTPUT_PATH" ]; then
    echo "Success: Image saved to $OUTPUT_PATH, HTML saved to $HTML_OUTPUT_PATH"
else
    echo "Error: Failed to generate image"
    exit 1
fi
