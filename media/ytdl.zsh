#!/usr/bin/env bash
# File: functions.zsh
# -------------------------------------------------------------------
# A cohesive script providing:
#   1) ytdl  -- a simple function to quickly download with preset formats
#   2) ytf   -- a quick function to list formats for a URL using domain-specific cookies
#   3) ytdlc -- advanced download with domain-based cookies, auto selection,
#              auto prompting for cookie updates if a download fails, and
#              manual interactive update with --update
# -------------------------------------------------------------------

# =============================[ Config Maps ]============================ #
declare -A YTDLP_COOKIES_MAP=(
    ["youtube.com"]="$HOME/.config/yt-dlp/youtube_cookies.txt"
    ["youtu.be"]="$HOME/.config/yt-dlp/youtube_cookies.txt"
    ["patreon.com"]="$HOME/.config/yt-dlp/patreon_cookies.txt"
    ["vimeo.com"]="$HOME/.config/yt-dlp/vimeo_cookies.txt"
    ["boosty.to"]="$HOME/.config/yt-dlp/boosty_cookies.txt"
    ["instagram.com"]="$HOME/.config/yt-dlp/instagram_cookies.txt"
    # Add more mappings as needed
)
PREFERRED_FORMATS=("335" "315" "313" "308" "303" "302" "271" "248" "247" "137")

# ===========================[ Basic Utilities ]=========================== #

# Quick URL validator
validate_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]] && return 0 || return 1
}

# Extract domain from a URL (strip 'www.' or 'm.')
get_domain_from_url() {
    local url="$1"
    echo "$url" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//'
}

# Retrieve cookie path from domain
get_cookie_path_for_domain() {
    local domain="$1"
    echo "${YTDLP_COOKIES_MAP[$domain]}"
}

# ======================[ Manual Clipboard Cookie Refresh ]===================== #
# Overwrites domain's cookie file with data from clipboard,
# falling back from wl-paste => xclip => error.
refresh_cookie_file() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        echo "Usage: refresh_cookie_file <domain>"
        return 1
    fi

    local cookie_file="${YTDLP_COOKIES_MAP[$domain]}"
    if [[ -z "$cookie_file" ]]; then
        echo "Error: No cookie file mapped for domain '$domain'."
        return 1
    fi

    # Attempt to find a workable clipboard utility
    local clipboard_cmd=""
    if command -v wl-paste &>/dev/null; then
        clipboard_cmd="wl-paste"
    elif command -v xclip &>/dev/null; then
        clipboard_cmd="xclip -selection clipboard -o"
    else
        echo "Error: No suitable clipboard utility found. Install 'wl-clipboard' or 'xclip'."
        return 1
    fi

    printf "Please copy the correct cookies for '$domain' to your clipboard, then press Enter.\n"
    read -r

    local clipboard_data
    clipboard_data="$($clipboard_cmd 2>/dev/null)"
    if [[ -z "$clipboard_data" ]]; then
        echo "Error: Clipboard empty or unreadable."
        return 1
    fi

    echo "$clipboard_data" > "$cookie_file" || {
        echo "Error: Could not write to '$cookie_file'."
        return 1
    }

    chmod 600 "$cookie_file" 2>/dev/null || {
        echo "Warning: Could not set permissions to 600 on '$cookie_file'."
    }

    echo "Cookie file for '$domain' updated successfully!"
}

# Prompt user to choose a domain from YTDLP_COOKIES_MAP and refresh
prompt_cookie_update() {
    echo "Select the domain to update cookies for:"

    local domains
    if [[ -n "$BASH_VERSION" ]]; then
        # Bash syntax for associative arrays
        domains=( "${!YTDLP_COOKIES_MAP[@]}" )
    elif [[ -n "$ZSH_VERSION" ]]; then
        # Zsh syntax for associative arrays
        domains=( ${(k)YTDLP_COOKIES_MAP} )
    else
        echo "Unsupported shell. Only Bash and Zsh are supported."
        return 1
    fi

    local idx=1
    for d in "${domains[@]}"; do
        echo "  $idx) $d"
        ((idx++))
    done

    printf "Enter the number or domain [1..%d]: " "$((idx-1))"
    read -r choice

    local domain=""
    if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$((idx-1))" ]]; then
        domain="${domains[$((choice-1))]}"
    else
        # Possibly user typed domain directly
        for d in "${domains[@]}"; do
            if [[ "$d" == "$choice" ]]; then
                domain="$d"
                break
            fi
        done
    fi

    if [[ -z "$domain" ]]; then
        echo "Invalid selection: $choice"
        return 1
    fi

    refresh_cookie_file "$domain"
}

# ======================[ Format Selection Logic ]======================== #

select_best_format() {
    local url="$1"
    local cookie_file="$2"

    local formats_json
    formats_json=$(yt-dlp -j --cookies "$cookie_file" "$url" 2>/dev/null)
    [[ -z "$formats_json" ]] && { echo "best"; return; }

    for fmt in "${PREFERRED_FORMATS[@]}"; do
        if echo "$formats_json" | jq -e --arg f "$fmt" '.formats[] | select(.format_id == $f)' &>/dev/null; then
            echo "$fmt"
            return
        fi
    done

    # If none matched, fallback to "best"
    echo "best"
}

get_format_details() {
    local url="$1"
    local cookie_file="$2"
    local format_id="$3"

    if [[ "$format_id" == "best" ]]; then
        echo "N/A"
        return
    fi

    local format_json
    format_json=$(yt-dlp -f "$format_id" -j --cookies "$cookie_file" "$url" 2>/dev/null)
    [[ -z "$format_json" ]] && { echo "N/A"; return; }

    # Extract desired format properties using jq
    echo "$format_json" | jq '{format_id, ext, resolution, fps, tbr, vcodec, acodec, filesize}'
}

# ======================[ Simple ytdl Function ]========================== #
# A quick function to download with preset formats (no domain-specific cookies).
# You can still pass your own --cookies or anything else if you want.
ytdl() {
    yt-dlp --add-metadata \
           --embed-metadata \
           --external-downloader aria2c \
           --external-downloader-args 'aria2c:-c -j3 -x3 -s3 -k1M' \
           -f "315/313/308/303/302/247/244/137+bestaudio/best" \
           --merge-output-format webm \
           --no-playlist \
           --no-mtime \
           "$@"
}

# ======================[ Quick ytf (List Formats) ]===================== #
# A minimal function to list available formats for a URL, using domain-specific cookies if available.
ytf() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ytf <URL>"
        echo "List all available formats for a given URL, using domain-specific cookies if available."
        return 0
    fi

    local url="$1"
    if [[ -z "$url" ]]; then
        echo "Usage: ytf <URL>"
        return 1
    fi

    if ! validate_url "$url"; then
        echo "Error: Invalid URL: $url"
        return 1
    fi

    local domain
    domain="$(get_domain_from_url "$url")"
    local cookie_file
    cookie_file="$(get_cookie_path_for_domain "$domain")"

    if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
        echo "Using cookies from '$cookie_file' to list formats."
        yt-dlp --list-formats --cookies "$cookie_file" "$url"
    else
        echo "No cookies found for domain '$domain'. Listing formats without cookies."
        yt-dlp --list-formats "$url"
    fi
}

# ======================[ Advanced ytdlc (Cookie-based) ]================== #
ytdlc() {
    # Function to display help
    show_ytdlc_help() {
        cat <<EOF
Usage: ytdlc [options] <URL> [<URL> ...]
Advanced downloads with domain-based cookies, auto-format selection, cookie refresh on failure.

Options:
  --list-formats, -l  Only list available formats, do not download
  --output-dir, -o    Specify a custom output directory (default: ~/Downloads)
  --update            Interactively update a cookie file, then exit
  --help, -h          Show this help text

Examples:
  ytdlc --update
  ytdlc --list-formats https://youtu.be/abc123
  ytdlc --output-dir /tmp https://patreon.com/whatever
EOF
    }

    # Display help if no arguments are provided
    if [[ $# -eq 0 ]]; then
        show_ytdlc_help
        return 0
    fi

    # Usage checks
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_ytdlc_help
        return 0
    fi

    local list_formats=0
    local output_dir="$HOME/Downloads"
    local update_mode=0

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
                    echo "Error: --output-dir requires a non-empty argument."
                    show_ytdlc_help
                    return 1
                fi
                ;;
            --update)
                update_mode=1
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_ytdlc_help
                return 1
                ;;
        esac
    done

    # If user only wants to update cookie files, do so and exit
    if (( update_mode )); then
        prompt_cookie_update
        return 0
    fi

    # Ensure the output directory exists
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || {
            echo "Error: Could not create '$output_dir'."
            return 1
        }
    fi

    # No URL => show help
    if [[ $# -eq 0 ]]; then
        show_ytdlc_help
        return 0
    fi

    # Process each URL
    for url in "$@"; do
        echo "----------------------------------------"
        echo "Processing URL: $url"

        if ! validate_url "$url"; then
            echo "Error: Invalid URL: $url"
            continue
        fi

        # Derive domain => cookie file
        local domain
        domain="$(get_domain_from_url "$url")"
        local cookie_file
        cookie_file="$(get_cookie_path_for_domain "$domain")"

        if [[ -z "$cookie_file" ]]; then
            echo "Error: No cookie file mapped for domain '$domain'."
            echo "Use 'ytdlc --update' to add or refresh cookie files."
            continue
        fi
        if [[ ! -f "$cookie_file" ]]; then
            echo "Cookie file not found at '$cookie_file'."
            echo "Use 'ytdlc --update' to create or refresh cookie for '$domain'."
            continue
        fi

        # Adjust permissions
        local perms
        perms="$(stat -c '%a' "$cookie_file" 2>/dev/null || echo '???')"
        if [[ "$perms" != "600" ]]; then
            echo "Adjusting cookie file permissions to 600."
            chmod 600 "$cookie_file" 2>/dev/null || {
                echo "Warning: Could not set permissions on '$cookie_file'."
            }
        else
            echo "Permissions for '$cookie_file' are already set to 600."
        fi

        if (( list_formats )); then
            echo "Listing available formats for '$url':"
            ytf "$url"
            echo "----------------------------------------"
            continue
        fi

        # Auto-pick best format
        local best_fmt
        best_fmt="$(select_best_format "$url" "$cookie_file")"
        echo "Selected format ID: $best_fmt"

        # If format_id is 'best', skip getting format details
        if [[ "$best_fmt" != "best" ]]; then
            local fmt_info
            fmt_info="$(get_format_details "$url" "$cookie_file" "$best_fmt")"
            echo "Format details:"
            echo "$fmt_info"
            echo ""
        else
            echo "Format details: N/A"
            echo ""
        fi

        # Download
        yt-dlp \
            --add-metadata \
            --embed-metadata \
            --external-downloader aria2c \
            --external-downloader-args 'aria2c:-c -j3 -x3 -s3 -k1M' \
            -f "$best_fmt+bestaudio/best" \
            --merge-output-format webm \
            --no-playlist \
            --no-mtime \
            --cookies "$cookie_file" \
            --output "$output_dir/%(title)s.%(ext)s" \
            "$url"

        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo "Download failed for '$url'. Possibly expired or invalid cookies? Attempt update? (y/n)"
            read -rp "Enter choice: " ans
            if [[ "$ans" =~ ^[Yy](es)?$ ]]; then
                refresh_cookie_file "$domain" || {
                    echo "Cookie refresh for domain '$domain' failed. Skipping re-attempt."
                    continue
                }
                echo "Cookies updated. Re-attempting download..."
                yt-dlp \
                    --add-metadata \
                    --embed-metadata \
                    --external-downloader aria2c \
                    --external-downloader-args 'aria2c:-c -j3 -x3 -s3 -k1M' \
                    -f "$best_fmt+bestaudio/best" \
                    --merge-output-format webm \
                    --no-playlist \
                    --no-mtime \
                    --cookies "$cookie_file" \
                    --output "$output_dir/%(title)s.%(ext)s" \
                    "$url" || {
                        echo "Retry also failed. Skipping."
                    }
            else
                echo "Skipping re-attempt."
                echo "Listing available formats for '$url':"
                ytf "$url"
            fi
        else
            echo "Download completed successfully for '$url'."
        fi

        echo "----------------------------------------"
    done
}

# ========================[ Script End ]=================================== #
# USAGE RECAP:
#   ytdl <URL>...
#     => Quick "no-cookies" approach with preset formats
#
#   ytf <URL>
#     => List formats using domain-specific cookies if available
#
#   ytdlc [--list-formats | --output-dir <dir> | --update] <URL>...
#     => Advanced domain-based cookie approach with auto fallback & update
#
# Add this file to your shell configuration (e.g., .zshrc) or source it manually.
