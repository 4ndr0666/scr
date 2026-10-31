#!/usr/bin/env python3
"""
plugin_loader.py

Load and categorize prompt blocks from Markdown "plugin" files.

Usage:
    python3 plugin_loader.py [--json | --yaml] plugin1.md plugin2.md ...

Outputs (default): Null-delimited quoted blocks (legacy behavior).
Outputs (--json): A JSON object: { category: [block1, block2, ...], ... }
Outputs (--yaml): A YAML object (requires PyYAML installed).

Categories recognized (case-insensitive):
    pose, lighting, lens, camera_move, environment, shadow, detail
Any block under an unrecognized heading is placed into "uncategorized".
"""

import sys
import re
import json
from pathlib import Path
from typing import Dict, List

CATEGORY_KEYS: Dict[str, str] = {
    "pose": "pose",
    "lighting": "lighting",
    "lens": "lens",
    "camera_move": "camera_move",
    "camera": "camera_move",  # allow "camera" alias
    "environment": "environment",
    "shadow": "shadow",
    "detail": "detail",
}


def load_prompt_plugin_categorized(path: Path) -> Dict[str, List[str]]:
    r"""
    Read a Markdown plugin file at `path` and extract quoted blocks under headings.

    Returns a dict mapping category → list of prompt-block strings.

    Quoted block syntax:
      - Begins with a line starting with a double-quote (")
      - Ends with a line ending with a double-quote (")
      - Everything between (including newlines) is the block body (quotes stripped)

    Headings syntax:
      - A line matching r"^##\s*(\w+)", where \1 (lowercased) is looked up in CATEGORY_KEYS.
      - If no valid heading appears before a quoted block, it goes into "uncategorized".

    Raises:
      - ValueError if EOF reached while inside a quoted block (unterminated).
    """
    categorized: Dict[str, List[str]] = {
        "pose": [],
        "lighting": [],
        "lens": [],
        "camera_move": [],
        "environment": [],
        "shadow": [],
        "detail": [],
        "uncategorized": [],
    }

    current_category = "uncategorized"
    inside_block = False
    block_lines: List[str] = []

    with path.open(encoding="utf-8", errors="ignore") as fh:
        for raw_line in fh:
            line = raw_line.rstrip("\n")

            # Detect heading (only if not inside a block)
            heading_match = re.match(r"^##\s*(\w+)", line)
            if heading_match and not inside_block:
                key = heading_match.group(1).lower()
                current_category = CATEGORY_KEYS.get(key, "uncategorized")
                continue

            # Detect start of quoted block (line begins with optional whitespace then ")
            if re.match(r'^\s*".*', line) and not inside_block:
                inside_block = True
                stripped = line.lstrip().lstrip('"')
                # Check if single-line block (also ends with ")
                if re.match(r'.*"\s*$', line) and len(line) > 1:
                    stripped = stripped.rstrip('"').rstrip()
                    categorized[current_category].append(stripped.strip())
                    inside_block = False
                    block_lines = []
                else:
                    block_lines = [stripped]
                continue

            # If inside a quoted block
            if inside_block:
                # Check if line ends with a closing quote
                if re.match(r'.*"\s*$', line):
                    stripped = line.rstrip().rstrip('"').rstrip()
                    block_lines.append(stripped)
                    categorized[current_category].append("\n".join(block_lines).strip())
                    inside_block = False
                    block_lines = []
                else:
                    block_lines.append(line)
                continue

            # Lines outside blocks and headings are ignored

    # After loop, ensure no unterminated block remains
    if inside_block:
        raise ValueError(f"Unterminated quoted block in plugin: {path}")

    # Deduplicate each category while preserving order
    for cat, blocks in categorized.items():
        seen = set()
        deduped: List[str] = []
        for b in blocks:
            if b not in seen:
                seen.add(b)
                deduped.append(b)
        categorized[cat] = deduped

    return categorized


def load_prompt_plugin_legacy(path: Path) -> List[str]:
    """
    Legacy loader: ignore categories. Return a list of all quoted blocks (content only),
    to be printed null-delimited when called from sora_prompt_builder.sh.
    """
    blocks: List[str] = []
    inside_block = False
    block_lines: List[str] = []

    with path.open(encoding="utf-8", errors="ignore") as fh:
        for raw_line in fh:
            line = raw_line.rstrip("\n")
            if re.match(r'^\s*".*', line) and not inside_block:
                inside_block = True
                stripped = line.lstrip().lstrip('"')
                # Single-line block?
                if re.match(r'.*"\s*$', line) and len(line) > 1:
                    stripped = stripped.rstrip('"').rstrip()
                    blocks.append(stripped.strip())
                    inside_block = False
                else:
                    block_lines = [stripped]
                continue

            if inside_block:
                if re.match(r'.*"\s*$', line):
                    stripped = line.rstrip().rstrip('"').rstrip()
                    block_lines.append(stripped)
                    blocks.append("\n".join(block_lines).strip())
                    inside_block = False
                    block_lines = []
                else:
                    block_lines.append(line)
                continue

    if inside_block:
        raise ValueError(f"Unterminated quoted block in plugin: {path}")

    # Deduplicate all blocks while preserving order
    seen = set()
    deduped: List[str] = []
    for b in blocks:
        if b not in seen:
            seen.add(b)
            deduped.append(b)
    return deduped


def main():
    """
    CLI entry point for plugin_loader.py.

    Usage:
      plugin_loader.py [--json | --yaml] plugin1.md plugin2.md ...

    Outputs:
      - With --json: print a JSON object {category: [blocks], ...}
      - With --yaml: print a YAML representation (requires PyYAML)
      - Otherwise: print all quoted blocks legacy-style, null-delimited.
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Load and categorize prompt blocks from Markdown plugin files."
    )
    parser.add_argument(
        "--json", action="store_true", help="Output categorized blocks as JSON"
    )
    parser.add_argument(
        "--yaml",
        action="store_true",
        help="Output categorized blocks as YAML (requires PyYAML)",
    )
    parser.add_argument("plugins", nargs="+", help="Paths to plugin Markdown files")
    args = parser.parse_args()

    # Initialize merged categories
    merged_categories: Dict[str, List[str]] = {
        "pose": [],
        "lighting": [],
        "lens": [],
        "camera_move": [],
        "environment": [],
        "shadow": [],
        "detail": [],
        "uncategorized": [],
    }

    # Load and merge each plugin file
    for plugin_path in args.plugins:
        path = Path(plugin_path)
        if not path.is_file():
            print(f"[ERROR] Plugin file not found: {path}", file=sys.stderr)
            sys.exit(1)

        try:
            categorized = load_prompt_plugin_categorized(path)
        except ValueError as e:
            print(f"[ERROR] {e}", file=sys.stderr)
            sys.exit(1)

        for cat, blocks in categorized.items():
            merged_categories[cat].extend(blocks)

    # Deduplicate merged lists again
    for cat, blocks in merged_categories.items():
        seen = set()
        deduped: List[str] = []
        for b in blocks:
            if b not in seen:
                seen.add(b)
                deduped.append(b)
        merged_categories[cat] = deduped

    # Handle JSON output
    if args.json:
        print(json.dumps(merged_categories, indent=2))
        sys.exit(0)

    # Handle YAML output
    if args.yaml:
        try:
            import yaml  # PyYAML
        except ModuleNotFoundError:
            print("[ERROR] PyYAML is required for --yaml output", file=sys.stderr)
            sys.exit(1)
        print(yaml.dump(merged_categories, sort_keys=False))
        sys.exit(0)

    # Legacy behavior: print all blocks null-delimited
    legacy_blocks: List[str] = []
    for blocks in merged_categories.values():
        legacy_blocks.extend(blocks)

    for b in legacy_blocks:
        sys.stdout.write(b)
        sys.stdout.write("\0")

    sys.exit(0)


if __name__ == "__main__":
    main()
