#!/usr/bin/env bash
# Author: 4ndr0666
# Version: 1.3
set -euo pipefail
# ======================== // MERGE //
# Description: Losslessly merge multiple video and image files,
# regardless of differences in container, resolution, FPS, 
# or codec.
# ---------------------------------------------------------

## Temporary File & Directory Management
declare -a TEMP_ITEMS=()
cleanup_all() {
	# Suppress errors as cleanup is a best-effort operation
	rm -rf "${TEMP_ITEMS[@]}" >/dev/null 2>&1
}
trap cleanup_all EXIT INT TERM
register_temp_item() {
	TEMP_ITEMS+=("$1")
}

## Utility Functions
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

is_image_file() {
    # Simple check based on file extension (case-insensitive)
    case "${1,,}" in
        *.jpg|*.jpeg|*.png|*.gif|*.bmp|*.webp|*.tif|*.tiff) return 0 ;;
        *) return 1 ;;
    esac
}

absolute_path() {
	# This function uses the globally set REALPATH_CMD
	"$REALPATH_CMD" -- "$1"
}

printv() {
	[ "${verbose:-0}" -eq 1 ] && printf '%s\n' "$@" >&2
}

## Dependency and Environment Check
check_deps() {
	local dep
	for dep in ffmpeg ffprobe awk bc; do
		if ! command_exists "$dep"; then
			echo "Error: Required command '$dep' not found." >&2
			exit 1
		fi
	done

	if command_exists realpath; then
		REALPATH_CMD="realpath"
	elif readlink -f / >/dev/null 2>&1; then
		REALPATH_CMD="readlink -f"
	else
		echo "Error: Neither 'realpath' nor 'readlink -f' found." >&2
		exit 1
	fi
	export REALPATH_CMD
}

## Main Merge Logic
run_merge() {
	# --- Option Defaults & Global Variables ---
	local output_file=""
	local fast_encode=0
	local verbose=0
	local image_duration=5 # Default duration for images in seconds
	local -a files=()

	# --- Argument Parsing ---
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-o | --output)
			[[ -n "${2:-}" ]] && output_file="$2" || { echo "Error: -o requires an argument." >&2; exit 1; }
			shift 2
			;;
		--fast-encode)
			fast_encode=1
			shift
			;;
		--image-duration)
			if [[ "${2:-}" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$2 > 0" | bc -l) )); then
				image_duration="$2"
			else
				echo "Error: --image-duration requires a positive numeric argument." >&2; exit 1
			fi
			shift 2
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-h | --help)
			cat <<EOH
Usage: ${0##*/} [OPTIONS] <file1> <file2> [...]

A dedicated tool to losslessly merge multiple video and image files,
even with varying containers, resolutions, codecs, or framerates.

Options:
  -o, --output FILE   Set the output filename.
                      (Default: merged_YYYYMMDD_HHMMSS.mp4)
  --image-duration N  Set the duration (in seconds) for each image input.
                      (Default: 5)
  --fast-encode       On re-encode, use a fast, high-quality (but not
                      lossless) preset instead of the default lossless mode.
  -v, --verbose       Enable verbose output to see ffmpeg commands.
  -h, --help          Show this help message.
EOH
			exit 0
			;;
		--)
			shift
			files+=("$@")
			break
			;;
		-*)
			echo "Error: Unknown option '$1'" >&2
			exit 1
			;;
		*)
			files+=("$1")
			shift
			;;
		esac
	done

	if ((${#files[@]} < 2)); then
		echo "Error: At least two input files are required." >&2
		exit 1
	fi

	# --- File Validation & Path Resolution ---
	local -a abs_files=()
	local has_image=0
	for f in "${files[@]}"; do
		if [[ -f "$f" ]]; then
			if local abs_f=$(absolute_path "$f"); then
				abs_files+=("$abs_f")
				if is_image_file "$abs_f"; then
					has_image=1
				fi
			else
				echo "Warning: Could not resolve path for '$f'. Skipping." >&2
			fi
		else
			echo "Warning: Input file not found: '$f'. Skipping." >&2
		fi
	done

	if ((${#abs_files[@]} < 2)); then
		echo "Error: Fewer than two valid input files were found." >&2
		exit 1
	fi
	files=("${abs_files[@]}")

	# --- Output File Handling ---
	if [[ -z "$output_file" ]]; then
		output_file="merged_$(date +%Y%m%d_%H%M%S).mp4"
	fi
	if [[ -e "$output_file" ]]; then
		echo "Error: Output file '$output_file' already exists. Refusing to overwrite." >&2
		exit 1
	fi

	# --- Stage 1: Attempt Lossless Stream Copy (skip if images are present) ---
	if [[ "$has_image" -eq 0 ]]; then
		echo "Attempting fast, lossless stream copy..." >&2
		local list_file
		list_file=$(mktemp) || { echo "Failed to create temp list file" >&2; exit 1; }
		register_temp_item "$list_file"
		for f in "${files[@]}"; do
			printf "file '%s'\n" "$(printf "%s" "$f" | sed "s/'/''/g")" >>"$list_file"
		done
		
		set +e
		ffmpeg -hide_banner -y -f concat -safe 0 -i "$list_file" -c copy "$output_file" >/dev/null 2>&1
		local exit_code=$?
		set -e

		if [[ $exit_code -eq 0 ]]; then
			echo "✅ Stream copy successful: $output_file"
			exit 0
		else
			echo "⚠️  Stream copy failed (Code: $exit_code). Incompatible streams detected. Falling back to re-encode..." >&2
			rm -f "$output_file" 2>/dev/null || true # Clean up failed/zero-byte output, ignore errors
		fi
	else
		echo "🖼️ Images detected. Proceeding directly to normalization and re-encode." >&2
	fi

	# --- Stage 2: Fallback to Normalize-then-Concatenate Architecture ---
	echo "Analyzing files for master format..." >&2
	local max_w=0 max_h=0 max_fps=0.0
	for inp in "${files[@]}"; do
		# ffprobe can get dimensions for both videos and images
		local ffprobe_output
		ffprobe_output=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,avg_frame_rate -of default=noprint_wrappers=1 "$inp" || echo "")
		if [[ -z "$ffprobe_output" ]]; then echo "Warning: Could not probe '$inp'. Skipping for analysis." >&2; continue; fi

		local w h fr
		w=$(echo "$ffprobe_output" | awk -F= '/^width=/ {print $2}')
		h=$(echo "$ffprobe_output" | awk -F= '/^height=/ {print $2}')
		fr=$(echo "$ffprobe_output" | awk -F= '/^avg_frame_rate=/ {print $2}')
		
		[[ "$w" =~ ^[0-9]+$ ]] && ((w > max_w)) && max_w=$w
		[[ "$h" =~ ^[0-9]+$ ]] && ((h > max_h)) && max_h=$h
		
		# Only consider frame rate for actual video files
		if [[ -n "$fr" ]] && ! is_image_file "$inp"; then
			local fr_val
			fr_val=$(echo "$fr" | awk -F/ '{if ($2 && $2 != 0) print $1/$2; else print $1}')
			if (( $(echo "$fr_val > $max_fps" | bc -l 2>/dev/null || echo 0) )); then
				max_fps="$fr_val"
			fi
		fi
	done

	if (( max_w == 0 || max_h == 0 )); then
		echo "Error: Could not determine video dimensions from any input files." >&2
		exit 1
	fi

	local target_res="${max_w}x${max_h}"
	local target_fps
	# If max_fps is still 0 (e.g., only images were provided), default to 30.
	if (( $(echo "$max_fps == 0" | bc -l) )); then
		target_fps=30
	else
		target_fps=$(printf "%.0f" "$max_fps")
	fi
	[[ "$target_fps" -eq 0 ]] && target_fps=30
	echo "Master format determined: ${target_res} @ ${target_fps}fps. Normalizing all clips..." >&2

	local temp_dir
	temp_dir=$(mktemp -d) || { echo "Failed to create temp dir" >&2; exit 1; }
	register_temp_item "$temp_dir"

	local intermediate_list_file
	intermediate_list_file=$(mktemp) || { echo "Failed to create intermediate list file" >&2; exit 1; }
	register_temp_item "$intermediate_list_file"
	
	local i
	for i in "${!files[@]}"; do
		local input_file="${files[$i]}"
		local intermediate_file="$temp_dir/intermediate_$i.ts"
		
		echo "Normalizing clip $(($i + 1))/${#files[@]}..."
		
		local -a norm_cmd=(ffmpeg -hide_banner -loglevel error -y)
		# FIX: Use pad=-1:-1 to robustly center video, avoiding fractional padding errors.
		local v_filter="scale=${target_res}:force_original_aspect_ratio=decrease,pad=${target_res}:-1:-1,format=yuv420p,fps=${target_fps}"
		local filter_complex
		
		if is_image_file "$input_file"; then
			printv "File '$input_file' is an image. Creating ${image_duration}s clip."
			norm_cmd+=(-loop 1 -framerate "$target_fps" -i "$input_file") # Input image
			norm_cmd+=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000) # Input silent audio
			filter_complex="[0:v]${v_filter}[vout];[1:a]anull[aout]"
			norm_cmd+=(-t "$image_duration" -shortest)
		else # It's a video file
			norm_cmd+=(-i "$input_file") # Input video
			
			if ! ffprobe -v quiet -select_streams a:0 "$input_file" >/dev/null 2>&1; then
				printv "File '$input_file' has no audio. Synthesizing silent track."
				norm_cmd+=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000)
				filter_complex="[0:v]${v_filter}[vout];[1:a]anull[aout]"
				norm_cmd+=(-shortest)
			else
				filter_complex="[0:v]${v_filter}[vout];[0:a]aresample=async=1:first_pts=0[aout]"
			fi
		fi
		
		norm_cmd+=(-filter_complex "$filter_complex" -map "[vout]" -map "[aout]")
		# FIX: Use lossless FLAC audio for intermediate files to preserve quality.
		norm_cmd+=(-c:v libx264 -preset ultrafast -qp 0 -c:a flac "$intermediate_file")
		
		printv "Executing: ${norm_cmd[*]}"
		if ! "${norm_cmd[@]}"; then
			echo "Error: Failed to normalize '$input_file'." >&2
			exit 1
		fi

		printf "file '%s'\n" "$intermediate_file" >> "$intermediate_list_file"
	done

	echo "All clips normalized. Performing final concatenation..." >&2
	local -a final_cmd=(ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$intermediate_list_file")
	
	if [[ "$fast_encode" -eq 1 ]]; then
		echo "Using fast re-encode for final output..." >&2
		final_cmd+=(-c:v libx264 -preset fast -crf 15 -c:a aac -b:a 192k)
	else
		echo "Performing lossless stream copy for final output..." >&2
		final_cmd+=(-c copy)
	fi

	final_cmd+=("$output_file")
	
	printv "Executing: ${final_cmd[*]}"
	if ! "${final_cmd[@]}"; then
		echo "❌ Final concatenation failed." >&2
		exit 1
	fi
	
	echo "✅ Merge complete: $output_file"
}

# --- Script Entry Point ---
check_deps
run_merge "$@"
