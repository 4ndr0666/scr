#!/usr/bin/env bash
# ffx-vidline.sh -- simple ffmpeg filter wrapper
#
# Functions: 9
# Lines: ~330

set -euo pipefail

# --- Constants ---
GREEN='\033[0;32m'
CYAN='\033[36m'
RED='\033[0;31m'
RESET='\033[0m'

LOGDIR="${XDG_DATA_HOME:-$HOME/.local/share}/vidline"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/ffmpeg_operations.log"

error_exit() {
    local ts
    ts="$(date '+%F %T')"
    printf '%b[%s] ERROR: %s%b\n' "$RED" "$ts" "$1" "$RESET" | tee -a "$LOGFILE" >&2
    exit 1
}
trap 'error_exit "Unexpected script failure near line ${LINENO}"' ERR

check_deps() {
    printf '%bChecking dependencies...%b\n' "$CYAN" "$RESET"
    local cmd
    for cmd in ffmpeg ffprobe fzf bc; do
        command -v "$cmd" > /dev/null 2>&1 || error_exit "Dependency missing: '$cmd' not found in PATH."
    done
    printf '%bDependencies OK.%b\n' "$GREEN" "$RESET"
}

unique_output_name() {
    local dir="$1" base="$2" ext="$3" candidate counter
    candidate="${dir}/${base}.${ext}"
    counter=1
    while [ -f "$candidate" ]; do
        candidate="${dir}/${base}_${counter}.${ext}"
        counter=$((counter + 1))
    done
    printf '%s\n' "$candidate"
}

choose_file() {
    printf '%bSelect input video:%b\n' "$CYAN" "$RESET"
    local f
    f="$(fzf)" || return 1
    [ -f "$f" ] || error_exit "Invalid file selected"
    printf '%s\n' "$f"
}

display_help() {
    cat << EOF2
Usage: ${0##*/} [--dry-run] [operations] [file]
Operations:
  --fps <val>             Set output frame rate
  --deflicker             Deflicker
  --dedot                 Dedot
  --dehalo                Dehalo
  --removegrain <t>       Removegrain type <t> (common: 1,2,17,22)
  --deband <params>       Deband with params (e.g., "range=16:r=4:d=4:t=4")
  --sharpen               Sharpen
  --scale                 Super resolution 2x
  --deshake               Deshake
  --edge-detect           Edge detection
  --slo-mo <factor>       Slow motion factor (e.g., 2 for half speed)
  --speed-up <factor>     Speed up factor (e.g., 2 for double speed)
  --convert <format>      Output container format (mp4|mkv|webm)
  --color-correct         Basic color correction
  --crop-resize <c> <r>   Crop then resize ("640:480:0:0" "1280:960")
  --rotate <deg>          Rotate by 90, 180, or -90 degrees
  --flip <h|v>            Flip horizontally (h) or vertically (v)
  -h, --help            Show this help
If no operations are provided an interactive menu will be shown.
EOF2
}

run_ffmpeg() {
    local infile="$1" outfile="$2" filters="$3"
    local -a cmd=(ffmpeg -y -i "$infile")
    [ -n "$filters" ] && cmd+=(-vf "$filters")
    cmd+=(-progress pipe:1 "$outfile")
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%bDry run:%b %q ' "$CYAN" "$RESET" "${cmd[@]}" && echo
        return 0
    fi
    printf '%bRunning ffmpeg...%b\n' "$CYAN" "$RESET"
    "${cmd[@]}" 2>&1 | tee -a "$LOGFILE"
    local status
    status=${PIPESTATUS[0]}
    if [ "$status" -ne 0 ]; then
        error_exit "ffmpeg failed with status $status. Check log file '$LOGFILE' for details."
    fi
    printf '%bffmpeg completed successfully.%b\n' "$GREEN" "$RESET"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                ;;
            --help | -h)
                display_help
                exit 0
                ;;
            --fps)
                if [ $# -lt 2 ]; then
                    error_exit "--fps requires a value"
                fi
                filters+=("fps=$2")
                shift
                ;;
            --deflicker)
                filters+=("deflicker")
                ;;
            --dedot)
                filters+=("removegrain=1")
                ;;
            --dehalo)
                filters+=("unsharp=5:5:-1.5:5:5:-1.5")
                ;;
            --removegrain)
                if [ $# -lt 2 ]; then
                    error_exit "--removegrain requires a type value"
                fi
                if ! [[ $2 =~ ^[0-9]+$ ]]; then
                    error_exit "--removegrain type must be numeric"
                fi
                filters+=("removegrain=$2")
                shift
                ;;
            --deband)
                if [ $# -lt 2 ]; then
                    error_exit "--deband requires parameter string"
                fi
                filters+=("deband=$2")
                shift
                ;;
            --sharpen)
                filters+=("unsharp")
                ;;
            --scale)
                filters+=("scale=iw*2:ih*2:flags=spline")
                ;;
            --deshake)
                filters+=("deshake")
                ;;
            --edge-detect)
                filters+=("edgedetect")
                ;;
            --slo-mo)
                if [ $# -lt 2 ]; then
                    error_exit "--slo-mo requires a factor"
                fi
                if ! [[ "$2" =~ ^[0-9]*(\.[0-9]+)?$ ]] || (($( echo "$2 <= 0" | bc -l))); then
                    error_exit "Invalid factor '$2' for --slo-mo. Must be a positive number."
                fi
                filters+=("setpts=$2*PTS")
                shift
                ;;
            --speed-up)
                if [ $# -lt 2 ]; then
                    error_exit "--speed-up requires a factor"
                fi
                if ! [[ "$2" =~ ^[0-9]*(\.[0-9]+)?$ ]] || (($( echo "$2 <= 0" | bc -l))); then
                    error_exit "Invalid factor '$2' for --speed-up. Must be a positive number."
                fi
                local sp
                sp="$(echo "1/$2" | bc -l)"
                filters+=("setpts=${sp}*PTS")
                shift
                ;;
            --convert)
                if [ $# -lt 2 ]; then
                    error_exit "--convert requires a format string"
                fi
                if ! [[ $2 =~ ^[A-Za-z0-9]+$ ]]; then
                    error_exit "--convert format must be alphanumeric"
                fi
                format="$2"
                shift
                ;;
            --color-correct)
                filters+=("eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7")
                ;;
            --crop-resize)
                if [ $# -lt 3 ]; then
                    error_exit "--crop-resize requires crop_params and scale_params"
                fi
                local crop_params="$2" scale_params="$3"
                if [ -z "$crop_params" ] || [ -z "$scale_params" ]; then
                    error_exit "--crop-resize requires non-empty crop_params and scale_params"
                fi
                filters+=("crop=$crop_params,scale=$scale_params")
                shift 2
                ;;
            --rotate)
                if [ $# -lt 2 ]; then
                    error_exit "--rotate requires degrees (90, 180, -90)"
                fi
                case "$2" in
                    90) filters+=("transpose=1") ;;
                    180) filters+=("transpose=2,transpose=2") ;;
                    -90) filters+=("transpose=2") ;;
                    *) error_exit "Invalid rotation degree '$2'. Must be 90, 180, or -90." ;;
                esac
                shift
                ;;
            --flip)
                if [ $# -lt 2 ]; then
                    error_exit "--flip requires direction (h or v)"
                fi
                case "$2" in
                    h) filters+=("hflip") ;;
                    v) filters+=("vflip") ;;
                    *) error_exit "Invalid flip direction '$2'. Must be 'h' or 'v'." ;;
                esac
                shift
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    if [ -z "$INPUT_FILE" ]; then
                        INPUT_FILE="$1"
                    else
                        error_exit "Unknown argument: '$1'. An input file '$INPUT_FILE' was already specified."
                    fi
                else
                    error_exit "Unknown argument: '$1'"
                fi
                ;;
        esac
        shift
    done
    if [ -n "$INPUT_FILE" ] && [ ! -r "$INPUT_FILE" ]; then
        error_exit "Input file not readable: '$INPUT_FILE'"
    fi
}

show_menu() {
    printf '%bNo operations provided. Select from menu (d to done, q to quit):%b\n' "$CYAN" "$RESET"
    cat << EOF
 1) fps <val>          Set frame rate
 2) deflicker          Deflicker
 3) dedot              Dedot
 4) dehalo             Dehalo
 5) removegrain <t>    Type 1,2,17,22
 6) deband <params>    Deband params
 7) sharpen            Sharpen
 8) scale              Super resolution
 9) deshake            Deshake
10) edge-detect        Edge detection
11) slo-mo <factor>    e.g., 2 for half speed
12) speed-up <factor>  e.g., 2 for double speed
13) convert <fmt>      mp4|mkv|webm
14) color-correct      Basic EQ
15) crop-resize <c> <r> Example: 640:480:0:0 1280:960
16) rotate <deg>       90, 180, -90
17) flip <h|v>         h or v
EOF
    local choice
    local -a args=()
    while true; do
        read -r -p "Choice: " choice
        case "$choice" in
            q) exit 0 ;;
            d) break ;;
            1)
                read -r -p "Enter fps value: " choice
                args+=(--fps "$choice")
                ;;
            2) args+=(--deflicker) ;;
            3) args+=(--dedot) ;;
            4) args+=(--dehalo) ;;
            5)
                read -r -p "Enter removegrain type (e.g., 1,2,17,22): " choice
                args+=(--removegrain "$choice")
                ;;
            6)
                read -r -p "Enter deband params (e.g., range=16:r=4:d=4:t=4): " choice
                args+=(--deband "$choice")
                ;;
            7) args+=(--sharpen) ;;
            8) args+=(--scale) ;;
            9) args+=(--deshake) ;;
            10) args+=(--edge-detect) ;;
            11)
                read -r -p "Enter slo-mo factor (e.g., 2): " choice
                args+=(--slo-mo "$choice")
                ;;
            12)
                read -r -p "Enter speed up factor (e.g., 2): " choice
                args+=(--speed-up "$choice")
                ;;
            13)
                read -r -p "Enter format (mp4|mkv|webm): " choice
                args+=(--convert "$choice")
                ;;
            14) args+=(--color-correct) ;;
            15)
                local c r
                read -r -p "Crop params (e.g., 640:480:0:0): " c
                read -r -p "Resize params (e.g., 1280:960): " r
                args+=(--crop-resize "$c" "$r")
                ;;
            16)
                read -r -p "Enter rotation degrees (90, 180, -90): " choice
                args+=(--rotate "$choice")
                ;;
            17)
                read -r -p "Enter flip direction (h or v): " choice
                args+=(--flip "$choice")
                ;;
            *)
                printf '%bInvalid choice%b\n' "$RED" "$RESET"
                ;;
        esac
    done
    printf '%s\n' "${args[@]}"
}

main() {
    check_deps
    DRY_RUN=0
    declare -a filters=()
    local format="mp4" INPUT_FILE=""

    parse_args "$@"

    if [ ${#filters[@]} -eq 0 ]; then
        mapfile -t _menu_args < <(show_menu)
        parse_args "${_menu_args[@]}"
    fi

    if [ -z "$INPUT_FILE" ]; then
        INPUT_FILE=$(choose_file) || exit 1
    fi

    local dir base outfile filter_chain
    dir=$(dirname "$INPUT_FILE")
    base=$(basename "$INPUT_FILE")
    base="${base%.*}_out"
    outfile=$(unique_output_name "$dir" "$base" "$format")
    filter_chain=$(
                   IFS=','
                            echo "${filters[*]}"
    )

    run_ffmpeg "$INPUT_FILE" "$outfile" "$filter_chain"
    printf '%bOutput saved to: %s%b\n' "$GREEN" "$outfile" "$RESET"
}

main "$@"
