#!/usr/bin/env python3
"""
Stream filter for claude --output-format stream-json

Reads JSONL from stdin, shows progress on stderr, writes the final
result JSON to the specified output file, and optionally writes a
plain-text turn log to <output_file>.turns.log.

Usage: claude -p --output-format stream-json ... | python3 stream_filter.py output.json
"""

import json
import sys
import os
from datetime import datetime


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


def tool_summary(tool_name, tool_input):
    """Return a plain-text one-line summary of a tool call."""
    if tool_name == "Read":
        path = tool_input.get("file_path", "?")
        return f"Read {path}"
    elif tool_name == "Glob":
        pattern = tool_input.get("pattern", "?")
        path = tool_input.get("path", "")
        return f"Glob {pattern}" + (f" in {path}" if path else "")
    elif tool_name == "Grep":
        pattern = tool_input.get("pattern", "?")
        path = tool_input.get("path", "")
        return f"Grep {pattern}" + (f" in {path}" if path else "")
    elif tool_name == "Write":
        path = tool_input.get("file_path", "?")
        return f"Write {path}"
    elif tool_name == "Edit":
        path = tool_input.get("file_path", "?")
        return f"Edit {path}"
    elif tool_name == "Bash":
        cmd = tool_input.get("command", "?")
        short = cmd[:100] + "..." if len(cmd) > 100 else cmd
        return f"Bash: {short}"
    elif tool_name == "Agent":
        prompt = tool_input.get("prompt", "")
        desc = tool_input.get("description", "")
        short_prompt = prompt[:150] + "..." if len(prompt) > 150 else prompt
        return f"Agent ({desc}): {short_prompt}"
    else:
        return tool_name


def main():
    if len(sys.argv) < 2:
        print("Usage: stream_filter.py <output_file>", file=sys.stderr)
        sys.exit(1)

    output_file = sys.argv[1]
    log_file = output_file.rsplit(".", 1)[0] + ".turns.log"

    all_events = []
    result_message = None
    tool_count = 0
    turn_count = 0
    log_lines = []

    start_time = datetime.now()
    log_lines.append(f"Claude session started at {start_time.isoformat()}")
    log_lines.append("")

    def ts():
        elapsed = (datetime.now() - start_time).total_seconds()
        return f"[{elapsed:6.1f}s]"

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
            turn_count += 1
            content = event.get("message", {}).get("content", [])
            log_lines.append(f"{ts()} --- Turn {turn_count} ---")

            for block in content:
                if block.get("type") == "tool_use":
                    tool_count += 1
                    tool_name = block.get("name", "unknown")
                    tool_input = block.get("input", {})

                    summary = tool_summary(tool_name, tool_input)
                    log_lines.append(f"{ts()}   [{tool_count}] {summary}")

                    # Show on stderr too
                    short_name = os.path.basename(tool_input.get("file_path", "")) if tool_name in ("Read", "Write", "Edit") else ""
                    if tool_name == "Read":
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Read')} {short_name}", file=sys.stderr)
                    elif tool_name == "Glob":
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Glob')} {tool_input.get('pattern', '')}", file=sys.stderr)
                    elif tool_name == "Grep":
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Grep')} {tool_input.get('pattern', '')}", file=sys.stderr)
                    elif tool_name == "Write":
                        print(f"  {dim(f'[{tool_count}]')} {green('Write')} {short_name}", file=sys.stderr)
                    elif tool_name == "Edit":
                        print(f"  {dim(f'[{tool_count}]')} {yellow('Edit')} {short_name}", file=sys.stderr)
                    elif tool_name == "Bash":
                        cmd = tool_input.get("command", "")
                        short = cmd[:60] + "..." if len(cmd) > 60 else cmd
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Bash')} {dim(short)}", file=sys.stderr)
                    elif tool_name == "Agent":
                        desc = tool_input.get("description", "")
                        prompt = tool_input.get("prompt", "")
                        short_prompt = prompt[:80] + "..." if len(prompt) > 80 else prompt
                        print(f"  {dim(f'[{tool_count}]')} {cyan('Agent')} {bold(desc)} {dim(short_prompt)}", file=sys.stderr)
                    else:
                        print(f"  {dim(f'[{tool_count}]')} {cyan(tool_name)}", file=sys.stderr)

                elif block.get("type") == "text":
                    text = block.get("text", "")
                    if text:
                        # Log first 200 chars of text blocks
                        preview = text[:200] + "..." if len(text) > 200 else text
                        log_lines.append(f"{ts()}   [text] {preview}")

            log_lines.append("")

        # Handle tool results (acknowledge completion)
        elif event_type == "tool_result":
            content = event.get("content", "")
            tool_id = event.get("tool_use_id", "")
            # Log truncated result size so you can see the flow
            if isinstance(content, str):
                size = len(content)
                content_str = content
            elif isinstance(content, list):
                size = sum(len(str(c)) for c in content)
                content_str = str(content)
            else:
                size = len(str(content))
                content_str = str(content)
            is_error = event.get("is_error", False)
            if is_error:
                preview = content_str[:300]
                log_lines.append(f"{ts()}   -> ERROR: {preview}")
                print(f"  {yellow('-> ERROR:')} {preview[:100]}", file=sys.stderr)
            else:
                # For agent results, show a preview of what the agent returned
                if size > 500:
                    preview = content_str[:300].replace("\n", " ")
                    log_lines.append(f"{ts()}   -> OK ({size} chars): {preview}...")
                else:
                    log_lines.append(f"{ts()}   -> OK ({size} chars)")

        # Handle the final result message
        elif event_type == "result":
            result_message = event
            cost = event.get("total_cost_usd", 0)
            duration = event.get("duration_ms", 0)
            turns = event.get("num_turns", 0)
            duration_s = duration / 1000 if duration else 0

            log_lines.append(f"=== Complete ===")
            log_lines.append(f"Turns: {turns}")
            log_lines.append(f"Tool calls: {tool_count}")
            log_lines.append(f"Duration: {duration_s:.1f}s")
            log_lines.append(f"Cost: ${cost:.4f}")

            print(f"\n  {bold('Done')} — {turns} turns, {duration_s:.1f}s, ${cost:.4f}", file=sys.stderr)

    # Write the result to the output file
    if result_message:
        with open(output_file, "w") as f:
            json.dump(result_message, f, indent=2)
    elif all_events:
        with open(output_file, "w") as f:
            json.dump(all_events[-1], f, indent=2)
    else:
        print("  Warning: no output from claude", file=sys.stderr)
        log_lines.append("WARNING: no output from claude")
        with open(output_file, "w") as f:
            json.dump({"error": "no output"}, f)

    # Write the turn log
    with open(log_file, "w") as f:
        f.write("\n".join(log_lines) + "\n")
    print(f"  Turn log: {log_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
