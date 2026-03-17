#!/usr/bin/env python3
"""
Stream filter for claude --output-format stream-json

Reads JSONL from stdin, shows progress on stderr, writes the final
result JSON to the specified output file.

Usage: claude -p --output-format stream-json ... | python3 _stream_filter.py output.json
"""

import json
import sys
import os

def dim(text):
    return f"\033[2m{text}\033[0m"

def bold(text):
    return f"\033[1m{text}\033[0m"

def cyan(text):
    return f"\033[36m{text}\033[0m"

def green(text):
    return f"\033[32m{text}\033[0m"

def yellow(text):
    return f"\033[33m{text}\033[0m"

def main():
    if len(sys.argv) < 2:
        print("Usage: _stream_filter.py <output_file>", file=sys.stderr)
        sys.exit(1)

    output_file = sys.argv[1]
    all_events = []
    result_message = None
    current_tool = None
    tool_count = 0
    text_chunks = []

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        all_events.append(event)
        event_type = event.get("type", "")

        # Handle assistant messages (contain tool use and text blocks)
        if event_type == "assistant":
            content = event.get("message", {}).get("content", [])
            for block in content:
                if block.get("type") == "tool_use":
                    tool_count += 1
                    tool_name = block.get("name", "unknown")
                    tool_input = block.get("input", {})

                    # Show a concise summary based on tool type
                    if tool_name == "Read":
                        path = tool_input.get("file_path", "")
                        short = os.path.basename(path) if path else "?"
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Read')} {short}", file=sys.stderr)
                    elif tool_name == "Glob":
                        pattern = tool_input.get("pattern", "")
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Glob')} {pattern}", file=sys.stderr)
                    elif tool_name == "Grep":
                        pattern = tool_input.get("pattern", "")
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Grep')} {pattern}", file=sys.stderr)
                    elif tool_name == "Write":
                        path = tool_input.get("file_path", "")
                        short = os.path.basename(path) if path else "?"
                        print(f"  {dim(f'[{tool_count}]')} {green('Write')} {short}", file=sys.stderr)
                    elif tool_name == "Edit":
                        path = tool_input.get("file_path", "")
                        short = os.path.basename(path) if path else "?"
                        print(f"  {dim(f'[{tool_count}]')} {yellow('Edit')} {short}", file=sys.stderr)
                    elif tool_name == "Bash":
                        cmd = tool_input.get("command", "")
                        short = cmd[:60] + "..." if len(cmd) > 60 else cmd
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Bash')} {dim(short)}", file=sys.stderr)
                    else:
                        print(f"  {dim(f'[{tool_count}]')} {cyan(tool_name)}", file=sys.stderr)

                elif block.get("type") == "text":
                    # Collect text output
                    text = block.get("text", "")
                    if text:
                        text_chunks.append(text)

        # Handle the final result message
        elif event_type == "result":
            result_message = event
            cost = event.get("total_cost_usd", 0)
            duration = event.get("duration_ms", 0)
            turns = event.get("num_turns", 0)
            duration_s = duration / 1000 if duration else 0
            print(f"\n  {bold('Done')} — {turns} turns, {duration_s:.1f}s, ${cost:.4f}", file=sys.stderr)

    # Write the result to the output file
    if result_message:
        with open(output_file, "w") as f:
            json.dump(result_message, f, indent=2)
    elif all_events:
        # No result message — write the last event as fallback
        with open(output_file, "w") as f:
            json.dump(all_events[-1], f, indent=2)
    else:
        print("  Warning: no output from claude", file=sys.stderr)
        with open(output_file, "w") as f:
            json.dump({"error": "no output"}, f)

if __name__ == "__main__":
    main()
