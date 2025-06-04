#!/bin/sh
# ffx-composite-v1.sh — Grid layout composite from multiple videos

set -e
trap 'for f in $TMPFILES; do [ -f "$f" ] && rm -f "$f"; done' EXIT
TMPFILES=""

get_default_filename() {
  base="composite"
  ext="mp4"
  name="${base}.${ext}"
  n=1
  while [ -f "$name" ]; do
    name="${base}${n}.${ext}"
    n=$((n+1))
  done
  echo "$name"
}

normalize_inputs() {
  files=("$@")
  norm=()
  for f in "${files[@]}"; do
    tmpf="$(mktemp --suffix=.mp4)"
    TMPFILES="$TMPFILES $tmpf"
    ffmpeg -y -i "$f" -r 30 -vf "scale=640:360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2:color=black" -c:v libx264 -qp 0 -pix_fmt yuv420p -preset veryfast "$tmpf" >/dev/null 2>&1
    norm+=("$tmpf")
  done
  echo "${norm[@]}"
}

generate_layout() {
  count="$1"
  case "$count" in
    1) echo "single" ;;
    2) echo "hstack=inputs=2" ;;
    3) echo "vstack=inputs=3" ;;
    4) echo "[0:v][1:v]hstack=2[top];[2:v][3:v]hstack=2[bottom];[top][bottom]vstack=2" ;;
    *) # default to grid
      layout=""
      cols=3
      rows=$(( (count + 2) / 3 ))
      for i in $(seq 0 $((count - 1))); do
        x=$(( (i % cols) * 640 ))
        y=$(( (i / cols) * 360 ))
        layout+="${x}_${y}|"
      done
      layout="${layout%|}"
      echo "xstack=inputs=$count:layout=${layout}:fill=black"
      ;;
  esac
}

composite_files() {
  files=("$@")
  count="${#files[@]}"
  out="$(get_default_filename)"

  norm=($(normalize_inputs "${files[@]}"))

  filter="$(generate_layout "$count")"
  if [ "$filter" = "single" ]; then
    cp "${norm[0]}" "$out"
  else
    ffmpeg -y $(for f in "${norm[@]}"; do printf -- "-i %s " "$f"; done)       -filter_complex "$filter" -c:v libx264 -qp 0 -pix_fmt yuv420p -preset medium "$out" >/dev/null 2>&1
  fi

  echo "✅ Composite created: $out"
}

main() {
  [ "$#" -lt 1 ] && {
    echo "Usage: $0 <video1> [video2 ... video9]" >&2
    exit 1
  }
  composite_files "$@"
}

main "$@"
