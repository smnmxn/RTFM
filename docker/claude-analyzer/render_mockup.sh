#!/bin/bash
# Usage: /render_mockup.sh <step_number> <html_content>
# Or:    /render_mockup.sh <step_number> --file <html_file_path>
#
# Renders HTML to a PNG image at /output/images/step_<N>.png
# Returns the output path on success, error message on failure.

set -e

if [ "$#" -lt 2 ]; then
    echo "Error: Usage: /render_mockup.sh <step_number> <html_content>"
    echo "       Or: /render_mockup.sh <step_number> --file <html_file_path>"
    exit 1
fi

STEP_NUM="$1"
shift

# Validate step number is numeric
if ! [[ "$STEP_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: step_number must be a positive integer"
    exit 1
fi

OUTPUT_PATH="/output/images/step_${STEP_NUM}.png"

# Ensure output directory exists
mkdir -p /output/images

if [ "$1" = "--file" ]; then
    # Read HTML from file
    HTML_FILE="$2"
    if [ ! -f "$HTML_FILE" ]; then
        echo "Error: HTML file not found: $HTML_FILE"
        exit 1
    fi
    HTML_CONTENT=$(cat "$HTML_FILE")
else
    # HTML passed as argument
    HTML_CONTENT="$1"
fi

# Run the Node.js renderer
echo "$HTML_CONTENT" | node /render_mockup.js "$OUTPUT_PATH"

if [ -f "$OUTPUT_PATH" ]; then
    echo "Success: Image saved to $OUTPUT_PATH"
else
    echo "Error: Failed to generate image"
    exit 1
fi
