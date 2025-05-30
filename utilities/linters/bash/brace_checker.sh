#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ===================== // BRACE_CHECKER.SH //
## Description: Static script structure analysis
# -------------------------------

## Help

usage() {
  echo "Usage: $0 <script> [--verbose] [--summary]"
  echo "  --verbose   Show all lines with braces (nl -ba + grep)"
  echo "  --summary   Show imbalance summary and location diffs"
  exit 1
}

[[ $# -lt 1 ]] && usage

SCRIPT="$1"
[[ ! -f "$SCRIPT" ]] && echo "Error: '$SCRIPT' not found." && exit 1

VERBOSE=false
SUMMARY=false

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true ;;
    --summary) SUMMARY=true ;;
    *) usage ;;
  esac
  shift
done

open_count=$(grep -o '{' "$SCRIPT" | wc -l)
close_count=$(grep -o '}' "$SCRIPT" | wc -l)

printf "\n--- Brace Count ---\n"
echo "{ count:   $open_count"
echo "} count:   $close_count"
echo "Delta:     $(( open_count - close_count ))"

printf "\n--- Functions / Block Starts ---\n"
awk '/\bfunction\b|{$/' "$SCRIPT" | nl

if [[ "$VERBOSE" == true ]]; then
  printf "\n--- Lines with { ---\n"
  nl -ba "$SCRIPT" | grep '{'
  printf "\n--- Lines with } ---\n"
  nl -ba "$SCRIPT" | grep '}'
fi

if [[ "$SUMMARY" == true ]]; then
  printf "\n--- Summary ---\n"
  echo "Script: $SCRIPT"
  if (( open_count != close_count )); then
    echo "⛔ Mismatch in { and } count!"
  else
    echo "✅ Braces balanced."
  fi

  echo "First 3 lines with open braces:"
  grep -n -o '{' "$SCRIPT" | head -3
  echo "First 3 lines with close braces:"
  grep -n -o '}' "$SCRIPT" | head -3
fi
