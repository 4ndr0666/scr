#!/usr/bin/env bash
# Version: 1.1.0
set -euo pipefail
# ====================== // INSTALL_YTDLC.SH // by 4ndr0666

## Constants (will be validated by ensure_xdg)

YTDL_HANDLER_FILE="/usr/local/bin/ytdl-handler.sh"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_DIR="$XDG_DATA_HOME/applications"
BIN_DIR="$HOME/.local/bin"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
YTDL_PLUGIN="$ZSH_DIR/ytdl.zsh"
DMENUHANDLER_FILE="$BIN_DIR/dmenuhandler"
DESKTOP_FILE="$APP_DIR/ytdl.desktop"

## Colors

if command -v tput >/dev/null && [[ -t 1 ]]; then
	GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
	BUG() { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
	INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
else
	GLOW() { printf '[OK] %s\n' "$*"; }
	BUG() { printf '[ERR] %s\n' "$*"; }
	INFO() { printf '[..] %s\n' "$*"; }
fi

## Debugging

[[ "${DEBUG:-0}" -eq 1 ]] && set -x && DEBUG_LOG() { echo "[DEBUG] $*"; } || DEBUG_LOG() { :; }

## Configure

INFO "Configuring system..."

if ! ./test_ytdlc.sh --preinstall; then
	BUG "Validation failed. Please fix issues or re-run with --repair."
	exit 1
fi

GLOW "System verification passed"
echo ""

## Immutability

unlock() { [[ -e $1 ]] && sudo chattr -i "$1" 2>/dev/null || true; }
lock() { [[ -e $1 ]] && sudo chattr +i "$1" 2>/dev/null || true; }

## XDG compliance (or fall back)

ensure_xdg() {
	INFO "Ensuring XDG directories"
	mkdir -p -- "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
		"$APP_DIR" "$BIN_DIR" "$ZSH_DIR"
	GLOW "XDG layout ready"
	echo ""
}

## Auto-Cleanup Old Installation

cleanup_old() {
	INFO "Cleaning previous install"
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e $f ]] || continue
		unlock "$f"
		INFO "Removing → $f"
		sudo rm -f -- "$f"
	done
}

## Deps

install_pkgs() {
	local -a deps=(yt-dlp aria2c jq dmenu wl-copy wl-paste xclip fzf)
	local -a missing=()
	for d in "${deps[@]}"; do command -v "$d" >/dev/null || missing+=("$d"); done
	if ((${#missing[@]})); then
		INFO "Installing: ${missing[*]}"
		sudo pacman -Sy --needed --noconfirm "${missing[@]}"
	else
		GLOW "All dependencies satisfied"
	fi
}

## Bootstrap

### Create empty cookie files so ytdl.zsh never errors on load

bootstrap_cookies() {
	local dir="$XDG_CONFIG_HOME/yt-dlp"
	mkdir -p -- "$dir"
	local -a files=(boosty_cookies.txt dzen.cookies.txt fanvue_cookies.txt instagram_cookies.txt
		patreon_cookies.txt redgifs_cookies.txt vimeo_cookies.txt
		youtube_cookies.txt youtu.be_cookies.txt)
	for f in "${files[@]}"; do
		: >|"$dir/$f"
		chmod 600 "$dir/$f"
	done
	INFO "Cookie store initialised → $dir"
}

## YTDL.zsh

write_ytdl_plugin() {
	mkdir -p -- "$ZSH_DIR"
	cat >"$YTDL_PLUGIN" <<'ZSH'
#!/usr/bin/env zsh
# Version: 1.1.0
# ======================== // YTDL.ZSH // by 4ndr0666

## Fallback Logging

typeset -f GLOW >/dev/null || GLOW(){ print "[✔️] $*"; }
typeset -f BUG  >/dev/null || BUG(){  print "[❌] $*"; }
typeset -f INFO >/dev/null || INFO(){ print "[→]  $*"; }

## Cookie Mapping

typeset -A YTDLP_COOKIES_MAP=(
  [boosty.to]=$XDG_CONFIG_HOME/yt-dlp/boosty_cookies.txt
  [dzen.com]=$XDG_CONFIG_HOME/yt-dlp/dzen.cookies.txt
  [fanvue.com]=$XDG_CONFIG_HOME/yt-dlp/fanvue_cookies.txt
  [instagram.com]=$XDG_CONFIG_HOME/yt-dlp/instagram_cookies.txt
  [patreon.com]=$XDG_CONFIG_HOME/yt-dlp/patreon_cookies.txt
  [redgifs.com]=$XDG_CONFIG_HOME/yt-dlp/redgifs_cookies.txt
  [vimeo.com]=$XDG_CONFIG_HOME/yt-dlp/vimeo_cookies.txt
  [youtube.com]=$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt
  [youtu.be]=$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt
)

## Validate Cookies

for p in ${(v)YTDLP_COOKIES_MAP}; do [[ -e $p ]] || { : >|"$p"; chmod 600 "$p"; }; done

## Validate URL

validate_url() [[ $1 == http*://* ]]

## Get Domain

get_domain_from_url(){ local r=${1#*://}; r=${r%%/*}; r=${r#www.}; r=${r#m.}; print -r -- ${r:l}; }

## Cookie Update

get_cookie(){ print -r -- "${YTDLP_COOKIES_MAP[$1]}"; }

prompt_cookie_update(){
  local domain cookie grab
  print "Select domain to refresh cookie:"
  if command -v fzf >/dev/null; then
    domain=$(print -rl -- ${(k)YTDLP_COOKIES_MAP} | fzf --prompt=Domain:)
  else
    print -rl -- ${(k)YTDLP_COOKIES_MAP} | nl -ba
    read -r "?Choice: " domain
  fi
  [[ -n $domain ]] || return 1
  cookie=$(get_cookie "$domain") || return 1
  printf "➡  Copy cookie for %s then press ENTER… " "$domain"; read -r _
  grab=$(command -v wl-paste || echo 'xclip -selection clipboard -o')
  eval "$grab" >| "$cookie" && chmod 600 "$cookie"
  GLOW "Cookie updated for $domain"
}

## ytdl - Standard Download

ytdl(){
  local usecookie=0 args=()
  while (( $# )); do case $1 in -c) usecookie=1 ;; *) args+=("$1") ;; esac; shift; done
  (( ${#args[@]} )) || { BUG "ytdl: URL required"; return 1; }
  local url=$args[1]
  local -a base=(yt-dlp --add-metadata --embed-metadata \
    --external-downloader aria2c \
    --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
    -f '335/315/313/308/303/299/271/248/137+bestaudio' \
    --newline --ignore-config --no-playlist --no-mtime)
  if (( usecookie )); then
    local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
    [[ -f $ck ]] && "${base[@]}" --cookies "$ck" "$url" && return
  fi
  "${base[@]}" "$url"
}

## ytf - List Formats

ytf(){
  local url=$1
  validate_url "$url" || { BUG "ytf: bad URL"; return 1; }
  local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
  yt-dlp --list-formats ${ck:+--cookies "$ck"} "$url" || {
    prompt_cookie_update || return
    ck=$(get_cookie "$dom")
    yt-dlp --list-formats ${ck:+--cookies "$ck"} "$url" || return
  }
  local fid; read -r "?Format ID (ENTER=default): " fid
  [[ -z $fid ]] && { ytdl "$url"; return; }
  yt-dlp --add-metadata --embed-metadata \
         --external-downloader aria2c \
         --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
         -f "$fid+bestaudio" \
         --newline --ignore-config --no-playlist --no-mtime \
         ${ck:+--cookies "$ck"} \
         --output '%(title)s.%(ext)s' "$url"
}

## Ytdlc

ytdlc(){
  (( $# )) || { show_ytdlc_help; return 1; }
  local list=0 odir="$HOME/Downloads" upd=0
  local -a extra urls
  while (( $# )); do
    case $1 in
      -l|--list-formats) list=1 ;;
      -o|--output-dir)   odir=$2; shift ;;
      --update)          upd=1 ;;
      -f)                extra+=("$1" "$2"); shift ;;
      -h|--help)         show_ytdlc_help; return 0 ;;
      *)                 urls+=("$1") ;;
    esac; shift
  done
  (( upd )) && { prompt_cookie_update; return; }
  mkdir -p -- "$odir"
  for url in "${urls[@]}"; do
    validate_url "$url" || { BUG "Bad URL: $url"; continue; }
    [[ $url == *embed/* ]] && url="https://www.youtube.com/watch?v=${url##*/embed/}"
    local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
    [[ -f $ck ]] || { BUG "Missing cookie for $dom"; continue; }
    if (( list )); then ytf "$url"; continue; fi
    if [[ $dom == fanvue.com ]]; then
      yt-dlp --cookies "$ck" --output "$odir/%(title)s.%(ext)s" "${extra[@]}" "$url" && continue
    fi
    ytdl -c "$url" || BUG "Download failed: $url"
  done
}

## Help

show_ytdlc_help(){
cat <<'USAGE'
ytdlc – cookie-aware yt-dlp wrapper
  -l | --list-formats        list only
  -o | --output-dir DIR      set output directory
       --update              interactively refresh cookie
  -f ID                      pass -f to yt-dlp
  -h | --help                this help
USAGE
}
ZSH
	chmod +x "$YTDL_PLUGIN"
	INFO "ytdl.zsh written"
}

## Dmenuhandler

write_dmenuhandler() {
	mkdir -p -- "$BIN_DIR"
	cat >"$DMENUHANDLER_FILE" <<'DM'
#!/usr/bin/env bash
# Version: 1.1.0
set -euo pipefail
# ========================== // DMENUHANDLER // by 4ndr0666
## Description: Feed a URL or file path to the dmenu
#               and choose and app to open it with.
# Usage:
#       <Super> + <KEY_F9>
# -------------------------------------

## Constants

TERM_CMD="${TERMINAL:-alacritty}"
EDITOR_CMD="${EDITOR:-vim}"
BROWSER_CMD="${BROWSER:-xdg-open}"

## Dynamic Clipboard

clip(){ command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard; }

## URL & File Path

feed="${1:-$(printf '' | dmenu -p 'Paste URL or file path')}"

[[ -z $feed ]] && exit 0

choice=$(printf '%s\n' "copy url" "ytf" "mpv" "mpv loop" "mpv float" "queue download" \
  "queue yt-dlp" "queue yt-dlp audio" "nsxiv" "PDF" "setbg" "browser" "lynx" "vim" | \
  dmenu -i -p "Open it with?")

[[ -z $choice ]] && exit 0

tmpfile="/tmp/$(basename "${feed//%20/ }")"

case "$choice" in
  "copy url") printf '%s' "$feed" | clip ;;
  ytf) setsid -f "$TERM_CMD" -e zsh -ic "ytf '$feed'; read -r -p 'ENTER to close…'" ;;
  mpv) setsid -f mpv --quiet "$feed" ;;
  "mpv loop") setsid -f mpv --quiet --loop "$feed" ;;
  "mpv float") setsid -f "$TERM_CMD" -e mpv --geometry=30% --title=mpvfloat "$feed" ;;
  "queue yt-dlp") qndl "$feed" >/dev/null 2>&1 ;;
  "queue yt-dlp audio") qndl "$feed" 'yt-dlp -o "%(title)s.%(ext)s" -f bestaudio --embed-metadata --restrict-filenames' ;;
  "queue download") qndl "$feed" 'curl -LO' ;;
  PDF)  curl -fsSL "$feed" >"$tmpfile" && zathura "$tmpfile" ;;
  nsxiv) curl -fsSL "$feed" >"$tmpfile" && nsxiv -a "$tmpfile" ;;
  vim)   curl -fsSL "$feed" >"$tmpfile" && setsid -f "$TERM_CMD" -e "$EDITOR_CMD" "$tmpfile" ;;
  setbg) curl -fsSL "$feed" >"$XDG_CACHE_HOME/pic" && swaybg -i "$XDG_CACHE_HOME/pic" --mode fill ;;
  browser) setsid -f "$BROWSER_CMD" "$feed" ;;
  lynx) setsid -f "$TERM_CMD" -e lynx "$feed" ;;
esac
DM
	chmod +x "$DMENUHANDLER_FILE"
	INFO "dmenuhandler written → $DMENUHANDLER_FILE"
}

## Desktop File

write_desktop() {
	mkdir -p -- "$APP_DIR"
	cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.1
Name=YTDL handler
Exec=$YTDL_HANDLER_FILE %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF
	INFO "Desktop entry written"
}

## Xdg-mime registration

register_xdg() {
	xdg-mime default ytdl.desktop x-scheme-handler/ytdl
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
	GLOW "xdg-mime handler registered"
}

## Bookmarklet

bookmarklet() {
	cat <<'BM'
➡️  javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('Bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();
BM
}

## Main entry point

main() {
	[[ $EUID -eq 0 ]] && {
		BUG "Do NOT run installer as root"
		exit 1
	}

	ensure_xdg
	GLOW "💥 Configured!"
	./test_ytdlc.sh --preinstall
	echo ""

	printf "⚡=== // YTDLC PROTOCOL INSTALLER by 4ndr0666 //\n\n"
	read -r -p "Press ENTER to continue…"

	cleanup_old
	install_pkgs
	bootstrap_cookies
	write_ytdl_plugin
	write_dmenuhandler
	write_desktop
	register_xdg

	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do lock "$f"; done
	GLOW "Installation complete"
	echo -e "$(tput setaf 6)\n💡 Alright $(whoami)... all you need to do now is save this bookmarlet:\n$(tput sgr0)"
	bookmarklet
}

main "$@"
