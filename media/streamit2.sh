#!/bin/bash

# Streamlink Wrapper Script with Enhanced MediaInfo, Logging, Notifications, and Error Handling

# Configuration
LOG_FILE="$HOME/.streamlink_wrapper.log"
EMAIL_RECIPIENT="your_email@example.com"  # Replace with your actual email
TERMINAL="alacritty"  # Specify your preferred terminal emulator

# Ensure required commands are available
REQUIRED_COMMANDS=(streamlink mediainfo jq speedtest-cli curl)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed. Please install it to continue."
        exit 1
    fi
done

# Function to log messages to a file
log_message() {
    local log_type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
}

# Function to send email notifications
send_email_notification() {
    local status="$1"
    local subject="Streamlink Wrapper - $status"
    echo "The stream has $status. Check the log for details." | mail -s "$subject" "$EMAIL_RECIPIENT"
}

# Function to display feedback messages with color and icons
display_message() {
    local message_type="$1"
    local message="$2"

    case "$message_type" in
        success)
            echo -e "\e[32m✔️  $message\e[0m"
            log_message "SUCCESS" "$message"
            send_email_notification "started successfully"
            ;;
        error)
            echo -e "\e[31m❌  $message\e[0m"
            log_message "ERROR" "$message"
            send_email_notification "failed"
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

# Function to extract media information using mediainfo
extract_media_info() {
    local file="$1"
    display_message info "Extracting media information from '$file'..."
    local media_data
    media_data=$(mediainfo --Output=JSON "$file" 2>/dev/null)

    if [ -z "$media_data" ] || ! echo "$media_data" | jq empty; then
        display_message warning "Failed to extract media info. Using default settings."
        return 1
    else
        echo "$media_data" > "${file}.mediainfo.json"
        local framerate=$(echo "$media_data" | jq -r '.media.track[] | select(.FrameRate) | .FrameRate')
        local height=$(echo "$media_data" | jq -r '.media.track[] | select(.Height) | .Height')
        local resolution="${height}p"
        local codec=$(echo "$media_data" | jq -r '.media.track[] | select(.CodecID) | .CodecID')

        display_message success "Media Info Extracted:"
        display_message info "Frame rate: $framerate fps"
        display_message info "Resolution: $resolution"
        display_message info "Codec: $codec"
        return 0
    fi
}

# Function to adjust stream settings based on media info
adjust_settings_based_on_media() {
    local file="$1"
    display_message info "Adjusting stream settings based on media info..."

    if extract_media_info "$file"; then
        local resolution=$(jq -r '.Height' "${file}.mediainfo.json")
        if [[ "$resolution" -lt 720 ]]; then
            echo "Low resolution detected: ${resolution}p. Recommend lowering stream quality."
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

# Function to check current network bandwidth
check_bandwidth() {
    display_message info "Checking current network bandwidth..."
    local download_speed
    download_speed=$(speedtest-cli --simple | grep "Download" | awk '{print $2}')

    if [[ -z "$download_speed" ]]; then
        display_message warning "Unable to determine download speed."
        return 1
    fi

    echo "Current download speed: $download_speed Mbps"

    if (( $(echo "$download_speed < 5.0" | bc -l) )); then
        echo "Low bandwidth detected: ${download_speed} Mbps. Adjusting stream quality to 'worst'."
        quality="worst"
    else
        echo "Sufficient bandwidth detected: ${download_speed} Mbps."
    fi
}

# Function to apply advanced options (retries, HLS settings, proxy)
apply_advanced_options() {
    display_message info "Applying advanced options..."
    retry_streams="--retry-streams 5 --retry-max 0"
    hls_options="--hls-live-edge 3 --stream-segment-threads 3 --hls-segment-timeout 30"

    # Proxy selection menu
    echo "Choose a proxy option:"
    echo "1. Use a proxy from HideMy.name"
    echo "2. Use a proxy from Proxyscrape"
    echo "3. Enter a custom proxy URL"
    echo "4. No proxy"
    echo -n "Enter your choice [1-4]: "
    read -r proxy_choice

    case "$proxy_choice" in
        1)
            proxy=$(curl -s "https://hidemy.name/en/proxy-list/?type=h&anon=4&start=0#list" | grep -oP '(\d{1,3}\.){3}\d{1,3}:\d+' | head -n 1)
            if [ -z "$proxy" ]; then
                display_message error "Failed to fetch proxy from HideMy.name. Skipping proxy setup."
                proxy_option=""
            else
                proxy_option="--http-proxy http://$proxy"
                display_message info "Proxy set to http://$proxy"
            fi
            ;;
        2)
            proxy=$(curl -s "https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=10000&country=all&ssl=all&anonymity=elite" | head -n 1)
            if [ -z "$proxy" ]; then
                display_message error "Failed to fetch proxy from Proxyscrape. Skipping proxy setup."
                proxy_option=""
            else
                proxy_option="--http-proxy http://$proxy"
                display_message info "Proxy set to http://$proxy"
            fi
            ;;
        3)
            echo -n "Enter your custom proxy URL (e.g., http://myproxy.example:8080): "
            read -r proxy
            if [ -z "$proxy" ]; then
                display_message warning "No proxy URL provided. Skipping proxy setup."
                proxy_option=""
            else
                proxy_option="--http-proxy $proxy"
                display_message info "Proxy set to $proxy"
            fi
            ;;
        4)
            proxy_option=""
            display_message info "No proxy will be used."
            ;;
        *)
            display_message warning "Invalid choice. Skipping proxy setup."
            proxy_option=""
            ;;
    esac

    echo "Retries: $retry_streams, HLS Options: $hls_options, Proxy: ${proxy_option:-None}"
}

# Function to execute Streamlink with inputs and options
run_streamlink() {
    local url="$1"
    local quality="$2"
    local output_file="$3"
    local final_log_file="$HOME/.local/share/logs/streamlink_${output_file%.ts}.log"

    display_message info "Executing Streamlink command..."
    
    while streamlink "$url" "$quality" --output "$output_file" $retry_streams $hls_options $proxy_option > "$final_log_file" 2>&1 &; do
        echo -ne "\rStreaming in progress..."
        sleep 2
    done

    if [ $? -eq 0 ]; then
        display_message success "Stream started successfully. Output saved to '$output_file'."
        display_message info "Log available at '$final_log_file'."
    else
        display_message error "Failed to start the stream. Check '$final_log_file' for details."
        exit 1
    fi
}

# Function to handle presets
handle_preset() {
    case "$1" in
        1)
            url="https://twitch.tv/lenastarkilla"
            quality="best"
            output_file="LenaStarKilla_$(date +%Y%m%d%H%M%S).ts"
            ;;
        2)
            url="https://twitch.tv/abstarkilla"
            quality="best"
            output_file="AbStarKilla_$(date +%Y%m%d%H%M%S).ts"
            ;;
        *)
            display_message error "Invalid preset option."
            exit 1
            ;;
    esac
    run_streamlink "$url" "$quality" "$output_file"
}

# Function to handle custom URL input and validation
handle_custom_url() {
    echo -n "Enter the Stream URL: "
    read -r url
    echo -n "Enter stream quality (e.g., best, worst, 720p60): "
    read -r quality
    echo -n "Enter output file name (e.g., video.ts): "
    read -r output_file

    # Validate inputs
    if [ -z "$url" ] || [ -z "$quality" ]; then
        display_message error "Invalid input. URL and quality are required."
        exit 1
    fi

    # Default output file if not provided
    if [ -z "$output_file" ]; then
        output_file="stream_$(date +%Y%m%d%H%M%S).ts"
    fi

    run_streamlink "$url" "$quality" "$output_file"
}

# Function to handle command-line arguments for flexibility in usage
handle_preset_with_media_info() {
    case "$1" in
        1)
            url="https://twitch.tv/lenastarkilla"
            quality="best"
            output_file="LenaStarKilla_$(date +%Y%m%d%H%M%S).ts"
            ;;
        2)
            url="https://twitch.tv/abstarkilla"
            quality="best"
            output_file="AbStarKilla_$(date +%Y%m%d%H%M%S).ts"
            ;;
        *)
            display_message error "Invalid preset option."
            exit 1
            ;;
    esac
    adjust_settings_based_on_media "$output_file"
    run_streamlink "$url" "$quality" "$output_file"
}

# Main script execution loop
main_menu() {
    while true; do
        echo "# --- // STREAMIT.SH //"
        echo "1. LenaStarKilla"
        echo "2. AbStarKilla"
        echo "3. Custom URL"
        echo "4. Exit"
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
                display_message info "Exiting Streamlink Wrapper."
                exit 0
                ;;
            *)
                display_message warning "Invalid option. Please choose between 1 and 4."
                ;;
        esac
    done
}

# Execute the main menu
main_menu
