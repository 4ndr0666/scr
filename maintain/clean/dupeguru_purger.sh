#!/bin/bash
# dupe-purger-safe.sh — Preview + explicit permission before deleting duplicates
# Keeps the largest file in each group

set -euo pipefail

SCANFILE="${1:-DUPEGURUSCAN.dupeguru}"
if [[ ! -f "$SCANFILE" ]]; then
  echo "Usage: $0 <dupeguru-scan-file>"
  exit 1
fi

echo "┌──(root💀4ndr0666)-[/dev/akasha]"
echo "└─$ Safe duplicate purger — will ask before every deletion"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Extract groups
awk '
  /<group>/ { group++ }
  /path="([^"]+)"/ {
    match($0, /path="([^"]+)"/, a)
    print a[1] >> "'"$TMP"'/group-"group".txt"
  }
' "$SCANFILE"

total_groups=0
total_deleted=0

for g in "$TMP"/group-*.txt; do
  [[ -f "$g" ]] || continue
  mapfile -t files < "$g"
  [[ ${#files[@]} -le 1 ]] && continue

  total_groups=$((total_groups + 1))

  # Find largest
  largest=""
  maxsize=0
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    if (( size > maxsize )); then
      maxsize=$size
      largest="$f"
    fi
  done

  echo ""
  echo "=== Group $total_groups ==="
  echo "Largest (keeper): $(basename "$largest") ($(numfmt --to=iec $maxsize))"

  # Preview all duplicates vs keeper
  preview=()
  for f in "${files[@]}"; do
    [[ "$f" == "$largest" ]] && continue
    [[ -f "$f" ]] && preview+=("$f")
  done

  if [[ ${#preview[@]} -gt 0 ]]; then
    echo "Opening preview (keeper + dupes) — close viewer to continue..."
    if [[ "${preview[0]}" =~ \.(mp4|mov|avi|mkv)$ ]]; then
      mpv --loop --no-audio "$largest" "${preview[@]}" &
      pid=$!
      read -r -p "Press Enter after reviewing..."
      kill $pid 2>/dev/null || true
    else
      nsxiv -a -b -s h "$largest" "${preview[@]}" &
      pid=$!
      read -r -p "Press Enter after reviewing..."
      kill $pid 2>/dev/null || true
    fi
  fi

  # Ask for permission to delete duplicates
  echo "Delete the ${#preview[@]} smaller duplicates in this group? (y/N)"
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    for f in "${preview[@]}"; do
      echo "  Deleting: $f"
      rm -f "$f"
      total_deleted=$((total_deleted + 1))
    done
  else
    echo "  Skipped this group."
  fi
done

echo ""
echo "Purge session complete."
echo "Groups reviewed: $total_groups"
echo "Files deleted: $total_deleted"
echo "All deletions required your explicit 'y' confirmation."
