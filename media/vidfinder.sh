#!/bin/bash

# Unified Video Finder Script - Refactored and Production-Ready
# Author: [Your Name]
# Description: Automates fetching and downloading video files from a specified webpage URL with robust error handling and configurability.

set -euo pipefail
IFS=$'\n\t'

# -----------------------------
# Configuration Variables
# -----------------------------
DOWNLOAD_DIR="$HOME/Downloads"
LOG_FILE="$DOWNLOAD_DIR/download_log.txt"

# Stream download method: ffmpeg or streamlink
DOWNLOAD_METHOD="streamlink"  # Default method

# -----------------------------
# Utility Functions
# -----------------------------

# Function to setup logging
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# Function to log actions with timestamp
log_action() {
    local log_type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
}

# Function to display messages with logging
display_message() {
    local message_type="$1"
    local message="$2"
    case "$message_type" in
        success)
            echo -e "\e[32m✔️  $message\e[0m"
            log_action "SUCCESS" "$message"
            ;;
        error)
            echo -e "\e[31m❌  $message\e[0m"
            log_action "ERROR" "$message"
            ;;
        warning)
            echo -e "\e[33m⚠️  $message\e[0m"
            log_action "WARNING" "$message"
            ;;
        info)
            echo -e "\e[34mℹ️  $message\e[0m"
            log_action "INFO" "$message"
            ;;
    esac
}

# Function to check if the script is running interactively
is_interactive() {
    [[ -t 0 ]]
}

# Function to check for required dependencies
check_dependencies() {
    local dependencies=("curl" "ffmpeg" "streamlink" "grep" "basename" "read" "echo")
    local missing=()
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        display_message error "Missing dependencies: ${missing[*]}. Please install them and retry."
        exit 1
    fi
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

# Function to validate URL format
validate_url() {
    local url="$1"
    local regex='^https?://'
    if [[ ! "$url" =~ $regex ]]; then
        display_message error "Invalid URL format: $url"
        exit 1
    fi
}

# Function to ensure a unique filename before downloading
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

# Function to fetch webpage content and extract video URLs
fetch_and_download() {
    local url="$1"
    echo "Fetching webpage content from $url ..."
    log_action "Fetching webpage content from $url"

    # Fetch the webpage content once
    local page_content
    page_content=$(curl -s "$url") || {
        display_message error "Failed to fetch content from $url"
        log_action "Failed to fetch content from $url"
        return 1
    }

    # Use grep -E to find video URLs
    video_urls=$(echo "$page_content" | grep -Eo 'https://[^"]*DASH[^"]*\.mp4')
    m3u8_urls=$(echo "$page_content" | grep -Eo 'https://[^"]*\.m3u8')

    # Check if any video URLs were found
    if [[ -z "$video_urls" && -z "$m3u8_urls" ]]; then
        echo "No video URLs found with pattern 'DASH' or '.m3u8'."
        log_action "No video URLs found with pattern 'DASH' or '.m3u8'"
        return 1
    fi

    # Download MP4 files
    if [[ -n "$video_urls" ]]; then
        echo "Found the following video URLs:"
        echo "$video_urls"

        # Loop through each found video URL and download it
        for video_url in $video_urls; do
            echo "Downloading video from $video_url ..."
            log_action "Downloading video from $video_url"
            local filename
            filename=$(basename "$video_url")
            filename=$(ensure_unique_filename "${filename%.*}" "mp4" "$DOWNLOAD_DIR")
            curl -o "$filename" "$video_url" && log_action "Successfully downloaded $video_url to $filename" || log_action "Failed to download $video_url"
        done
    fi

    # Handle .m3u8 files
    if [[ -n "$m3u8_urls" ]]; then
        echo "Found the following .m3u8 URLs:"
        echo "$m3u8_urls"

        for m3u8_url in $m3u8_urls; do
            echo "Processing .m3u8 stream from $m3u8_url ..."
            log_action "Processing .m3u8 stream from $m3u8_url"
            
            local output_file
            output_file="$DOWNLOAD_DIR/$(basename "$m3u8_url" .m3u8).mp4"
            output_file=$(ensure_unique_filename "${output_file%.*}" "mp4" "$DOWNLOAD_DIR")

            # Download using specified method
            case "$DOWNLOAD_METHOD" in
                ffmpeg)
                    ffmpeg -i "$m3u8_url" -c copy "$output_file" && log_action "Successfully downloaded stream with ffmpeg from $m3u8_url to $output_file" || log_action "Failed to download stream with ffmpeg from $m3u8_url"
                    ;;
                streamlink)
                    streamlink "$m3u8_url" best -o "$output_file" && log_action "Successfully downloaded stream with streamlink from $m3u8_url to $output_file" || log_action "Failed to download stream with streamlink from $m3u8_url"
                    ;;
                *)
                    display_message warning "Unknown download method: $DOWNLOAD_METHOD. Skipping $m3u8_url."
                    log_action "Unknown download method: $DOWNLOAD_METHOD. Skipped $m3u8_url"
                    ;;
            esac
        done
    fi
}

# Function to display help message
display_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -u, --url URL           Specify the webpage URL to fetch videos from."
    echo "  -d, --download-dir DIR  Specify the download directory. Default: \$HOME/Downloads"
    echo "  -m, --method METHOD     Specify the download method for .m3u8 streams (ffmpeg or streamlink). Default: streamlink"
    echo "  -h, --help              Display this help message."
    echo ""
    echo "Example:"
    echo "  $0 --url https://example.com/page --download-dir /path/to/downloads --method ffmpeg"
}

# -----------------------------
# Command-Line Argument Parsing
# -----------------------------
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -u|--url)
                url="$2"
                validate_url "$url"
                shift
                ;;
            -d|--download-dir)
                DOWNLOAD_DIR="$2"
                LOG_FILE="$DOWNLOAD_DIR/download_log.txt"
                shift
                ;;
            -m|--method)
                DOWNLOAD_METHOD="$2"
                if [[ "$DOWNLOAD_METHOD" != "ffmpeg" && "$DOWNLOAD_METHOD" != "streamlink" ]]; then
                    display_message warning "Invalid download method: $DOWNLOAD_METHOD. Defaulting to streamlink."
                    DOWNLOAD_METHOD="streamlink"
                fi
                shift
                ;;
            -h|--help)
                display_help
                exit 0
                ;;
            *)
                display_message warning "Unknown parameter passed: $1"
                display_help
                exit 1
                ;;
        esac
        shift
    done
}

# -----------------------------
# Main Script Logic
# -----------------------------

# Trap to ensure cleanup on exit
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/stream_media_info.json 2>/dev/null || true
    # Add any additional cleanup tasks here
}

# Initialize logging
setup_logging

# Check for dependencies
check_dependencies

# Parse command-line arguments
parse_arguments "$@"

# If URL is provided via command-line, execute directly
if [[ -n "${url:-}" ]]; then
    mkdir -p "$DOWNLOAD_DIR"
    fetch_and_download "$url"
    if [ $? -eq 0 ]; then
        echo "Download completed successfully."
        log_action "Download completed successfully"
    else
        echo "Download process encountered issues."
        log_action "Download process encountered issues"
    fi
    exit 0
fi

# Main menu system for interactive use
main_menu() {
    while true; do
        echo "# --- // Vidfinder //"                 
        echo ""
        echo "1. Enter URL"
        echo "2. Change Dl Dir"
        echo "3. Change Dl Method for .m3u8 Streams"
        echo "4. Exit"
        echo ""
        echo -n "Select an option (1-4): "
        read -r choice
        case "$choice" in
            1)
                echo -n "Enter the URL: "
                read -r webpage_url
                validate_url "$webpage_url"
                mkdir -p "$DOWNLOAD_DIR"
                fetch_and_download "$webpage_url"
                if [ $? -eq 0 ]; then
                    echo "Download completed successfully."
                    log_action "Download completed successfully"
                else
                    echo "Download process encountered issues."
                    log_action "Download process encountered issues"
                fi
                ;;
            2)
                echo -n "Enter new download directory: "
                read -r new_dir
                if [ -d "$new_dir" ]; then
                    DOWNLOAD_DIR="$new_dir"
                else
                    mkdir -p "$new_dir" && DOWNLOAD_DIR="$new_dir" && echo "Download directory set to $DOWNLOAD_DIR" && log_action "Download directory changed to $DOWNLOAD_DIR" || {
                        display_message error "Failed to create directory: $new_dir"
                        log_action "Failed to create directory: $new_dir"
                    }
                fi
                LOG_FILE="$DOWNLOAD_DIR/download_log.txt"
                ;;
            3)
                echo "Select download method for .m3u8 streams:"
                echo "1. ffmpeg"
                echo "2. streamlink"
                echo ""
                echo -n "Choose method (1-2): "
                read -r method_choice
                case "$method_choice" in
                    1)
                        DOWNLOAD_METHOD="ffmpeg"
                        echo "Download method set to ffmpeg."
                        log_action "Download method changed to ffmpeg"
                        ;;
                    2)
                        DOWNLOAD_METHOD="streamlink"
                        echo "Download method set to streamlink."
                        log_action "Download method changed to streamlink"
                        ;;
                    *)
                        display_message warning "Invalid choice. Download method remains as $DOWNLOAD_METHOD."
                        ;;
                esac
                ;;
            4)
                display_message info "Exiting Video Finder. Goodbye!"
                exit 0
                ;;
            *)
                display_message warning "Invalid option. Please choose between 1 and 4."
                ;;
        esac
        echo ""
    done
}

# Start the main menu if not executing a scheduled task
main_menu
