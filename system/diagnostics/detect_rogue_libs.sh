#!/bin/sh
# detect_rogue_libs.sh — safely detect untracked .so files in system lib dirs

set -eu
IFS='
'

LIB_DIRS="/usr/lib /usr/local/lib"
DRY_RUN=true
NEEDS_SUDO=false
declare_found=""

# ─── Helpers ───────────────────────────────────────────────────────

has_command() {
  command -v "$1" >/dev/null 2>&1
}

error() {
  printf >&2 "✖ %s\n" "$*"
  exit 1
}

msg() {
  printf "→ %s\n" "$*"
}

warn() {
  printf >&2 "⚠ %s\n" "$*"
}

# ─── Validation ────────────────────────────────────────────────────

has_command pacman || error "pacman is required"

# ─── Scan Logic ────────────────────────────────────────────────────

scan_dir() {
  dir="$1"
  [ -d "$dir" ] || return 0

  for sofile in "$dir"/*.so*; do
    [ -e "$sofile" ] || continue

    # realpath fallback
    canonical=$(readlink -f "$sofile" 2>/dev/null || realpath "$sofile" 2>/dev/null || echo "$sofile")
    found=false

    # check if file is owned by a package
    if ! pacman -Qo "$canonical" >/dev/null 2>&1; then
      found=true
    fi

    if $found; then
      echo "$canonical"
      declare_found=true
    fi
  done
}

# ─── Main Execution ────────────────────────────────────────────────

msg "Scanning for rogue shared objects not tracked by pacman..."

found_libs=""
for dir in $LIB_DIRS; do
  for f in $(scan_dir "$dir"); do
    found_libs="${found_libs}
$f"
  done
done

if [ -n "${found_libs:-}" ]; then
  echo "⚠ Found rogue .so files:"
  echo "$found_libs"

  if $DRY_RUN; then
    echo
    echo "🧪 Dry-run mode: not removing anything. To clean, re-run with:"
    echo "DRY_RUN=false sudo sh detect_rogue_libs.sh"
  else
    [ "$(id -u)" -eq 0 ] || error "This script must be run with sudo to delete files"

    echo
    echo "⚠ Proceeding with cleanup..."
    echo "$found_libs" | while read -r lib; do
      [ -e "$lib" ] && rm -v -- "$lib"
    done
    echo "✅ Cleanup complete"
  fi
else
  echo "✓ No rogue shared libraries found. System is clean."
fi
