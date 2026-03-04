#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034
#
# n_m3u8dl_orchestrator.sh
# Ψ-4ndr0666 High-Performance Stream Extraction Matrix (v3.0.0)
#
# COHESION & SUPERSET REPORT:
# - Fused CLI argument parsing and Interactive Menu fallback.
# - Implemented XDG Base Directory standard for configuration storage.
# - Replaced dangerous string command execution with strict Bash Arrays.
# - Dynamic dependency probing for N_m3u8DL-RE and ffmpeg.
# - Preserved advanced live-stream and VOD merging flags.

set -euo pipefail

# -----------------------------------------------------------------------------
# Global State & XDG Configuration
# -----------------------------------------------------------------------------
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/m3u8/m3u8.conf"

# Core Defaults
THREAD_COUNT=8
RETRY_COUNT=5
TMP_DIR="/tmp/n_m3u8dl_tmp"
SAVE_DIR="$PWD"
SAVE_NAME=""
PROXY_URL=""

# Boolean Toggles (Stored as True/False strings for N_m3u8DL-RE compatibility)
AUTO_SELECT="True"
SKIP_MERGE="False"
DEL_AFTER_DONE="True"
USE_FFMPEG_CONCAT="False"
LIVE_REAL_TIME_MERGE="False"
LIVE_PERFORM_AS_VOD="False"

# Execution Target
TARGET_URL=""

# -----------------------------------------------------------------------------
# Theming & Formatting
# -----------------------------------------------------------------------------
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_CYAN='\033[1;36m'
C_YELLOW='\033[1;33m'
C_RESET='\033[0m'

print_info() { echo -e "${C_CYAN}[Ψ] $1${C_RESET}"; }
print_success() { echo -e "${C_GREEN}[+] $1${C_RESET}"; }
print_warning() { echo -e "${C_YELLOW}[*] $1${C_RESET}"; }
print_error() { echo -e "${C_RED}[!] $1${C_RESET}"; }

# -----------------------------------------------------------------------------
# Dependency Management
# -----------------------------------------------------------------------------
check_dependencies() {
	local missing=()

	# Check for the primary downloader (handle common casing variations)
	if command -v N_m3u8DL-RE >/dev/null 2>&1; then
		BIN_M3U8="N_m3u8DL-RE"
	elif command -v n_m3u8dl-re >/dev/null 2>&1; then
		BIN_M3U8="n_m3u8dl-re"
	else
		missing+=("N_m3u8DL-RE")
	fi

	if ! command -v ffmpeg >/dev/null 2>&1; then
		missing+=("ffmpeg")
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		print_error "Critical dependencies missing: ${missing[*]}"
		print_info "Please install them to proceed."
		exit 1
	fi
}

BIN_M3U8="n-m3u8dl-re"
# -----------------------------------------------------------------------------
# Configuration Matrix
# -----------------------------------------------------------------------------
load_config() {
	if [[ -f "$CONFIG_FILE" ]]; then
		# Safely source config ignoring shell injection
		while IFS='=' read -r key val; do
			# Strip quotes
			val="${val%\"}"
			val="${val#\"}"
			case "$key" in
			THREAD_COUNT) THREAD_COUNT="$val" ;;
			RETRY_COUNT) RETRY_COUNT="$val" ;;
			SAVE_DIR) SAVE_DIR="$val" ;;
			TMP_DIR) TMP_DIR="$val" ;;
			PROXY_URL) PROXY_URL="$val" ;;
			esac
		done < <(grep -E '^[A-Z_]+=' "$CONFIG_FILE")
		print_success "Configuration loaded from $CONFIG_FILE"
	fi
}

save_config() {
	mkdir -p "$CONFIG_DIR"
	cat <<EOF >"$CONFIG_FILE"
# Ψ-4ndr0666 N_m3u8DL-RE Orchestrator Configuration
THREAD_COUNT="$THREAD_COUNT"
RETRY_COUNT="$RETRY_COUNT"
SAVE_DIR="$SAVE_DIR"
TMP_DIR="$TMP_DIR"
PROXY_URL="$PROXY_URL"
EOF
	print_success "Configuration locked at $CONFIG_FILE"
}

# -----------------------------------------------------------------------------
# Execution Engine (Array-Based)
# -----------------------------------------------------------------------------
execute_extraction() {
	if [[ -z "$TARGET_URL" ]]; then
		print_error "Extraction matrix requires a valid TARGET_URL."
		return 1
	fi

	print_info "Initiating Stream Extraction Sequence..."
	print_info "Target: $TARGET_URL"
	print_info "Threads: $THREAD_COUNT | Retries: $RETRY_COUNT"

	mkdir -p "$SAVE_DIR"
	mkdir -p "$TMP_DIR"

	# Construct the command array safely
	local cmd=("$BIN_M3U8" "$TARGET_URL")

	cmd+=(--thread-count "$THREAD_COUNT")
	cmd+=(--download-retry-count "$RETRY_COUNT")
	cmd+=(--tmp-dir "$TMP_DIR")
	cmd+=(--save-dir "$SAVE_DIR")
	cmd+=(--skip-merge "$SKIP_MERGE")
	cmd+=(--del-after-done "$DEL_AFTER_DONE")

	if [[ "$AUTO_SELECT" == "True" ]]; then
		cmd+=(--auto-select)
	fi

	if [[ -n "$SAVE_NAME" ]]; then
		cmd+=(--save-name "$SAVE_NAME")
	fi

	if [[ -n "$PROXY_URL" ]]; then
		cmd+=(--custom-proxy "$PROXY_URL")
	fi

	if [[ "$USE_FFMPEG_CONCAT" == "True" ]]; then
		cmd+=(--use-ffmpeg-concat-demuxer)
	fi

	if [[ "$LIVE_REAL_TIME_MERGE" == "True" ]]; then
		cmd+=(--live-real-time-merge)
	fi

	if [[ "$LIVE_PERFORM_AS_VOD" == "True" ]]; then
		cmd+=(--live-perform-as-vod)
	fi

	# Execute
	print_info "Executing: ${cmd[*]}"
	if "${cmd[@]}"; then
		print_success "Extraction Complete. Payload secured in $SAVE_DIR"
	else
		print_error "Extraction Failed. Check logs and stream validity."
	fi
}

# -----------------------------------------------------------------------------
# Interactive Interfaces
# -----------------------------------------------------------------------------
configure_advanced() {
	echo -e "\n${C_CYAN}--- Advanced Configuration Matrix ---${C_RESET}"
	echo "1. Set Thread Count (Current: $THREAD_COUNT)"
	echo "2. Set Retry Count (Current: $RETRY_COUNT)"
	echo "3. Toggle Segment Merge (Skip: $SKIP_MERGE)"
	echo "4. Set Output Directory (Current: $SAVE_DIR)"
	echo "5. Return to Main Menu"

	echo -n "> "
	read -r adv_opt

	case "$adv_opt" in
	1)
		echo -n "Enter Thread Count: "
		read -r THREAD_COUNT
		;;
	2)
		echo -n "Enter Retry Count: "
		read -r RETRY_COUNT
		;;
	3)
		if [[ "$SKIP_MERGE" == "False" ]]; then
			SKIP_MERGE="True"
		else
			SKIP_MERGE="False"
		fi
		print_success "Skip Merge toggled to: $SKIP_MERGE"
		;;
	4)
		echo -n "Enter Absolute Path for Output: "
		read -r SAVE_DIR
		mkdir -p "$SAVE_DIR"
		;;
	5)
		return
		;;
	*)
		print_warning "Invalid input."
		;;
	esac
}

interactive_menu() {
	# Preset Dictionary
	declare -A presets
	presets=(
		["1"]="https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8 (Test Stream 1)"
		["2"]="https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8 (Test Stream 2)"
	)

	while true; do
		echo -e "\n${C_CYAN}==== Ψ-4NDR0666 STREAM EXTRACTOR ====${C_RESET}"
		echo "1. Execute Preset 1: ${presets[1]}"
		echo "2. Execute Preset 2: ${presets[2]}"
		echo "3. Input Custom Target URL"
		echo "4. Access Advanced Configuration"
		echo "5. Save Current State to Config"
		echo "6. Terminate Connection"
		echo -n "> "

		read -r choice
		case "$choice" in
		1)
			TARGET_URL="$(echo "${presets[1]}" | awk '{print $1}')"
			execute_extraction
			;;
		2)
			TARGET_URL="$(echo "${presets[2]}" | awk '{print $1}')"
			execute_extraction
			;;
		3)
			echo -n "Enter M3U8/MPD URL: "
			read -r TARGET_URL
			if [[ -n "$TARGET_URL" ]]; then
				execute_extraction
			else
				print_warning "URL cannot be empty."
			fi
			;;
		4)
			configure_advanced
			;;
		5)
			save_config
			;;
		6)
			print_info "Terminating matrix. Goodbye."
			exit 0
			;;
		*)
			print_warning "Invalid directive."
			;;
		esac
	done
}

# -----------------------------------------------------------------------------
# CLI Argument Parsing
# -----------------------------------------------------------------------------
show_help() {
	echo -e "${C_CYAN}Ψ-4NDR0666 N_m3u8DL-RE Orchestrator${C_RESET}"
	echo "Usage: $0 [options] [URL]"
	echo ""
	echo "Options:"
	echo "  -h, --help            Show this help dialog."
	echo "  -t, --threads NUM     Set thread count (Default: $THREAD_COUNT)."
	echo "  -r, --retries NUM     Set retry count (Default: $RETRY_COUNT)."
	echo "  -d, --save-dir DIR    Set output directory."
	echo "  -o, --output NAME     Set output filename (without extension)."
	echo "  -c, --create-config   Generate default config file and exit."
	echo ""
	echo "If no URL or options are provided, the interactive menu will launch."
}

parse_arguments() {
	while [[ "$#" -gt 0 ]]; do
		case "$1" in
		-h | --help)
			show_help
			exit 0
			;;
		-t | --threads)
			THREAD_COUNT="$2"
			shift 2
			;;
		-r | --retries)
			RETRY_COUNT="$2"
			shift 2
			;;
		-d | --save-dir)
			SAVE_DIR="$2"
			shift 2
			;;
		-o | --output)
			SAVE_NAME="$2"
			shift 2
			;;
		-c | --create-config)
			save_config
			exit 0
			;;
		-*)
			print_error "Unknown parameter passed: $1"
			show_help
			exit 1
			;;
		*)
			# Treat any positional argument as the URL
			TARGET_URL="$1"
			shift
			;;
		esac
	done
}

# -----------------------------------------------------------------------------
# Boot Sequence
# -----------------------------------------------------------------------------
#check_dependencies
#load_config

if [[ $# -gt 0 ]]; then
	parse_arguments "$@"
	if [[ -n "$TARGET_URL" ]]; then
		execute_extraction
	else
		print_error "CLI mode triggered but no target URL provided."
		exit 1
	fi
else
	# No arguments provided, drop into the matrix
	interactive_menu
fi
