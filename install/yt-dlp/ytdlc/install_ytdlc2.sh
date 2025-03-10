#!/usr/bin/env bash
#
# install-ytdl.sh
# -------------------------------------------------------------
# A comprehensive, idempotent installer for your "ytdl" project:
#  - Installs dependencies (aria2c, xclip/wl-clipboard).
#  - Deploys "functions.zsh" with ytdl, ytf, and ytdlc into ~/.config
#  - Optionally sets up an x-scheme-handler for "ytdl://"
#  - Ensures your shell automatically sources the new functions on login
# -------------------------------------------------------------

########################################
# 0. Basic Setup and Confirmation
########################################
set -euo pipefail

# This script is designed for Arch Linux, but might also work on other distros.
# Use at your own risk. Adjust package names / install commands if needed.

echo "============================="
echo "  YTDL Setup & Install Script"
echo "============================="
echo
echo "This will install/refresh your local ytdl environment."

if [[ $EUID -eq 0 ]]; then
  echo "Warning: It's recommended to run this script as a normal user, not root."
  echo "Press Ctrl+C to abort or Enter to continue."
  read -r
fi

########################################
# 1. Install Dependencies (If Needed)
########################################
# We'll do a quick check for aria2, xclip, wl-paste, and if missing, prompt for pacman install.

declare -a PKGS_TO_INSTALL=()

if ! command -v aria2c &>/dev/null; then
  PKGS_TO_INSTALL+=( "aria2" )
fi

# For the clipboard functionality in refresh_cookie_file
if ! command -v xclip &>/dev/null && ! command -v wl-paste &>/dev/null; then
  # We'll install both; user can choose in the environment
  PKGS_TO_INSTALL+=( "xclip" "wl-clipboard" )
fi

if ((${#PKGS_TO_INSTALL[@]} > 0)); then
  echo "The following packages are required and will be installed via pacman: ${PKGS_TO_INSTALL[*]}"
  echo "Proceed? [Y/n]"
  read -r ans
  ans=${ans:-Y}
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm "${PKGS_TO_INSTALL[@]}"
  else
    echo "Skipping package installation. You may install them manually."
  fi
else
  echo "All required packages (aria2c, xclip/wl-paste) appear to be installed."
fi
echo

########################################
# 2. Create Directories
########################################

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"

echo "Creating or validating directories:"
mkdir -p "$BIN_DIR"
echo "  - $BIN_DIR"
mkdir -p "$CONFIG_DIR"
echo "  - $CONFIG_DIR"

# We'll store the script in $CONFIG_DIR/ytdl/functions.zsh for neatness
YTDL_DIR="$CONFIG_DIR/ytdl"
mkdir -p "$YTDL_DIR"
echo "  - $YTDL_DIR"
echo

########################################
# 3. Deploy the 'functions.zsh'
########################################
# We'll unify the final code you provided, with the solution that handles
# cookie updates, domain-based indexing (Bash vs Zsh), etc.

cat > "$YTDL_DIR/functions.zsh" << 'EOF'
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

# Formats updated to your final version:
PREFERRED_FORMATS=("335" "315" "313" "308" "303" "299" "271" "248" "137")

# ===========================[ Basic Utilities ]=========================== #

validate_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]] && return 0 || return 1
}

get_domain_from_url() {
    local url="$1"
    echo "$url" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//'
}

get_cookie_path_for_domain() {
    local domain="$1"
    echo "${YTDLP_COOKIES_MAP[$domain]}"
}

# ======================[ Manual Clipboard Cookie Refresh ]===================== #

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

prompt_cookie_update() {
    echo "Select the domain to update cookies for:"

    local domains
    if [[ -n "$BASH_VERSION" ]]; then
        domains=( "${!YTDLP_COOKIES_MAP[@]}" )  # Bash: 0-based
    elif [[ -n "$ZSH_VERSION" ]]; then
        domains=( ${(k)YTDLP_COOKIES_MAP} )     # Zsh: 1-based
    else
        echo "Unsupported shell. Only Bash or Zsh are recognized."
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
        if [[ -n "$BASH_VERSION" ]]; then
            domain="${domains[$((choice-1))]}"  # 0-based
        elif [[ -n "$ZSH_VERSION" ]]; then
            domain="${domains[$choice]}"        # 1-based
        fi
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

    echo "$format_json" | jq '{format_id, ext, resolution, fps, tbr, vcodec, acodec, filesize}'
}

# ======================[ ytdl ]========================== #
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

# ======================[ ytf ]===================== #
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

# ======================[ ytdlc ]================== #
ytdlc() {
    show_ytdlc_help() {
        cat <<EOF
Usage: ytdlc [options] <URL> [<URL> ...] [-- yt-dlp options]
Advanced downloads with domain-based cookies, auto-format selection, cookie refresh on failure.

Options:
  --list-formats, -l    Only list available formats, do not download
  --output-dir, -o      Specify a custom output directory (default: ~/Downloads)
  --update              Interactively update a cookie file, then exit
  --help, -h            Show this help text

Examples:
  ytdlc --update
  ytdlc --list-formats https://youtu.be/abc123
  ytdlc --output-dir /tmp https://patreon.com/whatever
  ytdlc https://patreon.com/whatever -- -f 6142
            >>EOF
    }

    if [[ $# -eq 0 ]]; then
        show_ytdlc_help
        return 0
    fi

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_ytdlc_help
        return 0
    fi

    local list_formats=0
    local output_dir="$HOME/Downloads"
    local update_mode=0
    local ytdlp_extra_args=()

    while [[ "$1" == -* && "$1" != "--" ]]; do
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

    if [[ "$1" == "--" ]]; then
        shift
        ytdlp_extra_args=( "$@" )
    fi

    if (( update_mode )); then
        prompt_cookie_update
        return 0
    fi

    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || {
            echo "Error: Could not create '$output_dir'."
            return 1
        }
    fi

    if [[ $# -eq 0 ]]; then
        show_ytdlc_help
        return 0
    fi

    for url in "$@"; do
        if [[ "$url" == "--" ]]; then
            shift
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
            echo "Use 'ytdlc --update' to create or refresh cookie for '$domain'."
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
            echo "Permissions for '$cookie_file' are already set to 600."
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
            echo "Format details:"
            echo "$fmt_info"
            echo ""
        else
            echo "Format details: N/A"
            echo ""
        fi

        yt-dlp \
            --add-metadata \
            --embed-metadata \
            --external-downloader aria2c \
            --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
            -f "335/315/313/308/303/299/271/248/137+bestaudio/best" \
            --no-playlist \
            --no-mtime \
            --cookies "$cookie_file" \
            --output "$output_dir/%(title)s.%(ext)s" \
            "${ytdlp_extra_args[@]}" \
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
                    --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
                    -f "335/315/313/308/299/271/248/137+bestaudio/best" \
                    --no-playlist \
                    --no-mtime \
                    --cookies "$cookie_file" \
                    --output "$output_dir/%(title)s.%(ext)s" \
                    "${ytdlp_extra_args[@]}" \
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

    if [[ "$#" -gt 0 ]]; then
        for arg in "$@"; do
            if [[ "$arg" == "--" ]]; then
                shift
                break
            fi
        done
    fi

    if [[ "$#" -gt 0 ]]; then
        ytdlp_extra_args+=( "$@" )
    fi
}
EOF

chmod +x "$YTDL_DIR/functions.zsh"
echo "Installed: $YTDL_DIR/functions.zsh"
echo

########################################
# 4. Source the 'functions.zsh' in .zshrc or .bashrc
########################################
# We'll add a small snippet to ensure the user’s shell picks it up.

SHELL_RC="$HOME/.zshrc"
if [[ -n "$BASH_VERSION" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

SNIPPET='
# Load ytdl, ytf, ytdlc functions
if [ -f "$HOME/.config/ytdl/functions.zsh" ]; then
  source "$HOME/.config/ytdl/functions.zsh"
fi
'

if ! grep -q "source \"\$HOME/.config/ytdl/functions.zsh\"" "$SHELL_RC" 2>/dev/null; then
  echo "Appending snippet to $SHELL_RC..."
  echo "$SNIPPET" >> "$SHELL_RC"
  echo "Added snippet to $SHELL_RC"
else
  echo "Snippet to source $YTDL_DIR/functions.zsh already present in $SHELL_RC."
fi
echo

########################################
# 5. (Optional) Register ytdl:// Protocol Handler
########################################
# We can provide the user with an option to install a "ytdl-handler.sh" script
# and a desktop entry to handle ytdl:// links from browsers.

echo "Would you like to register a ytdl:// protocol handler (y/n)?"
read -r ans
ans=${ans:-N}
if [[ "$ans" =~ ^[Yy]$ ]]; then
  # We'll do the same approach as your example: put a ytdl-handler.sh in $BIN_DIR and a .desktop in ~/.local/share/applications
  BIN_HANDLER="$BIN_DIR/ytdl-handler.sh"
  DESKTOP_FILE="$HOME/.local/share/applications/ytdl.desktop"

  cat > "$BIN_HANDLER" << 'SCRIPT_EOF'
#!/usr/bin/env bash

# ytdl-handler.sh
# A simple script to handle ytdl:// URIs

LOGFILE="$HOME/ytdl-handler.log"
echo "ytdl-handler.sh called at $(date)" >> "$LOGFILE"
echo "Arg1: $1" >> "$LOGFILE"

if [ -z "$1" ] || [ "$1" = "%u" ]; then
    echo "No valid URL provided. Exiting." >> "$LOGFILE"
    exit 1
fi

# Remove the 'ytdl://' prefix and decode
feed=$(echo "$1" | sed 's|^ytdl://||')

# Attempt to decode URL-encoded strings
if command -v python3 &>/dev/null; then
  feed_decoded=$(python3 -c "import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read().strip()))" <<<"$feed")
else
  feed_decoded="$feed"
fi

# default to feed_decoded if python3 is absent
final_feed="${feed_decoded:-$feed}"

echo "Final feed processed: $final_feed" >> "$LOGFILE"

# For demonstration, let's queue it with ytdlc
# or open a menu for the user to choose
setsid -f zsh -ic "ytdlc '$final_feed'; read -s -p 'Press Enter to close...' " >> "$LOGFILE" 2>&1
SCRIPT_EOF

  chmod +x "$BIN_HANDLER"
  echo "Installed: $BIN_HANDLER"

  mkdir -p "$HOME/.local/share/applications"
  cat > "$DESKTOP_FILE" << DESKTOP_EOF
[Desktop Entry]
Name=YTDL Protocol Handler
Exec=$BIN_HANDLER %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
DESKTOP_EOF

  # Register the scheme
  xdg-mime default ytdl.desktop x-scheme-handler/ytdl
  echo "Registered ytdl:// protocol with $DESKTOP_FILE"
fi

########################################
# 6. Done
########################################
echo "============================================================="
echo "YTDL environment setup complete!"
echo
echo "Files installed:"
echo " - $YTDL_DIR/functions.zsh"
echo " - snippet appended to: $SHELL_RC"
if [[ "$ans" =~ ^[Yy]$ ]]; then
  echo " - YTDL protocol handler installed in: $BIN_DIR/ytdl-handler.sh"
  echo " - Desktop file in: $HOME/.local/share/applications/ytdl.desktop"
fi
echo
echo "Please open a new terminal or run 'source $SHELL_RC' to enable 'ytdl', 'ytf', and 'ytdlc' commands."
echo "Enjoy!"
