#!/usr/bin/env bash
set -euo pipefail

# Color codes
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
trap 'error_exit "Unexpected failure"' ERR

check_deps() {
	for cmd in ffmpeg ffprobe fzf bc; do
		command -v "$cmd" >/dev/null 2>&1 || error_exit "$cmd not found"
	done
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
	cat <<EOF2
Usage: ${0##*/} [--dry-run] [operations] [file]
Operations:
  --fps <val>           Set output frame rate
  --deflicker           Deflicker
  --dedot               Dedot
  --dehalo              Dehalo
  --removegrain <t>     Removegrain type <t>
  --deband <params>     Deband with params
  --sharpen             Sharpen
  --scale               Super resolution 2x
  --deshake             Deshake
  --edge-detect         Edge detection
  --slo-mo <factor>     Slow motion by factor
  --speed-up <factor>   Speed up by factor
  --convert <format>    Output container format
  --color-correct       Basic color correction
  --crop-resize <c> <r> Crop then resize
  --rotate <deg>        Rotate 90,180,-90
  --flip <h|v>          Flip horizontally or vertically
  -h, --help            Show this help
If no operations are provided an interactive menu will be shown.
EOF2
}

run_ffmpeg() {
	local infile="$1" outfile="$2" filters="$3"
	local cmd=(ffmpeg -y -i "$infile")
	[ -n "$filters" ] && cmd+=(-vf "$filters")
	cmd+=(-progress pipe:1 "$outfile")
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '%q ' "${cmd[@]}" && echo
		return
	fi
	printf '%bRunning ffmpeg...%b\n' "$CYAN" "$RESET"
	"${cmd[@]}" 2>&1 | tee -a "$LOGFILE"
	local status
	status=${PIPESTATUS[0]}
	[ "$status" -eq 0 ] || error_exit "ffmpeg failed"
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--help | -h)
			display_help
			exit 0
			;;
		--fps)
			filters+=("fps=$2")
			shift
			;;
		--deflicker) filters+=("deflicker") ;;
		--dedot) filters+=("removegrain=1") ;;
		--dehalo) filters+=("unsharp=5:5:-1.5:5:5:-1.5") ;;
		--removegrain)
			filters+=("removegrain=$2")
			shift
			;;
		--deband)
			filters+=("deband=$2")
			shift
			;;
		--sharpen) filters+=("unsharp") ;;
		--scale) filters+=("scale=iw*2:ih*2:flags=spline") ;;
		--deshake) filters+=("deshake") ;;
		--edge-detect) filters+=("edgedetect") ;;
		--slo-mo)
			filters+=("setpts=$2*PTS")
			shift
			;;
		--speed-up)
			local sp
			sp="$(echo "1/$2" | bc -l)"
			filters+=("setpts=${sp}*PTS")
			shift
			;;
		--convert)
			format="$2"
			shift
			;;
		--color-correct) filters+=("eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7") ;;
		--crop-resize)
			filters+=("$2,$3")
			shift 2
			;;
		--rotate)
			case "$2" in
			90) filters+=("transpose=1") ;;
			180) filters+=("transpose=2,transpose=2") ;;
			-90) filters+=("transpose=2") ;;
			*) error_exit "Invalid rotation" ;;
			esac
			shift
			;;
		--flip)
			case "$2" in
			h) filters+=("hflip") ;;
			v) filters+=("vflip") ;;
			*) error_exit "Invalid flip" ;;
			esac
			shift
			;;
		*)
			if [ -z "$INPUT_FILE" ]; then
				INPUT_FILE="$1"
			else
				error_exit "Unknown arg $1"
			fi
			;;
		esac
		shift
	done
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
			read -r -p "Enter fps value: " choice
			args+=(--fps "$choice")
			;;
		2) args+=(--deflicker) ;;
		3) args+=(--dedot) ;;
		4) args+=(--dehalo) ;;
		5)
			read -r -p "Enter type: " choice
			args+=(--removegrain "$choice")
			;;
		6)
			read -r -p "Enter params: " choice
			args+=(--deband "$choice")
			;;
		7) args+=(--sharpen) ;;
		8) args+=(--scale) ;;
		9) args+=(--deshake) ;;
		10) args+=(--edge-detect) ;;
		11)
			read -r -p "Enter slo-mo factor: " choice
			args+=(--slo-mo "$choice")
			;;
		12)
			read -r -p "Enter speed up factor: " choice
			args+=(--speed-up "$choice")
			;;
		13)
			read -r -p "Enter format: " choice
			args+=(--convert "$choice")
			;;
		14) args+=(--color-correct) ;;
		15)
			local c r
			read -r -p "Crop params: " c
			read -r -p "Resize params: " r
			args+=(--crop-resize "$c" "$r")
			;;
		16)
			read -r -p "Enter rotation: " choice
			args+=(--rotate "$choice")
			;;
		17)
			read -r -p "Enter h or v: " choice
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
