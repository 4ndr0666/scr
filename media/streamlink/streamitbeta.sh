#!/bin/bash
# Unified Streamit Script - Merged and Refactored
# Author: Merged from streamit.sh and streamit2.sh

LOG_FILE="$HOME/.local/share/logs/streamit_merged.log"
OUTPUT_DIR="/storage/streamlink"  # Dedicated output directory
MAX_RETRIES=3  # Number of times to retry Streamlink in case of failure
RETRY_DELAY=10 # Time in seconds to wait between retries

# Setup logging for the entire script
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# General logging function
log_message() {
    local log_type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
}

# Function to display messages with colored output
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
    local command="$1"
    eval "$command" 2>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        display_message error "Failed to execute: $command"
        return 1
    else
        display_message success "Successfully executed: $command"
        return 0
    fi
}

# Function to extract media info from a stream URL using ffprobe
extract_media_info() {
    local stream_url="$1"
    display_message info "Extracting media information from stream URL..."

    # Use ffprobe to get media info in JSON format
    local media_data
    media_data=$(ffprobe -v quiet -print_format json -show_streams "$stream_url")

    if [ $? -ne 0 ] || [ -z "$media_data" ]; then
        display_message warning "Failed to extract media info from stream URL."
        return 1
    else
        echo "$media_data" > "/tmp/stream_media_info.json"
        local framerate height codec
        framerate=$(echo "$media_data" | jq -r '.streams[] | select(.codec_type=="video") | .avg_frame_rate' | head -n1)
        height=$(echo "$media_data" | jq -r '.streams[] | select(.codec_type=="video") | .height' | head -n1)
        codec=$(echo "$media_data" | jq -r '.streams[] | select(.codec_type=="video") | .codec_name' | head -n1)

        # Calculate the actual frame rate
        if [[ "$framerate" == *"/"* ]]; then
            framerate=$(awk "BEGIN { print $(echo "$framerate" | tr '/' '/') }")
        fi

        display_message success "Media Info Extracted:"
        display_message info "Frame rate: $framerate fps"
        display_message info "Resolution: ${height}p"
        display_message info "Codec: $codec"
        return 0
    fi
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

# Function to check if file exists and rename if necessary
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

        # Start streamlink in the background and show progress while waiting
        streamlink "$url" "$quality" --output "$final_output_file" > "$final_log_file" 2>&1 &
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

    if [ -z "$url" ] || [ -z "$quality" ] || [ -z "$cron_schedule" ]; then
        display_message error "URL, quality, and schedule time are required."
        exit 1
    fi

    if [ -z "$output_file" ]; then
        output_file="stream_$(date +%Y%m%d%H%M%S)"
    fi

    cron_command="$(which bash) $(realpath "$0") --url '$url' --quality '$quality' --output '$output_file'"

    # Add cron job to schedule the stream
    (crontab -l 2>/dev/null; echo "$cron_schedule $cron_command") | crontab -

    display_message success "Stream scheduled successfully with cron for '$cron_schedule'."
}

# Main menu system
main_menu() {
    while true; do
        echo "# --- // STREAMIT MENU //"
        echo "$(tput setaf 6)1$(tput sgr0). Lena"
        echo "$(tput setaf 6)2$(tput sgr0). Ab"
        echo "$(tput setaf 6)3$(tput sgr0). Custom URL"
        echo "$(tput setaf 6)4$(tput sgr0). Schedule"
        echo "$(tput setaf 6)5$(tput sgr0). Exit"
        echo ""
        echo -n "Select: "
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
                display_message info "Exiting Streamlink Wrapper."
                exit 0
                ;;
            *)
                display_message warning "Invalid option. Please choose between 1 and 5."
                ;;
        esac
    done
}

# Entry point for the script
setup_logging
main_menu
