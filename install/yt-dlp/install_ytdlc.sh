#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail

# ================== // INSTALL_YTDLC.SH //

## Constants
BIN_DIR="/usr/local/bin"
APP_DIR="$HOME/.local/share/applications"
CONFIG_DIR="$HOME/.config"
ZSH_DIR="$CONFIG_DIR/zsh"
YTDL_FILE="$ZSH_DIR/ytdl.zsh"
DESKTOP_FILE="$APP_DIR/ytdl.desktop"
HANDLER_FILE="$BIN_DIR/ytdl-handler.sh"

## Color definitions for output
CYAN="\033[38;2;21;255;255m"
BOLD="\033[1m"
RED="\033[0;31m"
NC="\033[0m"
glow() {
  echo -e "${BOLD}${CYAN}$1${NC}"
}
bug() {
  echo -e "${BOLD}${RED}$1${NC}"
}

## --------------------- Dependency Check --------------------- ##
check_dependencies() {
  local -a NEED_PKGS=()
  if ! command -v aria2c >/dev/null 2>&1; then
    NEED_PKGS+=("aria2")
  fi
  if ! command -v xclip >/dev/null 2>&1 && ! command -v wl-paste >/dev/null 2>&1; then
    NEED_PKGS+=("xclip" "wl-clipboard")
  fi
  if ! command -v jq >/dev/null 2>&1; then
    NEED_PKGS+=("jq")
  fi
  if ! command -v yt-dlp >/dev/null 2>&1; then
    NEED_PKGS+=("yt-dlp")
  fi
  if (( ${#NEED_PKGS[@]} > 0 )); then
    sudo pacman -S --needed --noconfirm "${NEED_PKGS[@]}"
  else
    glow "All required packages appear to be installed."
  fi
}

## --------------------- Immutability Functions --------------------- ##
remove_immutability() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sudo chattr -i "$file" 2>/dev/null || true
  fi
}
reapply_immutability() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sudo chattr +i "$file" 2>/dev/null || true
  fi
}

## --------------------- Write ytdl.zsh --------------------- ##
write_ytdl_zsh() {
  mkdir -p "$ZSH_DIR"
  cat > "$YTDL_FILE" <<'EOF_YTDL'
#!/usr/bin/env zsh
# Author: 4ndr0666

# =============== // YTDL.ZSH //

## Config Maps
typeset -A YTDLP_COOKIES_MAP=(
  ["youtube.com"]="$HOME/.config/yt-dlp/youtube_cookies.txt"
  ["youtu.be"]="$HOME/.config/yt-dlp/youtube_cookies.txt"
  ["patreon.com"]="$HOME/.config/yt-dlp/patreon_cookies.txt"
  ["vimeo.com"]="$HOME/.config/yt-dlp/vimeo_cookies.txt"
  ["boosty.to"]="$HOME/.config/yt-dlp/boosty_cookies.txt"
  ["instagram.com"]="$HOME/.config/yt-dlp/instagram_cookies.txt"
  ["fanvue.com"]="$HOME/.config/yt-dlp/fanvue_cookies.txt"
)
PREFERRED_FORMATS=("335" "315" "313" "308" "303" "299" "302" "271" "248" "137")

### Validate URL format.
validate_url() {
  local url="$1"
  [[ "$url" =~ ^https?:// ]] && return 0 || return 1
}

### Normalize domain.
# For fanvue URLs, we force the domain to "fanvue.com" (lowercase) so that our cookie mapping works.
get_domain_from_url() {
  local url="$1"
  local domain
  domain=$(echo "$url" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//')
  local lower_domain
  lower_domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
  if [[ "$lower_domain" =~ fanvue\.com$ ]]; then
    echo "fanvue.com"
  else
    echo "$domain"
  fi
}

### Retrieve cookie file path for a given domain.
get_cookie_path_for_domain() {
  local domain="$1"
  echo "${YTDLP_COOKIES_MAP[$domain]}"
}

### Refresh cookie file using clipboard.
refresh_cookie_file() {
  local domain="$1"
  if [[ -z "$domain" ]]; then
    echo "Usage: refresh_cookie_file <domain>"
    return 1
  fi
  local cookie_file
  cookie_file="$(get_cookie_path_for_domain "$domain")"
  if [[ -z "$cookie_file" ]]; then
    echo "❌ Error: No cookie file mapped for domain '$domain'." >&2
    return 1
  fi
  local clipboard_cmd=""
  if command -v wl-paste >/dev/null 2>&1; then
    clipboard_cmd="wl-paste"
  elif command -v xclip >/dev/null 2>&1; then
    clipboard_cmd="xclip -selection clipboard -o"
  else
    echo "❌ Error: No suitable clipboard utility found. Install 'wl-clipboard' or 'xclip'." >&2
    return 1
  fi
  printf "➡️ Copy current cookie file for '%s' to your clipboard, then press Enter.\n" "$domain"
  read -r
  local clipboard_data
  clipboard_data=$($clipboard_cmd 2>/dev/null || true)
  if [[ -z "$clipboard_data" ]]; then
    echo "❌ Error: Clipboard is empty or unreadable." >&2
    return 1
  fi
  mkdir -p "$(dirname "$cookie_file")"
  echo "$clipboard_data" > "$cookie_file" || { echo "❌ Error: Could not write to '$cookie_file'." >&2; return 1; }
  chmod 600 "$cookie_file" 2>/dev/null || echo "❌ Warning: Could not secure '$cookie_file'." >&2
  echo "Cookie file for '$domain' updated successfully!"
}

### Prompt user to update cookies.
# If fzf is available, use it for fuzzy selection.
prompt_cookie_update() {
  echo "Select the domain to update cookies for:"
  local domains
  if command -v fzf >/dev/null 2>&1; then
    domains=("${(@k)YTDLP_COOKIES_MAP}")
    local selection
    selection=$(printf "%s\n" "${domains[@]}" | fzf --prompt="Domain: ")
    if [[ -n "$selection" ]]; then
      refresh_cookie_file "$selection"
      return $?
    else
      echo "❌ No selection made." >&2
      return 1
    fi
  else
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      domains=("${(@k)YTDLP_COOKIES_MAP}")
    else
      domains=( "${!YTDLP_COOKIES_MAP[@]}" )
    fi
    local idx=1
    for d in "${domains[@]}"; do
      echo "  $idx) $d"
      idx=$(( idx + 1 ))
    done
    printf "Enter the number or domain [1-%d]: " $(( idx - 1 ))
    read -r choice
    local domain=""
    if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $(( idx - 1 )) ]]; then
      if [[ -n "${ZSH_VERSION:-}" ]]; then
        domain="${domains[$choice]}"
      else
        domain="${domains[$(( choice - 1 ))]}"
      fi
    else
      for item in "${domains[@]}"; do
        if [[ "$item" == "$choice" ]]; then
          domain="$item"
          break
        fi
      done
    fi
    if [[ -z "$domain" ]]; then
      echo "❌ Invalid selection: $choice" >&2
      return 1
    fi
    refresh_cookie_file "$domain"
  fi
}

### For fanvue.com, force default "best" format.
select_best_format() {
  local url="$1"
  local cfile="$2"
  local domain
  domain=$(get_domain_from_url "$url")
  if [[ "$(echo "$domain" | tr '[:upper:]' '[:lower:]')" == "fanvue.com" ]]; then
    echo "best"
    return
  fi
  local formats_json
  formats_json=$(yt-dlp -j --cookies "$cfile" "$url" 2>/dev/null || true)
  if [[ -z "$formats_json" ]]; then
    echo "best"
    return
  fi
  for fmt in "${PREFERRED_FORMATS[@]}"; do
    if echo "$formats_json" | jq -e --arg f "$fmt" '.formats[] | select(.format_id == $f)' >/dev/null 2>&1; then
      echo "$fmt"
      return
    fi
  done
  echo "best"
}

### Get detailed format info.
get_format_details() {
  local url="$1"
  local cfile="$2"
  local fmtid="$3"
  if [[ "$fmtid" == "best" ]]; then
    echo "N/A"
    return
  fi
  local out
  out=$(yt-dlp -f "$fmtid" -j --cookies "$cfile" "$url" 2>/dev/null || true)
  if [[ -z "$out" ]]; then
    echo "N/A"
    return
  fi
  echo "$out" | jq '{format_id, ext, resolution, fps, tbr, vcodec, acodec, filesize}'
}

### ytdl: Quick download; supports a -c flag to force using cookies.
ytdl() {
  local use_cookie=0
  local args=()
  while (( "$#" )); do
    case "$1" in
      -c)
        use_cookie=1; shift;;
      *)
        args+=("$1"); shift;;
    esac
  done
  if (( use_cookie )); then
    local url="${args[0]}"
    if validate_url "$url"; then
      local domain
      domain=$(get_domain_from_url "$url")
      local cookie_file
      cookie_file=$(get_cookie_path_for_domain "$domain")
      if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
        yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
          --external-downloader-args "aria2c:-c -j8 -x8 -s8 -k2M" \
          -f "335/315/313/308/303/299/271/248/137+bestaudio+bestaudio" \
          --newline --ignore-config --no-playlist --no-mtime \
          --cookies "$cookie_file" "${args[@]}"
        return $?
      fi
    fi
  fi
  yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
    --external-downloader-args "aria2c:-c -j8 -x8 -s8 -k2M" \
    -f "335/315/313/308/303/299/271/248/137+bestaudio+bestaudio" \
    --newline --ignore-config --no-playlist --no-mtime "${args[@]}"
}

### ytf: List formats, prompt for format ID, then pass it to ytdlc.
ytf() {
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: ytf <URL>"
    echo "Lists available download formats for the given URL and prompts for the desired format ID (default: best)."
    return 0
  fi
  local url="$1"
  if [[ -z "$url" ]]; then
    echo "Usage: ytf <URL>"
    return 1
  fi
  if ! validate_url "$url"; then
    echo "❌ Error: Invalid URL: $url" >&2
    return 1
  fi
  local domain
  domain=$(get_domain_from_url "$url")
  local cookie_file
  cookie_file=$(get_cookie_path_for_domain "$domain")
  local output
  if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
    output=$(yt-dlp --list-formats --cookies "$cookie_file" "$url")
  else
    output=$(yt-dlp --list-formats "$url")
  fi
  echo "$output"
  echo ""
  local best_fmt
  best_fmt=$(select_best_format "$url" "$cookie_file")
  echo "Automatically selected best format: $best_fmt"
  echo ""
  printf "Enter the desired format ID (default: %s): " "$best_fmt"
  read -r user_input
  if [[ -z "$user_input" ]]; then
    user_input="$best_fmt"
  fi
  echo "Proceeding with format ID: $user_input"
  ytdlc -f "$user_input" "$url"
}

### Helper: Attempt advanced download.
attempt_advanced_download() {
  local url="$1"
  local cookie_file="$2"
  local bestf="$3"
  local odir="$4"
  shift 4
  yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
    --external-downloader-args "aria2c:-c -j8 -x8 -s8 -k2M" \
    --ignore-config --no-playlist --no-mtime \
    --cookies "$cookie_file" \
    --output "${odir}/%(title)s.%(ext)s" "${extra_args[@]}" "$url"
}

### Helper: Reattempt advanced download after fallback.
reattempt_advanced_download() {
  local url="$1"
  local cookie_file="$2"
  local bestf="$3"
  local odir="$4"
  shift 4
  yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
    --external-downloader-args "aria2c:-c -j8 -x8 -s8 -k2M" \
    -f "${bestf}+bestaudio+bestaudio" --merge-output-format webm \
    --no-playlist --no-mtime --cookies "$cookie_file" \
    --output "${odir}/%(title)s.%(ext)s" "$@"
}

### ytdlc: Advanced download with fallback and reattempt logic.
ytdlc() {
  if [[ $# -eq 0 ]]; then
    show_ytdlc_help
    return 0
  fi
  local listfmt=0
  local odir="$HOME/Downloads"
  local update_mode=0
  declare -a extra_args
  declare -a urls
  while (( "$#" )); do
    case "$1" in
      --list-formats|-l)
        listfmt=1; shift;;
      --output-dir|-o)
        if [[ -n "$2" && "$2" != -* ]]; then
          odir="$2"; shift 2;
        else
          echo "❌ Error: --output-dir requires a non-empty argument." >&2
          show_ytdlc_help; return 1;
        fi;;
      --update)
        update_mode=1; shift;;
      --help|-h)
        show_ytdlc_help; return 0;;
      -f)
        if [[ -n "$2" && "$2" != -* ]]; then
          extra_args+=("-f" "$2"); shift 2;
        else
          echo "❌ Error: -f requires an argument." >&2; return 1;
        fi;;
      -*)
        extra_args+=("$1"); shift;;
      *)
        urls+=("$1"); shift;;
    esac
  done
  if (( update_mode )); then
    prompt_cookie_update
    return 0
  fi
  if (( ${#urls[@]} == 0 )); then
    echo "❌ No URLs specified." >&2
    show_ytdlc_help; return 1;
  fi
  if [[ ! -d "$odir" ]]; then
    mkdir -p "$odir" || { echo "❌ Error: Could not create '$odir'." >&2; return 1; }
  fi
  for url in "${urls[@]}"; do
    echo "----------------------------------------"
    echo "Analyzing URL: $url"
    if ! validate_url "$url"; then
      echo "❌ Error: Invalid URL: $url" >&2
      continue
    fi
    ### Convert YouTube embed URL if needed.
    if [[ "$url" =~ youtube\.com/embed/([^?]+) ]]; then
      video_id="${BASH_REMATCH[1]}"
      url="https://www.youtube.com/watch/${video_id}"
      echo "➡️ Converted embed URL to: $url"
    fi
    local domain
    domain=$(get_domain_from_url "$url")
    local cookie_file
    cookie_file=$(get_cookie_path_for_domain "$domain")
    if [[ -z "$cookie_file" ]]; then
      echo "❌ Error: No cookie file mapped for domain '$domain'." >&2
      echo "➡️ Use 'ytdlc --update' to add or refresh cookie files."
      continue
    fi
    if [[ ! -f "$cookie_file" ]]; then
      echo "❌ Cookie file not found at '$cookie_file'." >&2
      echo "➡️ Use 'ytdlc --update' and paste the new cookie for '$domain'."
      continue
    fi
    local perms
    perms=$(stat -c '%a' "$cookie_file" 2>/dev/null || echo '???')
    if [[ "$perms" != "600" ]]; then
      chmod 600 "$cookie_file" 2>/dev/null || { echo "❌ Warning: Could not secure '$cookie_file'." >&2; }
    else
      echo "Permissions for '$cookie_file' are already set to 600."
    fi
    if (( listfmt )); then
      echo "➡️ Listing available formats for '$url':"
      ytf "$url"
      echo "----------------------------------------"
      continue
    fi
    local bestf
    bestf=$(select_best_format "$url" "$cookie_file")
    # For fanvue, force bestf to "best"
    if [[ "$(echo "$(get_domain_from_url "$url")" | tr '[:upper:]' '[:lower:]')" == "fanvue.com" ]]; then
      bestf="best"
      echo "➡️ Fanvue URL detected; defaulting to format: best"
    fi
    printf "✔️ Selected format ID: %s\n" "$bestf"
    if [[ "$bestf" != "best" ]]; then
      local fmt_info
      fmt_info=$(get_format_details "$url" "$cookie_file" "$bestf")
      echo "Format details:"; echo "$fmt_info"; echo ""
    else
      echo "Format details: N/A"; echo ""
    fi
    echo "➡️ Attempting advanced download for '$url'..."
    attempt_advanced_download "$url" "$cookie_file" "$bestf" "$odir" "${extra_args[@]}"
    local exit_code_adv=$?
    if [[ $exit_code_adv -eq 0 ]]; then
      printf "✔️ Advanced download completed successfully for '%s'.\n" "$url"
    else
      echo "❌ Advanced download failed for '$url'." >&2
      echo "➡️ Falling back to simple download (ytdl)..." >&2
      ytdl "$url"
      local exit_code_simple=$?
      if [[ $exit_code_simple -eq 0 ]]; then
        printf "✔️ Fallback download (ytdl) succeeded for '%s'.\n" "$url"
      else
        echo "❌ Fallback download (ytdl) also failed for '$url'." >&2
        echo -n "➡️ Automatically reattempt advanced download? (max 1 reattempt) (y/n): "
        read -r reattempt_choice
        if [[ "$reattempt_choice" =~ ^[Yy](es)?$ ]]; then
          reattempt_advanced_download "$url" "$cookie_file" "$bestf" "$odir" "${extra_args[@]}"
          local exit_code_reattempt=$?
          if [[ $exit_code_reattempt -eq 0 ]]; then
            printf "✔️ Reattempt after fallback succeeded for '%s'.\n" "$url"
          else
            echo "❌ Reattempt after fallback failed for '$url'. Skipping." >&2
          fi
        else
          echo "➡️ Skipping re-attempt for '$url'."
        fi
      fi
    fi
    echo "----------------------------------------"
  done
}

### Help for ytdlc
show_ytdlc_help() {
  cat <<'EOF_HELP'
Usage: ytdlc [options] <URL> [<URL> ...] [yt-dlp options]
Advanced downloads with domain-based cookies, auto-format selection, and cookie refresh on failure.

Options:
  --list-formats, -l      Only list available formats, do not download.
  --output-dir, -o <dir>  Specify a custom output directory (default: ~/Downloads).
  --update                Interactively update a cookie file, then exit.
  --help, -h              Show this help text.

Examples:
  ytdlc --update
  ytdlc --list-formats https://youtu.be/abc123
  ytdlc --output-dir /tmp https://patreon.com/page
  ytdlc https://patreon.com/page -f 303
EOF_HELP
}

EOF_YTDL
  glow "✔️ Wrote ytdl.zsh to $YTDL_FILE"
}

## --------------------- Write protocol handler --------------------- ##
write_protocol_handler() {
  sudo mkdir -p "$BIN_DIR"
  sudo tee "$HANDLER_FILE" > /dev/null <<'EOF_HANDLER'
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1:-}" ] || [ "$1" = "%u" ]; then
  echo "Error: No valid URL provided. Exiting." >&2
  exit 1
fi

feed="${1#ytdl://}"
if command -v python3 >/dev/null 2>&1; then
  feed_decoded=$(echo "$feed" | python3 -c "import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read().strip()))")
else
  feed_decoded="$feed"
fi
final_feed="${feed_decoded:-$feed}"

if [[ "$final_feed" =~ youtube\.com/embed/([^?]+) ]]; then
  video_id="${BASH_REMATCH[1]}"
  final_feed="https://www.youtube.com/watch/${video_id}"
elif [[ "$final_feed" =~ youtube\.com/watch\?v=([^&]+) ]]; then
  video_id="${BASH_REMATCH[1]}"
  final_feed="https://www.youtube.com/watch/${video_id}"
fi

echo "✔️ Final feed processed: $final_feed" >&2
#### Launch the dmenuhandler with the processed URL.
exec /usr/local/bin/dmenuhandler "$final_feed"
EOF_HANDLER
  sudo chmod +x "$HANDLER_FILE"
  glow "✔️ Wrote protocol handler to $HANDLER_FILE"
}

## --------------------- Write desktop file --------------------- ##
write_desktop_file() {
  mkdir -p "$APP_DIR"
  cat <<'EOF_DESK' > "$DESKTOP_FILE"
[Desktop Entry]
Name=YTDL Handler
Exec=/usr/local/bin/ytdl-handler.sh %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF_DESK
  glow "✔️ Wrote desktop file to $DESKTOP_FILE"
}

## --------------------- Register protocol --------------------- ##
register_protocol() {
  if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Desktop file not found at $DESKTOP_FILE" >&2
    exit 1
  fi
  xdg-mime default ytdl.desktop x-scheme-handler/ytdl
  update-desktop-database "$APP_DIR" > /dev/null 2>&1 || true
  glow "✔️ Registered ytdl:// protocol with $DESKTOP_FILE"
}

## --------------------- Print bookmarklet --------------------- ##
print_bookmarklets() {
  cat <<'EOF_BM'
Save this bookmarklet as YTDLC:

➡️ javascript:(function(){const url=window.location.href;if(!url.startsWith("http")){alert("Invalid URL.");return;}window.location.href=`ytdl://${encodeURIComponent(url)}`})();
EOF_BM
}

## --------------------- Write dmenuhandler --------------------- ##
write_dmenuhandler() {
  sudo mkdir -p "$BIN_DIR"
  if [ -f "$BIN_DIR/dmenuhandler" ]; then
    read -rp "Dmenuhandler detected, overwrite? (y/n) " _consent
    if [[ $_consent != [Yy] ]]; then
      return
    fi
  fi
  sudo tee "$BIN_DIR/dmenuhandler" > /dev/null <<'EOF_DMENU'
#!/bin/sh
# Author: 4ndr0666
# ================== // DMENUHANDLER //

# Input feed: if no argument is provided, prompt the user via dmenu
feed="${1:-$(true | dmenu -p 'Paste URL or file path')}"
TERM_EMULATOR="${TERMINAL:-xterm}"
choice=$(printf "copy url\nytdlc\nnsxiv\nsetbg\nPDF\nbrowser\nlynx\nvim\nmpv\nmpv loop\nmpv float\nqueue yt-dlp\nqueue yt-dlp audio\nqueue download" | dmenu -i -p "Open it with?")
case "$choice" in
    "copy url") echo "$feed" | wl-copy ;;
    "ytdlc") setsid -f "$TERM_EMULATOR" -e bash -c "echo 'Listing formats for $feed:'; ytf \"$feed\"" ;;
    "nsxiv") curl -sL "$feed" > "/tmp/$(basename "$feed" | sed 's/%20/ /g')"; nsxiv -a "/tmp/$(basename "$feed" | sed 's/%20/ /g')" >/dev/null 2>&1 ;;
    "setbg") curl -L "$feed" > "$XDG_CACHE_HOME/pic"; swaybg -i "$XDG_CACHE_HOME/pic" >/dev/null 2>&1 ;;
    "PDF") curl -sL "$feed" > "/tmp/$(basename "$feed" | sed 's/%20/ /g')"; zathura "/tmp/$(basename "$feed" | sed 's/%20/ /g')" >/dev/null 2>&1 ;;
    "browser") setsid -f "$BROWSER" "$feed" >/dev/null 2>&1 ;;
    "lynx") setsid -f "$TERM_EMULATOR" -e lynx "$feed" >/dev/null 2>&1 ;;
    "vim") curl -sL "$feed" > "/tmp/$(basename "$feed" | sed 's/%20/ /g')"; setsid -f "$TERM_EMULATOR" -e "$EDITOR" "/tmp/$(basename "$feed" | sed 's/%20/ /g')" >/dev/null 2>&1 ;;
    "mpv") setsid -f mpv -quiet "$feed" >/dev/null 2>&1 ;;
    "mpv loop") setsid -f mpv -quiet --loop=inf "$feed" >/dev/null 2>&1 ;;
    "mpv float") setsid -f "$TERM_EMULATOR" -e mpv --geometry=+0-0 --autofit=30% --title="mpvfloat" "$feed" >/dev/null 2>&1 ;;
    "queue yt-dlp") setsid -f qndl "$feed" >/dev/null 2>&1 ;;
    "queue yt-dlp audio") setsid -f qndl "$feed" 'yt-dlp -o "%(title)s.%(ext)s" -f bestaudio --embed-metadata --restrict-filenames' >/dev/null 2>&1 ;;
    "queue download") setsid -f qndl "$feed" 'curl -LO' >/dev/null 2>&1 ;;
    *) echo "Invalid choice or no action taken." >/dev/null 2>&1 ;;
esac
EOF_DMENU
  sudo chmod +x "$BIN_DIR/dmenuhandler"
  glow "✔️ Installed new dmenuhandler to $BIN_DIR/dmenuhandler"
}

## --------------------- Main Entry Point --------------------- ##
main() {
  echo "💥 === // YTDL Protocol //"
  echo
  glow "Press Enter to install or Ctrl+C to abort."
  read -r

  if [[ $EUID -eq 0 ]]; then
    echo "❌ Warning: It's recommended not to run this as root. Press Enter to continue."
    read -r
  fi

  check_dependencies
  remove_immutability "$YTDL_FILE"
  remove_immutability "$HANDLER_FILE"
  write_ytdl_zsh
  write_protocol_handler
  write_desktop_file
  # Uncomment the next line if you wish to overwrite the existing dmenuhandler.
  write_dmenuhandler
  register_protocol
  reapply_immutability "$YTDL_FILE"
  reapply_immutability "$HANDLER_FILE"
  glow "✔️ Installation complete."
  echo
  print_bookmarklets
}
main
