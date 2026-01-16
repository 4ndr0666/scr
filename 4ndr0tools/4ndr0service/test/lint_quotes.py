#!/usr/bin/env python3
"""
Custom Linter for Quote Consistency in Bash Scripts.
Validates that all string literals have matching opening and closing quotes.
Detects unescaped quotes inside strings.
"""

import sys
import glob
import re

def validate_quotes(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    errors = []
    lines = content.splitlines()
    
    # Simple state machine to track quotes
    # This is a basic parser and might not catch complex nested subshells correctly,
    # but covers the 90% case for unbalanced quotes in scripts.
    
    in_single = False
    in_double = False
    escaped = False
    
    for i, line in enumerate(lines):
        # Skip comments
        code_line = line.strip()
        if code_line.startswith('#'):
            continue

        for char_idx, char in enumerate(line):
            if escaped:
                escaped = False
                continue
            
            if char == '\\':
                escaped = True
                continue
                
            if char == "'" and not in_double:
                in_single = not in_single
            elif char == '"' and not in_single:
                in_double = not in_double

        # Reset escape at end of line (unless line continuation, which we skip for simplicity here)
        escaped = False

    if in_single:
        errors.append("Unclosed single quote detected.")
    if in_double:
        errors.append("Unclosed double quote detected.")

    if errors:
        print(f"[FAIL] {file_path}")
        for err in errors:
            print(f"  - {err}")
        return False
    else:
        print(f"[OK]   {file_path}")
        return True

def main():
    if len(sys.argv) < 2:
        print("Usage: lint_quotes.py <file_pattern>")
        sys.exit(1)

    files = []
    for pattern in sys.argv[1:]:
        files.extend(glob.glob(pattern, recursive=True))

    passed = True
    for file_path in files:
        if not validate_quotes(file_path):
            passed = False

    if not passed:
        sys.exit(1)

if __name__ == "__main__":
    main()
