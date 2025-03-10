#!/usr/bin/env bash
# Author: 4ndr0666
#
# ==================== YTDL Protocol Installation Script (Final) ====================
# This script sets up or refreshes the YTDL custom protocol handler on Arch Linux.
# It performs the following steps:
#  1. Checks for required packages (yt-dlp, aria2, xclip/wl-clipboard, jq) and installs them.
#  2. Creates necessary directories: /usr/local/bin, ~/.config/zsh, etc.
#  3. Deploys the YTDL functions file to ~/.config/zsh/ytdl.zsh.
#  4. Ensures your shell config (~/.zshrc or ~/.bashrc) sources the functions file.
#  5. Installs the ytdl:// handler script to /usr/local/bin/ytdl-handler.sh.
#  6. Creates a ytdl.desktop file to register the x-scheme-handler.
#  7. Uses xdg-mime to register the protocol.
#  8. (Optional) Applies `chattr +i` to the functions file and handler for security.
#
set -euo pipefail

# --- Privilege Check (don't run as root) ---
if [[ $EUID -eq 0 ]]; then
    echo "Please run this script as a *normal user*, not root."
    echo "Press Ctrl+C to abort, or Enter to continue as root (not recommended)."
    read -r
fi

# --- Dependency Check ---
echo "Checking for required tools..."
declare -a PKGS_TO_INSTALL=()
if ! command -v yt-dlp &>/dev/null; then
    PKGS_TO_INSTALL+=( "yt-dlp" )
fi
if ! command -v aria2c &>/dev/null; then
    PKGS_TO_INSTALL+=( "aria2" )
fi
if ! command -v xclip &>/dev/null && ! command -v wl-paste &>/dev/null; then
    # Install both X11 and Wayland clipboard utilities if neither is present
    PKGS_TO_INSTALL+=( "xclip" "wl-clipboard" )
fi
if ! command -v jq &>/dev/null; then
    PKGS_TO_INSTALL+=( "jq" )
fi

if (( ${#PKGS_TO_INSTALL[@]} > 0 )); then
    echo "The following packages will be installed: ${PKGS_TO_INSTALL[*]}"
    echo -n "Proceed with installation? [Y/n]: "
    read -r ans
    ans=${ans:-Y}
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo pacman -S --needed --noconfirm "${PKGS_TO_INSTALL[@]}"
    else
        echo "Skipped installing some dependencies. Ensure you have all required packages before continuing."
    fi
else
    echo "All required packages are already installed."
fi
echo

# --- Prepare Directories ---
BIN_DIR="/usr/local/bin"
APP_DIR="$HOME/.local/share/applications"
CONFIG_DIR="$HOME/.config"
ZSH_DIR="$CONFIG_DIR/zsh"
echo "Creating necessary directories (if not already present)..."
sudo mkdir -p "$BIN_DIR"
mkdir -p "$APP_DIR" "$CONFIG_DIR" "$ZSH_DIR"
echo " - $BIN_DIR"
echo " - $APP_DIR"
echo " - $ZSH_DIR"
echo

# --- Deploy YTDL Functions File ---
YTDL_FILE="$ZSH_DIR/ytdl.zsh"
# If an old file exists and is immutable, remove immutability so we can overwrite
if [[ -f "$YTDL_FILE" ]]; then
    sudo chattr -i "$YTDL_FILE" 2>/dev/null || true
fi
# Write the updated ytdl.zsh functions file
cat > "$YTDL_FILE" << 'EOF'
#!/usr/bin/env bash
# Author: 4ndr0666
#
# ================ YTDL.ZSH Functions ================
# 1. ytdl  -- quick download (no cookies) with preset formats
# 2. ytf   -- list formats for a URL (uses site-specific cookies if available)
# 3. ytdlc -- advanced download: uses domain-based cookies, auto-selects best format,
#            prompts for cookie updates on failure, and supports extra yt-dlp options.
# ---------------------------------------------------

declare -A YTDLP_COOKIES_MAP=(
    ["youtube.com"]="$HOME/.config/yt-dlp/youtube_cookies.txt"
    ["youtu.be"]="$HOME/.config/yt-dlp/youtube_cookies.txt"
    ["patreon.com"]="$HOME/.config/yt-dlp/patreon_cookies.txt"
    ["vimeo.com"]="$HOME/.config/yt-dlp/vimeo_cookies.txt"
    ["boosty.to"]="$HOME/.config/yt-dlp/boosty_cookies.txt"
    ["instagram.com"]="$HOME/.config/yt-dlp/instagram_cookies.txt"
)

PREFERRED_FORMATS=("335" "315" "313" "308" "303" "299" "302" "271" "248" "137")

validate_url() {
    local url
    url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

get_domain_from_url() {
    local url
    url="$1"
    echo "$url" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//'
}

get_cookie_path_for_domain() {
    local domain
    domain="$1"
    echo "${YTDLP_COOKIES_MAP[$domain]}"
}

refresh_cookie_file() {
    local domain
    domain="$1"
    if [[ -z "$domain" ]]; then
        echo "Usage: refresh_cookie_file <domain>"
        return 1
    fi
    local cookie_file
    cookie_file="$(get_cookie_path_for_domain "$domain")"
    if [[ -z "$cookie_file" ]]; then
        echo "Error: No cookie file mapped for domain '$domain'."
        return 1
    fi
    local clipboard_cmd
    clipboard_cmd=""
    if command -v wl-paste &>/dev/null; then
        clipboard_cmd="wl-paste"
    elif command -v xclip &>/dev/null; then
        clipboard_cmd="xclip -selection clipboard -o"
    else
        echo "Error: No suitable clipboard utility found. Install 'wl-clipboard' or 'xclip'."
        return 1
    fi
    printf "Please copy the cookies for '%s' to your clipboard, then press Enter.\n" "$domain"
    read -r
    local clipboard_data
    clipboard_data="$($clipboard_cmd 2>/dev/null)"
    if [[ -z "$clipboard_data" ]]; then
        echo "Error: Clipboard is empty or unreadable."
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

prompt_cookie_update() {
    echo "Select the domain to update cookies for:"
    local domains
    if [[ -n "$BASH_VERSION" ]]; then
        domains=( "${!YTDLP_COOKIES_MAP[@]}" )
    elif [[ -n "$ZSH_VERSION" ]]; then
        domains=( ${(k)YTDLP_COOKIES_MAP} )
    else
        echo "Unsupported shell. Only Bash and Zsh are supported."
        return 1
    fi
    local idx
    idx=1
    local d
    for d in "${domains[@]}"; do
        echo "  $idx) $d"
        idx=$(( idx + 1 ))
    done
    printf "Enter the number or domain name [1-%d]: " $(( idx - 1 ))
    read -r choice
    local domain
    domain=""
    if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $(( idx - 1 )) ]]; then
        if [[ -n "$BASH_VERSION" ]]; then
            domain="${domains[$(( choice - 1 ))]}"
        elif [[ -n "$ZSH_VERSION" ]]; then
            domain="${domains[$choice]}"
        fi
    else
        local item
        for item in "${domains[@]}"; do
            if [[ "$item" == "$choice" ]]; then
                domain="$item"
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

select_best_format() {
    local url
    url="$1"
    local cookie_file
    cookie_file="$2"
    local formats_json
    formats_json=$(yt-dlp -j --cookies "$cookie_file" "$url" 2>/dev/null)
    if [[ -z "$formats_json" ]]; then
        echo "best"
        return
    fi
    local fmt
    for fmt in "${PREFERRED_FORMATS[@]}"; do
        if echo "$formats_json" | jq -e --arg f "$fmt" '.formats[] | select(.format_id == $f)' &>/dev/null; then
            echo "$fmt"
            return
        fi
    done
    echo "best"
}

get_format_details() {
    local url
    url="$1"
    local cookie_file
    cookie_file="$2"
    local format_id
    format_id="$3"
    if [[ "$format_id" == "best" ]]; then
        echo "N/A"
        return
    fi
    local format_json
    format_json=$(yt-dlp -f "$format_id" -j --cookies "$cookie_file" "$url" 2>/dev/null)
    if [[ -z "$format_json" ]]; then
        echo "N/A"
        return
    fi
    echo "$format_json" | jq '{format_id, ext, resolution, fps, tbr, vcodec, acodec, filesize}'
}

ytdl() {
    yt-dlp --add-metadata \
           --embed-metadata \
           --external-downloader aria2c \
           --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
           -f "335/315/313/308/303/299/271/248/137+bestaudio/best" \
           --no-playlist \
           --no-mtime \
           "$@"
}

ytf() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ytf <URL>"
        echo "List all available formats for a given URL, using domain-specific cookies if available."
        return 0
    fi
    local url
    url="$1"
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

show_ytdlc_help() {
    cat <<'EOF'
Usage: ytdlc [options] <URL> [<URL> ...] [-- yt-dlp options]
Advanced downloads with domain-based cookies and best-format selection.

Options:
  --list-formats, -l    List available formats for each URL (no download).
  --output-dir, -o DIR  Save downloads to the specified directory (default: ~/Downloads).
  --update              Interactively update a cookie file and exit.
  --help, -h            Show this help message.

Examples:
  ytdl https://youtube.com/watch?v=XXXX       (quick download without cookies)
  ytdlc --update                               (refresh a cookie file via clipboard)
  ytf https://youtu.be/ABC123                  (list formats for a YouTube video)
  ytdlc https://patreon.com/page -- -f 303     (download with an extra yt-dlp flag)
EOF
}

ytdlc() {
    if [[ $# -eq 0 ]]; then
        show_ytdlc_help
        return 0
    fi
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_ytdlc_help
        return 0
    fi

    local list_formats
    list_formats=0
    local output_dir
    output_dir="$HOME/Downloads"
    local update_mode
    update_mode=0
    local ytdlp_extra_args
    ytdlp_extra_args=()

    while [[ "$1" == -* && "$1" != "--" ]]; do
        case "$1" in
            --list-formats|-l)
                list_formats=1
                shift
                ;;
            --output-dir|-o)
                if [[ -n "$2" && "$2" != -* ]]; then
                    output_dir="$2"
                    shift 2
                else
                    echo "Error: --output-dir requires a directory argument."
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

    if [[ "$1" == "--" ]]; then
        shift
        ytdlp_extra_args=( "$@" )
        set --
    fi

    if (( update_mode )); then
        prompt_cookie_update
        return 0
    fi

    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || { echo "Error: Could not create '$output_dir'."; return 1; }
    fi

    if [[ $# -eq 0 ]]; then
        show_ytdlc_help
        return 0
    fi

    local url
    for url in "$@"; do
        if [[ "$url" == "--" ]]; then
            break
        fi
        echo "----------------------------------------"
        echo "Processing URL: $url"
        if ! validate_url "$url"; then
            echo "Error: Invalid URL: $url"
            continue
        fi
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
            echo "Use 'ytdlc --update' to create or refresh cookies for '$domain'."
            continue
        fi
        local perms
        perms="$(stat -c '%a' "$cookie_file" 2>/dev/null || echo '???')"
        if [[ "$perms" != "600" ]]; then
            echo "Adjusting cookie file permissions to 600."
            chmod 600 "$cookie_file" 2>/dev/null || {
                echo "Warning: Could not set permissions on '$cookie_file'."
            }
        else
            echo "Permissions for '$cookie_file' are already 600."
        fi

        if (( list_formats )); then
            echo "Listing available formats for '$url':"
            ytf "$url"
            echo "----------------------------------------"
            continue
        fi

        local best_fmt
        best_fmt="$(select_best_format "$url" "$cookie_file")"
        echo "Selected format ID: $best_fmt"
        if [[ "$best_fmt" != "best" ]]; then
            local fmt_info
            fmt_info="$(get_format_details "$url" "$cookie_file" "$best_fmt")"
            echo "Format details: $fmt_info"
        else
            echo "Format details: N/A"
        fi
        echo ""

        yt-dlp \
            --add-metadata \
            --embed-metadata \
            --external-downloader aria2c \
            --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
            -f "${best_fmt}+bestaudio/best" \
            --no-playlist \
            --no-mtime \
            --cookies "$cookie_file" \
            --output "$output_dir/%(title)s.%(ext)s" \
            "${ytdlp_extra_args[@]}" \
            "$url"
        local exit_code
        exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo "Download failed for '$url'. Possibly expired cookies? Attempt update? [y/N]"
            read -r ans
            if [[ "$ans" =~ ^[Yy](es)?$ ]]; then
                if ! refresh_cookie_file "$domain"; then
                    echo "Cookie refresh for '$domain' failed. Skipping re-attempt."
                    continue
                fi
                echo "Cookies updated. Retrying download..."
                yt-dlp \
                    --add-metadata \
                    --embed-metadata \
                    --external-downloader aria2c \
                    --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
                    -f "${best_fmt}+bestaudio/best" \
                    --no-playlist \
                    --no-mtime \
                    --cookies "$cookie_file" \
                    --output "$output_dir/%(title)s.%(ext)s" \
                    "${ytdlp_extra_args[@]}" \
                    "$url" || {
                        echo "Retry also failed. Skipping this URL."
                    }
            else
                echo "Skipping re-attempt for '$url'."
                echo "Listing available formats for '$url':"
                ytf "$url"
            fi
        else
            echo "Download completed successfully for '$url'."
        fi
        echo "----------------------------------------"
    done

    if [[ "$#" -gt 0 ]]; then
        for arg in "$@"; do
            [[ "$arg" == "--" ]] && { shift; break; }
        done
    fi
    if [[ "$#" -gt 0 ]]; then
        ytdlp_extra_args+=( "$@" )
    fi
}
EOF

chmod 644 "$YTDL_FILE" 2>/dev/null || true
echo "Installed functions file: $YTDL_FILE"

SHELL_RC="$HOME/.zshrc"
if [[ -n "$BASH_VERSION" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi
SNIPPET='#### YTDL protocol functions
if [ -f "$HOME/.config/zsh/ytdl.zsh" ]; then
    source "$HOME/.config/zsh/ytdl.zsh"
fi'
if ! grep -q 'source $HOME/.config/zsh/ytdl.zsh' "$SHELL_RC" 2>/dev/null; then
    echo "Appending source snippet to $SHELL_RC"
    echo "$SNIPPET" >> "$SHELL_RC"
    echo "[$SHELL_RC] will now source ytdl.zsh on startup."
else
    echo "Startup file already sources ytdl.zsh (no changes made)."
fi

echo
echo -n "Register the 'ytdl://' URL protocol handler? [Y/n]: "
read -r ans
ans=${ans:-Y}
if [[ "$ans" =~ ^[Yy]$ ]]; then
    YTDL_HANDLER="$BIN_DIR/ytdl-handler.sh"
    if [[ -f "$YTDL_HANDLER" ]]; then
        sudo chattr -i "$YTDL_HANDLER" 2>/dev/null || true
    fi
    sudo tee "$YTDL_HANDLER" >/dev/null << 'HND_EOF'
#!/bin/sh
# Author: 4ndr0666
# Simple handler for ytdl:// links – calls ytdlc in a new Zsh shell.
if [ -z "$1" ] || [ "$1" = "%u" ]; then
    echo "Error: No URL provided to ytdl-handler."
    exit 1
fi
feed=$(echo "$1" | sed 's|^ytdl://||')
if command -v python3 >/dev/null 2>&1; then
    feed="$(python3 -c "import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read().strip()))" <<< "$feed")"
fi
setsid -f zsh -ic "ytdlc '$feed'; read -s -p 'Press Enter to close...' "
HND_EOF
    sudo chmod +x "$YTDL_HANDLER"
    echo "Installed handler script: $YTDL_HANDLER"

    DESKTOP_FILE="$APP_DIR/ytdl.desktop"
    cat > "$DESKTOP_FILE" << DESK_EOF
[Desktop Entry]
Name=YTDL Protocol Handler
Exec=$YTDL_HANDLER %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
DESK_EOF
    echo "Installed desktop entry: $DESKTOP_FILE"

    xdg-mime default ytdl.desktop x-scheme-handler/ytdl
    echo "Registered 'ytdl://' as a custom URL protocol."
fi

echo "====================================================="
echo "✅ YTDL protocol handler installation is complete."
echo
echo "Files deployed:"
echo " - $YTDL_FILE (functions file)"
echo " - $SHELL_RC (updated to source the functions)"
if [[ "$ans" =~ ^[Yy]$ ]]; then
    echo " - $YTDL_HANDLER (URL handler script)"
    echo " - $DESKTOP_FILE (desktop entry for x-scheme-handler)"
fi
echo
echo "Browser Bookmarklets (for convenience):"
echo " YTDL:  javascript:(function(){ const url=encodeURIComponent(window.location.href); window.location='ytdl://'+url; })();"
echo " YTDLC: javascript:(function(){ const url=window.location.href; if(!url.startsWith('http')){alert('Invalid URL');return;} window.location='ytdl://'+encodeURIComponent(url); })();"
echo
echo "👉 To use the new commands, open a **new terminal** or run 'source $SHELL_RC'."
echo "👉 You can click a 'ytdl://' link (or use the bookmarklet) to trigger the handler."
echo
echo "Done! Enjoy your YTDL protocol handler."

sudo chattr +i "$YTDL_FILE" 2>/dev/null || true
if [[ -n "${YTDL_HANDLER:-}" ]]; then
    sudo chattr +i "$YTDL_HANDLER" 2>/dev/null || true
fi
