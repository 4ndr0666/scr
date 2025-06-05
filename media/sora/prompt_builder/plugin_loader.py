#!/usr/bin/env python3
"""
plugin_loader.py

Reads a Markdown file (e.g. plugins/prompts1.md) and extracts every top-level
quoted prompt block (i.e. blocks that start with a line beginning with `"` and
end with a line that is exactly `"`). Prints each prompt block as a null-
delimited string (for safe Bash ingestion).

Usage:
    python3 plugin_loader.py path/to/plugins/prompts1.md

Output:
    <prompt1>\0<prompt2>\0...<promptN>\0
"""

import sys
from pathlib import Path
import re

def load_prompt_plugin(path: Path) -> list[str]:
    """
    Parse the Markdown file at 'path' and return a list of prompt blocks.
    A 'prompt block' is any multiline segment that:
      - Starts on a line whose first character is a double-quote:    ^"
      - Ends on a line whose entire content is a single double-quote: ^"$
      - All lines in-between are part of the block, preserving newlines.
    """
    text = path.read_text(encoding="utf-8")
    prompts: list[str] = []

    lines = text.splitlines()
    in_block = False
    current_block = []

    for line in lines:
        # Detect start of a block
        if not in_block and line.startswith('"'):
            in_block = True
            # strip only the leading quote
            current_block.append(line[1:])
            continue

        # Detect end of a block (line that is exactly a single quote)
        if in_block and line.strip() == '"':
            in_block = False
            prompts.append("\n".join(current_block))
            current_block = []
            continue

        # Accumulate lines if in_block
        if in_block:
            current_block.append(line)

    return prompts


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} path/to/plugin.md", file=sys.stderr)
        sys.exit(1)

    plugin_path = Path(sys.argv[1])
    if not plugin_path.is_file():
        print(f"Error: File not found: {plugin_path}", file=sys.stderr)
        sys.exit(1)

    blocks = load_prompt_plugin(plugin_path)
    for block in blocks:
        # Print each block followed by a NUL terminator
        sys.stdout.write(block)
        sys.stdout.write("\0")

    # Exit (number of blocks is inferred by Bash through its reading logic)
    sys.exit(0)


if __name__ == "__main__":
    main()
