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

# --- Global state ---
DRY_RUN=0
filters=()
format="mp4"
INPUT_FILE=""

error_exit() {
    local ts
    ts="$(date '+%F %T')"
    printf '%b[%s] ERROR: %s%b\n' "$RED" "$ts" "$1" "$RESET" | tee -a "$LOGFILE" >&2
    exit 1
}
trap 'error_exit "Unexpected script failure near line ${LINENO}"' ERR

check_deps() {
    printf '%bChecking dependencies...%b\n' "$CYAN" "$RESET"
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
  -h, --help              Show this help
If no operations are provided an interactive menu will be shown.
EOF2
}

run_ffmpeg() {
    local infile="$1" outfile="$2" filters="$3"
    local -a cmd=(ffmpeg -y -i "$infile")
    [ -n "$filters" ] && cmd+=(-vf "$filters")
    cmd+=(-progress pipe:1 "$outfile")
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%bDry run:%b %q\n' "$CYAN" "$RESET" "${cmd[@]}"
        return 0
    fi
    printf '%bRunning ffmpeg...%b\n' "$CYAN" "$RESET"
    "${cmd[@]}" 2>&1 | tee -a "$LOGFILE"
    local status=${PIPESTATUS[0]}
    if [ "$status" -ne 0 ]; then
        error_exit "ffmpeg failed with status $status. Check log file '$LOGFILE' for details."
    fi
    printf '%bffmpeg completed successfully.%b\n' "$GREEN" "$RESET"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1 ;;
            --help | -h)
                display_help
                exit 0 ;;
            --fps)
                [ $# -lt 2 ] && error_exit "--fps requires a value"
                [[ $2 =~ ^[0-9]+$ ]] || error_exit "--fps must be a positive integer"
                filters+=("fps=$2")
                shift ;;
            --deflicker)
                filters+=("deflicker") ;;
            --dedot)
                filters+=("removegrain=1") ;;
            --dehalo)
                filters+=("unsharp=5:5:-1.5:5:5:-1.5") ;;
            --removegrain)
                [ $# -lt 2 ] && error_exit "--removegrain requires a type"
                [[ $2 =~ ^[0-9]+$ ]] || error_exit "--removegrain type must be numeric"
                filters+=("removegrain=$2")
                shift ;;
            --deband)
                [ $# -lt 2 ] && error_exit "--deband requires parameter string"
                filters+=("deband=$2")
                shift ;;
            --sharpen)
                filters+=("unsharp") ;;
            --scale)
                filters+=("scale=iw*2:ih*2:flags=spline") ;;
            --deshake)
                filters+=("deshake") ;;
            --edge-detect)
                filters+=("edgedetect") ;;
            --slo-mo)
                [ $# -lt 2 ] && error_exit "--slo-mo requires a factor"
                [[ "$2" =~ ^[0-9]+([.][0-9]+)?$ ]] || error_exit "--slo-mo factor must be numeric"
                (( $(echo "$2 > 0" | bc -l) )) || error_exit "--slo-mo factor must be >0"
                filters+=("setpts=$2*PTS")
                shift ;;
            --speed-up)
                [ $# -lt 2 ] && error_exit "--speed-up requires a factor"
                [[ "$2" =~ ^[0-9]+([.][0-9]+)?$ ]] || error_exit "--speed-up factor must be numeric"
                (( $(echo "$2 > 0" | bc -l) )) || error_exit "--speed-up factor must be >0"
                local sp
                sp="$(echo "1/$2" | bc -l)"
                filters+=("setpts=${sp}*PTS")
                shift ;;
            --convert)
                [ $# -lt 2 ] && error_exit "--convert requires a format"
                [[ $2 =~ ^[A-Za-z0-9]+$ ]] || error_exit "--convert format must be alphanumeric"
                format="$2"
                shift ;;
            --color-correct)
                filters+=("eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7") ;;
            --crop-resize)
                [ $# -lt 3 ] && error_exit "--crop-resize requires crop_params and scale_params"
                [ -z "$2" ] || [ -z "$3" ] && error_exit "--crop-resize requires non-empty crop_params and scale_params"
                filters+=("crop=$2,scale=$3")
                shift 2 ;;
            --rotate)
                [ $# -lt 2 ] && error_exit "--rotate requires degrees (90, 180, -90)"
                case "$2" in
                    90) filters+=("transpose=1") ;;
                    180) filters+=("transpose=2,transpose=2") ;;
                    -90) filters+=("transpose=2") ;;
                    *) error_exit "Invalid rotation degree '$2'. Must be 90, 180, or -90." ;;
                esac
                shift ;;
            --flip)
                [ $# -lt 2 ] && error_exit "--flip requires direction (h or v)"
                case "$2" in
                    h) filters+=("hflip") ;;
                    v) filters+=("vflip") ;;
                    *) error_exit "Invalid flip direction '$2'. Must be 'h' or 'v'." ;;
                esac
                shift ;;
            *)
                if [[ "$1" != -* ]]; then
                    if [ -z "$INPUT_FILE" ]; then
                        INPUT_FILE="$1"
                    else
                        error_exit "Unknown argument: '$1'. An input file '$INPUT_FILE' was already specified."
                    fi
                else
                    error_exit "Unknown argument: '$1'"
                fi ;;
        esac
        shift
    done
    [ -n "$INPUT_FILE" ] && [ ! -f "$INPUT_FILE" ] && error_exit "Input file not found: '$INPUT_FILE'"
}

show_menu() {
    printf '%bNo operations provided. Select from menu (d to done, q to quit):%b\n' "$CYAN" "$RESET"
    printf ' 1) fps\n 2) deflicker\n 3) dedot\n 4) dehalo\n 5) removegrain\n'
    printf ' 6) deband\n 7) sharpen\n 8) scale\n 9) deshake\n10) edge-detect\n'
    printf '11) slo-mo\n12) speed-up\n13) convert\n14) color-correct\n15) crop-resize\n'
    printf '16) rotate\n17) flip\n'
    local choice
    local -a args=()
    while true; do
        read -r -p "Choice: " choice
        case "$choice" in
            q) exit 0 ;;
            d) break ;;
            1)
                local val
                read -r -p "Enter fps value: " val
                [[ $val =~ ^[0-9]+$ ]] || { printf '%bInvalid FPS value%b\n' "$RED" "$RESET"; continue; }
                args+=(--fps "$val") ;;
            2) args+=(--deflicker) ;;
            3) args+=(--dedot) ;;
            4) args+=(--dehalo) ;;
            5)
                local type
                read -r -p "Enter removegrain type: " type
                [[ $type =~ ^[0-9]+$ ]] || { printf '%bInvalid type%b\n' "$RED" "$RESET"; continue; }
                args+=(--removegrain "$type") ;;
            6)
                local params
                read -r -p "Enter deband params: " params
                [ -n "$params" ] || { printf '%bParams required%b\n' "$RED" "$RESET"; continue; }
                args+=(--deband "$params") ;;
            7) args+=(--sharpen) ;;
            8) args+=(--scale) ;;
            9) args+=(--deshake) ;;
            10) args+=(--edge-detect) ;;
            11)
                local factor
                read -r -p "Enter slo-mo factor: " factor
                [[ "$factor" =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf '%bInvalid factor%b\n' "$RED" "$RESET"; continue; }
                (( $(echo "$factor > 0" | bc -l) )) || { printf '%bFactor must be > 0%b\n' "$RED" "$RESET"; continue; }
                args+=(--slo-mo "$factor") ;;
            12)
                local factor
                read -r -p "Enter speed up factor: " factor
                [[ "$factor" =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf '%bInvalid factor%b\n' "$RED" "$RESET"; continue; }
                (( $(echo "$factor > 0" | bc -l) )) || { printf '%bFactor must be > 0%b\n' "$RED" "$RESET"; continue; }
                args+=(--speed-up "$factor") ;;
            13)
                local fmt
                read -r -p "Enter format: " fmt
                [[ $fmt =~ ^[A-Za-z0-9]+$ ]] || { printf '%bInvalid format%b\n' "$RED" "$RESET"; continue; }
                args+=(--convert "$fmt") ;;
            14) args+=(--color-correct) ;;
            15)
                local c r
                read -r -p "Enter crop params: " c
                read -r -p "Enter scale params: " r
                [ -n "$c" ] && [ -n "$r" ] || { printf '%bCrop and scale required%b\n' "$RED" "$RESET"; continue; }
                args+=(--crop-resize "$c" "$r") ;;
            16)
                local deg
                read -r -p "Enter degrees (90,180,-90): " deg
                case "$deg" in
                    90|180|-90) args+=(--rotate "$deg") ;;
                    *) printf '%bInvalid degrees%b\n' "$RED" "$RESET"; continue ;;
                esac ;;
            17)
                local dir
                read -r -p "Enter flip direction (h|v): " dir
                case "$dir" in
                    h|v) args+=(--flip "$dir") ;;
                    *) printf '%bInvalid direction%b\n' "$RED" "$RESET"; continue ;;
                esac ;;
            *) printf '%bInvalid choice%b\n' "$RED" "$RESET";;
        esac
    done
    printf '%s\n' "${args[@]}"
}

main() {
    check_deps

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
    # Ensure output file extension matches chosen format (avoid double-ext)
    outfile=$(unique_output_name "$dir" "$base" "$format")

    # Build comma-separated filter string robustly
    filter_chain=""
    if [ ${#filters[@]} -gt 0 ]; then
        local IFS=,
        filter_chain="${filters[*]}"
    fi

    run_ffmpeg "$INPUT_FILE" "$outfile" "$filter_chain"
    printf '%bOutput saved to: %s%b\n' "$GREEN" "$outfile" "$RESET"
}

main "$@"
