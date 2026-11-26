#!/usr/bin/env python3
"""
Interactive string replace in multiple files.
Usage: replace.py old_text new_text file1 [file2...]
"""

import sys
import fileinput

if len(sys.argv) < 4:
    print("Usage: replace.py old new file1 [file2...]", file=sys.stderr)
    sys.exit(1)

old = sys.argv[1]
new = sys.argv[2]

for line in fileinput.input(sys.argv[3:], inplace=True, backup='.bak'):
    if old in line:
        print(f"\n{fileinput.filename()}:{fileinput.filelineno()}")
        print("OLD:", line.rstrip())
        choice = input(f"Replace '{old}' → '{new}'? [Y/n/edit]: ").strip().lower()
        
        if choice in ('', 'y'):
            line = line.replace(old, new)
        elif choice == 'edit':
            line = input("Enter new line: ") + "\n"
        # else: keep original

    sys.stdout.write(line)
