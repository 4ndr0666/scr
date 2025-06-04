#!/bin/sh
# ffx-process-v1.sh — Repair broken video files progressively

set -e
trap 'for f in $TMPFILES; do [ -f "$f" ] && rm -f "$f"; done' EXIT
TMPFILES=""

check_dts_monotonicity() {
  file="$1"
  prev=""
  ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null |
  while read -r dts; do
    [ -z "$dts" ] && continue
    if [ -n "$prev" ] && awk "BEGIN{exit !($dts < $prev)}"; then
      echo "❌ Non-monotonic DTS detected"
      return 1
    fi
    prev="$dts"
  done
}

process_file() {
  in="$1"
  out="$2"

  echo "🔧 Attempting to repair: $in → $out"

  echo "📦 Phase 1: Try container remux (copy)..."
  if ffmpeg -y -i "$in" -c copy -movflags +faststart "$out" >/dev/null 2>&1; then
    echo "✅ Phase 1 succeeded."
    return 0
  fi

  echo "⚠️ Phase 1 failed. Trying rewrap + genpts..."
  if ffmpeg -y -fflags +genpts -i "$in" -c:v copy -c:a aac -movflags +faststart "$out" >/dev/null 2>&1; then
    echo "✅ Phase 2 succeeded."
    return 0
  fi

  echo "⚠️ Phase 2 failed. Checking DTS..."
  tmpf="$(mktemp --suffix=.mp4)"
  TMPFILES="$TMPFILES $tmpf"

  if ! check_dts_monotonicity "$in"; then
    echo "🧬 Re-encoding with corrected timestamps..."
    ffmpeg -y -fflags +genpts -i "$in" -c:v libx264 -qp 0 -preset medium -c:a aac -movflags +faststart "$out" >/dev/null 2>&1
    echo "✅ Phase 3 (re-encode) succeeded."
    return 0
  fi

  echo "🚫 All phases failed. File may be irreparable."
  return 1
}

main() {
  [ "$#" -ne 2 ] && {
    echo "Usage: $0 input.mp4 output_fixed.mp4" >&2
    exit 1
  }
  process_file "$1" "$2"
}

main "$@"
