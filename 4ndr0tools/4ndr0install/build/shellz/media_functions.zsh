# Media Functions

# Downscale Video to 1080p using FFmpeg
downscale() {
    local input_file="$1"
    local output_file="${2:-downscaled_1080p.mp4}"
    local quality="${3:-15}"  # Default CRF value for quality, lower is better

    # Validate input file presence
    if [[ -z "$input_file" ]]; then
        echo "Usage: downscale <path/to/media> [output_file_path] [quality]"
        return 1
    fi

    # Validate input file existence
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' does not exist."
        return 1
    fi

    # Validate quality parameter
    if ! [[ "$quality" =~ ^[0-9]+$ ]]; then
        echo "Error: Quality parameter should be an integer."
        return 1
    fi

    # Ensure output file name is unique
    local base_name="${output_file%.*}"
    local extension="${output_file##*.}"
    local counter=1

    while [[ -f "$output_file" ]]; then
        output_file="${base_name}_${counter}.${extension}"
        ((counter++))
    done

    # Start downscale process using FFmpeg
    echo "Starting downscale process to 1080p..."
    ffmpeg -i "$input_file" \
           -vf "scale=1920x1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
           -c:v libx264 -crf "$quality" -preset slower -c:a copy "$output_file"

    # Check if FFmpeg command was successful
    if [[ $? -eq 0 ]]; then
        echo "Downscale complete. Output saved to '$output_file'."
    else
        echo "Error: Downscale process failed."
        return 1
    fi
}

# yt-dlp Download with Predefined Settings
declare -A YTDLP_COOKIES_MAP=(
    ["youtube.com"]="$HOME/.config/yt-dlp/youtube_cookies.txt"    # YouTube
    ["youtu.be"]="$HOME/.config/yt-dlp/youtube_cookies.txt"       # YouTube Short Links
    ["patreon.com"]="$HOME/.config/yt-dlp/patreon_cookies.txt"    # Patreon
    ["vimeo.com"]="$HOME/.config/yt-dlp/vimeo_cookies.txt"        # Vimeo
    # Add more mappings as needed
)

PREFERRED_FORMATS=("313" "308" "303" "302" "247" "244" "136" "137" "bestaudio" "best")

# Validate URL
validate_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Get Cookies File Based on URL
get_cookies_file() {
    local url="$1"
    local domain
    domain=$(echo "$url" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//')

    echo "${YTDLP_COOKIES_MAP[$domain]}"
}

# Select Best Available Format
select_best_format() {
    local url="$1"
    local cookies_file="$2"
    local format_id

    # Fetch JSON output of formats
    local formats_json
    formats_json=$(yt-dlp -j --cookies "$cookies_file" "$url" 2>/dev/null)

    if [[ -z "$formats_json" ]]; then
        echo "best"
        return
    fi

    # Iterate through preferred formats and select the first available one
    for fmt in "${PREFERRED_FORMATS[@]}"; do
        if echo "$formats_json" | jq -e --arg fmt "$fmt" '.formats[] | select(.format_id == $fmt)' > /dev/null; then
            format_id="$fmt"
            echo "$format_id"
            return
        fi
    done

    # If none of the preferred formats are found, fallback to best
    echo "best"
}

# Get Format Details
get_format_details() {
    local url="$1"
    local cookies_file="$2"
    local format_id="$3"

    # Fetch JSON output for the selected format
    local format_json
    format_json=$(yt-dlp -f "$format_id" -j --cookies "$cookies_file" "$url" 2>/dev/null)

    if [[ -z "$format_json" ]]; then
        echo "N/A"
        return
    fi

    # Extract desired format properties using jq
    echo "$format_json" | jq '{format_id, ext, resolution, fps, tbr, vcodec, acodec, filesize}'
}

# yt-dlp Download Function with Predefined Settings
ytdlc () {
    # Check for help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ytdlc [options] <URL> [<URL> ...]"
        echo "Downloads videos using yt-dlp with predefined settings and site-specific cookies."
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message and exit."
        echo "  --list-formats, -l  List available formats for the provided URL(s) without downloading."
        echo "  --output-dir, -o    Specify a custom output directory. Defaults to ~/Downloads."
        echo ""
        echo "Examples:"
        echo "  ytdlc https://www.youtube.com/watch?v=example_video"
        echo "  ytdlc --list-formats https://www.patreon.com/example_creator"
        echo "  ytdlc --output-dir ~/Videos https://www.vimeo.com/example_video"
        return 0
    fi

    # Initialize variables
    local list_formats=0
    local output_dir="$HOME/Downloads"  # Default output directory

    # Parse options
    while [[ "$1" == -* ]]; do
        case "$1" in
            --list-formats|-l)
                list_formats=1
                shift
                ;;
            --output-dir|-o)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    output_dir="$2"
                    shift 2
                else
                    echo "Error: --output-dir requires a non-empty option argument."
                    echo "Usage: ytdlc [options] <URL> [<URL> ...]"
                    return 1
                fi
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: ytdlc [options] <URL> [<URL> ...]"
                return 1
                ;;
        esac
    done

    # Ensure output directory exists
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create output directory '$output_dir'."
            return 1
        fi
    fi

    # Iterate over all provided URLs
    for url in "$@"; do
        echo "----------------------------------------"
        echo "Processing URL: $url"

        # Check if URL is provided
        if [[ -z "$url" ]]; then
            echo "Error: No URL provided."
            echo "Usage: ytdlc [options] <URL> [<URL> ...]"
            continue
        fi

        # Validate URL
        if ! validate_url "$url"; then
            echo "Error: Invalid URL format: $url"
            continue
        fi

        # Retrieve the corresponding cookie file using the helper function
        local cookies_file
        cookies_file=$(get_cookies_file "$url")

        if [[ -z "$cookies_file" ]]; then
            echo "Error: No cookie file configured for the domain in '$url'."
            echo "Please update the YTDLP_COOKIES_MAP associative array with the appropriate cookie file."
            continue
        fi

        # Check if the cookie file exists
        if [[ ! -f "$cookies_file" ]]; then
            echo "Error: Cookie file not found at '$cookies_file'."
            echo "Please ensure the cookie file exists."
            continue
        fi

        # Retrieve the current permissions of the cookie file
        local current_perms
        current_perms=$(stat -c "%a" "$cookies_file" 2>/dev/null)

        if [[ $? -ne 0 ]]; then
            echo "Error: Unable to retrieve permissions for '$cookies_file'."
            continue
        fi

        # Check if permissions are not set to 600
        if [[ "$current_perms" != "600" ]]; then
            echo "Setting permissions of '$cookies_file' to 600 for security."
            chmod 600 "$cookies_file"
            if [[ $? -ne 0 ]]; then
                echo "Error: Failed to set permissions on '$cookies_file'."
                continue
            else
                echo "Permissions set successfully."
            fi
        else
            echo "Permissions for '$cookies_file' are already set to 600."
        fi

        if [[ $list_formats -eq 1 ]]; then
            echo "Listing available formats for '$url':"
            yt-dlp --list-formats --cookies "$cookies_file" "$url"
            echo "----------------------------------------"
            continue
        fi

        # Select the preferred format
        local best_format
        best_format=$(select_best_format "$url" "$cookies_file")

        echo "Selected format ID: $best_format"

        # Fetch and display selected format details
        local format_details
        format_details=$(get_format_details "$url" "$cookies_file" "$best_format")
        echo "Selected format details:"
        echo "$format_details"
        echo ""

        # Execute yt-dlp with the selected format and configurable output directory
        yt-dlp \
            --add-metadata \
            --embed-metadata \
            --external-downloader aria2c \
            --external-downloader-args "-c -j 3 -x 3 -s 3 -k 1M" \
            -f "$best_format+bestaudio/best" \
            --merge-output-format webm \
            --no-playlist \
            --no-mtime \
            --cookies "$cookies_file" \
            --output "$output_dir/%(title)s.%(ext)s" \
            "$url"

        # Check if yt-dlp executed successfully
        if [[ $? -ne 0 ]]; then
            echo "Error: yt-dlp failed to download the video from '$url'."
        else
            echo "Download completed successfully for '$url'."
        fi

        echo "----------------------------------------"
    done
}

# List Available Formats for a URL
ytf() {
    # Check for help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ytf <URL>"
        echo ""
        echo "Description:"
        echo "  Lists all available formats for a given video URL."
        echo ""
        echo "Parameters:"
        echo "  <URL>                    The URL of the video to list formats for."
        echo ""
        echo "Options:"
        echo "  --help                   Display this help message."
        echo ""
        echo "Examples:"
        echo "  ytf \"https://www.youtube.com/watch?v=example_video\""
        return 0
    fi

    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Usage: ytf <URL>"
        return 1
    fi

    # Validate URL
    if ! validate_url "$url"; then
        echo "Error: Invalid URL format: $url"
        return 1
    fi

    # Retrieve the corresponding cookie file using the helper function
    local cookies_file
    cookies_file=$(get_cookies_file "$url")

    if [[ -z "$cookies_file" ]]; then
        echo "Error: No cookie file configured for the domain in '$url'."
        echo "Please update the YTDLP_COOKIES_MAP associative array with the appropriate cookie file."
        return 1
    fi

    # Check if the cookie file exists
    if [[ ! -f "$cookies_file" ]]; then
        echo "Error: Cookie file not found at '$cookies_file'."
        echo "Please ensure the cookie file exists."
        return 1
    fi

    # Retrieve the current permissions of the cookie file
    local current_perms
    current_perms=$(stat -c "%a" "$cookies_file" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to retrieve permissions for '$cookies_file'."
        return 1
    fi

    # Check if permissions are not set to 600
    if [[ "$current_perms" != "600" ]]; then
        echo "Setting permissions of '$cookies_file' to 600 for security."
        chmod 600 "$cookies_file"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to set permissions on '$cookies_file'."
            return 1
        else
            echo "Permissions set successfully."
        fi
    else
        echo "Permissions for '$cookies_file' are already set to 600."
    fi

    # List available formats
    echo "Listing available formats for '$url':"
    yt-dlp --list-formats --cookies "$cookies_file" "$url"
    echo "----------------------------------------"
}
