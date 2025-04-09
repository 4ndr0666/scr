#!/usr/bin/env bash
# streamit.sh – Final Merged Script
# Dynamically adjusts quality based on ffprobe if the stream is truly online.
# Displays dot progress only for valid online streams, otherwise quickly fails.

# -----------------------------
# Configuration
# -----------------------------
#LOG_FILE="$HOME/.local/share/logs/streamit_merged.log"
OUTPUT_DIR="/storage/streamlink"
MAX_RETRIES=3
RETRY_DELAY=10
RETRY_STREAMS="--retry-streams 3"
HLS_OPTIONS="--hls-live-edge 3"
PROXY_OPTION=""
CACHE_OPTION="" # Example: "--hls-segment-attempts 5 --hls-segment-threads 3"

# -----------------------------
# Logging
# -----------------------------
#setup_logging() {
#    mkdir -p "$(dirname "$LOG_FILE")"
#    touch "$LOG_FILE"
#}

#log_message() {
#    local log_type="$1"
#    local message="$2"
#    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
#}

display_message() {
	local msg_type="$1" msg="$2"
	case "$msg_type" in
	success)
		echo -e "\e[32m✔️  $msg\e[0m"
		log_message "SUCCESS" "$msg"
		;;
	error)
		echo -e "\e[31m❌  $msg\e[0m"
		log_message "ERROR" "$msg"
		;;
	warning)
		echo -e "\e[33m⚠️  $msg\e[0m"
		log_message "WARNING" "$msg"
		;;
	info)
		echo -e "\e[34mℹ️  $msg\e[0m"
		log_message "INFO" "$msg"
		;;
	esac
}

# -----------------------------
# Cleanup
# -----------------------------
trap 'rm -f /tmp/stream_media_info.json 2>/dev/null || true' EXIT

# -----------------------------
# ffprobe + jq
# -----------------------------
extract_media_info() {
	local stream_url="$1"
	display_message info "Extracting media information from stream URL..."

	if ! command -v ffprobe >/dev/null || ! command -v jq >/dev/null; then
		display_message warning "ffprobe/jq not installed. Skipping dynamic resolution checks."
		return 1
	fi

	local media_json
	media_json="$(ffprobe -v quiet -print_format json -show_streams "$stream_url")" || {
		display_message warning "ffprobe failed. Possibly offline or unsupported."
		return 1
	}

	# If the JSON is empty or only braces, it's effectively invalid.
	if [[ -z "$media_json" || "$media_json" =~ ^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$ ]]; then
		display_message warning "No valid media data. Possibly offline."
		return 1
	fi

	# Store for adjust_settings_based_on_media
	echo "$media_json" >/tmp/stream_media_info.json

	# Quick parse just for user display
	local framerate height codec
	framerate="$(jq -r '.streams[]|select(.codec_type=="video")|.avg_frame_rate' /tmp/stream_media_info.json | head -n1)"
	height="$(jq -r '.streams[]|select(.codec_type=="video")|.height' /tmp/stream_media_info.json | head -n1)"
	codec="$(jq -r '.streams[]|select(.codec_type=="video")|.codec_name' /tmp/stream_media_info.json | head -n1)"

	if [[ -z "$height" || "$height" == "null" ]]; then
		display_message warning "ffprobe found no valid video streams. Possibly offline."
		return 1
	fi

	if [[ "$framerate" == */* ]]; then
		local num="${framerate%/*}" den="${framerate#*/}"
		if [[ "$den" -ne 0 ]]; then
			framerate="$(awk "BEGIN{printf \"%.2f\",$num/$den}")"
		else
			framerate="0"
		fi
	fi

	display_message success "Media Info: Resolution ~${height}p, ~${framerate}fps, codec=$codec"
	return 0
}

adjust_settings_based_on_media() {
	local url="$1"
	display_message info "Adjusting stream settings (if resolution <720p)..."

	if extract_media_info "$url"; then
		local resolution
		resolution="$(jq -r '.streams[]|select(.codec_type=="video")|.height' /tmp/stream_media_info.json | head -n1)"
		if [[ "$resolution" =~ ^[0-9]+$ && "$resolution" -lt 720 ]]; then
			display_message warning "Resolution ${resolution}p <720. Suggest lowering quality."
			read -rp "Accept lower quality (worst)? (y/n): " ans
			if [[ "$ans" =~ ^[Yy]$ ]]; then
				quality="worst"
				display_message info "Stream quality set to 'worst'."
			fi
		fi
		return 0
	else
		display_message warning "Skipping resolution-based adjustment. Using default settings."
		return 1
	fi
}

# -----------------------------
# File & Directory Helpers
# -----------------------------
ensure_directories() {
	local base_dir="$1"
	local date_dir="$base_dir/$(date +%Y-%m-%d)"
	mkdir -p "$date_dir"
	echo "$date_dir"
}

ensure_unique_filename() {
	local base="$1" ext="$2" odir="$3"
	local newf="$odir/$base.$ext"
	local c=1
	while [[ -e "$newf" ]]; do
		newf="$odir/${base}_${c}.$ext"
		((c++))
	done
	echo "$newf"
}

# -----------------------------
# Streamlink Runner
# Dots appear only if ffprobe indicated "likely online"
# -----------------------------
run_streamlink() {
	local url="$1"
	local q="$2"
	local base="$3"
	local out_dir
	out_dir="$(ensure_directories "$OUTPUT_DIR")"
	local final_out
	final_out="$(ensure_unique_filename "$base" ts "$out_dir")"

	#    local final_log="$HOME/.local/share/logs/streamlink_${final_out##*/}.log"
	local tries=0 success=false

	while ((tries < MAX_RETRIES)); do
		display_message info "Executing Streamlink (attempt $((tries + 1)))..."
		streamlink "$url" "$q" \
			--output "$final_out" \
			$RETRY_STREAMS $HLS_OPTIONS $PROXY_OPTION $CACHE_OPTION 2>&1 &

		local pid=$!
		# Because we only call run_streamlink after verifying "online" in extract_media_info,
		# we show dots. If it's actually offline, streamlink soon fails with code=2.
		while kill -0 "$pid" 2>/dev/null; do
			echo -n "."
			sleep 1
		done

		wait "$pid"
		local ex=$?
		if ((ex == 0)); then
			display_message success "Streamlink success -> $final_out"
			printf "%b\n"
			success=true
			break
		else
			display_message error "Streamlink exit=$ex. Retrying in $RETRY_DELAY s..."
			sleep "$RETRY_DELAY"
		fi
		((tries++))
	done

	if [[ "$success" == false ]]; then
		display_message error "Failed after $MAX_RETRIES tries. Check log: $final_log"
	fi
}

# -----------------------------
# Menu / Input
# -----------------------------
handle_custom_url() {
	echo -n "Stream URL: "
	read -r url
	#    echo -n "Quality (best/worst/720p60): "
	#    read -r q
	echo -n "Output base name: "
	read -r base
	[[ -z "$url" ]] && {
		display_message error "URL required."
		exit 1
	}
	[[ -z "$base" ]] && base="stream_$(date +%Y%m%d%H%M%S)"

	#    adjust_settings_based_on_media "$url"
	run_streamlink "$url" "$base"
}

handle_preset_with_media_info() {
	case "$1" in
	1)
		url="https://twitch.tv/lenastarkilla"
		#            q="best"
		base="LenaStarKilla_$(date +%Y%m%d%H%M%S)"
		;;
	2)
		url="https://twitch.tv/abstarkilla"
		#            q="best"
		base="AbStarKilla_$(date +%Y%m%d%H%M%S)"
		;;
	*)
		display_message error "Invalid preset."
		exit 1
		;;
	esac
	#    adjust_settings_based_on_media "$url"
	run_streamlink "$url" "$base"
}

schedule_stream() {
	echo -n "URL: "
	read -r url
	echo -n "Quality: "
	read -r q
	echo -n "Output base: "
	read -r base
	echo -n "Cron schedule: "
	read -r when
	[[ -z "$url" || -z "$q" || -z "$when" ]] && {
		display_message error "Missing input for scheduling."
		exit 1
	}
	[[ -z "$base" ]] && base="stream_$(date +%Y%m%d%H%M%S)"

	local script_path
	script_path="$(realpath "$0")"
	local cron_cmd
	cron_cmd="$(which bash) \"$script_path\" --url \"$url\" --quality \"$q\" --output \"$base\""

	(
		crontab -l 2>/dev/null
		echo "$when $cron_cmd"
	) | crontab - || {
		display_message error "Failed to add cron job."
		exit 1
	}
	display_message success "Scheduled at '$when'."
}

# -----------------------------
# Validation
# -----------------------------
validate_url() {
	local t="$1"
	[[ ! "$t" =~ ^https?:// ]] && {
		display_message error "Invalid URL: $t"
		exit 1
	}
}

# -----------------------------
# CLI Argument Handling
# -----------------------------
parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--url)
			url="$2"
			shift
			;;
			#            --quality)
			#                quality="$2"
			#                shift
			#                ;;
		--output)
			output_file="$2"
			shift
			;;
		--help | -h)
			display_help
			exit 0
			;;
		*)
			display_message warning "Unknown param: $1"
			;;
		esac
		shift
	done
}

display_help() {
	echo "Usage: $0 [--url <stream_url>] [--output <base_file>] [--help]"
	echo "Ex: $0 --url https://twitch.tv/somechannel --output myvid"
}

# -----------------------------
# Initialization
# -----------------------------
#setup_logging
parse_arguments "$@"

if [[ -n "${url:-}" ]]; then
	[[ -z "${output_file:-}" ]] && output_file="stream_$(date +%Y%m%d%H%M%S)"
	validate_url "$url"
	#    adjust_settings_based_on_media "$url"
	run_streamlink "$url" "$output_file"
	exit 0
fi

main_menu() {
	while true; do
		echo "# --- // STREAMIT //"
		echo "1 Lena"
		echo "2 Ab"
		echo "3 Custom URL"
		echo "4 Schedule"
		echo "5 Exit"
		echo ""
		echo -n "Choice [1-5]: "
		read -r c
		case "$c" in
		1 | 2)
			handle_preset_with_media_info "$c"
			;;
		3)
			handle_custom_url
			;;
		4)
			schedule_stream
			;;
		5)
			display_message info "Lena got some fat tits huh..."
			exit 0
			;;
		*)
			display_message warning "Invalid choice."
			;;
		esac
	done
}

main_menu
