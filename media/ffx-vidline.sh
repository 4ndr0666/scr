#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ===================== // ffx-vidline.sh //

## Colors
readonly GREEN='\033[0;32m'
readonly CYAN='\033[36m'
readonly RED='\033[0;31m'
readonly RESET='\033[0m'

## Logging

LOGDIR="${XDG_DATA_HOME:-$HOME/.local/share}/vidline"
mkdir -p -- "$LOGDIR"
readonly LOGFILE="$LOGDIR/ffmpeg_operations.log"

## Constants

DRY_RUN=0
filters=()    # array of individual filter strings
format="mp4"  # output container
INPUT_FILE="" # path to input video

## TRAP

error_exit() {
	local ts
	ts="$(date '+%F %T')"
	printf '%b[%s] ERROR: %s%b\n' "$RED" "$ts" "$1" "$RESET" | tee -a "$LOGFILE" >&2
	exit 1
}
trap 'error_exit "Unexpected script failure near line ${LINENO}"' ERR

## Dependencies

check_deps() {
	printf '%bChecking dependencies...%b\n' "$CYAN" "$RESET"
	for cmd in ffmpeg ffprobe fzf bc; do
		command -v "$cmd" >/dev/null 2>&1 || error_exit "Dependency missing: '$cmd' not found in PATH."
	done
	printf '%bDependencies OK.%b\n' "$GREEN" "$RESET"
}

## Output

unique_output_name() {
	local dir=$1 base=$2 ext=$3 candidate counter=1
	candidate="${dir}/${base}.${ext}"
	while [[ -e $candidate ]]; do
		candidate="${dir}/${base}_${counter}.${ext}"
		((counter++))
	done
	printf '%s\n' "$candidate"
}

## Fzf

choose_file() {
	printf '%bSelect input video:%b\n' "$CYAN" "$RESET"
	local f
	f="$(fzf)" || return 1
	[[ -f $f ]] || error_exit "Invalid selection: '$f' is not a regular file."
	printf '%s\n' "$f"
}

## Help

display_help() {
	cat <<EOF
Usage: ${0##*/} [--dry-run] [operations] [file]

Operations:
  --fps <val>             Set output frame rate
  --deflicker             Deflicker
  --dedot                 Dedot
  --dehalo                Dehalo
  --removegrain <t>       Removegrain type <t>
  --deband <params>       Deband with params
  --sharpen               Sharpen
  --scale                 Super resolution 2x
  --deshake               Deshake
  --edge-detect           Edge detection
  --slo-mo <factor>       Slow motion (factor > 0)
  --speed-up <factor>     Speed up (factor > 0)
  --convert <format>      Output container (mp4|mkv|webm…)
  --color-correct         Basic colour correction
  --crop-resize <c> <r>   Crop then resize
  --rotate <deg>          Rotate 90 / 180 / -90
  --flip <h|v>            Flip horizontally / vertically
  -h, --help              Show this help

If no operations are specified an interactive menu will be shown.
EOF
}

# ── ffmpeg runner ──────────────────────────────────────────────
run_ffmpeg() {
	local infile=$1 outfile=$2
	shift 2
	local -a filter_arr=("$@") # remaining args are filters

	local -a cmd=(ffmpeg -y -i "$infile")

	if ((${#filter_arr[@]})); then
		local filter_chain
		local IFS=,
		filter_chain="${filter_arr[*]}"
		cmd+=(-vf "$filter_chain")
	fi

	cmd+=(-progress pipe:1 "$outfile")

	if ((DRY_RUN)); then
		printf '%bDry-run:%b %q\n' "$CYAN" "$RESET" "${cmd[@]}"
		return 0
	fi

	printf '%bRunning ffmpeg...%b\n' "$CYAN" "$RESET"
	"${cmd[@]}" 2>&1 | tee -a "$LOGFILE"
	local status=${PIPESTATUS[0]}
	((status == 0)) || error_exit "ffmpeg failed with status $status (see $LOGFILE)."
	printf '%bffmpeg completed successfully.%b\n' "$GREEN" "$RESET"
}

# ── Command-line parser ────────────────────────────────────────
parse_args() {
	while (($#)); do
		case $1 in
		--dry-run) DRY_RUN=1 ;;
		-h | --help)
			display_help
			exit 0
			;;
		--fps)
			[[ $# -ge 2 && $2 =~ ^[0-9]+$ ]] || error_exit "--fps needs positive integer"
			filters+=("fps=$2")
			shift
			;;
		--deflicker) filters+=("deflicker") ;;
		--dedot) filters+=("removegrain=1") ;;
		--dehalo) filters+=("unsharp=5:5:-1.5:5:5:-1.5") ;;
		--removegrain)
			[[ $# -ge 2 && $2 =~ ^[0-9]+$ ]] || error_exit "--removegrain needs numeric type"
			filters+=("removegrain=$2")
			shift
			;;
		--deband)
			[[ $# -ge 2 ]] || error_exit "--deband needs parameter string"
			filters+=("deband=$2")
			shift
			;;
		--sharpen) filters+=("unsharp") ;;
		--scale) filters+=("scale=iw*2:ih*2:flags=spline") ;;
		--deshake) filters+=("deshake") ;;
		--edge-detect) filters+=("edgedetect") ;;
		--slo-mo)
			[[ $# -ge 2 && $2 =~ ^[0-9]+(\.[0-9]+)?$ ]] || error_exit "--slo-mo needs numeric factor"
			(($(bc -l <<<"$2 > 0"))) || error_exit "--slo-mo factor must be >0"
			filters+=("setpts=$2*PTS")
			shift
			;;
		--speed-up)
			[[ $# -ge 2 && $2 =~ ^[0-9]+(\.[0-9]+)?$ ]] || error_exit "--speed-up needs numeric factor"
			(($(bc -l <<<"$2 > 0"))) || error_exit "--speed-up factor must be >0"
			local sp
			sp=$(bc -l <<<"1/$2")
			filters+=("setpts=${sp}*PTS")
			shift
			;;
		--convert)
			[[ $# -ge 2 && $2 =~ ^[A-Za-z0-9]+$ ]] || error_exit "--convert needs alphanumeric format"
			format=$2
			shift
			;;
		--color-correct) filters+=("eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7") ;;
		--crop-resize)
			[[ $# -ge 3 && -n $2 && -n $3 ]] || error_exit "--crop-resize needs crop and scale params"
			filters+=("crop=$2,scale=$3")
			shift 2
			;;
		--rotate)
			[[ $# -ge 2 ]] || error_exit "--rotate needs degrees"
			case $2 in
			90) filters+=("transpose=1") ;;
			180) filters+=("transpose=2,transpose=2") ;;
			-90) filters+=("transpose=2") ;;
			*) error_exit "Rotation must be 90, 180 or -90" ;;
			esac
			shift
			;;
		--flip)
			[[ $# -ge 2 ]] || error_exit "--flip needs h or v"
			case $2 in
			h) filters+=("hflip") ;;
			v) filters+=("vflip") ;;
			*) error_exit "Flip must be 'h' or 'v'" ;;
			esac
			shift
			;;
		--*) error_exit "Unknown option: $1" ;;
		*) # positional arg (input file)
			if [[ -z $INPUT_FILE ]]; then
				INPUT_FILE=$1
			else
				error_exit "Multiple input files specified ('$INPUT_FILE' & '$1')"
			fi ;;
		esac
		shift
	done

	[[ -n $INPUT_FILE && -f $INPUT_FILE ]] || true # file existence will be validated later
}

# ── Interactive menu ───────────────────────────────────────────
show_menu() {
	printf '%bMenu (d=done, q=quit)%b\n' "$CYAN" "$RESET" >&2
	printf ' 1) fps\n 2) deflicker\n 3) dedot\n 4) dehalo\n' >&2
	printf ' 5) removegrain\n 6) deband\n 7) sharpen\n 8) scale\n' >&2
	printf ' 9) deshake\n10) edge-detect\n11) slo-mo\n12) speed-up\n' >&2
	printf '13) convert\n14) color-correct\n15) crop-resize\n16) rotate\n17) flip\n' >&2
	local choice
	local -a args=()
	while true; do
		read -r -p "Choice: " choice
		case $choice in
		q) exit 0 ;;
		d) break ;;
		1)
			read -r -p "FPS value: " val
			if [[ $val =~ ^[0-9]+$ ]]; then
				args+=(--fps "$val")
			else
				printf '%bInvalid FPS%b\n' "$RED" "$RESET" >&2
			fi
			;;
		2) args+=(--deflicker) ;;
		3) args+=(--dedot) ;;
		4) args+=(--dehalo) ;;
		5)
			read -r -p "removegrain type: " t
			if [[ $t =~ ^[0-9]+$ ]]; then
				args+=(--removegrain "$t")
			else
				printf '%bInvalid type%b\n' "$RED" "$RESET" >&2
			fi
			;;
		6)
			read -r -p "deband params: " p
			if [[ -n $p ]]; then
				args+=(--deband "$p")
			else
				printf '%bParams required%b\n' "$RED" "$RESET" >&2
			fi
			;;
		7) args+=(--sharpen) ;;
		8) args+=(--scale) ;;
		9) args+=(--deshake) ;;
		10) args+=(--edge-detect) ;;
		11)
			read -r -p "slo-mo factor: " f
			if [[ $f =~ ^[0-9]+(\.[0-9]+)?$ ]] && (($(bc -l <<<"$f>0"))); then
				args+=(--slo-mo "$f")
			else
				printf '%bInvalid factor%b\n' "$RED" "$RESET" >&2
			fi
			;;
		12)
			read -r -p "speed-up factor: " f
			if [[ $f =~ ^[0-9]+(\.[0-9]+)?$ ]] && (($(bc -l <<<"$f>0"))); then
				args+=(--speed-up "$f")
			else
				printf '%bInvalid factor%b\n' "$RED" "$RESET" >&2
			fi
			;;
		13)
			read -r -p "format: " fmt
			if [[ $fmt =~ ^[A-Za-z0-9]+$ ]]; then
				args+=(--convert "$fmt")
			else
				printf '%bInvalid format%b\n' "$RED" "$RESET" >&2
			fi
			;;
		14) args+=(--color-correct) ;;
		15)
			read -r -p "crop params: " c
			read -r -p "scale params: " s
			if [[ -n $c && -n $s ]]; then
				args+=(--crop-resize "$c" "$s")
			else
				printf '%bCrop & scale required%b\n' "$RED" "$RESET" >&2
			fi
			;;
		16)
			read -r -p "degrees (90/180/-90): " d
			case $d in 90 | 180 | -90) args+=(--rotate "$d") ;;
			*) printf '%bInvalid degrees%b\n' "$RED" "$RESET" >&2 ;;
			esac
			;;
		17)
			read -r -p "flip h|v: " dir
			case $dir in h | v) args+=(--flip "$dir") ;;
			*) printf '%bInvalid dir%b\n' "$RED" "$RESET" >&2 ;;
			esac
			;;
		*) printf '%bInvalid choice%b\n' "$RED" "$RESET" >&2 ;;
		esac
	done
	printf '%s\n' "${args[@]}"
}

# ── Main entry point ───────────────────────────────────────────
main() {
	check_deps
	parse_args "$@"

	# If no operations, open interactive menu
	if ((${#filters[@]} == 0)); then
		local menu_out
		menu_out=$(show_menu) || exit 1
		# read newline-separated output into array safely
		local _line
		while IFS= read -r _line; do
			[[ -n $_line ]] && set -- "$@" "$_line"
		done <<<"$menu_out"
		filters=() # reset before re-parsing
		parse_args "$@"
	fi

	# If still no input file, ask via fzf
	if [[ -z $INPUT_FILE ]]; then
		INPUT_FILE=$(choose_file) || exit 1
	fi
	[[ -r $INPUT_FILE ]] || error_exit "Input file not readable: '$INPUT_FILE'"

	# Build output filename
	local dir base outfile
	dir=$(dirname -- "$INPUT_FILE")
	base=$(basename -- "$INPUT_FILE")
	base=${base%.*}_out
	outfile=$(unique_output_name "$dir" "$base" "$format")

	run_ffmpeg "$INPUT_FILE" "$outfile" "${filters[@]}"
	printf '%bOutput saved to:%b %s\n' "$GREEN" "$RESET" "$outfile"
}

main "$@"
