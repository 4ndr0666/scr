#!/usr/bin/env bash
# Author: 4ndr0666
# v3.1.7 (Mathematical Lossless Quality - CRF 0, No Overwrite Prompt)
set -euo pipefail
# ================== // WM_SUITE.SH //
## Description: Embeds a normalized, crisp watermark (resolution-aware).
#  Lossless watermarking (FFV1 .mkv intermediate), then re-encode to H.264 .mp4.
#  Automatically concatenates preset intro and outro videos.
#  Recursion, error trapping.
# ------------------------------------------------
# Canonical defaults
# Project root where config file and output directories reside, can be overridden by env variable
PROJECT_ROOT="${PROJECT_ROOT:-/Nas/Fanvue}"

OUTPUT_DIR="$PROJECT_ROOT/output"
IMG_OUT_DIR="$OUTPUT_DIR/images"
VID_OUT_DIR="$OUTPUT_DIR/videos"

# Resolve script dir (for default watermark/intro/outro paths in config setup)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Config file definition
CONFIG_FILE_NAME=".config_wm_suite"
CONFIG_FILE="$PROJECT_ROOT/$CONFIG_FILE_NAME"

# WM_FILE, INTRO_FILE, OUTRO_FILE, CONFIG_TMPDIR_PATH will be sourced from CONFIG_FILE

# Video encoding defaults
# For intermediate FFV1 lossless step:
VIDEO_INTERMEDIATE_CODEC="ffv1"
VIDEO_INTERMEDIATE_QP=0
# For final H.264 MP4 output step:
VIDEO_FINAL_CODEC="libx264"
# Set to CRF 0 for mathematically lossless H.264 encoding.
# Be aware: This will result in very large file sizes.
# Also, the 'format=yuv420p' filter still applies chroma subsampling if the source was higher chroma.
VIDEO_FINAL_CRF=0
VIDEO_FINAL_PRESET="slow" # Default preset for final libx264 output
AUDIO_MODE_FLAG="-an"     # Default: remove audio. Can be overridden by --keep-audio
MAX_RESOLUTION=1080

# Watermark layout
WM_HORIZONTAL_PADDING_RATIO=0.01 # Horizontal padding ratio for tighter placement
WM_VERTICAL_PADDING_RATIO=0.02   # Vertical padding ratio
WM_OPACITY=0.65                  # used only for images; video uses PNG alpha as-is
WM_POSITION="bottom-right"       # bottom-right | bottom-left | top-right | top-left

# Resolution-aware watermark widths (px) for video AND images
WM_W_1080=340
WM_W_720=260
WM_W_LOW=200

# Images encoding defaults (hardcoded to lossless PNG)
MIN_LONG_EDGE=1440
IMAGE_OUT_FORMAT="png" # Hardcoded to lossless PNG

# Legacy/compat
FFLOGLEVEL="error" # Default FFMPEG log level. Set to 'info' with --verbose.

########################
# Flags
########################
KEEP_AUDIO=0  # Default: remove audio
VERBOSE=0     # Default: non-verbose output
FULL_CONCAT=0 # Default: do not include intro/outro concatenation

usage() {
	cat <<EOF
Usage:
  wm_suite.sh <file-or-dir> [more ...]
Options:
  --keep-audio       Keep original audio track in final video output
  --verbose          Enable verbose logging
  --full             Include intro and outro videos in the final output
  -h, --help         Show help
Outputs:
  videos  -> $PROJECT_ROOT/output/videos/*_wm.mp4 (H.264, CRF $VIDEO_FINAL_CRF 'mathematically lossless', with Intro/Outro if present)
  images  -> $PROJECT_ROOT/output/images/*_wm.png (lossless)
Configuration paths (Watermark, Intro, Outro, Temporary Directory) are managed in: $CONFIG_FILE
Never overwrites existing outputs.
EOF
}
ARGS=()
while (($#)); do
	case "${1:-}" in
	-h | --help)
		usage
		exit 0
		;;
	--keep-audio)
		KEEP_AUDIO=1
		shift
		;;
	--verbose)
		VERBOSE=1
		FFLOGLEVEL="info"
		shift
		;;
	--full)
		FULL_CONCAT=1
		shift
		;; # New flag to enable full concatenation
	*)
		ARGS+=("$1")
		shift
		;;
	esac
done
set -- "${ARGS[@]:-}"
[[ $# -ge 1 ]] || {
	usage
	exit 1
}

# Set AUDIO_MODE_FLAG based on --keep-audio flag
if ((KEEP_AUDIO == 1)); then
	AUDIO_MODE_FLAG="" # Keep audio
else
	AUDIO_MODE_FLAG="-an" # Remove audio
fi

########################
# Setup and deps
########################
mkdir -p "$OUTPUT_DIR" "$IMG_OUT_DIR" "$VID_OUT_DIR"

need() { command -v "$1" >/dev/null 2>&1 || {
	echo "Missing $1. Install: sudo pacman -S $1"
	exit 1
}; }
need ffmpeg
need ffprobe
need magick
need find

# Array to store temporary files for cleanup
declare -a TEMP_FILES
GLOBAL_TMP_WM="" # Global temporary watermark file

# Trap for errors and exit cleanup
cleanup() {
	local exit_code=$?
	if [[ $exit_code -ne 0 && $exit_code -ne 130 ]]; then # 130 is typically Ctrl+C
		echo "Error on line $LINENO. Exiting." >&2
	fi
	if ((${#TEMP_FILES[@]} > 0)); then
		[[ "$VERBOSE" == 1 ]] && echo "Cleaning up temporary files: ${TEMP_FILES[*]}" >&2
		rm -f "${TEMP_FILES[@]}" || true
	fi
	exit "$exit_code"
}
trap cleanup EXIT
trap 'echo "An error occurred. Cleaning up and exiting." >&2; exit 1' ERR

# Function to get user input with a default value
get_user_input() {
	local prompt="$1"
	local default_val="$2"
	local input_result=""
	read -rp "$prompt [default: $default_val]: " input_result
	if [[ -z "$input_result" ]]; then
		echo "$default_val"
	else
		echo "$input_result"
	fi
}

# Function to run initial configuration setup
run_config_setup() {
	echo "========================================================"
	echo "  wm_suite.sh Configuration Setup"
	echo "========================================================"
	echo "Configuration file not found. Let's set up essential paths."
	echo "The config file will be saved in: $CONFIG_FILE"
	echo ""

	mkdir -p "$PROJECT_ROOT" || {
		echo "Error: Could not create project root directory '$PROJECT_ROOT'."
		exit 1
	}

	# Define default paths for the prompts based on your initial request
	local _wm_file_default="$SCRIPT_DIR/wm-XL.png"
	local _intro_file_default="/Nas/Fanvue/video/Intro.mp4"
	local _outro_file_default="/Nas/Fanvue/video/Outro.mp4"
	local _tmpdir_default="$PROJECT_ROOT/tmp" # Suggest tmp dir within project root

	local _wm_file_input=""
	local _intro_file_input=""
	local _outro_file_input=""
	local _tmpdir_input=""

	_wm_file_input=$(get_user_input "Watermark file path" "$_wm_file_default")
	if [[ -z "$_wm_file_input" ]]; then
		echo "Error: Watermark file path cannot be empty. Exiting setup."
		exit 1
	fi

	_intro_file_input=$(get_user_input "Intro video file path (leave blank if none)" "$_intro_file_default")
	_outro_file_input=$(get_user_input "Outro video file path (leave blank if none)" "$_outro_file_default")
	_tmpdir_input=$(get_user_input "Temporary files directory (leave blank for system default /tmp)" "$_tmpdir_default")

	echo "# wm_suite.sh Configuration" >"$CONFIG_FILE"
	echo "WM_FILE=\"$_wm_file_input\"" >>"$CONFIG_FILE"
	echo "INTRO_FILE=\"$_intro_file_input\"" >>"$CONFIG_FILE"
	echo "OUTRO_FILE=\"$_outro_file_input\"" >>"$CONFIG_FILE"
	echo "CONFIG_TMPDIR_PATH=\"$_tmpdir_input\"" >>"$CONFIG_FILE"
	chmod 600 "$CONFIG_FILE"
	echo ""
	echo "Configuration saved to '$CONFIG_FILE'."
	echo "You can edit this file directly to change paths later."
	echo "========================================================"
	echo ""
}

# Check for and load config file
if [[ ! -f "$CONFIG_FILE" ]]; then
	run_config_setup
fi
# Source the config file to load WM_FILE, INTRO_FILE, OUTRO_FILE, CONFIG_TMPDIR_PATH
source "$CONFIG_FILE"

# Set TMPDIR environment variable if configured
if [[ -n "${CONFIG_TMPDIR_PATH:-}" ]]; then
	export TMPDIR="${CONFIG_TMPDIR_PATH}"
	mkdir -p "$TMPDIR" || {
		echo "Error: Could not create configured TMPDIR '$TMPDIR'. Please check permissions."
		exit 1
	}
	[[ "$VERBOSE" == 1 ]] && echo "Using configured temporary directory: $TMPDIR"
else
	[[ "$VERBOSE" == 1 ]] && echo "Using system default temporary directory (usually /tmp)."
fi

# Function to resolve the watermark file (now uses WM_FILE sourced from config)
resolve_watermark_file() {
	if [[ -z "${WM_FILE:-}" ]]; then
		echo "Error: WM_FILE not set in configuration. Please run setup again or check $CONFIG_FILE."
		exit 1
	fi
	if [[ ! -f "$WM_FILE" ]]; then
		echo "Error: Configured watermark file '$WM_FILE' not found. Please update your configuration ($CONFIG_FILE)."
		exit 1
	fi

	[[ "$VERBOSE" == 1 ]] && echo "Using watermark: $WM_FILE"

	# Pre-process watermark once globally
	GLOBAL_TMP_WM="$(mktemp --suffix=.png)"
	TEMP_FILES+=("$GLOBAL_TMP_WM") # Add temp file to cleanup list
	[[ "$VERBOSE" == 1 ]] && echo "Pre-processing watermark to $GLOBAL_TMP_WM..."
	magick "$WM_FILE" -trim +repage "$GLOBAL_TMP_WM"
}

# Resolve watermark file and pre-process it globally
resolve_watermark_file

########################
# Helpers
########################
lower_ext() { awk -F. '{print tolower($NF)}' <<<"$1"; }
is_video() { case "$(lower_ext "$1")" in mp4 | mov | mkv) return 0 ;; *) return 1 ;; esac }
is_image() { case "$(lower_ext "$1")" in jpg | jpeg | png | webp) return 0 ;; *) return 1 ;; esac }

probe_dim() { ffprobe -v 0 -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$1"; }
probe_dur() { ffprobe -v 0 -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null || echo "0"; }

wm_xy_expr() {
	# Use separate horizontal and vertical padding ratios
	case "$WM_POSITION" in
	bottom-right) echo "x=W-w-${WM_HORIZONTAL_PADDING_RATIO}*W:y=H-h-${WM_VERTICAL_PADDING_RATIO}*H" ;;
	bottom-left) echo "x=${WM_HORIZONTAL_PADDING_RATIO}*W:y=H-h-${WM_VERTICAL_PADDING_RATIO}*H" ;;
	top-right) echo "x=W-w-${WM_HORIZONTAL_PADDING_RATIO}*W:y=${WM_VERTICAL_PADDING_RATIO}*H" ;;
	top-left) echo "x=${WM_HORIZONTAL_PADDING_RATIO}*W:y=${WM_VERTICAL_PADDING_RATIO}*H" ;;
	*) echo "x=W-w-${WM_HORIZONTAL_PADDING_RATIO}*W:y=H-h-${WM_VERTICAL_PADDING_RATIO}*H" ;;
	esac
}

wm_target_px_for_h() {
	local h="$1"
	if ((h >= 1000)); then
		echo "$WM_W_1080"
	elif ((h >= 700)); then
		echo "$WM_W_720"
	else
		echo "$WM_W_LOW"
	fi
}

img_gravity() {
	case "$WM_POSITION" in
	bottom-right) echo "southeast" ;;
	bottom-left) echo "southwest" ;;
	top-right) echo "northeast" ;;
	top-left) echo "northwest" ;;
	*) echo "southeast" ;;
	esac
}

########################
# Image pipeline
########################
process_image() {
	local in="$1"
	local base="${in##*/}"
	local stem="${base%.*}"
	local out_ext="$IMAGE_OUT_FORMAT"
	local out="$IMG_OUT_DIR/${stem}_wm.$out_ext"

	[[ -e "$out" ]] && {
		echo "Skip image (exists): $out"
		return
	}

	[[ "$VERBOSE" == 1 ]] && echo "Processing image: $in to $out"

	# Identify size
	read -r W H < <(magick identify -format "%w %h" "$in")
	[[ -z "${W:-}" || -z "${H:-}" ]] && {
		echo "Identify failed for image: $in"
		return
	}
	local LONG="$W"
	((H > W)) && LONG="$H"
	local TARGET="$LONG"
	((LONG < MIN_LONG_EDGE)) && TARGET="$MIN_LONG_EDGE"

	# Derived geometry
	local wm_w xoff yoff
	# Resolution-aware watermark width for images, using image height
	wm_w="$(wm_target_px_for_h "$H")"
	xoff="$(awk "BEGIN{printf \"%d\", $W*$WM_HORIZONTAL_PADDING_RATIO}")"
	yoff="$(awk "BEGIN{printf \"%d\", $H*$WM_VERTICAL_PADDING_RATIO}")"

	local magick_cmd=(
		magick "$in"
		-resize "${TARGET}x${TARGET}\>"
	)

	# Watermark overlay using the globally pre-processed watermark
	magick_cmd+=(
		\( "$GLOBAL_TMP_WM" -alpha on -channel A -evaluate multiply "$WM_OPACITY" +channel -resize "${wm_w}x" \)
		-gravity "$(img_gravity)" -geometry +"${xoff}"+"${yoff}" -compose over -composite
		-strip # Remove EXIF/IPTC profiles, comments. This is a lossless operation for PNG.
	)

	# Output is hardcoded to PNG. PNG is lossless by nature.
	magick_cmd+=("$out")

	# Execute the magick command
	[[ "$VERBOSE" == 1 ]] && echo "  Executing: ${magick_cmd[*]}"
	"${magick_cmd[@]}"
	echo "Image -> $out"
}

########################
# Video pipeline
########################
process_video() {
	local in="$1"
	local base="${in##*/}"
	local stem="${base%.*}"
	# mktemp will use $TMPDIR if set, otherwise /tmp
	local intermediate_mkv="$(mktemp --suffix=.mkv.tmp)"     # Temporary FFV1 output for first pass
	local watermarked_mp4_temp="$(mktemp --suffix=.mp4.tmp)" # Temporary H.264 MP4 of just the main video content

	local final_output_mp4="$VID_OUT_DIR/${stem}_wm.mp4" # The actual final output file

	[[ -e "$final_output_mp4" ]] && {
		echo "Skip video (exists): $final_output_mp4"
		return
	}

	[[ "$VERBOSE" == 1 ]] && echo "Processing video: $in"
	[[ "$VERBOSE" == 1 ]] && echo "  Intermediate FFV1 output: $intermediate_mkv"
	[[ "$VERBOSE" == 1 ]] && echo "  Temporary watermarked MP4: $watermarked_mp4_temp"
	[[ "$VERBOSE" == 1 ]] && echo "  Final output: $final_output_mp4"

	# Probe source size
	local WxH
	WxH="$(probe_dim "$in")" || WxH="1920x1080"
	local src_h="${WxH#*x}"

	# Pick crisp watermark width by height
	local WM_TARGET
	WM_TARGET="$(wm_target_px_for_h "$src_h")"

	local pos
	pos="$(wm_xy_expr)"

	# Build full filter graph: scale watermark -> overlay -> normalize -> label [v]
	# Removed 'fps=30' to preserve original video speed.
	local graph="[1:v]scale=${WM_TARGET}:-1:flags=lanczos[wm];[0:v][wm]overlay=${pos}:format=auto[ov];[ov]scale='if(gt(iw,$MAX_RESOLUTION),$MAX_RESOLUTION,iw)':'-2',format=yuv420p[v]"

	# --- First Pass: Watermark and encode to lossless FFV1 MKV ---
	# Explicitly specify output format as matroska
	# Added -y to automatically overwrite existing temporary files.
	ffmpeg -y -hide_banner -loglevel "$FFLOGLEVEL" \
		-i "$in" -i "$GLOBAL_TMP_WM" \
		-filter_complex "$graph" \
		-map "[v]" -c:v "$VIDEO_INTERMEDIATE_CODEC" -qp "$VIDEO_INTERMEDIATE_QP" $AUDIO_MODE_FLAG \
		-f matroska "$intermediate_mkv"

	TEMP_FILES+=("$intermediate_mkv") # Add intermediate file to cleanup list
	echo "Intermediate FFV1 MKV created: $intermediate_mkv"

	# --- Second Pass: Re-encode from lossless FFV1 MKV to H.264 MP4 (main content only) ---
	# Added -y to automatically overwrite existing temporary files.
	# Added -f mp4 to explicitly specify output format for non-standard .mp4.tmp extension.
	ffmpeg -y -hide_banner -loglevel "$FFLOGLEVEL" \
		-i "$intermediate_mkv" \
		-c:v "$VIDEO_FINAL_CODEC" -crf "$VIDEO_FINAL_CRF" -preset "$VIDEO_FINAL_PRESET" $AUDIO_MODE_FLAG \
		-f mp4 "$watermarked_mp4_temp"

	TEMP_FILES+=("$watermarked_mp4_temp") # Add temporary watermarked MP4 to cleanup list
	echo "Temporary H.264 MP4 (main content) created: $watermarked_mp4_temp"

	# --- Third Pass: Concatenate Intro, Main Video, Outro (if FULL_CONCAT is enabled and files exist) ---
	if ((FULL_CONCAT == 1)); then
		local has_intro=0
		local has_outro=0
		local concat_files=()

		# INTRO_FILE and OUTRO_FILE are sourced from the config
		if [[ -n "${INTRO_FILE:-}" && -f "$INTRO_FILE" ]]; then
			has_intro=1
			concat_files+=("file '$INTRO_FILE'")
			[[ "$VERBOSE" == 1 ]] && echo "  Found intro: $INTRO_FILE"
		fi

		concat_files+=("file '$watermarked_mp4_temp'")

		if [[ -n "${OUTRO_FILE:-}" && -f "$OUTRO_FILE" ]]; then
			has_outro=1
			concat_files+=("file '$OUTRO_FILE'")
			[[ "$VERBOSE" == 1 ]] && echo "  Found outro: $OUTRO_FILE"
		fi

		if ((has_intro == 1 || has_outro == 1)); then
			local concat_list="$(mktemp --suffix=.txt)"
			TEMP_FILES+=("$concat_list") # Add concat list to cleanup

			printf "%s\n" "${concat_files[@]}" >"$concat_list"
			[[ "$VERBOSE" == 1 ]] && {
				echo "  Concat list content:"
				cat "$concat_list"
			}

			# Perform concatenation using concat demuxer (fast and lossless if compatible streams)
			ffmpeg -hide_banner -loglevel "$FFLOGLEVEL" \
				-f concat -safe 0 -i "$concat_list" \
				-c copy "$final_output_mp4"
			echo "Concatenated video (with intro/outro) -> $final_output_mp4"
		else
			# If --full was specified but no intro/outro files were found, just move the watermarked file
			mv "$watermarked_mp4_temp" "$final_output_mp4"
			echo "Video (no intro/outro found) -> $final_output_mp4"
		fi
	else
		# If FULL_CONCAT is not enabled, simply move the watermarked_mp4_temp to the final destination
		mv "$watermarked_mp4_temp" "$final_output_mp4"
		echo "Video -> $final_output_mp4"
	fi
}

########################
# Dispatch
########################
handle_target() {
	local t="$1"
	if [[ -d "$t" ]]; then
		[[ "$VERBOSE" == 1 ]] && echo "Processing directory: $t"
		find "$t" -type f -iregex '.*\.\(mp4\|mov\|mkv\|jpg\|jpeg\|png\|webp\)' |
			while IFS= read -r f; do
				if is_video "$f"; then
					process_video "$f"
				elif is_image "$f"; then process_image "$f"; fi
			done
	else
		[[ "$VERBOSE" == 1 ]] && echo "Processing single file: $t"
		if is_video "$t"; then
			process_video "$t"
		elif is_image "$t"; then
			process_image "$t"
		else echo "Skip unsupported: $t"; fi
	fi
}

for target in "$@"; do handle_target "$target"; done
echo "Done."
