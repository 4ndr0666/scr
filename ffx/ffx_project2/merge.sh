#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
set -E

# XDG Compliance
declare -x XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -x XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
declare -x XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
declare -r APP_NAME="merge"
declare -r MERGE_CONF="$XDG_CONFIG_HOME/$APP_NAME/merge.conf"

mkdir -p "$XDG_CONFIG_HOME/$APP_NAME" "$XDG_CACHE_HOME/$APP_NAME" "$XDG_DATA_HOME/$APP_NAME" >/dev/null 2>&1 || {
	echo "Error: Failed to create XDG directories." >&2
	exit 1
}

declare -a TEMP_DIRS=()
declare -a TEMP_FILES=()
declare BASE_TMP_DIR=""
declare _CLEANUP_DONE=0

register_temp_file() {
	local file_path="$1"
	[[ -n "$file_path" ]] && TEMP_FILES+=("$file_path")
}

register_temp_dir() {
	local dir_path="$1"
	[[ -n "$dir_path" ]] && TEMP_DIRS+=("$dir_path")
}

cleanup_all() {
	[[ "${_CLEANUP_DONE}" -eq 1 ]] && return 0
	_CLEANUP_DONE=1

	[[ "${verbose:-0}" -eq 1 ]] && printf '[%s] Cleaning up temporary resources...\n' "$(date +%T)" >&2

	for f in "${TEMP_FILES[@]}"; do
		if [[ -f "$f" ]]; then
			rm -f -- "$f" >/dev/null 2>&1 || true
		fi
	done

	if ((${#TEMP_DIRS[@]} > 0)); then
		printf '%s\0' "${TEMP_DIRS[@]}" | sort -r -z -V | xargs -0 -r -- rm -rf >/dev/null 2>&1 || true
	fi

	[[ "${verbose:-0}" -eq 1 ]] && printf '[%s] Cleanup complete.\n' "$(date +%T)" >&2
}

trap cleanup_all EXIT INT TERM HUP

printv() {
	[[ "${verbose:-0}" -eq 1 ]] && printf '[%s] %s\n' "$(date +%T)" "$*" >&2
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

declare REALPATH_CMD=""

check_deps() {
	local deps missing_deps
	deps=(ffmpeg ffprobe awk bc stat)
	missing_deps=()

	if command_exists realpath; then
		REALPATH_CMD="realpath"
		printv "Using realpath command: $REALPATH_CMD"
	elif command_exists readlink; then
		local tmp_file
		tmp_file=$(mktemp -p "${TMPDIR:-/tmp}" "readlink_test.XXXXXXXX") || {
			echo "Error: Failed to create temporary file for readlink test." >&2
			exit 1
		}
		if readlink -f -- "$tmp_file" >/dev/null 2>&1; then
			REALPATH_CMD="readlink -f"
			printv "Using realpath command: $REALPATH_CMD"
		else
			echo "Error: 'readlink -f' not functional." >&2
			exit 1
		fi
		rm -f -- "$tmp_file" >/dev/null 2>&1 || true
	else
		echo "Error: Neither 'realpath' nor 'readlink' found." >&2
		exit 1
	fi

	for dep in "${deps[@]}"; do
		command_exists "$dep" || missing_deps+=("$dep")
	done

	if ((${#missing_deps[@]} > 0)); then
		echo "Error: Required command(s) not found: ${missing_deps[*]}" >&2
		exit 1
	fi
}

absolute_path() {
	local path="$1"
	if [[ -z "$REALPATH_CMD" ]]; then
		echo "Error: REALPATH_CMD not set. Dependency check might have failed." >&2
		return 1
	fi
	if ! abs_path_output=$("$REALPATH_CMD" -- "$path" 2>/dev/null); then
		echo "Error: Could not determine absolute path for '$path'." >&2
		return 1
	fi
	local abs_path="$abs_path_output"
	printf '%s\n' "$abs_path"
	return 0
}

bytes_to_human() {
	local bytes="${1:-0}"
	local human_readable_output
	if ! human_readable_output=$(printf '%s' "$bytes" | awk 'BEGIN {split("B KiB MiB GiB TiB PiB EiB ZiB YiB",u);b=ARGV[1]+0;p=0;while(b>=1024&&p<8){b/=1024;p++}printf "%.2f %s\n",b,u[p+1]}' 2>/dev/null); then
		echo "Error: Awk failed during bytes conversion for '$bytes'." >&2
		printf 'N/A\n'
		return 1
	fi
	local human_readable="$human_readable_output"
	if [[ -z "$human_readable" ]]; then
		echo "Error: Could not convert bytes '$bytes' to human-readable format." >&2
		printf 'N/A\n'
		return 1
	fi
	printf '%s\n' "$human_readable"
	return 0
}

portable_stat() {
	local file="$1"
	local size_output
	if size_output=$(stat -c '%s' "$file" 2>/dev/null); then
		local size="$size_output"
		printf '%s\n' "$size"
		return 0
	fi
	if size_output=$(stat -f '%z' "$file" 2>/dev/null); then
		local size="$size_output"
		printf '%s\n' "$size"
		return 0
	fi
	echo "Error: Could not get file size for '$file'." >&2
	return 1
}

validate_resolution() {
	local res="$1"
	if ! [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then
		echo "Error: Invalid resolution format '$res'. Expected WxH (e.g., 1920x1080)." >&2
		return 1
	fi
	return 0
}

validate_fps() {
	local fps="$1"
	if ! [[ "$fps" =~ ^[0-9]+$ ]] || ((fps <= 0)); then
		echo "Error: Invalid FPS '$fps'. Expected a positive integer." >&2
		return 1
	fi
	return 0
}

validate_factor() {
	local factor="$1"
	local factor_float bc_result_output
	if ! [[ "$factor" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
		echo "Error: Invalid numeric format for factor '$factor'." >&2
		return 1
	fi
	factor_float=$(printf "%.8f" "$factor")
	if ! bc_result_output=$(bc -l <<<"$factor_float <= 0" 2>/dev/null); then
		echo "Error: bc calculation failed during factor validation for '$factor'." >&2
		return 1
	fi
	local bc_result="$bc_result_output"
	if [[ "$bc_result" -eq 1 ]]; then
		echo "Error: Factor must be greater than zero '$factor'." >&2
		return 1
	fi
	return 0
}

load_config() {
	if [[ -f "$MERGE_CONF" ]]; then
		printv "Loading configuration from $MERGE_CONF"
		source "$MERGE_CONF" >/dev/null 2>&1 || {
			echo "Warning: Could not source configuration file '$MERGE_CONF'." >&2
		}
	else
		printv "No configuration file found at $MERGE_CONF"
	fi
}
get_default_filename() {
	local base="$1"
	local suf="$2"
	local ext="$3"
	local dir="${4:-.}"
	local name full_path n=1

	name="${base}_${suf}.${ext}"
	full_path="$dir/$name"

	while [[ -e "$full_path" ]]; do
		name="${base}_${suf}${n}.${ext}"
		full_path="$dir/$name"
		n=$((n + 1))
	done

	if [[ -z "$full_path" ]]; then
		echo "Error: Failed to generate a unique filename for base '$base'." >&2
		return 1
	fi

	printf '%s\n' "$full_path"
	return 0
}

select_files() {
	local selected_output selected_array manual_input abs_f file_found_count
	selected_array=()

	if command_exists fzf; then
		printv "Using fzf for file selection..."
		local find_cmd xargs_cmd fzf_cmd
		find_cmd=(find . -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' \))
		xargs_cmd=(xargs -0 "$REALPATH_CMD" --)
		fzf_cmd=(fzf --multi --preview 'ffprobe -hide_banner -loglevel error {}' --preview-window=right:60% --bind='ctrl-a:select-all+accept' --height=40% --print0)

		if ! selected_output=$("${find_cmd[@]}" -print0 | "${xargs_cmd[@]}" | "${fzf_cmd[@]}"); then
			echo "No files selected or fzf interrupted." >&2
			return 1
		fi
		mapfile -d '' -t selected_array < <(printf '%s' "$selected_output")
	else
		echo "fzf not found. Please manually specify file paths (space-separated, quote paths with spaces):" >&2
		read -r manual_input
		if [[ -z "$manual_input" ]]; then
			echo "No files entered." >&2
			return 1
		fi
		local -a temp_array abs_selected_array
		abs_selected_array=()
		file_found_count=0
		read -r -a temp_array <<<"$manual_input"
		for f in "${temp_array[@]}"; do
			if [[ -f "$f" ]]; then
				local abs_f_output
				if abs_f_output=$(absolute_path "$f"); then
					local abs_f="$abs_f_output"
					abs_selected_array+=("$abs_f")
					file_found_count=$((file_found_count + 1))
				else
					continue
				fi
			else
				echo "Error: Input file not found: '$f'" >&2
				continue
			fi
		done
		if ((file_found_count == 0)); then
			echo "Error: No valid files entered." >&2
			return 1
		fi
		selected_array=("${abs_selected_array[@]}")
	fi

	if ((${#selected_array[@]} == 0)); then
		echo "No files selected." >&2
		return 1
	fi

	printf '%s\n' "${selected_array[@]}"
	return 0
}
get_video_opts() {
	local codec="${1:-libx264}"
	local preset="${2:-slow}"
	local crf_val="$3"
	local qp_val="$4"
	local -a opts=("-c:v" "$codec" "-preset" "$preset" "-pix_fmt" "yuv420p" "-movflags" "+faststart")

	if [[ -n "$qp_val" ]]; then
		opts+=("-qp" "$qp_val")
	elif [[ -n "$crf_val" ]]; then
		opts+=("-crf" "$crf_val")
	else
		opts+=("-crf" "18")
	fi

	printf '%s\0' "${opts[@]}"
	return 0
}

get_audio_opts() {
	local remove_audio="${1:-false}"
	local -a opts=()

	if [[ "$remove_audio" = "true" ]]; then
		opts+=("-an")
	else
		opts+=("-c:a" "aac" "-b:a" "128k")
	fi

	printf '%s\0' "${opts[@]}"
	return 0
}

generate_atempo_filter() {
	local target_speed="$1"
	local rem_speed="$target_speed"
	local -a atempo_parts=()
	local formatted_rem_speed bc_is_one_output bc_result_output is_in_range_output

	if ! validate_factor "$target_speed"; then
		return 1
	fi

	formatted_rem_speed=$(printf "%.8f" "$rem_speed")

	if ! bc_is_one_output=$(bc -l <<<"$formatted_rem_speed == 1.0" 2>/dev/null); then
		echo "Error: bc calculation failed (comparison == 1.0) for speed '$target_speed'." >&2
		return 1
	fi
	local bc_is_one="$bc_is_one_output"
	if [[ "$bc_is_one" -eq 1 ]]; then
		printf ''
		return 0
	fi

	if ! bc_result_output=$(bc -l <<<"$formatted_rem_speed > 2.0" 2>/dev/null); then
		echo "Error: bc calculation failed (> 2.0) for speed '$target_speed'." >&2
		return 1
	fi
	local bc_result="$bc_result_output"
	while [[ "$bc_result" -eq 1 ]]; do
		atempo_parts+=(atempo=2.0)
		local rem_speed_output
		if ! rem_speed_output=$(bc -l <<<"$formatted_rem_speed / 2.0" 2>/dev/null); then
			echo "Error: bc calculation failed (division by 2.0) for speed '$target_speed'." >&2
			return 1
		fi
		rem_speed="$rem_speed_output"
		formatted_rem_speed=$(printf "%.8f" "$rem_speed")
		if ! bc_result_output=$(bc -l <<<"$formatted_rem_speed > 2.0" 2>/dev/null); then
			echo "Error: bc calculation failed (> 2.0) in loop for speed '$target_speed'." >&2
			return 1
		fi
		bc_result="$bc_result_output"
	done

	if ! bc_result_output=$(bc -l <<<"$formatted_rem_speed < 0.5" 2>/dev/null); then
		echo "Error: bc calculation failed (< 0.5) for speed '$target_speed'." >&2
		return 1
	fi
	bc_result="$bc_result_output"
	while [[ "$bc_result" -eq 1 ]]; do
		atempo_parts+=(atempo=0.5)
		if ! rem_speed_output=$(bc -l <<<"$formatted_rem_speed / 0.5" 2>/dev/null); then
			echo "Error: bc calculation failed (division by 0.5) for speed '$target_speed'." >&2
			return 1
		fi
		rem_speed="$rem_speed_output"
		formatted_rem_speed=$(printf "%.8f" "$rem_speed")
		if ! bc_result_output=$(bc -l <<<"$formatted_rem_speed < 0.5" 2>/dev/null); then
			echo "Error: bc calculation failed (< 0.5) in loop for speed '$target_speed'." >&2
			return 1
		fi
		bc_result="$bc_result_output"
	done
	if ! is_in_range_output=$(bc -l <<<"$formatted_rem_speed >= 0.5 && $formatted_rem_speed <= 2.0" 2>/dev/null); then
		echo "Error: bc calculation failed (range check) for speed '$target_speed'." >&2
		return 1
	fi
	local is_in_range="$is_in_range_output"
	if [[ "$is_in_range" -eq 1 ]]; then
		atempo_parts+=(atempo="$(printf "%.4f" "$rem_speed")")
	else
		echo "Error: Calculated final atempo speed '$rem_speed' is out of expected range." >&2
		return 1
	fi

	local atempo_filter_str
	atempo_filter_str=$(
		IFS=,
		printf '%s' "${atempo_parts[*]}"
	)

	local bc_is_not_one_output
	if ! bc_is_not_one_output=$(bc -l <<<"$formatted_rem_speed != 1.0" 2>/dev/null); then
		echo "Error: bc calculation failed (comparison != 1.0) for speed '$target_speed'." >&2
		return 1
	fi
	local bc_is_not_one="$bc_is_not_one_output"
	if [[ "$bc_is_not_one" -eq 1 && -z "$atempo_filter_str" ]]; then
		echo "Error: Generated empty atempo filter string for speed '$target_speed'." >&2
		return 1
	fi

	printf '%s' "$atempo_filter_str"
	return 0
}
usage() {
	local exit_status="${1:-1}"
	cat <<EOH
Usage: ${0##*/} [global options]  [subcommand options] [args...]

Global Options:
  -v              Verbose output
  -r WxH          Output resolution (e.g., 1280x720)
  -f N            Output FPS (integer)
  -c              Video codec (default: libx264)
  -p              Encoding preset (default: slow)
  --crf           CRF value (default: 18)
  --qp            QP value (overrides --crf)
  -a              Remove audio tracks (Default: false for process/looperang/slowmo, true for merge)
  -h, --help      Show this message

Subcommands:
  probe
  process [opts]  [out]
  merge   [opts] [<files> ...]
  looperang [opts]  [out]
  slowmo  [opts]  [out]

Subcommand Options:
  merge:
    -o              Output file (default: from first input)
    --scale         Scale mode: largest, composite, 1080p
    --speed         Playback speed multiplier
    --interpolate   Enable interpolation (experimental)
    --output-dir    Output directory

  slowmo:
    -s              Slow factor (e.g., 2.0 for 2x slow)

Config File:
  Options can be set in '$MERGE_CONF'.
  Command-line overrides config.
EOH
	exit "$exit_status"
}
main() {
	if [[ $# -eq 0 ]]; then
		usage 1
	fi

	declare resolution=""
	declare fps=""
	declare codec="libx264"
	declare preset="slow"
	declare crf=""
	declare qp=""
	declare remove_audio="false"
	declare scale_mode="largest"
	declare speed_factor="1.0"
	declare interpolate="0"
	declare output_dir="."
	declare slowmo_factor="2.0"
	declare verbose="0"
	declare output=""

	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		usage 0
	fi

	check_deps
	load_config

	local subcommand=""
	local -a positional_args=()
	local status=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-v)
			verbose=1
			shift
			;;
		-r | --resolution)
			shift
			resolution="$1"
			shift
			;;
		-f | --fps)
			shift
			fps="$1"
			shift
			;;
		-c | --codec)
			shift
			codec="$1"
			shift
			;;
		-p | --preset)
			shift
			preset="$1"
			shift
			;;
		--crf)
			shift
			crf="$1"
			shift
			;;
		--qp)
			shift
			qp="$1"
			shift
			;;
		-a | --remove-audio)
			shift
			remove_audio="$1"
			shift
			;;
		--scale)
			shift
			scale_mode="$1"
			shift
			;;
		--speed)
			shift
			speed_factor="$1"
			shift
			;;
		--interpolate)
			interpolate=1
			shift
			;;
		--output-dir)
			shift
			output_dir="$1"
			shift
			;;
		-o | --output)
			shift
			output="$1"
			shift
			;;
		-s | --slow-factor)
			shift
			slowmo_factor="$1"
			shift
			;;
		-h | --help)
			usage 0
			;;
		--)
			shift
			break
			;;
		-*)
			echo "Error: Unknown option '$1'" >&2
			usage 1
			;;
		*)
			subcommand="$1"
			shift
			positional_args=("$@")
			break
			;;
		esac
	done

	case "$subcommand" in
	probe)
		cmd_probe "${positional_args[@]}"
		status=$?
		;;
	process)
		cmd_process "${positional_args[@]}"
		status=$?
		;;
	merge)
		cmd_merge "${positional_args[@]}"
		status=$?
		;;
	looperang)
		cmd_looperang "${positional_args[@]}"
		status=$?
		;;
	slowmo)
		cmd_slowmo "${positional_args[@]}"
		status=$?
		;;
	help | -h | --help)
		usage 0
		;;
	"")
		echo "Error: No subcommand provided." >&2
		usage 1
		;;
	*)
		echo "Error: Unknown subcommand '$subcommand'." >&2
		usage 1
		;;
	esac

	exit "$status"
}
