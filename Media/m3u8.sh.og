#!/bin/bash

# N_m3u8DL-RE Wrapper Script - Production-Ready Version

# Global Defaults and Presets for Common Scenarios
THREAD_COUNT=8
RETRY_COUNT=5
TMP_DIR="/tmp/n_m3u8dl_tmp"
LOG_LEVEL="INFO"
SAVE_DIR="."
AUTO_SELECT="--auto-select"
MERGE_SEGMENTS="--skip-merge False"
DELETE_AFTER_DONE="--del-after-done True"
PROXY_OPTION=""
DEFAULT_PROXY="http://free-proxy.hidemy.name:8080"
USE_FFMPEG_CONCAT_DEMUXER="--use-ffmpeg-concat-demuxer"
LIVE_REAL_TIME_MERGE="--live-real-time-merge"
LIVE_PERFORM_AS_VOD="--live-perform-as-vod"
CHECK_SEGMENTS_COUNT="--check-segments-count True"

# Dictionary for Mapping Options (Example for Future Scalability)
declare -A option_map
option_map=( 
    [preset_1]="https://example.com/stream1.m3u8" 
    [preset_2]="https://example.com/stream2.m3u8"
)

# Function to Display the Help Section
show_help() {
    echo "Usage: n_m3u8dl_wrapper.sh [options]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message and exit"
    echo "  -p, --preset            Choose from preset stream URLs"
    echo "  -c, --custom            Enter a custom URL"
    echo "  -t, --threads           Set the download thread count (default: $THREAD_COUNT)"
    echo "  -r, --retries           Set the download retry count (default: $RETRY_COUNT)"
    echo "  -P, --proxy             Set a custom proxy URL"
    echo "  -d, --save-dir          Set the output directory"
    echo "  -s, --save-name         Set the output filename"
    echo "  --live                  Enable real-time live stream downloading (VOD or real-time)"
    echo "  --merge                 Force merge of segments using ffmpeg concat demuxer"
    echo "  --advanced              Display advanced options"
    echo "  --confirmation          Add confirmation prompts before running"
    echo
    echo "For more information, visit the n-m3u8dl-re repository or documentation."
}

# Function to Handle User Confirmation
confirm_action() {
    read -p "$1 (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "Action canceled."
        exit 1
    fi
}

# Function to Validate URL Input
validate_url() {
    if [[ -z "$1" ]]; then
        echo "Error: No URL provided. Please enter a valid URL."
        exit 1
    fi
}

# Function to Validate Directory Input
validate_directory() {
    if [[ -z "$1" ]]; then
        echo "Error: No output directory provided. Using default directory."
        SAVE_DIR="$PWD"
    fi
}

# Function to Check and Set Proxy Options
apply_proxy_option() {
    echo "Choose a proxy option:"
    echo "1. Use default proxy: $DEFAULT_PROXY"
    echo "2. Enter a custom proxy URL"
    echo "3. Skip proxy"

    read -r proxy_choice
    case $proxy_choice in
        1)
            PROXY_OPTION="--custom-proxy $DEFAULT_PROXY"
            ;;
        2)
            echo -n "Enter your custom proxy URL: "
            read -r custom_proxy
            if [[ -z "$custom_proxy" ]]; then
                echo "Error: No custom proxy provided. Skipping proxy."
                PROXY_OPTION=""
            else
                PROXY_OPTION="--custom-proxy $custom_proxy"
            fi
            ;;
        3)
            PROXY_OPTION=""
            ;;
        *)
            echo "Invalid choice. Skipping proxy."
            PROXY_OPTION=""
            ;;
    esac
}

# Function to Apply Advanced Options
apply_advanced_options() {
    echo "Applying best practices for advanced options..."
    echo "Thread count: $THREAD_COUNT, Retry count: $RETRY_COUNT"
    echo "Temporary directory: $TMP_DIR"
    apply_proxy_option
}

# Function to Run the n-m3u8dl-re Command with Input Validation
run_n_m3u8dl() {
    local url="$1"
    local save_dir="$2"
    local save_name="$3"
    local is_live="$4"
    local merge_option="$5"

    # Validate Inputs
    validate_url "$url"
    validate_directory "$save_dir"

    # Apply Advanced Options
    apply_advanced_options

    # Build the Base n-m3u8dl-re Command
    local log_file="$save_dir/n_m3u8dl_log.txt"
    echo "Executing: n-m3u8dl-re command..."

    # Determine if Live Stream Options are Needed
    if [[ "$is_live" == "y" ]]; then
        live_options="$LIVE_REAL_TIME_MERGE"
    else
        live_options=""
    fi

    # Check if Merging of Segments is Required
    if [[ "$merge_option" == "y" ]]; then
        merge_options="$USE_FFMPEG_CONCAT_DEMUXER"
    else
        merge_options=""
    fi

    # Execute the Command
    n-m3u8dl-re "$url" --save-dir "$save_dir" --save-name "$save_name" \
        --thread-count "$THREAD_COUNT" --download-retry-count "$RETRY_COUNT" \
        $PROXY_OPTION $live_options $merge_options $AUTO_SELECT $MERGE_SEGMENTS $DELETE_AFTER_DONE \
        --write-meta-json --log-level "$LOG_LEVEL" > "$log_file" 2>&1

    # Check for Errors
    if [[ $? -eq 0 ]]; then
        echo "Download completed successfully. Check the directory: $save_dir"
    else
        echo "Error: Download failed. Check the log file for details: $log_file"
        exit 1
    fi
}

# Function to Handle Preset Streams
handle_preset() {
    case "$1" in
        1)
            url=${option_map[preset_1]}
            save_name="Example_Stream_1"
            ;;
        2)
            url=${option_map[preset_2]}
            save_name="Example_Stream_2"
            ;;
        *)
            echo "Invalid preset option."
            exit 1
            ;;
    esac

    # Prompt for Save Directory
    echo -n "Enter output directory (leave empty for current directory): "
    read -r save_dir
    [ -z "$save_dir" ] && save_dir="."

    echo "Is this a live stream (y/n)?"
    read -r is_live

    echo "Do you want to merge segments (y/n)?"
    read -r merge_option

    echo "Starting download for preset stream: $url"
    run_n_m3u8dl "$url" "$save_dir" "$save_name" "$is_live" "$merge_option"
}

# Function to Handle Custom URL Input
handle_custom_url() {
    echo -n "Enter the URL: "
    read -r url

    # Validate URL
    validate_url "$url"

    echo -n "Enter save name (without extension): "
    read -r save_name
    echo -n "Enter output directory (leave empty for current directory): "
    read -r save_dir
    [ -z "$save_dir" ] && save_dir="$PWD"

    echo "Is this a live stream (y/n)?"
    read -r is_live

    echo "Do you want to merge segments (y/n)?"
    read -r merge_option

    echo "Starting custom download: $url"
    run_n_m3u8dl "$url" "$save_dir" "$save_name" "$is_live" "$merge_option"
}

# Function to Display the Main Menu
main_menu() {
    echo "====================================="
    echo " N_m3u8DL-RE Wrapper Script - Main Menu"
    echo "====================================="
    echo "1. Preset: Example Stream 1"
    echo "2. Preset: Example Stream 2"
    echo "3. Enter a custom URL"
    echo "4. Advanced Options"
    echo "5. Exit"
    echo "====================================="
    echo -n "Choose an option [1-5]: "
}

# Function to Handle Advanced Options
advanced_options_menu() {
    echo "Advanced Options:"
    echo "1. Set download thread count (current: $THREAD_COUNT)"
    echo "2. Set retry count (current: $RETRY_COUNT)"
    echo "3. Enable or disable merging of segments"
    echo "4. Return to main menu"

    read -r adv_option
    case "$adv_option" in
        1)
            echo -n "Enter thread count: "
            read -r THREAD_COUNT
            ;;
        2)
            echo -n "Enter retry count: "
            read -r RETRY_COUNT
            ;;
        3)
            echo "Do you want to merge segments? (y/n): "
            read -r merge_choice
            if [[ "$merge_choice" == "y" ]]; then
                MERGE_SEGMENTS="--skip-merge False"
            else
                MERGE_SEGMENTS="--skip-merge True"
            fi
            ;;
        4)
            return
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# Main function
main() {
    while true; do
        main_menu
        read -r choice
        case "$choice" in
            1|2)
                handle_preset "$choice"
                ;;
            3)
                handle_custom_url
                ;;
            4)
                advanced_options_menu
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option. Please choose between 1 and 5."
                ;;
        esac
    done
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Call the main function
main
