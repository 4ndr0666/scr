#!/bin/bash

# N_m3u8DL-RE Wrapper Script - Production-Ready Version with Advanced Options, Config Support, and Progress Bar

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
    echo "  -c, --create-config                 Create a configuration file in ~/.config/m3u8/"
    echo "  --advanced                          Display advanced options for selection"
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

# Function to apply advanced options
apply_advanced_options() {
    log_info "Advanced options enabled. Select one or more options:"
    echo "1. --binary-merge: Binary merge"
    echo "2. --no-date-info: No date info during muxing"
    echo "3. --write-meta-json: Write meta json after parsing"
    echo "4. --append-url-params: Add URL params to segments"
    echo "5. --concurrent-download: Concurrent audio/video download"
    echo "6. --header: Pass custom headers"
    echo "7. --sub-only: Download subtitles only"
    echo "8. --sub-format: Subtitle output format (SRT/VTT)"
    echo "9. --auto-subtitle-fix: Auto-fix subtitles"
    echo "10. --key: Pass decryption key(s)"
    echo "11. --key-text-file: Set KID-KEY file"
    echo "12. --decryption-binary-path: Path to decryption tool"
    echo "13. --use-shaka-packager: Use shaka-packager for decryption"
    echo "14. --mp4-real-time-decryption: Real-time MP4 decryption"
    echo "15. --max-speed: Set speed limit"
    echo "16. --mux-after-done: Mux streams after download"
    echo "17. --custom-hls-method: Set HLS encryption method"
    echo "18. --custom-hls-key: Set HLS decryption key"
    echo "19. --use-system-proxy: Use system proxy"
    echo "20. --custom-range: Download specific segments"
    echo "21. --task-start-at: Schedule task start time"
    echo "22. --live-perform-as-vod: Download live streams as VOD"
    echo "23. --live-real-time-merge: Real-time live stream merging"
    echo "24. --live-keep-segments: Keep live stream segments"
    echo "25. --live-record-limit: Set recording time limit"
    
    read -p "Enter option number(s) separated by space: " -a advanced_selections
    
    for option in "${advanced_selections[@]}"; do
        case $option in
            1) ADVANCED_OPTIONS+=" --binary-merge";;
            2) ADVANCED_OPTIONS+=" --no-date-info";;
            3) ADVANCED_OPTIONS+=" --write-meta-json";;
            4) ADVANCED_OPTIONS+=" --append-url-params";;
            5) ADVANCED_OPTIONS+=" -mt";;
            6) ADVANCED_OPTIONS+=" -H";;
            7) ADVANCED_OPTIONS+=" --sub-only";;
            8) ADVANCED_OPTIONS+=" --sub-format SRT";; # Change SRT to VTT if needed
            9) ADVANCED_OPTIONS+=" --auto-subtitle-fix";;
            10) ADVANCED_OPTIONS+=" --key";;
            11) ADVANCED_OPTIONS+=" --key-text-file";;
            12) ADVANCED_OPTIONS+=" --decryption-binary-path";;
            13) ADVANCED_OPTIONS+=" --use-shaka-packager";;
            14) ADVANCED_OPTIONS+=" --mp4-real-time-decryption";;
            15) ADVANCED_OPTIONS+=" -R";;
            16) ADVANCED_OPTIONS+=" -M";;
            17) ADVANCED_OPTIONS+=" --custom-hls-method";;
            18) ADVANCED_OPTIONS+=" --custom-hls-key";;
            19) ADVANCED_OPTIONS+=" --use-system-proxy";;
            20) ADVANCED_OPTIONS+=" --custom-range";;
            21) ADVANCED_OPTIONS+=" --task-start-at";;
            22) ADVANCED_OPTIONS+=" --live-perform-as-vod";;
            23) ADVANCED_OPTIONS+=" --live-real-time-merge";;
            24) ADVANCED_OPTIONS+=" --live-keep-segments";;
            25) ADVANCED_OPTIONS+=" --live-record-limit";;
            *) log_error "Invalid option number: $option";;
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
    local cmd="n-m3u8dl-re $url --save-dir $SAVE_DIR --save-name $SAVE_NAME --thread-count $THREAD_COUNT --download-retry-count $RETRY_COUNT $USE_FFMPEG_CONCAT_DEMUXER $AUTO_SELECT $DELETE_AFTER_DONE $ADVANCED_OPTIONS --log-level $LOG_LEVEL"

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

# Function to create a configuration file
create_config_file() {
    local config_dir="$HOME/.config/m3u8/"
    local config_path="$config_dir/m3u8.conf"

    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"
        log_info "Created config directory at $config_dir"
    fi

    echo "THREAD_COUNT=$THREAD_COUNT" > "$config_path"
    echo "RETRY_COUNT=$RETRY_COUNT" >> "$config_path"
    echo "SAVE_DIR=$SAVE_DIR" >> "$config_path"
    echo "LOG_LEVEL=$LOG_LEVEL" >> "$config_path"

    log_success "Configuration file created at $config_path"
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
            -c|--create-config)
                create_config_file
                exit 0
                ;;
            --advanced)
                apply_advanced_options
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
