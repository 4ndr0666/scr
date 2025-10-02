#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ================== // FFX-VIDLINE //
## Description: A script to apply ffmpeg filters and
#              operations via CLI or interactive menu.
# ---------------------------------------

## Colors

GREEN='\033[0;32m' CYAN='\033[36m' RED='\033[0;31m' RESET='\033[0m'

## Logging

LOGDIR="${XDG_DATA_HOME:-$HOME/.local/share}/vidline"
mkdir -p -- "$LOGDIR"
LOGFILE="$LOGDIR/ffmpeg_operations.log"

##Globals

DRY_RUN=0
filters=()          # individual filter tokens
format="mp4"        # output container
INPUT_FILE=""       # path to input video

## TRAP

error_exit() {
  local ts; ts="$(date '+%F %T')"
  printf '%b[%s] ERROR: %s%b\n' "$RED" "$ts" "$1" "$RESET" | tee -a "$LOGFILE" >&2
  exit 1
}
trap 'error_exit "Unexpected script failure near line ${LINENO}"' ERR

## Dependencies

check_deps() {
  printf '%bChecking dependencies...%b\n' "$CYAN" "$RESET"
  for cmd in ffmpeg ffprobe fzf bc; do
    command -v "$cmd" &>/dev/null || error_exit "Dependency missing: '$cmd'"
  done
  printf '%bDependencies OK.%b\n' "$GREEN" "$RESET"
}

unique_output_name() {
  local dir=$1 base=$2 ext=$3 counter=1 cand
  cand="${dir}/${base}.${ext}"
  while [[ -e $cand ]]; do
    cand="${dir}/${base}_${counter}.${ext}"
    ((counter++))
  done
  printf '%s\n' "$cand"
}

choose_file() {
  # Prompt to stderr so stdout carries only the selected path
  printf '%bSelect input video:%b\n' "$CYAN" "$RESET" >&2
  local f; f="$(fzf)" || return 1
  [[ -f $f ]] || error_exit "Invalid selection: '$f'"
  printf '%s\n' "$f"
}

display_help() {
  cat <<EOF
Usage: ${0##*/} [--dry-run] [operations] [file]

Examples
  --fps 30             --scale             --slo-mo 2
  --deflicker          --edge-detect       --speed-up 1.5
  --removegrain 22     --deband "range=16:r=4:d=4"

Run without arguments for an interactive menu.
EOF
}

# ── ffmpeg runner ──────────────────────────────────────────────────────────
run_ffmpeg() {
  local infile=$1 outfile=$2; shift 2
  local -a flt=("$@") cmd filter_chain
  cmd=(ffmpeg -y -i "$infile")

  if ((${#flt[@]})); then
    local IFS=,
    filter_chain="${flt[*]}"
    cmd+=(-vf "$filter_chain")
  fi

  cmd+=(-progress pipe:1 "$outfile")

  if ((DRY_RUN)); then
    printf '%bDRY-RUN:%b %q\n' "$CYAN" "$RESET" "${cmd[@]}"
    return 0
  fi

  printf '%bRunning ffmpeg...%b\n' "$CYAN" "$RESET"
  "${cmd[@]}" 2>&1 | tee -a "$LOGFILE"
  local rv=${PIPESTATUS[0]}
  ((rv == 0)) || error_exit "ffmpeg failed (status $rv), see $LOGFILE"
  printf '%bffmpeg completed successfully.%b\n' "$GREEN" "$RESET"
}

# ── CLI parser ─────────────────────────────────────────────────────────────
parse_args() {
  while (($#)); do
    case $1 in
      --dry-run) DRY_RUN=1 ;;
      -h|--help) display_help; exit 0 ;;
      --fps)
        if [ $# -lt 2 ] || [[ ! $2 =~ ^[0-9]+$ ]]; then error_exit "--fps <int>"; fi
        filters+=("fps=$2"); shift ;;
      --deflicker)     filters+=("deflicker") ;;
      --dedot)         filters+=("removegrain=1") ;;
      --dehalo)        filters+=("unsharp=5:5:-1.5:5:5:-1.5") ;;
      --removegrain)
        if [ $# -lt 2 ] || [[ ! $2 =~ ^[0-9]+$ ]]; then error_exit "--removegrain <type>"; fi
        filters+=("removegrain=$2"); shift ;;
      --deband)
        if [ $# -lt 2 ]; then error_exit "--deband <params>"; fi
        filters+=("deband=$2"); shift ;;
      --sharpen)       filters+=("unsharp") ;;
      --scale)         filters+=("scale=iw*2:ih*2:flags=spline") ;;
      --deshake)       filters+=("deshake") ;;
      --edge-detect)   filters+=("edgedetect") ;;
      --slo-mo)
        if [ $# -lt 2 ] || [[ ! $2 =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error_exit "--slo-mo <factor>"; fi
        if (( $(bc -l <<<"$2 <= 0") )); then error_exit "--slo-mo factor > 0"; fi
        filters+=("setpts=$2*PTS"); shift ;;
      --speed-up)
        if [ $# -lt 2 ] || [[ ! $2 =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error_exit "--speed-up <factor>"; fi
        if (( $(bc -l <<<"$2 <= 0") )); then error_exit "--speed-up factor > 0"; fi
        filters+=("setpts=$(bc -l <<<"1/$2")*PTS"); shift ;;
      --convert)
        if [ $# -lt 2 ] || [[ ! $2 =~ ^[A-Za-z0-9]+$ ]]; then error_exit "--convert <fmt>"; fi
        format=$2; shift ;;
      --color-correct) filters+=("eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7") ;;
      --crop-resize)
        if [ $# -lt 3 ] || [ -z "$2" ] || [ -z "$3" ]; then
          error_exit "--crop-resize <crop> <scale>"
        fi
        filters+=("crop=$2,scale=$3"); shift 2 ;;
      --rotate)
        if [ $# -lt 2 ]; then error_exit "--rotate <deg>"; fi
        case $2 in
          90)  filters+=("transpose=1") ;;
          180) filters+=("transpose=2,transpose=2") ;;
          -90) filters+=("transpose=2") ;;
          *)   error_exit "rotate must be 90, 180 or -90" ;;
        esac; shift ;;
      --flip)
        if [ $# -lt 2 ]; then error_exit "--flip <h|v>"; fi
        case $2 in
          h) filters+=("hflip") ;;
          v) filters+=("vflip") ;;
          *) error_exit "flip must be h|v" ;;
        esac; shift ;;
      --*) error_exit "Unknown option $1" ;;
      *)   # input file
        if [[ -z $INPUT_FILE ]]; then INPUT_FILE=$1
        else error_exit "Multiple input files"; fi ;;
    esac
    shift
  done
}

# ── Interactive menu (prints only tokens) ─────────────────────
show_menu() {
  {
    printf '%bMenu (d=done, q=quit)%b\n' "$CYAN" "$RESET"
    printf ' 1) fps         6) deband        11) slo-mo      16) rotate\n'
    printf ' 2) deflicker   7) sharpen       12) speed-up    17) flip\n'
    printf ' 3) dedot       8) scale         13) convert\n'
    printf ' 4) dehalo      9) deshake       14) color-correct\n'
    printf ' 5) removegrain 10) edge-detect  15) crop-resize\n'
  } >&2

  local choice; local -a out=()
  while true; do
    read -r -p "Choice: " choice
    case $choice in
      d) break ;;
      q) exit 0 ;;
      1)  read -r -p "FPS value: " v
          [[ $v =~ ^[0-9]+$ ]] && out+=(--fps "$v") ||
            printf '%bInvalid FPS%b\n' "$RED" "$RESET" >&2 ;;
      2)  out+=(--deflicker) ;;
      3)  out+=(--dedot) ;;
      4)  out+=(--dehalo) ;;
      5)  read -r -p "removegrain type: " t
          [[ $t =~ ^[0-9]+$ ]] && out+=(--removegrain "$t") ||
            printf '%bInvalid type%b\n' "$RED" "$RESET" >&2 ;;
      6)  read -r -p "deband params: " p
          [[ $p ]] && out+=(--deband "$p") ||
            printf '%bParams required%b\n' "$RED" "$RESET" >&2 ;;
      7)  out+=(--sharpen) ;;
      8)  out+=(--scale) ;;
      9)  out+=(--deshake) ;;
      10) out+=(--edge-detect) ;;
      11) read -r -p "slo-mo factor: " f
          if [[ $f =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(bc -l <<<"$f > 0") )); then
              out+=(--slo-mo "$f")
          else
              printf '%bInvalid factor%b\n' "$RED" "$RESET" >&2
          fi ;;
      12) read -r -p "speed-up factor: " f
          if [[ $f =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(bc -l <<<"$f > 0") )); then
              out+=(--speed-up "$f")
          else
              printf '%bInvalid factor%b\n' "$RED" "$RESET" >&2
          fi ;;
      13) read -r -p "format: " fmt
          [[ $fmt =~ ^[A-Za-z0-9]+$ ]] && out+=(--convert "$fmt") ||
            printf '%bInvalid format%b\n' "$RED" "$RESET" >&2 ;;
      14) out+=(--color-correct) ;;
      15) read -r -p "crop params: " c; read -r -p "scale params: " s
          if [[ $c && $s ]]; then out+=(--crop-resize "$c" "$s")
          else printf '%bRequired%b\n' "$RED" "$RESET" >&2; fi ;;
      16) read -r -p "degrees (90/180/-90): " d
          case $d in 90|180|-90) out+=(--rotate "$d") ;;
          *) printf '%bInvalid%b\n' "$RED" "$RESET" >&2 ;; esac ;;
      17) read -r -p "flip h|v: " f
          case $f in h|v) out+=(--flip "$f") ;;
          *) printf '%bInvalid%b\n' "$RED" "$RESET" >&2 ;; esac ;;
      *)  printf '%bUnknown choice%b\n' "$RED" "$RESET" >&2 ;;
    esac
  done
  printf '%s\n' "${out[@]}"
}

# ── Main ───────────────────────────────────────────────────────
main() {
  check_deps
  parse_args "$@"

  # menu if no filters yet
  if ((${#filters[@]} == 0)); then
    mapfile -t menu_args < <(show_menu)
    local -a new_cli=("${menu_args[@]}")
    [[ -n $INPUT_FILE ]] && new_cli+=("$INPUT_FILE")
    filters=(); INPUT_FILE=""
    parse_args "${new_cli[@]}"
  fi

  # prompt for file if still missing
  [[ -n $INPUT_FILE ]] || INPUT_FILE=$(choose_file) || exit 1
  [[ -r $INPUT_FILE ]] || error_exit "Cannot read '$INPUT_FILE'"

  # build output
  local dir base outfile
  dir=$(dirname -- "$INPUT_FILE")
  base=${INPUT_FILE##*/}; base=${base%.*}_out
  outfile=$(unique_output_name "$dir" "$base" "$format")

  run_ffmpeg "$INPUT_FILE" "$outfile" "${filters[@]}"
  printf '%bOutput saved to:%b %s\n' "$GREEN" "$RESET" "$outfile"
}
main "$@"
