#!/bin/bash

# Streamlink Wrapper Script with Presets, Customization, and Error Handling

# Function to display the main menu and guide the user
main_menu() {
    echo "========================="
    echo "Streamlink Wrapper Script"
    echo "========================="
    echo "1. Preset: Twitch - LenaStarKilla"
    echo "2. Preset: Twitch - AbStarKilla"
    echo "3. Enter a custom URL"
    echo "4. Exit"
    echo "========================="
    echo -n "Choose an option [1-4]: "
}

# Function to validate URL and stream quality input
validate_input() {
    if [ -z "$1" ]; then
        echo "Error: No URL provided. Please enter a valid URL."
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "Error: No stream quality provided. Please enter a valid stream quality."
        exit 1
    fi
}

# Function to apply advanced options (retries, HLS settings, proxy)
apply_advanced_options() {
    echo "Applying advanced options..."
    
    # Setting defaults for retry attempts and delay between retries
    retry_streams="--retry-streams 5 --retry-max 0"
    
    # Setting default HLS live edge and segment threads for optimal performance
    hls_options="--hls-live-edge 3 --stream-segment-threads 3 --hls-segment-threads 3 --hls-segment-timeout 30"
    
    # Proxy selection menu
    echo "Choose a proxy option:"
    echo "1. Use a proxy from HideMy.name"
    echo "2. Use a proxy from Proxyscrape"
    echo "3. Enter a custom proxy URL"
    echo "4. No proxy"
    read -r proxy_choice

    case $proxy_choice in
        1)
            # Fetching a proxy from HideMy.name
            proxy=$(curl -s "https://hidemy.name/en/proxy-list/?type=h&anon=4&start=0#list" | grep -oP '(\d{1,3}\.){3}\d{1,3}:\d+' | head -n 1)
            if [ -z "$proxy" ]; then
                echo "Error: Failed to fetch proxy from HideMy.name. Skipping proxy setup."
                proxy_option=""
            else
                proxy_option="--http-proxy http://$proxy"
            fi
            ;;
        2)
            # Fetching a proxy from Proxyscrape
            proxy=$(curl -s "https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=10000&country=all&ssl=all&anonymity=elite" | head -n 1)
            if [ -z "$proxy" ]; then
                echo "Error: Failed to fetch proxy from Proxyscrape. Skipping proxy setup."
                proxy_option=""
            else
                proxy_option="--http-proxy http://$proxy"
            fi
            ;;
        3)
            echo -n "Enter your custom proxy URL (e.g., http://myproxy.example:8080): "
            read -r proxy
            if [ -z "$proxy" ]; then
                echo "Error: No proxy URL provided. Skipping proxy setup."
                proxy_option=""
            else
                proxy_option="--http-proxy $proxy"
            fi
            ;;
        4)
            proxy_option=""
            ;;
        *)
            echo "Invalid choice. Skipping proxy setup."
            proxy_option=""
            ;;
    esac

    echo "Retries: $retry_streams, HLS: $hls_options, Proxy: ${proxy_option:-None}"
}

# Function to execute streamlink with the provided inputs and advanced options
run_streamlink() {
    local url="$1"
    local quality="$2"
    local output_file="$3"
    local log_file="streamlink_log.txt"

    # Applying advanced options with best practices
    apply_advanced_options

    # Running the Streamlink command and logging output/errors to a log file
    echo "Executing streamlink command..."
    streamlink "$url" "$quality" --output "$output_file" $retry_streams $hls_options $proxy_option > "$log_file" 2>&1

    # Error handling and success notification
    if [ $? -eq 0 ]; then
        echo "Stream started successfully. Output saved to $output_file."
    else
        echo "Error: Failed to start the stream. Check $log_file for details."
        exit 1
    fi
}

# Function to handle preset URLs
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
            echo "Invalid preset option."
            exit 1
            ;;
    esac

    echo "Starting preset stream: $url ($quality)"
    run_streamlink "$url" "$quality" "$output_file"
}

# Function to handle custom URL input and validation
handle_custom_url() {
    echo -n "Enter the URL: "
    read -r url
    echo -n "Enter stream quality (e.g., best, worst, 720p60): "
    read -r quality
    echo -n "Enter output file name (e.g., video.ts): "
    read -r output_file

    # Validate inputs to ensure proper values
    validate_input "$url" "$quality"

    echo "Starting custom stream: $url ($quality)"
    run_streamlink "$url" "$quality" "$output_file"
}

# Main script execution loop
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
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose between 1 and 4."
            ;;
    esac
done
