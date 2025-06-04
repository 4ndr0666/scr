#!/bin/sh
# ffxd-v3.1.sh — Bulk video toolkit: merge/composite/process/batch with XDG, grid, and advanced mode.

set -eu
TMPFILES=""
trap 'for f in $TMPFILES; do [ -f "$f" ] && rm -f "$f"; done' EXIT
VERBOSE=0
FFX_DEBUG=${FFX_DEBUG:-0}

logv() {
  [ "$VERBOSE" -eq 1 ] && printf '[VERBOSE] %s\n' "$*" >&2
}

init_paths() {
  CFG_DIR=${XDG_CONFIG_HOME:-"$HOME/.config"}/ffx
  CACHE_DIR=${XDG_CACHE_HOME:-"$HOME/.cache"}/ffx
  RUN_DIR=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/ffx
  mkdir -p "$CFG_DIR" "$CACHE_DIR" "$RUN_DIR"
  CFG_FILE="$CFG_DIR/config"
}

# shellcheck source=/dev/null
load_defaults() {
  [ -f "$CFG_FILE" ] && . "$CFG_FILE"
  ADV_CONTAINER=${ADV_CONTAINER:-mp4}
  ADV_RES=${ADV_RES:-1920x1080}
  ADV_FPS=${ADV_FPS:-30}
  ADV_SPEED=${ADV_SPEED:-1.0}
  ADV_INTERPOLATE=${ADV_INTERPOLATE:-false}
}

save_defaults() {
  {
    printf 'ADV_CONTAINER=%s\n' "$ADV_CONTAINER"
    printf 'ADV_RES=%s\n' "$ADV_RES"
    printf 'ADV_FPS=%s\n' "$ADV_FPS"
    printf 'ADV_SPEED=%s\n' "$ADV_SPEED"
    printf 'ADV_INTERPOLATE=%s\n' "$ADV_INTERPOLATE"
  } >"$CFG_FILE"
}

wizard_prompt() {
  printf '--- Advanced Wizard (cfg at %s) ---\n' "$CFG_FILE"
  printf 'Container [%s]: ' "$ADV_CONTAINER"; read -r ans || :
  [ -n "$ans" ] && ADV_CONTAINER=$ans
  printf 'Resolution WxH [%s]: ' "$ADV_RES"; read -r ans || :
  [ -n "$ans" ] && ADV_RES=$ans
  printf 'FPS [%s]: ' "$ADV_FPS"; read -r ans || :
  [ -n "$ans" ] && ADV_FPS=$ans
  printf 'Speed factor [%s]: ' "$ADV_SPEED"; read -r ans || :
  [ -n "$ans" ] && ADV_SPEED=$ans
  printf 'Interpolate motion? (y/N): ' ; read -r ans || :
  case ${ans:-n} in y|Y) ADV_INTERPOLATE=true ;; *) ADV_INTERPOLATE=false ;; esac
  save_defaults
}

get_default_filename() {
  base=$1 ext=$2 n=0
  while :; do
    fn="${base}${n:+_$n}.${ext}"
    [ -e "$fn" ] || { printf '%s\n' "$fn"; return; }
    n=$((n+1))
  done
}

mktemp_run() { mktemp -p "$RUN_DIR" "$@"; }

detect_max_res() {
  max_w=0 max_h=0
  for f; do
    set -- $(ffprobe -v error -select_streams v:0 \
      -show_entries stream=width,height -of csv=p=0:s=' ' "$f" 2>/dev/null || printf '0 0')
    [ "$1" -gt "$max_w" ] && max_w=$1
    [ "$2" -gt "$max_h" ] && max_h=$2
  done
  printf '%s %s\n' "$max_w" "$max_h"
}

generate_leader_layout() {
  cnt=$1 w=$2 h=$3
  [ "$cnt" -eq 1 ] && { printf 'null'; return; }
  cols=3; layout=""; i=0
  cw=$(( w / cols )); ch=$(( h * 2 / 3 / cols ))   # more precise
  while [ "$i" -lt "$cnt" ]; do
    x=$(( (i % cols) * cw ))
    y=$(( (i / cols) * ch ))
    layout="${layout:+${layout}|}${x}_${y}"
    i=$((i+1))
  done
  printf 'xstack=inputs=%s:layout=%s:fill=black[v]' "$cnt" "$layout"
}

normalize_inputs() {
  sf=$1; shift; out_list=""
  for inpf; do
    [ -f "$inpf" ] || { printf 'Missing: %s\n' "$inpf" >&2; exit 1; }
    tmp=$(mktemp_run --suffix=.mp4)
    TMPFILES="$TMPFILES $tmp"
    if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$inpf" >/dev/null 2>&1; then
      ACMD="-c:a aac -b:a 128k"
    else
      ACMD="-an"
    fi
    ffmpeg -y -i "$inpf" -vf "$sf" -r "$ADV_FPS" \
      -c:v libx264 -qp 0 -pix_fmt yuv420p -preset veryfast $ACMD "$tmp" >/dev/null 2>&1
    out_list="${out_list}${tmp}
"
  done
  printf '%s' "$out_list"
}

check_dts_monotonicity() {
  f=$1 prev=""
  ffprobe -v error -select_streams v \
    -show_entries frame=pkt_dts_time -of csv=p=0 "$f" 2>/dev/null |
  while IFS= read -r dts; do
    [ -z "$dts" ] && continue
    [ -n "$prev" ] && awk "BEGIN{exit !($dts < $prev)}" && return 1
    prev=$dts
  done
}

apply_bulk_glob() {
  dir=$1
  find "$dir" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' \
      -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.webm' \
      -o -iname '*.gif' -o -iname '*.ts' \) -print
}

cmd_merge() {
  SCALE=largest COMPOSITE=0 ADVANCED=0 BULK=0 DIR=""
  INPUTS="" OUTPUT=""
  while [ $# -gt 0 ]; do
    case $1 in
      --scale) SCALE=$2; shift ;;
      --composite) COMPOSITE=1 ;;
      --advanced) ADVANCED=1 ;;
      --bulk) BULK=1; DIR=$2; shift ;;
      -v|--verbose) VERBOSE=1 ;;
      --help) printf 'Usage: ffxd merge [options] inputs out\n'; return ;;
      --*) printf 'merge: unknown %s\n' "$1" >&2; exit 1 ;;
      *) INPUTS="$INPUTS $1" ;;
    esac; shift
  done

  init_paths; load_defaults
  [ "$ADVANCED" -eq 1 ] && wizard_prompt
  [ "$BULK" -eq 1 ] && INPUTS=$(apply_bulk_glob "$DIR")

  set -- $INPUTS
  [ $# -lt 2 ] && { printf 'merge: need ≥2 inputs + output\n' >&2; exit 1; }
  for f in "$@"; do OUTPUT=$f; done
  IN_LIST=$(printf '%s\n' "$@" | sed "\$d")

  read -r max_w max_h <<EOF
$(detect_max_res $IN_LIST)
EOF

  case $SCALE in
    1080p) sf="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=black" ;;
    composite|largest|*) sf="scale=${max_w}:${max_h}:force_original_aspect_ratio=decrease,pad=${max_w}:${max_h}:(ow-iw)/2:(oh-ih)/2:color=black" ;;
  esac

  norm=$(normalize_inputs "$sf" $IN_LIST)
  set -- $norm

  if [ "$COMPOSITE" -eq 1 ]; then
    filt=$(generate_leader_layout $# "$max_w" "$max_h")
    cmd="ffmpeg -y"; for f; do cmd="$cmd -i \"$f\""; done
    cmd="$cmd -filter_complex '$filt' -map '[v]' -c:v libx264 -qp 0 -pix_fmt yuv420p -preset medium \"$OUTPUT\" >/dev/null 2>&1"
  else
    filt="[0:v][0:a]"
    i=1; while [ "$i" -lt "$#" ]; do filt="$filt[${i}:v][${i}:a]"; i=$((i+1)); done
    filt="$filt concat=n=$#:v=1:a=1[v][a]"
    cmd="ffmpeg -y"; for f; do cmd="$cmd -i \"$f\""; done
    cmd="$cmd -filter_complex '$filt' -map '[v]' -map '[a]' -c:v libx264 -qp 0 -pix_fmt yuv420p -preset medium -c:a aac -b:a 128k \"$OUTPUT\" >/dev/null 2>&1"
  fi
  eval "$cmd"
  printf '✅ Merge complete → %s\n' "$OUTPUT"
}

cmd_process() {
  BULK=0 DIR=""
  while [ $# -gt 0 ]; do
    case $1 in
      --bulk) BULK=1; DIR=$2; shift ;;
      --help) printf 'Usage: ffxd process [--bulk DIR] in out\n'; return ;;
      --*) printf 'process: unknown %s\n' "$1" >&2; exit 1 ;;
      *) break ;;
    esac; shift
  done
  if [ "$BULK" -eq 1 ]; then
    for f in $(apply_bulk_glob "$DIR"); do
      out="${f%.*}_fixed.mp4"; ffxd process "$f" "$out"
    done; return
  fi
  [ $# -lt 2 ] && { printf 'process: need in out\n' >&2; exit 1; }
  in=$1 out=$2
  ffmpeg -y -i "$in" -c copy -movflags +faststart "$out" >/dev/null 2>&1 && { printf '✅ Repaired: %s\n' "$out"; return; }
  ffmpeg -y -fflags +genpts -i "$in" -c:v copy -c:a aac -movflags +faststart "$out" >/dev/null 2>&1 && { printf '✅ Repaired: %s\n' "$out"; return; }
  check_dts_monotonicity "$in" || {
    ffmpeg -y -fflags +genpts -i "$in" -c:v libx264 -qp 0 -preset medium -c:a aac -movflags +faststart "$out" >/dev/null 2>&1 &&
    printf '✅ Repaired: %s\n' "$out"
  }
}

cmd_composite() {
  ADVANCED=0 BULK=0 DIR=""
  while [ $# -gt 0 ]; do
    case $1 in
      --advanced) ADVANCED=1 ;;
      --bulk) BULK=1; DIR=$2; shift ;;
      -v|--verbose) VERBOSE=1 ;;
      --help) printf 'Usage: ffxd composite [files]\n'; return ;;
      --*) printf 'composite: unknown %s\n' "$1" >&2; exit 1 ;;
      *) break ;;
    esac; shift
  done
  init_paths; load_defaults; [ "$ADVANCED" -eq 1 ] && wizard_prompt
  [ "$BULK" -eq 1 ] && set -- $(apply_bulk_glob "$DIR")
  [ $# -lt 1 ] && { printf 'composite: need inputs\n' >&2; exit 1; }
  read -r max_w max_h <<EOF
$(detect_max_res "$@")
EOF
  scale="scale=${max_w}:${max_h}:force_original_aspect_ratio=decrease,pad=${max_w}:${max_h}:(ow-iw)/2:(oh-ih)/2:color=black"
  norm=$(normalize_inputs "$scale" "$@")
  set -- $norm
  filt=$(generate_leader_layout $# "$max_w" "$max_h")
  out=$(get_default_filename composite mp4)
  if [ "$filt" = null ]; then
    cp "$1" "$out"
  else
    cmd="ffmpeg -y"; for f; do cmd="$cmd -i \"$f\""; done
    cmd="$cmd -filter_complex '$filt' -map '[v]' -c:v libx264 -qp 0 -pix_fmt yuv420p -preset medium \"$out\" >/dev/null 2>&1"
    eval "$cmd"
  fi
  printf '✅ Composite created: %s\n' "$out"
}

print_help() {
  cat <<'EOF'
ffxd — Media Toolkit
Usage: ffxd <command> [options]

Commands:
  merge      [--composite] [--bulk DIR] files... out.mp4
  process    [--bulk DIR]  in.mp4 out_fixed.mp4
  composite  [--bulk DIR] files...
  help       Show this help
EOF
}

[ $# -gt 0 ] || { print_help; exit 1; }
case $1 in
  merge)     shift; cmd_merge "$@" ;;
  process)   shift; cmd_process "$@" ;;
  composite) shift; cmd_composite "$@" ;;
  help|-h|--help) print_help ;;
  -v|--verbose) VERBOSE=1; shift; exec ffxd "$@" ;;
  *) printf 'Unknown subcmd: %s\n' "$1" >&2; exit 1 ;;
esac
