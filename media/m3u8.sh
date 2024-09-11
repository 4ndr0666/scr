#!/bin/bash

# N_m3u8DL-RE Wrapper Script - Production-Ready Version with CLI flags, config support, full error handling, and advanced options

# Global Defaults and Presets for Common Scenarios
THREAD_COUNT=8
RETRY_COUNT=5
TMP_DIR="/tmp/n_m3u8dl_tmp"
LOG_LEVEL="INFO"
SAVE_DIR="$PWD"
SAVE_NAME=""
AUTO_SELECT="--auto-select"
MERGE_SEGMENTS="--skip-merge False"
DELETE_AFTER_DONE="--del-after-done True"
PROXY_OPTION=""
DEFAULT_PROXY="http://free-proxy.hidemy.name:8080"
USE_FFMPEG_CONCAT_DEMUXER="--use-ffmpeg-concat-demuxer"
LIVE_REAL_TIME_MERGE="--live-real-time-merge"
LIVE_PERFORM_AS_VOD="--live-perform-as-vod"
CHECK_SEGMENTS_COUNT="--check-segments-count True"
CONFIG_FILE="$HOME/.config/m3u8/m3u8.conf"
LOG_FILE=""
URL=""

# Error message color formatting
ERROR_COLOR="\033[1;31m"
SUCCESS_COLOR="\033[1;32m"
INFO_COLOR="\033[1;36m"
NO_COLOR="\033[0m"

# Function to log error messages
log_error() {
    echo -e "${ERROR_COLOR}Error: $1${NO_COLOR}"
}

# Function to log success messages
log_success() {
    echo -e "${SUCCESS_COLOR}$1${NO_COLOR}"
}

# Function to log information messages
log_info() {
    echo -e "${INFO_COLOR}$1${NO_COLOR}"
}

# Function to load configuration from a config file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_info "No config file found at $CONFIG_FILE, proceeding with defaults."
    fi
}

# Function to display help section
show_help() {
    echo "Usage: m3u8.sh <URL> [options]"
    echo
    echo "Options:"
    echo "  -h, --help                          Show this help message and exit"
    echo "  -t, --threads <number>              Set the download thread count (default: $THREAD_COUNT)"
    echo "  -r, --retries <number>              Set the download retry count (default: $RETRY_COUNT)"
    echo "  -d, --save-dir <directory>          Set the output directory (default: $SAVE_DIR)"
    echo "  -o, --output <filename>             Set the output filename (default: auto-generated)"
    echo "  --advanced                          Display advanced options"
    echo
    echo "For more information, visit the n-m3u8dl-re repository or documentation."
}

# Function to validate URL input
validate_url() {
    if [[ -z "$1" ]]; then
        log_error "No URL provided. Please enter a valid URL."
        exit 1
    elif ! [[ "$1" =~ ^https?:// ]]; then
        log_error "Invalid URL format."
        exit 1
    fi
}

# Function to validate directory input
validate_directory() {
    if [[ ! -d "$1" ]]; then
        log_error "Invalid directory. Please provide a valid directory."
        exit 1
    fi
}

# Function to generate an idempotent save name
generate_save_name() {
    if [[ -z "$SAVE_NAME" ]]; then
        SAVE_NAME="m3u8_download_$(date +%Y%m%d%H%M%S)"
        log_info "No save name provided, using default: $SAVE_NAME"
    fi
}

# Function to show the advanced options menu and collect user input
show_advanced_options() {
    log_info "Advanced Options Menu:"
    echo "1. Use ffmpeg concat demuxer (--use-ffmpeg-concat-demuxer)"
    echo "2. Real-time live stream merging (--live-real-time-merge)"
    echo "3. Live stream as VOD (--live-perform-as-vod)"
    echo "4. Set custom proxy (--custom-proxy)"
    echo "5. Concurrent download (--concurrent-download)"
    echo "6. Max speed (--max-speed)"
    echo "7. Skip merge (--skip-merge)"
    echo "8. Use shaka-packager for decryption (--use-shaka-packager)"
    echo "9. Set temporary directory (--tmp-dir)"
    echo "0. Done"
    echo "Select options (enter numbers separated by space): "

    read -ra advanced_selections
    for selection in "${advanced_selections[@]}"; do
        case "$selection" in
            1) USE_FFMPEG_CONCAT_DEMUXER="--use-ffmpeg-concat-demuxer" ;;
            2) LIVE_REAL_TIME_MERGE="--live-real-time-merge" ;;
            3) LIVE_PERFORM_AS_VOD="--live-perform-as-vod" ;;
            4)
                echo -n "Enter custom proxy URL: "
                read -r PROXY_OPTION
                PROXY_OPTION="--custom-proxy $PROXY_OPTION"
                ;;
            5) CONCURRENT_DOWNLOAD="--concurrent-download" ;;
            6)
                echo -n "Enter maximum speed (e.g., 15M or 100K): "
                read -r MAX_SPEED
                MAX_SPEED="--max-speed $MAX_SPEED"
                ;;
            7) MERGE_SEGMENTS="--skip-merge True" ;;
            8) USE_SHAKA_PACKAGER="--use-shaka-packager" ;;
            9)
                echo -n "Enter temporary directory: "
                read -r TMP_DIR
                TMP_DIR="--tmp-dir $TMP_DIR"
                ;;
            0) break ;;
            *)
                log_error "Invalid selection: $selection"
                ;;
        esac
    done
}

# Function to display a simple progress bar
show_progress_bar() {
    local progress=0
    while true; do
        progress=$((progress+1))
        printf "\r${INFO_COLOR}[%-50s] %d%%${NO_COLOR}" $(head -c $((progress/2)) < /dev/zero | tr '\0' '=') "$progress"
        sleep 1
        if [[ "$progress" -ge 100 ]]; then
            break
        fi
    done
}

# Function to run n_m3u8dl-re command
run_n_m3u8dl() {
    local url="$1"
    
    # Validate URL and directory
    validate_url "$url"
    validate_directory "$SAVE_DIR"
    generate_save_name

    LOG_FILE="$SAVE_DIR/n_m3u8dl_log.txt"
    local cmd="n-m3u8dl-re $url --save-dir $SAVE_DIR --save-name $SAVE_NAME --thread-count $THREAD_COUNT --download-retry-count $RETRY_COUNT $USE_FFMPEG_CONCAT_DEMUXER $AUTO_SELECT $DELETE_AFTER_DONE $PROXY_OPTION $LIVE_REAL_TIME_MERGE $LIVE_PERFORM_AS_VOD --log-level $LOG_LEVEL"

    log_info "Executing: $cmd"
    
    # Show progress bar in parallel
    show_progress_bar &

    # Run the download command
    $cmd > "$LOG_FILE" 2>&1

    # Check if the download was successful
    if [[ $? -eq 0 ]]; then
        log_success "Download completed successfully. Check the directory: $SAVE_DIR"
    else
        log_error "Download failed. Check the log file for details: $LOG_FILE"
    fi

    kill $!  # Stop the progress bar when download finishes
}

# Function to parse flags and arguments
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--threads)
                THREAD_COUNT="$2"
                shift
                ;;
            -r|--retries)
                RETRY_COUNT="$2"
                shift
                ;;
            -d|--save-dir)
                SAVE_DIR="$2"
                shift
                ;;
            -o|--output)
                SAVE_NAME="$2"
                shift
                ;;
            --advanced)
                show_advanced_options
                ;;
            *)
                URL="$1"
                ;;
        esac
        shift
    done
}

# Load config before parsing arguments
load_config

# Parse the command-line arguments
parse_args "$@"

# Run the download if URL is provided
if [[ -n "$URL" ]]; then
    run_n_m3u8dl "$URL"
else
    log_error "URL is required."
    show_help
    exit 1
fi
