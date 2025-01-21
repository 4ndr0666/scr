#!/bin/sh

# === Configurations ===
# Map domains to cookie files
YTDLP_COOKIES_MAP="youtube.com=$HOME/.config/yt-dlp/youtube_cookies.txt
youtu.be=$HOME/.config/yt-dlp/youtube_cookies.txt
patreon.com=$HOME/.config/yt-dlp/patreon_cookies.txt
vimeo.com=$HOME/.config/yt-dlp/vimeo_cookies.txt
boosty.to=$HOME/.config/yt-dlp/boosty_cookies.txt"

# Preferred formats
PREFERRED_FORMATS="335 315 313 308 303 302 271 248 247 137"

# === Helper Functions ===

# Validate a URL
validate_url() {
    case "$1" in
        http://*|https://*) return 0 ;;
        *) return 1 ;;
    esac
}

# Extract domain from URL
get_domain_from_url() {
    echo "$1" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//'
}

# Get the cookie file for a domain
get_cookie_path_for_domain() {
    echo "$YTDLP_COOKIES_MAP" | grep -E "^$1=" | cut -d= -f2
}

# Select the best format
select_best_format() {
    url="$1"
    cookie_file="$2"

    # Fetch formats JSON
    formats_json=$(yt-dlp -j --cookies "$cookie_file" "$url" 2>/dev/null)
    if [ -z "$formats_json" ]; then
        echo "best"
        return
    fi

    # Find the first matching format
    for fmt in $PREFERRED_FORMATS; do
        echo "$formats_json" | grep -q "\"format_id\": \"$fmt\"" && {
            echo "$fmt"
            return
        }
    done

    echo "best" # Default fallback
}

# Download a URL
download_url() {
    url="$1"
    domain=$(get_domain_from_url "$url")
    cookie_file=$(get_cookie_path_for_domain "$domain")

    if [ -z "$cookie_file" ]; then
        echo "No cookie file mapped for domain '$domain'. Using no cookies."
    elif [ ! -f "$cookie_file" ]; then
        echo "Cookie file '$cookie_file' not found. Using no cookies."
        cookie_file=""
    fi

    # Select the best format
    best_fmt=$(select_best_format "$url" "$cookie_file")
    echo "Using format: $best_fmt"

    # Run yt-dlp with the selected format
    yt-dlp \
        --add-metadata \
        --embed-metadata \
        --external-downloader aria2c \
        --external-downloader-args "--continue=true -j3 -x3 -s3 -k1M" \
        -f "${best_fmt}+bestaudio/best" \
        --cookies "$cookie_file" \
        "$url"
}

# === Main Script Logic ===

# Ensure URL is passed as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <URL>"
    exit 1
fi

# Iterate over all provided URLs
for url in "$@"; do
    if validate_url "$url"; then
        echo "Processing URL: $url"
        download_url "$url"
    else
        echo "Invalid URL: $url"
    fi
done
