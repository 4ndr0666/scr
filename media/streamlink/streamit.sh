#!/bin/bash
# shellcheck disable=all
# Unified Streamit Script - Refactored and Production-Ready
# Author: [Your Name]
# Description: A comprehensive script to manage streaming via Streamlink with robust error handling and configurability.


# -----------------------------
# Configuration Variables
# -----------------------------
LOG_FILE="$HOME/.local/share/logs/streamit_merged.log"
OUTPUT_DIR="/storage/streamlink"  # Dedicated output directory
MAX_RETRIES=3  # Number of times to retry Streamlink in case of failure
RETRY_DELAY=10 # Time in seconds to wait between retries

# Streamlink Additional Options
# These can be customized as needed or sourced from an external config file
RETRY_STREAMS="--retry-streams 3"
HLS_OPTIONS="--hls-live-edge 3"
PROXY_OPTION=""  # Example: "--http-proxy http://proxyserver:port"

# -----------------------------
# Utility Functions
# -----------------------------

# Function to setup logging
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# Function to log messages with timestamp and type
log_message() {
    local log_type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
}

# Function to display messages with colored output and logging
display_message() {
    local message_type="$1"
    local message="$2"
    case "$message_type" in
        success)
            echo -e "\e[32m✔️  $message\e[0m"
            log_message "SUCCESS" "$message"
            ;;
        error)
            echo -e "\e[31m❌  $message\e[0m"
            log_message "ERROR" "$message"
            ;;
        warning)
            echo -e "\e[33m⚠️  $message\e[0m"
            log_message "WARNING" "$message"
            ;;
        info)
            echo -e "\e[34mℹ️  $message\e[0m"
            log_message "INFO" "$message"
            ;;
    esac
}


# Helper function to execute system commands with error handling
execute_command() {
    local -a command=("$@")
    "${command[@]}" 2>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        display_message error "Failed to execute: ${command[*]}"
        return 1
    else
        display_message success "Successfully executed: ${command[*]}"
        return 0
    fi
}

# Function to extract media info from a stream URL using ffprobe
extract_media_info() {
    local stream_url="$1"
    display_message info "Extracting media information from stream URL..."

    # Use ffprobe to get media info in JSON format
    local media_data
    media_data=$(ffprobe -v quiet -print_format json -show_streams "$stream_url") || {
        display_message warning "Failed to extract media info from stream URL."
        return 1
    }

    if [ -z "$media_data" ]; then
        display_message warning "No media data retrieved from ffprobe."
        return 1
    fi

    # Securely create a temporary file for media info
    local tmp_file
    tmp_file=$(mktemp /tmp/stream_media_info.XXXXXX.json)
    echo "$media_data" > "$tmp_file"

    # Parse media information
    local framerate height codec
    framerate=$(jq -r '.streams[] | select(.codec_type=="video") | .avg_frame_rate' "$tmp_file" | head -n1)
    height=$(jq -r '.streams[] | select(.codec_type=="video") | .height' "$tmp_file" | head -n1)
    codec=$(jq -r '.streams[] | select(.codec_type=="video") | .codec_name' "$tmp_file" | head -n1)

    # Clean up temporary file
    rm -f "$tmp_file"

    # Calculate the actual frame rate
    if [[ "$framerate" == *"/"* ]]; then
        local numerator denominator
        numerator=$(echo "$framerate" | cut -d'/' -f1)
        denominator=$(echo "$framerate" | cut -d'/' -f2)
        if [[ "$denominator" -ne 0 ]]; then
            framerate=$(awk "BEGIN { printf \"%.2f\", $numerator/$denominator }")
        else
            framerate="0"
        fi
    fi

    display_message success "Media Info Extracted:"
    display_message info "Frame rate: $framerate fps"
    display_message info "Resolution: ${height}p"
    display_message info "Codec: $codec"
    return 0
}

# Function to adjust stream settings based on media info
adjust_settings_based_on_media() {
    local stream_url="$1"
    display_message info "Adjusting stream settings based on media info..."

    if extract_media_info "$stream_url"; then
        local resolution
        resolution=$(jq -r '.streams[] | select(.codec_type=="video") | .height' /tmp/stream_media_info.json | head -n1)
        if [[ "$resolution" -lt 720 ]]; then
            display_message warning "Low resolution detected: ${resolution}p. Recommend lowering stream quality."
            
                read -p "Would you like to accept this recommendation? (y/n): " accept_quality
                if [[ "$accept_quality" =~ ^[Yy]$ ]]; then
                    quality="worst"
                    display_message info "Stream quality set to 'worst'."
            fi
        fi
    else
        display_message warning "Skipping automatic adjustments. Using default or user-specified settings."
    fi
}

# Function to ensure a unique filename
ensure_unique_filename() {
    local base_name="$1"
    local extension="$2"
    local output_dir="$3"
    local new_file="$output_dir/$base_name.$extension"
    local counter=1

    while [ -e "$new_file" ]; do
        new_file="$output_dir/${base_name}_$counter.$extension"
        counter=$((counter + 1))
    done

    echo "$new_file"
}

# Function to ensure directories exist and create them idempotently
ensure_directories() {
    local base_dir="$1"
    local stream_dir="$base_dir/$(date +%Y-%m-%d)"

    mkdir -p "$stream_dir"
    echo "$stream_dir"
}

# Function to execute Streamlink with inputs and options, with retry mechanism
run_streamlink() {
    local url="$1"
    local quality="$2"
    local base_output_file="$3"
    local final_output_file
    local final_log_file

    # Ensure directories exist and create them idempotently
    local stream_output_dir
    stream_output_dir=$(ensure_directories "$OUTPUT_DIR")

    # Ensure the output file has a unique name
    final_output_file=$(ensure_unique_filename "$base_output_file" "ts" "$stream_output_dir")
    final_log_file="$HOME/.local/share/logs/streamlink_${final_output_file##*/}.log"

    local retries=0
    local success=false

    while [ $retries -lt $MAX_RETRIES ]; do
        display_message info "Executing Streamlink command (Attempt: $((retries + 1)))..."

        # Start Streamlink in the background
        streamlink "$url" "$quality" --output "$final_output_file" $RETRY_STREAMS $HLS_OPTIONS $PROXY_OPTION > "$final_log_file" 2>&1 &
        local pid=$!

        # Display a live progress bar
        while kill -0 $pid 2> /dev/null; do
            echo -n "."
            sleep 1
        done

        wait $pid
        if [ $? -eq 0 ]; then
            display_message success "Streamlink executed successfully. Output saved to $final_output_file"
            success=true
            break
        else
            display_message error "Streamlink execution failed. Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        fi

        retries=$((retries + 1))
    done

    if [ "$success" = false ]; then
        display_message error "Streamlink failed after $MAX_RETRIES attempts. Check log: $final_log_file"
    fi
}

# Function to handle custom URL input
handle_custom_url() {
    echo -n "Enter stream URL: "
    read -r url
    echo -n "Enter stream quality (e.g., best, worst, 720p60): "
    read -r quality
    echo -n "Enter output file base name (e.g., video): "
    read -r output_file

    # Validate inputs
    if [ -z "$url" ] || [ -z "$quality" ]; then
        display_message error "Invalid input. URL and quality are required."
        exit 1
    fi

    if [ -z "$output_file" ]; then
        output_file="stream_$(date +%Y%m%d%H%M%S)"
    fi

    adjust_settings_based_on_media "$url"
    run_streamlink "$url" "$quality" "$output_file"
}

# Function to handle preset URLs and media info adjustment
handle_preset_with_media_info() {
    case "$1" in
        1)
            url="https://twitch.tv/lenastarkilla"
            quality="best"
            output_file="LenaStarKilla_$(date +%Y%m%d%H%M%S)"
            ;;
        2)
            url="https://twitch.tv/abstarkilla"
            quality="best"
            output_file="AbStarKilla_$(date +%Y%m%d%H%M%S)"
            ;;
        *)
            display_message error "Invalid preset option."
            exit 1
            ;;
    esac
    adjust_settings_based_on_media "$url"
    run_streamlink "$url" "$quality" "$output_file"
}

# Function to validate URL format
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?:// ]]; then
        display_message error "Invalid URL: $url"
        exit 1
    fi
}

# Function to schedule streams using cron
schedule_stream() {
    echo -n "Enter stream URL: "
    read -r url
    echo -n "Enter stream quality: "
    read -r quality
    echo -n "Enter output file base name: "
    read -r output_file
    echo -n "Enter schedule time (in cron format, e.g., '0 5 * * *' for daily 5 AM): "
    read -r cron_schedule

    # Validate inputs
    if [ -z "$url" ] || [ -z "$quality" ] || [ -z "$cron_schedule" ]; then
        display_message error "URL, quality, and schedule time are required."
        exit 1
    fi

    if [ -z "$output_file" ]; then
        output_file="stream_$(date +%Y%m%d%H%M%S)"
    fi

    validate_url "$url"

    # Construct the cron command
    local script_path
    script_path=$(realpath "$0")
    local cron_command
    cron_command="$(which bash) \"$script_path\" --url \"$url\" --quality \"$quality\" --output \"$output_file\""

    # Add cron job to schedule the stream
    (crontab -l 2>/dev/null; echo "$cron_schedule $cron_command") | crontab - || {
        display_message error "Failed to add cron job. Please check your cron configuration."
        exit 1
    }

    display_message success "Stream scheduled successfully with cron for '$cron_schedule'."
}

# -----------------------------
# Command-Line Argument Parsing
# -----------------------------
# Allows the script to be called with --url, --quality, --output for scheduled tasks

parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --url)
                url="$2"
                shift
                ;;
            --quality)
                quality="$2"
                shift
                ;;
            --output)
                output_file="$2"
                shift
                ;;
            --help|-h)
                display_help
                exit 0
                ;;
            *)
                display_message warning "Unknown parameter passed: $1"
                ;;
        esac
        shift
    done
}

# Function to display help message
display_help() {
    echo "Usage: $0 [--url <stream_url>] [--quality <stream_quality>] [--output <output_file>]"
    echo ""
    echo "Options:"
    echo "  --url       Specify the stream URL."
    echo "  --quality   Specify the stream quality (e.g., best, worst, 720p60)."
    echo "  --output    Specify the output file base name."
    echo "  --help, -h  Display this help message."
}

# -----------------------------
# Main Execution Flow
# -----------------------------

# Trap to ensure cleanup on exit
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/stream_media_info.json 2>/dev/null || true
    # Add any additional cleanup tasks here
}

# Initialize logging
setup_logging

# Parse command-line arguments
parse_arguments "$@"

# If URL and quality are provided via command-line, execute directly
if [[ -n "${url:-}" && -n "${quality:-}" ]]; then
    if [[ -z "${output_file:-}" ]]; then
        output_file="stream_$(date +%Y%m%d%H%M%S)"
    fi
    validate_url "$url"
    adjust_settings_based_on_media "$url"
    run_streamlink "$url" "$quality" "$output_file"
    exit 0
fi

# Main menu system for interactive use
main_menu() {
    while true; do
        echo "# --- // STREAMIT MENU //"
        echo "$(tput setaf 6)1$(tput sgr0). Lena"
        echo "$(tput setaf 6)2$(tput sgr0). Ab"
        echo "$(tput setaf 6)3$(tput sgr0). Custom URL"
        echo "$(tput setaf 6)4$(tput sgr0). Schedule"
        echo "$(tput setaf 6)5$(tput sgr0). Exit"
        echo ""
        echo -n "Select an option (1-5): "
        read -r choice
        case "$choice" in
            1|2)
                handle_preset_with_media_info "$choice"
                ;;
            3)
                handle_custom_url
                ;;
            4)
                schedule_stream
                ;;
            5)
                display_message info "Exiting Streamlink Wrapper. Goodbye!"
                exit 0
                ;;
            *)
                display_message warning "Invalid option. Please choose between 1 and 5."
                ;;
        esac
    done
}

# Start the main menu if not executing a scheduled task
main_menu
