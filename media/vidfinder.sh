#!/bin/bash

# Set the default download directory
DOWNLOAD_DIR="$HOME/Downloads"
LOG_FILE="$DOWNLOAD_DIR/download_log.txt"

# Function to log actions
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to fetch and download video files
fetch_and_download() {
    local url="$1"
    echo "Fetching webpage content from $url ..."
    log_action "Fetching webpage content from $url"

    # Use curl to fetch webpage content and grep to find video URLs
    video_urls=$(curl -s "$url" | grep -oP 'https://[^"]*DASH[^"]*\.mp4')
    m3u8_urls=$(curl -s "$url" | grep -oP 'https://[^"]*\.m3u8')

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
            curl -o "$DOWNLOAD_DIR/$(basename "$video_url")" "$video_url" && log_action "Successfully downloaded $video_url" || log_action "Failed to download $video_url"
        done
    fi

    # Handle .m3u8 files
    if [[ -n "$m3u8_urls" ]]; then
        echo "Found the following .m3u8 URLs:"
        echo "$m3u8_urls"

        for m3u8_url in $m3u8_urls; do
            echo "Processing .m3u8 stream from $m3u8_url ..."
            log_action "Processing .m3u8 stream from $m3u8_url"
            
            output_file="$DOWNLOAD_DIR/$(basename "$m3u8_url" .m3u8).mp4"

            # Choose between ffmpeg and streamlink
            read -p "Use ffmpeg (f) or streamlink (s) to download the stream? " choice
            case "$choice" in
                f|F)
                    ffmpeg -i "$m3u8_url" -c copy "$output_file" && log_action "Successfully downloaded stream with ffmpeg from $m3u8_url to $output_file" || log_action "Failed to download stream with ffmpeg from $m3u8_url"
                    ;;
                s|S)
                    streamlink "$m3u8_url" best -o "$output_file" && log_action "Successfully downloaded stream with streamlink from $m3u8_url to $output_file" || log_action "Failed to download stream with streamlink from $m3u8_url"
                    ;;
                *)
                    echo "Invalid choice, skipping this URL."
                    log_action "Invalid choice for stream download method, skipped $m3u8_url"
                    ;;
            esac
        done
    fi
}

# Main script logic
echo "##########################################################"
echo "### Fetching and downloading video files ..."
echo "##########################################################"
echo

# Prompt the user to enter the URL
read -p "Enter the webpage URL: " webpage_url

# Create the download directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Fetch and download videos
fetch_and_download "$webpage_url"

# Provide feedback about the operation
if [ $? -eq 0 ]; then
    echo "Download completed successfully."
    log_action "Download completed successfully"
else
    echo "Download process encountered issues."
    log_action "Download process encountered issues"
fi
