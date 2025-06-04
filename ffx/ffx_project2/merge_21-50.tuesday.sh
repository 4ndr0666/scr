#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
set -E
# ======================== // MERGE //
## Description: Modular, idempotent, robust wrapper
#               for batch video processing and merging.
## Compliance: Strictly XDG, zero placeholders, exhaustive
#              input validation, failsafe cleanup.
# ---------------------------------------------

##XDG Compliance

declare -x XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -x XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
declare -x XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

declare -r APP_NAME="merge"

declare -r MERGE_CONF="$XDG_CONFIG_HOME/$APP_NAME/merge.conf"

mkdir -p "$XDG_CONFIG_HOME/$APP_NAME" "$XDG_CACHE_HOME/$APP_NAME" "$XDG_DATA_HOME/$APP_NAME" || {
	echo "Error: Failed to create XDG directories." >&2
	exit 1
}

## Temp Resource Mgmt.

declare BASE_TMP_DIR
declare -a TEMP_DIRS=()
declare -a TEMP_FILES=()
if ! BASE_TMP_DIR="$(mktemp -d -p "${TMPDIR:-/tmp}" "$APP_NAME.XXXXXXXX")"; then
	echo "Error: Could not create base temporary directory." >&2
	exit 1
fi

TEMP_DIRS+=("$BASE_TMP_DIR")

declare _CLEANUP_DONE=0

register_temp_file() {
	local file_path="$1"
	[[ -n "$file_path" ]] && TEMP_FILES+=("$file_path")
}

register_temp_dir() {
	local dir_path="$1"
	[[ -n "$dir_path" ]] && TEMP_DIRS+=("$dir_path")
}

## TRAP

cleanup_all() {
	[[ "${_CLEANUP_DONE}" -eq 1 ]] && return 0
	_CLEANUP_DONE=1

	# Print verbose message if enabled (use parameter expansion default)
	[[ "${verbose:-0}" -eq 1 ]] && printf '[%s] Cleaning up temporary resources...\n' "$(date +%T)" >&2

	# Remove temporary files
	for f in "${TEMP_FILES[@]}"; do
		# Use -- to protect against filenames starting with '-'
		# Redirect stderr to /dev/null and use || true to ignore errors during cleanup
		# Check if file exists before attempting removal (optional but clear)
		if [[ -f "$f" ]]; then
			rm -f -- "$f" >/dev/null 2>&1 || true
		fi
	done

	# Remove temporary directories
	# Sort directories in reverse order to ensure nested directories are removed safely
	# Use printf and xargs -0 for robustness with filenames containing spaces/special chars
	# Use || true to ignore errors during cleanup
	# Check if TEMP_DIRS is not empty before piping to xargs
	if ((${#TEMP_DIRS[@]} > 0)); then
		printf '%s\0' "${TEMP_DIRS[@]}" | sort -r -z | xargs -0 -r -- rm -rf >/dev/null 2>&1 || true
	fi

	# Print verbose message if enabled
	[[ "${verbose:-0}" -eq 1 ]] && printf '[%s] Cleanup complete.\n' "$(date +%T)" >&2
}
trap cleanup_all EXIT INT TERM HUP

## Logging & Output

printv() {
	# Check if verbose mode is enabled (global variable, use parameter expansion default)
	[[ "${verbose:-0}" -eq 1 ]] && printf '[%s] %s\n' "$(date +%T)" "$*" >&2
}

## Dependency Checking

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

declare REALPATH_CMD=""

check_deps() {
	local deps=(ffmpeg ffprobe awk bc stat)
	local missing_deps=()
	local realpath_cmd_local=""
	local realpath_found=0

	# Determine the best realpath command (realpath or readlink -f)
	if command_exists realpath; then
		realpath_cmd_local="realpath"
		realpath_found=1
	elif command_exists readlink; then
		# Test readlink -f capability using a temporary file
		local tmp_file tmp_status # Declare variables
		# Use the base temp dir created earlier
		# Use || exit 1 for robustness if mktemp fails here (unlikely after initial check)
		if ! tmp_file=$(mktemp -p "$BASE_TMP_DIR" "readlink_test.XXXXXXXX"); then
			echo "Error: Failed to create temporary file for readlink test." >&2
			# Cannot proceed if temp file creation fails, exit here
			exit 1
		fi
		# No need to register tmp_file for cleanup, it's in BASE_TMP_DIR which is registered

		# Check if readlink -f works on the temporary file
		# Check exit code directly (SC2181)
		if readlink -f -- "$tmp_file" >/dev/null 2>&1; then
			realpath_cmd_local="readlink -f"
			realpath_found=1
		fi
		# Remove the temporary file used for the test immediately
		rm -f -- "$tmp_file" >/dev/null 2>&1 || true
	fi

	# Exit if no suitable realpath command is found
	# Check variable value directly (SC2181)
	if [[ "$realpath_found" -eq 0 ]]; then
		echo "Error: Neither 'realpath' nor 'readlink -f' found or functional." >&2
		exit 1
	fi

	# Check for other required dependencies
	for dep in "${deps[@]}"; do
		command_exists "$dep" || missing_deps+=("$dep")
	done

	# Exit if any dependencies are missing
	# Refactored SC2181: Check array size directly
	if ((${#missing_deps[@]} > 0)); then
		echo "Error: Required command(s) not found: ${missing_deps[*]}" >&2
		exit 1
	fi

	# Set the global REALPATH_CMD variable
	REALPATH_CMD="$realpath_cmd_local"
	printv "Using realpath command: $REALPATH_CMD"
}

## File/Path Utilities

absolute_path() {
	local path="$1" abs_path # Declare variables
	# Check if REALPATH_CMD is set (should be after check_deps)
	if [[ -z "$REALPATH_CMD" ]]; then
		echo "Error: REALPATH_CMD not set. Dependency check might have failed." >&2
		return 1
	fi
	# Use -- to protect against paths starting with -
	# Capture stderr to prevent realpath/readlink errors from cluttering stdout
	# Check exit status directly (SC2181)
	if ! abs_path=$("$REALPATH_CMD" -- "$path" 2>/dev/null); then
		echo "Error: Could not determine absolute path for '$path'." >&2
		return 1
	fi
	printf '%s\n' "$abs_path"
	return 0
}

bytes_to_human() {
	local bytes="${1:-0}" human_readable # Declare variables
	# Use awk for calculation and formatting
	# Pass bytes as ARGV[1] to awk for safety
	# Redirect awk stderr to /dev/null
	# Check exit status directly (SC2181) (awk should succeed if input is numeric)
	# Use printf to ensure bytes is treated as a number by awk, even if it's a string like "N/A"
	if ! human_readable=$(printf '%s' "$bytes" | awk 'BEGIN {split("B KiB MiB GiB TiB PiB EiB ZiB YiB",u);b=ARGV[1]+0;p=0;while(b>=1024&&p<8){b/=1024;p++}printf "%.2f %s\n",b,u[p+1]}' 2>/dev/null); then
		echo "Error: Awk failed during bytes conversion for '$bytes'." >&2
		printf 'N/A\n' # Print N/A to stdout as the value
		return 1
	fi
	# Check if awk produced output (e.g., if input was non-numeric and awk didn't error)
	if [[ -z "$human_readable" ]]; then
		echo "Error: Could not convert bytes '$bytes' to human-readable format." >&2
		printf 'N/A\n' # Print N/A to stdout as the value
		return 1
	fi
	printf '%s\n' "$human_readable"
	return 0
}

portable_stat() {
	local file="$1" size # Declare variables
	# Try GNU stat first
	# Check exit status directly (SC2181)
	if size=$(stat -c '%s' "$file" 2>/dev/null); then
		printf '%s\n' "$size"
		return 0
	fi
	# Try BSD stat if GNU stat fails
	# Check exit status directly (SC2181)
	if size=$(stat -f '%z' "$file" 2>/dev/null); then
		printf '%s\n' "$size"
		return 0
	fi
	# If both fail
	echo "Error: Could not get file size for '$file'." >&2
	return 1
}

## Input Validation

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
	# Use ((...)) for integer comparison
	if ! [[ "$fps" =~ ^[0-9]+$ ]] || ((fps <= 0)); then
		echo "Error: Invalid FPS '$fps'. Expected a positive integer." >&2
		return 1
	fi
	return 0
}

validate_factor() {
	local factor="$1"
	# Check format: digits, optional dot, optional digits (requires at least one digit total)
	if ! [[ "$factor" =~ ^[0-9]\.?[0-9]+$ ]] && ! [[ "$factor" =~ ^[0-9]+\.?[0-9]$ ]]; then
		echo "Error: Invalid numeric format for factor '$factor'. Expected a positive number (e.g., 2, 0.5, 1.5)." >&2
		return 1
	fi
	# Check if positive using bc
	local factor_float bc_result # Declare variables
	# Use printf for precise float formatting before bc
	factor_float=$(printf "%.8f" "$factor")
	# Use bc to compare, redirect stderr to suppress potential warnings
	# Check exit status directly (SC2181)
	if ! bc_result=$(bc -l <<<"$factor_float <= 0" 2>/dev/null); then
		echo "Error: bc calculation failed during factor validation for '$factor'." >&2
		return 1
	fi
	# Check the comparison result from bc
	if [[ "$bc_result" -eq 1 ]]; then
		echo "Error: Factor must be positive '$factor'." >&2
		return 1
	fi
	return 0
}

## Config Loader

load_config() {
	# Check if the config file exists in the XDG config path
	if [[ -f "$MERGE_CONF" ]]; then
		printv "Loading configuration from $MERGE_CONF"
		# Source the config file. Use || true to prevent set -e from exiting
		# if the config file contains errors (though ideally it should be valid shell).
		# SC1090: Shellcheck warning about non-constant source. Suppress with directive.
		# shellcheck source=/dev/null
		source "$MERGE_CONF" || {
			echo "Warning: Could not source configuration file '$MERGE_CONF'." >&2
			# Continue execution, command-line args will still be processed
		}
	else
		printv "No configuration file found at $MERGE_CONF"
	fi
}

## Output Filename

get_default_filename() {
	local base="$1" suf="$2" ext="$3" dir="${4:-.}"
	local name full_path n=1 # Refactored SC2318: Split local declaration and assignment
	name="${base}_${suf}.${ext}"
	full_path="$dir/$name"

	# Loop until a non-existent filename is found
	while [[ -e "$full_path" ]]; do
		name="${base}_${suf}${n}.${ext}"
		full_path="$dir/$name"
		n=$((n + 1))
	done

	# Check if the resulting path is empty (should not happen if dir is valid)
	if [[ -z "$full_path" ]]; then
		echo "Error: Failed to generate a unique filename for base '$base'." >&2
		return 1
	fi

	printf '%s\n' "$full_path"
	return 0
}

## File Selection

select_files() {
	local selected_output selected_array=() # Declare variables

	if command_exists fzf; then
		printv "Using fzf for file selection..."
		# Define command arrays for clarity and safety
		local find_cmd=(find . -maxdepth 1 -type f \( -iname '.mp4' -o -iname '.mov' -o -iname '.mkv' -o -iname '.webm' \))
		local xargs_cmd=(xargs -0 "$REALPATH_CMD" --)
		local fzf_cmd=(fzf --multi --preview 'ffprobe -hide_banner -loglevel error {}' --preview-window=right:60% --bind='ctrl-a:select-all+accept' --height=40% --print0)

		# Find video files (mp4, mov, mkv, webm) in the current directory (maxdepth 1)
		# Use -print0 and xargs -0 with REALPATH_CMD for robustness
		# Pipe to fzf for interactive selection
		# --multi: allow multiple selection
		# --preview: show ffprobe info
		# --bind='ctrl-a:select-all+accept': select all and accept on Ctrl+A
		# --print0: output selected files null-separated
		# Capture stderr from fzf (e.g., if preview command fails)
		# Check exit status directly (SC2181)
		# FIX: Use command substitution $(...) to capture pipeline output into a scalar variable
		if ! selected_output=$("${find_cmd[@]}" -print0 | "${xargs_cmd[@]}" 2>/dev/null | "${fzf_cmd[@]}" 2>/dev/null); then
			# fzf returns non-zero for no match (1) or interrupt (130)
			echo "No files selected or fzf interrupted." >&2
			return 1
		fi

		# Read null-separated output into array
		# Use printf to handle potential issues with selected_output being empty or containing non-printable chars
		mapfile -d '' -t selected_array < <(printf '%s' "$selected_output") # Use "$selected_output" for scalar

	else
		echo "fzf not found. Please manually specify file paths (space-separated):" >&2
		read -r manual_input # Read the entire line

		if [[ -z "$manual_input" ]]; then
			echo "No files entered." >&2
			return 1
		fi

		# Read space-separated input into a temporary array
		# NOTE: This will split on spaces and will not handle filenames with spaces
		# unless the user manually quotes them during input. This is a limitation
		# of this manual input method, but we proceed with validation.
		local -a temp_array
		read -r -a temp_array <<<"$manual_input"

		local -a abs_selected_array=()
		local file_found_count=0
		local abs_f # Declare variable
		# Validate each manually entered path
		for f in "${temp_array[@]}"; do
			# Use absolute_path function and check its exit status
			# Check exit status directly (SC2181)
			if [[ -f "$f" ]]; then
				if abs_f=$(absolute_path "$f"); then
					abs_selected_array+=("$abs_f")
					file_found_count=$((file_found_count + 1))
				else
					# absolute_path printed an error
					continue # Continue to check other files
				fi
			else
				echo "Error: Input file not found: '$f'" >&2
				continue # Continue to check other files
			fi
		done

		# If none of the provided files were valid
		if ((file_found_count == 0)); then
			echo "Error: No valid files entered." >&2
			return 1
		fi

		selected_array=("${abs_selected_array[@]}") # Use the validated absolute paths
	fi

	# Final check if any files were selected/provided
	if ((${#selected_array[@]} == 0)); then
		echo "No files selected." >&2
		return 1
	fi

	# Print selected files newline-separated to stdout
	printf '%s\n' "${selected_array[@]}"
	return 0
}

## Video/Audio Opts

get_video_opts() {
	local codec="${1:-libx264}" preset="${2:-slow}" crf_val="${3:-}" qp_val="${4:-}"
	local -a opts=("-c:v" "$codec" "-preset" "$preset" "-pix_fmt" "yuv420p" "-movflags" "+faststart")

	# Add CRF or QP, QP overrides CRF
	if [[ -n "$qp_val" ]]; then
		opts+=("-qp" "$qp_val")
	elif [[ -n "$crf_val" ]]; then
		opts+=("-crf" "$crf_val")
	else
		# Default CRF if neither is specified
		opts+=("-crf" "18")
	fi

	# Output options null-separated for safe reading into an array
	printf '%s\0' "${opts[@]}"
	return 0
}

get_audio_opts() {
	local remove_audio="${1:-false}"
	local -a opts=()

	if [[ "$remove_audio" = "true" ]]; then
		opts+=("-an") # No audio
	else
		opts+=("-c:a" "aac" "-b:a" "128k") # Default AAC 128k
	fi

	# Output options null-separated for safe reading into an array
	printf '%s\0' "${opts[@]}"
	return 0
}

## Filter Chain

generate_atempo_filter() {
	local target_speed="$1" rem_speed atempo_parts=() formatted_rem_speed bc_is_one bc_result # Declare variables
	rem_speed="$target_speed"                                                                 # Assign after declaration (SC2318)

	# Validate the input factor
	if ! validate_factor "$target_speed"; then
		# validate_factor printed the error
		return 1
	fi

	# Format speed for precise bc calculations
	formatted_rem_speed=$(printf "%.8f" "$rem_speed")

	# Check if speed is exactly 1.0 using bc
	# Check exit status directly (SC2181)
	if ! bc_is_one=$(bc -l <<<"$formatted_rem_speed == 1.0" 2>/dev/null); then
		echo "Error: bc calculation failed (comparison == 1.0) for speed '$target_speed'." >&2
		return 1
	fi
	# Check the comparison result from bc
	if [[ "$bc_is_one" -eq 1 ]]; then
		printf '' # Return empty string for speed 1.0
		return 0
	fi

	# Chain atempo=2.0 filters for speeds > 2.0
	# Check exit status directly (SC2181)
	if ! bc_result=$(bc -l <<<"$formatted_rem_speed > 2.0" 2>/dev/null); then
		echo "Error: bc calculation failed (> 2.0) for speed '$target_speed'." >&2
		return 1
	fi
	while [[ "$bc_result" -eq 1 ]]; do
		atempo_parts+=(atempo=2.0)
		# Calculate remaining speed using bc
		# Check exit status directly (SC2181)
		if ! rem_speed=$(bc -l <<<"$formatted_rem_speed / 2.0" 2>/dev/null); then
			echo "Error: bc calculation failed (division by 2.0) for speed '$target_speed'." >&2
			return 1
		fi
		formatted_rem_speed=$(printf "%.8f" "$rem_speed")
		# Check exit status directly (SC2181)
		if ! bc_result=$(bc -l <<<"$formatted_rem_speed > 2.0" 2>/dev/null); then
			echo "Error: bc calculation failed (> 2.0) in loop for speed '$target_speed'." >&2
			return 1
		fi
	done

	# Chain atempo=0.5 filters for speeds < 0.5
	# Check exit status directly (SC2181)
	if ! bc_result=$(bc -l <<<"$formatted_rem_speed < 0.5" 2>/dev/null); then
		echo "Error: bc calculation failed (< 0.5) for speed '$target_speed'." >&2
		return 1
	fi
	while [[ "$bc_result" -eq 1 ]]; do
		atempo_parts+=(atempo=0.5)
		# Calculate remaining speed using bc
		# Check exit status directly (SC2181)
		if ! rem_speed=$(bc -l <<<"$formatted_rem_speed / 0.5" 2>/dev/null); then
			echo "Error: bc calculation failed (division by 0.5) for speed '$target_speed'." >&2
			return 1
		fi
		formatted_rem_speed=$(printf "%.8f" "$rem_speed")
		# Check exit status directly (SC2181)
		if ! bc_result=$(bc -l <<<"$formatted_rem_speed < 0.5" 2>/dev/null); then
			echo "Error: bc calculation failed (< 0.5) in loop for speed '$target_speed'." >&2
			return 1
		fi
	done

	# The remaining speed should now be between 0.5 and 2.0 (inclusive)
	local is_in_range # Declare variable
	# Check exit status directly (SC2181)
	if ! is_in_range=$(bc -l <<<"$formatted_rem_speed >= 0.5 && $formatted_rem_speed <= 2.0" 2>/dev/null); then
		echo "Error: bc calculation failed (range check) for speed '$target_speed'." >&2
		return 1
	fi
	# Add the final atempo filter with the remaining speed
	if [[ "$is_in_range" -eq 1 ]]; then
		atempo_parts+=(atempo="$(printf "%.4f" "$rem_speed")")
	else
		# This case indicates a logic error in the chaining loops
		echo "Error: Calculated final atempo speed '$rem_speed' is out of the expected [0.5, 2.0] range after chaining." >&2
		return 1
	fi

	# Join the atempo parts with commas
	local atempo_filter_str # Declare variable
	# Use printf and IFS in a subshell for safe joining
	atempo_filter_str=$(
		IFS=,
		printf '%s' "${atempo_parts[*]}"
	)

	# Final check: if target speed was not 1.0, the filter string should not be empty
	# Check exit status directly (SC2181)
	local bc_is_not_one # Declare variable
	if ! bc_is_not_one=$(bc -l <<<"$formatted_rem_speed != 1.0" 2>/dev/null); then
		echo "Error: bc calculation failed (comparison != 1.0) for speed '$target_speed'." >&2
		return 1
	fi

	if [[ "$bc_is_not_one" -eq 1 && -z "$atempo_filter_str" ]]; then
		echo "Error: Generated empty atempo filter string for speed '$target_speed' (expected non-empty)." >&2
		return 1
	fi

	printf '%s' "$atempo_filter_str"
	return 0
}

## Help Message

usage() {
	local exit_status="${1:-1}"
	# Use unquoted EOH to allow variable expansion (${0##*/}, $MERGE_CONF)
	# Ensure EOH is on a line by itself with no leading whitespace
	cat <&2 <<EOH
Usage: ${0##*/} [global options] <subcommand> [subcommand options] [args...]

Global Options:
  -v              Verbose output
  -r WxH          Output resolution (e.g., 1280x720) - Required for process, looperang, slowmo
  -f N            Output FPS (integer) - Required for process, looperang, slowmo
  -c <codec>      Video codec (default: libx264)
  -p <preset>     Encoding preset (default: slow)
  --crf <value>   CRF value (default: 18, ignored if --qp is set)
  --qp <value>    QP value (overrides --crf)
  -a <true|false> Remove audio tracks (Default: false for process/looperang/slowmo, true for merge)
  -h, --help      Show this message

Subcommands:
  probe <file>
  process [opts] <in> [out]
  merge   [opts] [<file1> <file2> ...]
  looperang [opts] <in> [out]
  slowmo  [opts] <in> [out]

Subcommand Options:
  merge:
    -o <file>         Output file (default: determined from first input)
    --scale <mode>    Scaling mode for merge: largest, composite, 1080p (default: largest)
                      'largest': Scale all to largest input resolution (or -r if specified), padding if needed.
                      'composite': Scale all to 1280x720 (or -r if specified), padding if needed.
                      '1080p': Scale all to 1920x1080 (or -r if specified), padding if needed.
    --speed <factor>  Playback speed multiplier for merge (default: 1.0)
    --interpolate     Enable frame interpolation for smooth fps in merge
    --output-dir <dir> Output directory for merge (default: .)
  slowmo:
    -s <factor>       Slow factor (float, e.g., 2.0 for 2x slow, 0.5 for 0.5x speed)

Configuration File:
  Options can be set in '$MERGE_CONF' (e.g., output_dir="~/Videos", codec="libvpx-vp9").
  Command-line options override config file options.
EOH
	exit "$exit_status"
}

## Subcommands

cmd_probe() {
	local in="${1:-}"

	# Validate input file argument
	if [[ -z "$in" ]]; then
		echo "Error: No input file provided for probe." >&2
		usage >&2 # Show usage on missing required arg
		return 1  # Return status from function
	fi
	if [[ ! -f "$in" ]]; then
		echo "Error: Input file not found: '$in'" >&2
		return 1 # Return status from function
	fi

	local sz # Declare variable
	# Get file size, check exit status of portable_stat
	# Check exit status directly (SC2181)
	if ! sz=$(portable_stat "$in"); then
		echo "Warning: Could not get file size for '$in'." >&2
		sz="N/A" # Set to N/A on failure
	fi

	local ffprobe_output # Declare variable
	# Capture stderr for potential ffprobe errors
	# Using -v quiet to suppress non-error messages from ffprobe itself
	# Check exit status directly (SC2181)
	if ! ffprobe_output=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,avg_frame_rate:format=duration,format_name "$in" 2>&1); then
		echo "Error running ffprobe on '$in':" >&2
		echo "$ffprobe_output" >&2 # Print captured stderr
		return 1                   # Return status from function
	fi

	local probe_data # Declare variable
	# Use printf to safely pipe ffprobe output to awk (handles nulls/backslashes)
	# Use awk for parsing, more robust than grep | awk chain
	# Handle cases where streams or format info might be missing by defaulting to N/A
	probe_data=$(printf '%s' "$ffprobe_output" | awk '
        /^width=/ { width=$2 }
        /^height=/ { height=$2 }
        /^avg_frame_rate=/ { avg_frame_rate=$2 }
        /^duration=/ { duration=$2 }
        /^format_name=/ { split($2, a, ","); format_name=a[1] } # Handle multiple format names
        END {
            printf "width=%s\n", width ? width : "N/A";
            printf "height=%s\n", height ? height : "N/A";
            printf "avg_frame_rate=%s\n", avg_frame_rate ? avg_frame_rate : "N/A";
            printf "duration=%s\n", duration ? duration : "N/A";
            printf "format_name=%s\n", format_name ? format_name : "N/A";
        }
    ')

	# Extract values from parsed probe_data
	local width="" height="" res="N/A" # Declare and initialize
	width=$(printf '%s' "$probe_data" | awk -F'=' '/^width=/ {print $2}')
	height=$(printf '%s' "$probe_data" | awk -F'=' '/^height=/ {print $2}')
	[[ "$width" != "N/A" && "$height" != "N/A" ]] && res="${width}x${height}"

	local avg_frame_rate="" fps="N/A" fps_val # Declare and initialize
	avg_frame_rate=$(printf '%s' "$probe_data" | awk -F'=' '/^avg_frame_rate=/ {print $2}')

	if [[ "$avg_frame_rate" != "N/A" ]]; then
		# Use bc for floating point division
		# Check if bc successfully produces a number before assigning
		# Use printf for precise float formatting before bc
		# Capture stderr from bc to suppress potential warnings/errors
		# Check exit status directly (SC2181)
		if fps_val=$(bc -l <<<"$(printf "%.8f" "$avg_frame_rate")" 2>/dev/null); then
			# bc succeeded, format to 2 decimal places
			fps=$(printf "%.2f" "$fps_val")
		fi # If bc failed, fps remains "N/A"
	fi

	local dur="" container="" # Declare variables
	dur=$(printf '%s' "$probe_data" | awk -F'=' '/^duration=/ {print $2}')
	container=$(printf '%s' "$probe_data" | awk -F'=' '/^format_name=/ {print $2}')

	# Use unquoted EOF for heredoc to allow variable expansion
	cat <<EOF
=== PROBE REPORT ===

File: '$in'
Container: ${container}
Size: $(bytes_to_human "$sz")
Resolution: ${res}
Frame Rate: ${fps}
Duration: ${dur}s
EOF
	return 0 # Return success status
}

## Process

cmd_process() {
	local in="${1:-}"
	# Default output name based on input, ensuring .mp4 extension
	local out="${2:-${in%.*}.processed.mp4}"

	# Access global options set in main (defaults handled in main)
	# Use parameter expansion defaults to ensure variables are set
	local current_res="${resolution:-}" # Use global/config/cmdline, required
	local current_fps="${fps:-}"        # Use global/config/cmdline, required
	local current_codec="${codec:-libx264}"
	local current_preset="${preset:-slow}"
	local current_crf="${crf:-}"
	local current_qp="${qp:-}"
	local current_remove_audio="${remove_audio:-false}"

	# Validate input file argument
	if [[ -z "$in" ]]; then
		echo "Error: No input file provided for process." >&2
		usage >&2
		return 1
	fi
	if [[ ! -f "$in" ]]; then
		echo "Error: Input file not found: '$in'" >&2
		return 1
	fi

	# Validate required options for process
	if [[ -z "$current_res" ]]; then
		echo "Error: Output resolution (-r) is required for 'process' command." >&2
		usage >&2
		return 1
	fi
	if [[ -z "$current_fps" ]]; then
		echo "Error: Output FPS (-f) is required for 'process' command." >&2
		usage >&2
		return 1
	fi

	# Validate resolution and fps format using validation functions
	if ! validate_resolution "$current_res"; then return 1; fi # validate_resolution prints error
	if ! validate_fps "$current_fps"; then return 1; fi        # validate_fps prints error

	local vopts_str aopts_str # Declare variables
	# Get encoding options as arrays using null separator, check status
	# Check exit status directly (SC2181)
	if ! vopts_str=$(get_video_opts "$current_codec" "$current_preset" "$current_crf" "$current_qp"); then
		echo "Error getting video options." >&2
		return 1
	fi
	# Check exit status directly (SC2181)
	if ! aopts_str=$(get_audio_opts "$current_remove_audio"); then
		echo "Error getting audio options." >&2
		return 1
	fi

	# Read null-separated strings into arrays safely
	local -a vopts=() aopts=()
	mapfile -d '' -t vopts < <(printf '%s' "$vopts_str")
	mapfile -d '' -t aopts < <(printf '%s' "$aopts_str")

	printv "Processing '$in' to '$out' (Resolution: $current_res, FPS: $current_fps)..."
	printv "Video Options: ${vopts[*]}"
	printv "Audio Options: ${aopts[*]}"

	# Build FFmpeg command array
	# Start with the command name 'ffmpeg' and global input options
	local -a ffmpeg_cmd=(ffmpeg -hide_banner -loglevel error -y -i "$in")

	# Add video filter chain (scale and fps)
	# Use parameter expansion to replace 'x' with ':' for the scale filter
	ffmpeg_cmd+=("-vf" "scale=${current_res/x/:},fps=${current_fps}")

	# Add video and audio encoding options
	ffmpeg_cmd+=("${vopts[@]}")
	ffmpeg_cmd+=("${aopts[@]}")

	# Add output file
	ffmpeg_cmd+=("$out")

	printv "FFmpeg command: ${ffmpeg_cmd[*]}"

	# Execute FFmpeg command and check exit status
	# Check exit status directly (SC2181)
	if ! "${ffmpeg_cmd[@]}"; then
		echo "Error: ffmpeg process failed for '$in'." >&2
		return 1 # Return status from function
	fi

	echo "✅ Processed: $out"
	return 0 # Return success status
}

## Merge

cmd_merge() {
	local -a files=("$@") # Positional arguments are input files

	# Access global options set in main (defaults handled in main)
	local current_resolution="${resolution:-}"
	local current_fps="${fps:-}" # Use global/config/cmdline fps if set
	local current_codec="${codec:-libx264}"
	local current_preset="${preset:-slow}"
	local current_crf="${crf:-}"
	local current_qp="${qp:-}"
	# Note: remove_audio default for merge is handled in main before calling cmd_merge
	local current_remove_audio="${remove_audio:-true}" # Default true for merge if not set globally
	local current_scale_mode="${scale_mode:-largest}"
	local current_speed_factor="${speed_factor:-1.0}"
	local current_interpolate="${interpolate:-0}"
	local current_output_dir="${output_dir:-.}"
	local current_output="${output:-}" # Output file specified by -o

	# If no files provided, use interactive selection
	if ((${#files[@]} == 0)); then
		printv "No files provided; launching interactive selection..."
		local selected_files_str # Declare variable
		# Read newline-separated paths from select_files into the files array
		# Use mapfile/readarray for robustness, check exit status of select_files
		# Check exit status directly (SC2181)
		if ! selected_files_str=$(select_files); then
			# select_files already printed an error/message
			return 1 # Return status from function if selection failed
		fi
		# Read newline-separated paths into the files array
		mapfile -t files < <(printf '%s' "$selected_files_str")
	fi

	# Check if any files were selected/provided after potential interactive step
	if ((${#files[@]} < 2)); then # Need at least 2 files to merge
		echo "Error: Need at least two input files for merge. ${#files[@]} provided." >&2
		usage >&2
		return 1
	fi

	# Validate input files exist and get absolute paths
	local -a abs_files=()
	local valid_file_count=0
	for f in "${files[@]}"; do
		local abs_f # Declare variable
		# Use absolute_path function and check its exit status
		# Check exit status directly (SC2181)
		if [[ -f "$f" ]]; then
			if abs_f=$(absolute_path "$f"); then
				abs_files+=("$abs_f")
				valid_file_count=$((valid_file_count + 1))
			else
				# absolute_path printed an error if it failed
				continue # Continue to check other files
			fi
		else
			echo "Error: Input file not found: '$f'" >&2
			continue # Continue to check other files
		fi
	done

	# If none of the provided files were valid
	if ((valid_file_count == 0)); then
		echo "Error: No valid input files found." >&2
		return 1
	fi

	files=("${abs_files[@]}")     # Use absolute paths for all processing
	local num_inputs=${#files[@]} # Update num_inputs based on valid files

	local max_w=0 max_h=0
	local max_fps=0.0 # Use float for max_fps
	printv "Analyzing input files for max resolution and FPS..."
	for inp in "${files[@]}"; do
		local ffprobe_output # Declare variable
		# Capture stderr for potential ffprobe errors
		# Check exit status directly (SC2181)
		if ! ffprobe_output=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,avg_frame_rate "$inp" 2>&1); then
			echo "Warning: Could not probe video stream of '$inp'. Skipping analysis for this file." >&2
			echo "$ffprobe_output" >&2 # Print captured stderr
			continue                   # Skip to next file if probe fails
		fi

		local w="" h="" fr="" # Declare variables
		w=$(printf '%s' "$ffprobe_output" | awk '/^width=/ {print $2}')
		h=$(printf '%s' "$ffprobe_output" | awk '/^height=/ {print $2}')
		[[ "$w" =~ ^[0-9]+$ ]] && [[ "$h" =~ ^[0-9]+$ ]] && {
			((w > max_w)) && max_w=$w
			((h > max_h)) && max_h=$h
		}

		fr=$(printf '%s' "$ffprobe_output" | awk '/^avg_frame_rate=/ {print $2}')
		# Update max FPS if a valid frame rate is found
		if [[ -n "$fr" ]]; then
			# Use bc for floating point comparison
			local val bc_compare # Declare variables
			# Use printf for precise float formatting before bc
			# Use || echo 0.0 to handle potential bc errors gracefully during analysis
			# Capture stderr from bc to suppress potential warnings/errors
			# Check exit status directly (SC2181)
			if ! val=$(bc -l <<<"$(printf "%.8f" "$fr")" 2>/dev/null || echo 0.0); then
				echo "Warning: bc calculation failed during FPS analysis for '$inp'." >&2
				continue
			fi
			# Compare using bc
			# Check exit status directly (SC2181)
			if ! bc_compare=$(bc -l <<<"$val > $max_fps" 2>/dev/null); then
				echo "Warning: bc comparison failed during FPS analysis for '$inp'." >&2
				continue
			fi

			if [[ "$bc_compare" -eq 1 ]]; then
				max_fps="$val"
			fi
		fi
	done

	local target_res="${current_resolution:-}" # Use global/config/cmdline resolution if set
	local target_fps="${current_fps:-}"        # Use global/config/cmdline fps if set

	# Determine target resolution if not specified via -r
	if [[ -z "$target_res" ]]; then
		case "$current_scale_mode" in
		largest)
			if ((max_w > 0 && max_h > 0)); then
				target_res="${max_w}x${max_h}"
				printv "Target resolution not specified, using max input resolution ($current_scale_mode mode): $target_res"
			else
				# Fallback if no video streams found or probe failed
				target_res="1280x720" # A reasonable default
				printv "Could not determine max input resolution, defaulting to $target_res ($current_scale_mode mode)." >&2
			fi
			;;
		composite)
			target_res="1280x720" # Default for composite
			printv "Target resolution not specified, defaulting to $target_res ($current_scale_mode mode)."
			;;
		1080p)
			target_res="1920x1080" # Default for 1080p
			printv "Target resolution not specified, defaulting to $target_res ($current_scale_mode mode)."
			;;
		*)
			# Should not be reached due to validation in main, but for safety
			echo "Error: Unknown scale mode '$current_scale_mode'." >&2
			return 1
			;;
		esac
	else
		# Resolution was specified via -r, validate it
		if ! validate_resolution "$target_res"; then
			# validate_resolution printed an error
			return 1
		fi
		printv "Target resolution specified: $target_res (scale mode: $current_scale_mode)"
	fi

	# Determine target FPS if not specified via -f
	if [[ -z "$target_fps" ]]; then
		local bc_max_fps_gt_0 # Declare variable
		# Capture stderr from bc to suppress potential warnings/errors
		# Check exit status directly (SC2181)
		if ! bc_max_fps_gt_0=$(bc -l <<<"$max_fps > 0" 2>/dev/null); then
			echo "Error: bc comparison failed during target FPS determination." >&2
			return 1
		fi

		if [[ "$bc_max_fps_gt_0" -eq 1 ]]; then
			# Round max_fps to nearest integer for target_fps
			target_fps=$(printf "%.0f" "$max_fps")
			printv "Target FPS not specified, using rounded max input FPS: $target_fps"
		else
			# Fallback if no video streams found or probe failed
			target_fps=30 # A reasonable default
			printv "Could not determine max input FPS, defaulting to: $target_fps" 2>&1
		fi
	else
		# FPS was specified via -f, validate it
		if ! validate_fps "$target_fps"; then
			# validate_fps printed an error
			return 1
		fi
		printv "Target FPS specified: $target_fps"
	fi

	# Parse target resolution into width and height for scaling filters
	local target_res_w target_res_h # Declare variables
	target_res_w=$(echo "$target_res" | cut -d'x' -f1)
	target_res_h=$(echo "$target_res" | cut -d'x' -f2)

	# --- Build FFmpeg Command ---
	# Start with the command name 'ffmpeg' and global input options
	local -a ffmpeg_cmd=(ffmpeg -hide_banner -loglevel error -y)
	local -a stream_filters=() # Array to hold individual stream filter chains
	local -a video_concat_inputs=()
	local -a audio_concat_inputs=()

	# Add inputs and build per-stream filters
	for i in "${!files[@]}"; do
		local input_file="${files[$i]}"
		ffmpeg_cmd+=("-i" "$input_file")

		# Video filter chain for input i
		local v_chain="[${i}:v]"
		# Apply speed factor
		# Use printf for precise float formatting before including in filter string
		v_chain+=",setpts=$(printf "%.8f" "$current_speed_factor")*PTS"
		# Apply scaling (maintain aspect ratio and pad)
		# scale=W:H:force_original_aspect_ratio=decrease,pad=W:H:(ow-iw)/2:(oh-ih)/2
		v_chain+=",scale=${target_res_w}:${target_res_h}:force_original_aspect_ratio=decrease"
		v_chain+=",pad=${target_res_w}:${target_res_h}:(ow-iw)/2:(oh-ih)/2"

		# Apply interpolation if enabled (before FPS)
		if [[ "$current_interpolate" -eq 1 ]]; then
			# minterpolate works best when input FPS is higher than target FPS,
			# or when used to increase FPS. Applying it before the final fps filter.
			v_chain+=",minterpolate='mi_mode=blend:fps=${target_fps}'"
		fi

		# Apply target FPS
		v_chain+=",fps=${target_fps}"

		# Label the output video stream for concatenation
		v_chain+="[v${i}]"

		# Add this video chain to the list of stream filters
		stream_filters+=("$v_chain")

		# Add the output label to the list of inputs for the final video concat filter
		video_concat_inputs+=("[v${i}]")

		# Audio filter chain for input i (if keeping audio)
		if [[ "$current_remove_audio" != "true" ]]; then
			local a_chain="[${i}:a]"

			# Build atempo chain for audio speed adjustment (1/speed_factor)
			local target_audio_speed_val # Declare variable
			# Use printf for precise float formatting before bc
			# Capture stderr from bc to suppress potential warnings/errors
			# Check bc exit status and if output is empty
			if ! target_audio_speed_val=$(bc -l <<<"1 / $(printf "%.8f" "$current_speed_factor")" 2>/dev/null) || [[ -z "$target_audio_speed_val" ]]; then # Increased precision
				echo "Error: Could not calculate target audio speed (1 / $current_speed_factor)." >&2
				return 1
			fi

			local atempo_filter_str # Declare variable
			# Call generate_atempo_filter and check its exit status
			# Check exit status directly (SC2181)
			if ! atempo_filter_str=$(generate_atempo_filter "$target_audio_speed_val"); then
				# generate_atempo_filter printed an error
				return 1
			fi

			# Apply atempo filter chain IF it's not empty (i.e., speed was not exactly 1.0)
			if [[ -n "$atempo_filter_str" ]]; then
				a_chain+=",${atempo_filter_str}"
			fi

			# Label the output audio stream for concatenation
			a_chain+="[a${i}]"

			# Add this audio chain to the list of stream filters
			stream_filters+=("$a_chain")

			# Add the output label to the list of inputs for the final audio concat filter
			audio_concat_inputs+=("[a${i}]")
		fi
	done

	# Build the final concat filter(s)
	local -a concat_filters=()

	# Video concat filter
	# Join video concat input labels (e.g., [v0][v1][v2]...)
	local joined_video_concat_inputs # Declare variable
	joined_video_concat_inputs=$(printf '%s' "${video_concat_inputs[*]}")
	concat_filters+=("${joined_video_concat_inputs}concat=n=${num_inputs}:v=1:a=0[v_out]")

	# Audio concat filter ONLY if audio is not removed
	if [[ "$current_remove_audio" != "true" ]]; then
		# Join audio concat input labels (e.g., [a0][a1][a2]...)
		local joined_audio_concat_inputs # Declare variable
		joined_audio_concat_inputs=$(printf '%s' "${audio_concat_inputs[*]}")
		concat_filters+=("${joined_audio_concat_inputs}concat=n=${num_inputs}:v=0:a=1[a_out]")
	fi

	# Join all stream filters and concat filters with semicolons
	# This is the robust way to build the filter_complex string
	local filter_complex_str # Declare variable
	# Use printf and IFS for safe joining in a subshell
	filter_complex_str=$(
		IFS=';'
		printf '%s' "${stream_filters[@]}" "${concat_filters[@]}"
	)

	# Add the complete filter_complex string to the FFmpeg command
	# Only add if the string is not empty (it should not be with video always present)
	if [[ -n "$filter_complex_str" ]]; then
		ffmpeg_cmd+=("-filter_complex" "$filter_complex_str")
	fi

	# Map output streams
	ffmpeg_cmd+=("-map" "[v_out]")
	if [[ "$current_remove_audio" != "true" ]]; then
		ffmpeg_cmd+=("-map" "[a_out]")
	fi

	local vopts_str aopts_str # Declare variables
	# Get encoding options as arrays using null separator, check status
	# Check exit status directly (SC2181)
	if ! vopts_str=$(get_video_opts "$current_codec" "$current_preset" "$current_crf" "$current_qp"); then
		echo "Error getting video options." >&2
		return 1
	fi
	# Check exit status directly (SC2181)
	if ! aopts_str=$(get_audio_opts "$current_remove_audio"); then
		echo "Error getting audio options." >&2
		return 1
	fi

	# Read null-separated strings into arrays safely
	local -a vopts=() aopts=()
	mapfile -d '' -t vopts < <(printf '%s' "$vopts_str")
	mapfile -d '' -t aopts < <(printf '%s' "$aopts_str")

	# Add encoding options
	ffmpeg_cmd+=("${vopts[@]}")
	ffmpeg_cmd+=("${aopts[@]}")

	# Determine final output path
	local final_output_path # Declare variable
	if [[ -z "$current_output" ]]; then
		# Use base name of the first input file for default output name
		local base_name # Declare variable
		base_name=$(basename "${files[0]%.*}")
		# Use get_default_filename to find a unique name, check status
		# Check exit status directly (SC2181)
		if ! final_output_path=$(get_default_filename "$base_name" "merged" "mp4" "$current_output_dir"); then
			echo "Error determining default output filename." >&2
			return 1
		fi
	else
		# If output is specified, ensure it's a full path relative to output_dir if not absolute
		# Use absolute_path to resolve the output path relative to output_dir, check status
		# First, resolve output_dir itself to an absolute path for robustness
		local abs_output_dir # Declare variable
		if ! abs_output_dir=$(absolute_path "$current_output_dir"); then
			echo "Error: Could not determine absolute path for output directory '$current_output_dir'." >&2
			return 1
		fi
		local relative_output_path="$abs_output_dir/$current_output"
		# Check exit status directly (SC2181)
		if ! final_output_path=$(absolute_path "$relative_output_path"); then
			echo "Error: Could not determine absolute path for output file '$relative_output_path'." >&2
			return 1
		fi
	fi

	# Ensure the output directory exists, check status
	local output_dir_path # Declare variable
	output_dir_path=$(dirname "$final_output_path")
	if ! mkdir -p "$output_dir_path"; then
		echo "Error: Failed to create output directory '$output_dir_path' for '$final_output_path'." >&2
		return 1
	fi

	# Add output file
	ffmpeg_cmd+=("$final_output_path")

	printv "Merging files: ${files[*]}"
	printv "Target Resolution: $target_res, Target FPS: $target_fps"
	printv "Scale Mode: $current_scale_mode, Speed Factor: $current_speed_factor, Interpolate: $current_interpolate"
	printv "Remove Audio: $current_remove_audio"
	printv "Output File: $final_output_path"
	printv "FFmpeg filter_complex: $filter_complex_str" # Print the constructed filter_complex
	printv "FFmpeg command: ${ffmpeg_cmd[*]}"

	# Execute FFmpeg command and check exit status
	# Check exit status directly (SC2181)
	if ! "${ffmpeg_cmd[@]}"; then
		echo "Error: ffmpeg merge failed." >&2
		return 1 # Return status from function
	fi

	echo "✅ Merged: $final_output_path"
	return 0 # Return success status
}

## Looperang

cmd_looperang() {
	local in="${1:-}"
	# Default output name based on input, ensuring .mp4 extension
	local out="${2:-${in%.*}.looperang.mp4}"

	# Access global options set in main (defaults handled in main)
	local current_res="${resolution:-}" # Use global/config/cmdline, required
	local current_fps="${fps:-}"        # Use global/config/cmdline, required
	local current_codec="${codec:-libx264}"
	local current_preset="${preset:-slow}"
	local current_crf="${crf:-}"
	local current_qp="${qp:-}"
	local current_remove_audio="${remove_audio:-false}"

	# Validate input file argument
	if [[ -z "$in" ]]; then
		echo "Error: No input file provided for looperang." >&2
		usage >&2
		return 1
	fi
	if [[ ! -f "$in" ]]; then
		echo "Error: Input file not found: '$in'" >&2
		return 1
	fi

	# Validate required options for looperang
	if [[ -z "$current_res" ]]; then
		echo "Error: Output resolution (-r) is required for 'looperang' command." >&2
		usage >&2
		return 1
	fi
	if [[ -z "$current_fps" ]]; then
		echo "Error: Output FPS (-f) is required for 'looperang' command." >&2
		usage >&2
		return 1
	fi

	# Validate resolution and fps format using validation functions
	if ! validate_resolution "$current_res"; then return 1; fi # validate_resolution prints error
	if ! validate_fps "$current_fps"; then return 1; fi        # validate_fps prints error

	local vopts_str aopts_str # Declare variables
	# Get encoding options as arrays using null separator, check status
	# Check exit status directly (SC2181)
	if ! vopts_str=$(get_video_opts "$current_codec" "$current_preset" "$current_crf" "$current_qp"); then
		echo "Error getting video options." >&2
		return 1
	fi
	# Check exit status directly (SC2181)
	if ! aopts_str=$(get_audio_opts "$current_remove_audio"); then
		echo "Error getting audio options." >&2
		return 1
	fi

	# Read null-separated strings into arrays safely
	local -a vopts=() aopts=()
	mapfile -d '' -t vopts < <(printf '%s' "$vopts_str")
	mapfile -d '' -t aopts < <(printf '%s' "$aopts_str")

	printv "Creating looperang from '$in' to '$out' (Resolution: $current_res, FPS: $current_fps)..."
	printv "Video Options: ${vopts[*]}"
	printv "Audio Options: ${aopts[*]}"

	# --- Build FFmpeg Command ---
	# Start with the command name 'ffmpeg' and global input options
	local -a ffmpeg_cmd=(ffmpeg -hide_banner -loglevel error -y -i "$in")

	# Filter complex: split video/audio, reverse video/audio, concat original and reversed
	local -a stream_filters=() # Array to hold individual stream filter chains

	# Video filter chain: split, reverse, concat
	local video_filter_chain="[0:v]split[f][r];[r]reverse[r];[f][r]concat=n=2:v=1:a=0[v_out]"
	stream_filters+=("$video_filter_chain")

	local map_v="-map [v_out]"
	local map_a=""

	# Add audio chain if keeping audio
	if [[ "$current_remove_audio" != "true" ]]; then
		local audio_filter_chain="[0:a]asplit[af][ar];[ar]areverse[ar];[af][ar]aconcat=n=2:v=0:a=1[a_out]"
		stream_filters+=("$audio_filter_chain")
		map_a="-map [a_out]"
	fi

	# Join all stream filters with semicolons
	local filter_complex_str # Declare variable
	# Use printf and IFS for safe joining in a subshell
	filter_complex_str=$(
		IFS=';'
		printf '%s' "${stream_filters[@]}"
	)

	# Add the complete filter_complex string to the FFmpeg command
	# Only add if the string is not empty (it should not be with video always present)
	if [[ -n "$filter_complex_str" ]]; then
		ffmpeg_cmd+=("-filter_complex" "$filter_complex_str")
	fi

	# Map output streams
	ffmpeg_cmd+=("$map_v")
	[[ -n "$map_a" ]] && ffmpeg_cmd+=("$map_a")

	# Apply scaling and FPS filters after concat for efficiency and consistency
	# Use parameter expansion to replace 'x' with ':' for the scale filter
	ffmpeg_cmd+=("-vf" "scale=${current_res/x/:},fps=${current_fps}")

	# Add video and audio encoding options
	ffmpeg_cmd+=("${vopts[@]}")
	ffmpeg_cmd+=("${aopts[@]}")

	# Add output file
	ffmpeg_cmd+=("$out")

	printv "FFmpeg filter_complex: $filter_complex_str" # Print the constructed filter_complex
	printv "FFmpeg command: ${ffmpeg_cmd[*]}"

	# Execute FFmpeg command and check exit status
	# Check exit status directly (SC2181)
	if ! "${ffmpeg_cmd[@]}"; then
		echo "Error: ffmpeg looperang failed for '$in'." >&2
		return 1 # Return status from function
	fi

	echo "✅ Looperang created: $out"
	return 0 # Return success status
}

## Slow Motion subcommand: Create a slow-motion video from a single file

cmd_slowmo() {
	local in="${1:-}"
	# Default output name based on input, ensuring .mp4 extension
	local out="${2:-${in%.*}.slowmo.mp4}"

	# Access global options set in main (defaults handled in main)
	local current_res="${resolution:-}"          # Use global/config/cmdline, required
	local current_fps="${fps:-}"                 # Use global/config/cmdline, required
	local current_factor="${slowmo_factor:-2.0}" # Use global/config/cmdline, required
	local current_codec="${codec:-libx264}"
	local current_preset="${preset:-slow}"
	local current_crf="${crf:-}"
	local current_qp="${qp:-}"
	local current_remove_audio="${remove_audio:-false}"

	# Validate input file argument
	if [[ -z "$in" ]]; then
		echo "Error: No input file provided for slowmo." >&2
		usage >&2
		return 1
	fi
	if [[ ! -f "$in" ]]; then
		echo "Error: Input file not found: '$in'" >&2
		return 1
	fi

	# Validate required options for slowmo
	if [[ -z "$current_res" ]]; then
		echo "Error: Output resolution (-r) is required for 'slowmo' command." >&2
		usage >&2
		return 1
	fi
	if [[ -z "$current_fps" ]]; then
		echo "Error: Output FPS (-f) is required for 'slowmo' command." >&2
		usage >&2
		return 1
	fi
	# Validate resolution, fps, and slowmo_factor format/value using validation functions
	if ! validate_resolution "$current_res"; then return 1; fi # validate_resolution prints error
	if ! validate_fps "$current_fps"; then return 1; fi        # validate_fps prints error
	# slowmo_factor is validated in main's option parsing, but re-validate here for safety
	if ! validate_factor "$current_factor"; then return 1; fi # validate_factor prints error

	# --- Build audio atempo chain ---
	# The atempo filter applies a SPEED multiplier (0.5 to 2.0).
	# If video is slowed by factor F (playback speed 1/F), audio must be sped by 1/F
	# to keep original duration, OR slowed by 1/F to match the new duration.
	# This script assumes the goal is to match the slowed video duration,
	# so audio speed multiplier needed is 1/factor.
	# We need to chain atempo filters to achieve the target speed 1/factor.

	local target_audio_speed_val # Declare variable
	# Use printf for precise float formatting before bc
	# Capture stderr from bc to suppress potential warnings/errors
	# Check bc exit status and if output is empty
	if ! target_audio_speed_val=$(bc -l <<<"1 / $(printf "%.8f" "$current_factor")" 2>/dev/null) || [[ -z "$target_audio_speed_val" ]]; then # Increased precision
		echo "Error: Could not calculate target audio speed (1 / $current_factor)." >&2
		return 1
	fi

	local atempo_filter_str # Declare variable
	local audio_filter_chain=""
	local map_v="-map [v_out]"
	local map_a=""
	local audio_filter_chain_present=0 # Flag to indicate if audio filter chain is needed

	local -a stream_filters=() # Array to hold individual stream filter chains

	# Video filter chain: setpts, scale, fps
	# Use parameter expansion to replace 'x' with ':' for the scale filter
	local video_filter_chain
	video_filter_chain="[0:v]setpts=$(printf "%.8f" "$current_factor")*PTS,scale=${current_res/x/:},fps=${current_fps}[v_out]"
	stream_filters+=("$video_filter_chain")

	if [[ "$current_remove_audio" != "true" ]]; then
		# Call generate_atempo_filter and check its exit status
		# Check exit status directly (SC2181)
		if ! atempo_filter_str=$(generate_atempo_filter "$target_audio_speed_val"); then
			# generate_atempo_filter printed an error
			return 1
		fi
		# Build audio chain ONLY if atempo_filter_str is not empty (i.e., speed was not exactly 1.0)
		if [[ -n "$atempo_filter_str" ]]; then
			audio_filter_chain="[0:a]${atempo_filter_str}[a_out]"
			stream_filters+=("$audio_filter_chain")
			map_a="-map [a_out]"
			audio_filter_chain_present=1
		else
			# If speed is 1.0 and audio is kept, just map the original audio stream
			map_a="-map 0:a"
		fi
	fi

	# Join all stream filters with semicolons
	local filter_complex_str # Declare variable
	# Use printf and IFS for safe joining in a subshell
	filter_complex_str=$(
		IFS=';'
		printf '%s' "${stream_filters[@]}"
	)

	# Build FFmpeg command array
	# Start with the command name 'ffmpeg' and global input options
	local -a ffmpeg_cmd=(ffmpeg -hide_banner -loglevel error -y -i "$in")

	# Add filter_complex only if it's not empty (it will always have video chain)
	if [[ -n "$filter_complex_str" ]]; then
		ffmpeg_cmd+=("-filter_complex" "$filter_complex_str")
	fi

	# Map output streams
	ffmpeg_cmd+=("$map_v")
	[[ -n "$map_a" ]] && ffmpeg_cmd+=("$map_a")

	local vopts_str aopts_str # Declare variables
	# Get encoding options as arrays using null separator, check status
	# Check exit status directly (SC2181)
	if ! vopts_str=$(get_video_opts "$current_codec" "$current_preset" "$current_crf" "$current_qp"); then
		echo "Error getting video options." >&2
		return 1
	fi
	# Check exit status directly (SC2181)
	if ! aopts_str=$(get_audio_opts "$current_remove_audio"); then
		echo "Error getting audio options." >&2
		return 1
	fi

	# Read null-separated strings into arrays safely
	local -a vopts=() aopts=()
	mapfile -d '' -t vopts < <(printf '%s' "$vopts_str")
	mapfile -d '' -t aopts < <(printf '%s' "$aopts_str")

	printv "Creating slow-motion from '$in' to '$out' (Factor: $current_factor, Resolution: $current_res, FPS: $current_fps)..."
	printv "Video Options: ${vopts[*]}"
	[[ "$current_remove_audio" != "true" && "$audio_filter_chain_present" -eq 1 ]] && printv "Audio Filter: $atempo_filter_str"
	printv "Audio Options: ${aopts[*]}"

	# Add video and audio encoding options
	ffmpeg_cmd+=("${vopts[@]}")
	ffmpeg_cmd+=("${aopts[@]}")

	# Add output file
	ffmpeg_cmd+=("$out")

	printv "FFmpeg filter_complex: $filter_complex_str" # Print the constructed filter_complex
	printv "FFmpeg command: ${ffmpeg_cmd[*]}"

	# Execute FFmpeg command and check exit status
	# Check exit status directly (SC2181)
	if ! "${ffmpeg_cmd[@]}"; then
		echo "Error: ffmpeg slowmo failed for '$in'." >&2
		return 1 # Return status from function
	fi

	echo "✅ Slow-motion processed: $out"
	return 0 # Return success status
}

## Main Entry Point

main() {
	# Declare global variables for options.
	# These are defaults if not set in config or command line.
	# Some are initialized empty and defaulted later based on subcommand/analysis.
	# These variables will be populated by load_config and then overridden by command-line args.
	declare resolution="" # Default: unset, determined by command or input
	declare fps=""        # Default: unset, determined by command or input
	declare codec="libx264"
	declare preset="slow"
	declare crf="" # Default: unset, get_video_opts will use 18
	declare qp=""  # Default: unset
	# Default: keep audio (merge command overrides this default later)
	declare remove_audio="false"
	declare scale_mode="largest" # Default: largest for merge
	declare speed_factor="1.0"   # Default: 1.0 for merge
	declare interpolate="0"      # Default: off for merge (0 or 1)
	declare output_dir="."       # Default: current directory for merge output
	declare slowmo_factor="2.0"  # Default: 2.0 for slowmo
	declare verbose="0"          # Default: not verbose (0 or 1)
	declare output=""            # Default: unset, output file specified by -o for merge

	# Check dependencies and determine realpath command first
	check_deps

	# Load configuration file. This populates the global variables if set in the config.
	load_config

	local subcommand=""
	local -a positional_args=() # Arguments after subcommand
	local status                # Declare status variable

	# Parse command-line options. These will override values loaded from the config.
	# This loop processes arguments until a subcommand or '--' is found
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-v)
			verbose=1
			shift
			;;
		-r | --resolution)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -r/--resolution requires an argument." >&2
				usage >&2
				exit 1
			fi
			# Validate immediately and exit if invalid
			if ! validate_resolution "$1"; then
				usage >&2 # validate_resolution prints the error message
				exit 1
			fi
			resolution="$1" # Override config/default with command-line value
			shift
			;;
		-f | --fps)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -f/--fps requires an argument." >&2
				usage >&2
				exit 1
			fi
			# Validate immediately and exit if invalid
			if ! validate_fps "$1"; then
				usage >&2 # validate_fps prints the error message
				exit 1
			fi
			fps="$1" # Override config/default with command-line value
			shift
			;;
		-c | --codec)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -c/--codec requires an argument." >&2
				usage >&2
				exit 1
			fi
			codec="$1" # Override config/default with command-line value
			shift
			;;
		-p | --preset)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -p/--preset requires an argument." >&2
				usage >&2
				exit 1
			fi
			preset="$1" # Override config/default with command-line value
			shift
			;;
		--crf)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: --crf requires an argument." >&2
				usage >&2
				exit 1
			fi
			local crf_val="$1"
			# Basic numeric check for crf (non-negative integer)
			if ! [[ "$crf_val" =~ ^[0-9]+$ ]]; then
				echo "Error: Invalid CRF value '$crf_val'. Expected a non-negative integer." >&2
				usage >&2
				exit 1
			fi
			crf="$crf_val" # Override config/default with command-line value
			shift
			;;
		--qp)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: --qp requires an argument." >&2
				usage >&2
				exit 1
			fi
			local qp_val="$1"
			# Basic numeric check for qp (non-negative integer)
			if ! [[ "$qp_val" =~ ^[0-9]+$ ]]; then
				echo "Error: Invalid QP value '$qp_val'. Expected a non-negative integer." >&2
				usage >&2
				exit 1
			fi
			qp="$qp_val" # Override config/default with command-line value
			shift
			;;
		-a | --remove-audio)
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -a/--remove-audio requires an argument ('true' or 'false')." >&2
				usage >&2
				exit 1
			fi
			local remove_audio_val="$1"
			# Allow 'true' or 'false' case-insensitively, store as lowercase
			case "$(echo "$remove_audio_val" | tr '[:upper:]' '[:lower:]')" in
			true) remove_audio="true" ;;
			false) remove_audio="false" ;;
			*)
				echo "Error: Invalid value for -a/--remove-audio: '$remove_audio_val'. Expected 'true' or 'false'." >&2
				usage >&2
				exit 1
				;;
			esac
			shift
			;;
		--scale) # Merge-specific option parsed globally
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: --scale requires an argument ('largest', 'composite', or '1080p')." >&2
				usage >&2
				exit 1
			fi
			local scale_val="$1"
			case "$scale_val" in
			largest | composite | 1080p) scale_mode="$scale_val" ;;
			*)
				echo "Error: Invalid value for --scale: '$scale_val'. Expected 'largest', 'composite', or '1080p'." >&2
				usage >&2
				exit 1
				;;
			esac
			shift
			;;
		--speed) # Merge-specific option parsed globally
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: --speed requires a numeric argument." >&2
				usage >&2
				exit 1
			fi
			local speed_val="$1"
			# Validate immediately and exit if invalid
			if ! validate_factor "$speed_val"; then
				usage >&2 # validate_factor prints the error message
				exit 1
			fi
			speed_factor="$speed_val" # Override config/default with command-line value
			shift
			;;
		--interpolate) # Merge-specific option parsed globally
			interpolate=1 # Flag option, no argument needed
			shift
			;;
		--output-dir) # Merge-specific option parsed globally
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: --output-dir requires an argument." >&2
				usage >&2
				exit 1
			fi
			output_dir="$1" # Override config/default with command-line value
			shift
			;;
		-o | --output) # Merge-specific output file option parsed globally
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -o/--output requires an argument." >&2
				usage >&2
				exit 1
			fi
			output="$1" # Override config/default with command-line value
			shift
			;;
		-s | --slow-factor) # Slowmo-specific option parsed globally
			shift
			# Check if argument exists after shift
			if [[ $# -eq 0 || -z "$1" ]]; then
				echo "Error: -s/--slow-factor requires a numeric argument." >&2
				usage >&2
				exit 1
			fi
			local slowmo_val="$1"
			# Validate immediately and exit if invalid
			if ! validate_factor "$slowmo_val"; then
				usage >&2 # validate_factor prints the error message
				exit 1
			fi
			slowmo_factor="$slowmo_val" # Override config/default with command-line value
			shift
			;;
		-h | --help)
			usage 0 # Print help and exit successfully
			;;
		--) # Stop option parsing, treat rest as positional args
			shift
			positional_args=("$@") # Capture remaining args as positional
			break
			;;
		-*)
			# Unknown option encountered before subcommand.
			# Treat as an error.
			echo "Error: Unknown option '$1'." >&2
			usage >&2
			exit 1
			;;
		*)
			# First non-option argument is the subcommand
			subcommand="$1"
			shift
			positional_args=("$@") # Capture remaining args as positional
			break                  # Stop parsing options
			;;
		esac
	done

	# If subcommand wasn't found, the first argument wasn't a subcommand
	if [[ -z "$subcommand" ]]; then
		echo "Error: No subcommand provided." >&2
		usage >&2
		exit 1
	fi

	# Dispatch subcommand with captured positional arguments
	# Pass global options implicitly by having subcommands read the global variables
	case "$subcommand" in
	probe)
		cmd_probe "${positional_args[@]}"
		status=$? # Capture status
		;;
	process)
		cmd_process "${positional_args[@]}"
		status=$? # Capture status
		;;
	merge)
		# Merge specific default: remove_audio=true if not already set by config or cmdline
		: "${remove_audio:=true}"
		cmd_merge "${positional_args[@]}" # Pass positional args to subcommand
		status=$?                         # Capture status
		;;
	looperang)
		cmd_looperang "${positional_args[@]}"
		status=$? # Capture status
		;;
	slowmo)
		cmd_slowmo "${positional_args[@]}"
		status=$? # Capture status
		;;
	help | --help | -h) # Catch help again if it was after global options
		usage 0
		;;
	*)
		echo "Error: Unknown subcommand '$subcommand'." >&2
		usage >&2
		exit 1
		;;
	esac

	exit "$status"
}

main "$@"
