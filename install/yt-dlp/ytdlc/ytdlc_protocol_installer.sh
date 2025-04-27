#!/usr/bin/env bash
# Version: 1.1.0
# Author: 4ndr0666

set -euo pipefail
# ====================== // INSTALL_YTDLC.SH // by 4ndr0666
## Description: The YTDLC protocol installer by 4ndr0666. Sets up a protocol to
#               handle all YouTube links with YTDL://. Each time you visit a YouTube link
#               the protocol will take over and launch anything you want.
# ----------------------------------------------------

## Constants & PATHS

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

### Ensure truecolor support or fallback gracefully

case "${COLORTERM}" in
truecolor | 24bit) ;;
*) export COLORTERM="24bit" ;;
esac

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

### Configure

printf "\n"
INFO "Configuring system..."

if ! ./configure --preinstall; then
	BUG "Issues detected. Attempting to repair..."
	sleep 1
	./configure --repair || {
		BUG "Could not repair system..."
	}
	exit 1
	GLOW "System repaired!"
fi

## Immutability

unlock() { [[ -e $1 ]] && sudo chattr -i "$1" 2>/dev/null || true; }
lock() { [[ -e $1 ]] && sudo chattr +i "$1" 2>/dev/null || true; }

## XDG compliance (or fall back)

ensure_xdg() {
	echo ""
	INFO "Checking XDG Specifications..."
	mkdir -p -- "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
		"$APP_DIR" "$BIN_DIR" "$ZSH_DIR"
	echo ""
	GLOW "XDG compliant"
	echo ""
}

## Auto-Cleanup Old Installation

cleanup_old() {
	INFO "Cleaning previous installation..."
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e $f ]] || continue
		unlock "$f"
		INFO "Removing → $f"
		sudo rm -f -- "$f"
	done
	echo ""
	GLOW "Environment Cleaned!"
	echo ""
	INFO "Installing system files..."
}

## Deps

install_pkgs() {
	local -a deps=(yt-dlp aria2c jq dmenu wl-copy wl-paste xclip fzf)
	local -a missing=()
	for d in "${deps[@]}"; do command -v "$d" >/dev/null || missing+=("$d"); done
	if ((${#missing[@]})); then
		INFO "Installing: ${missing[*]}"
		sudo pacman -Sy --needed --noconfirm "${missing[@]}"
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
	echo ""
	GLOW "Cookie Storage Initialised at → $dir"
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
	GLOW "ytdl.zsh Plugin Installed"
}

## ytdl-handler.sh

write_handler() {
	sudo tee "$YTDL_HANDLER_FILE" >/dev/null <<'WH'
#!/usr/bin/env bash
# Version: 2.2.0
# Author: 4ndr0666
set -euo pipefail

# ========================== // YTDL-HANDLER.SH // by 4ndr0666
## Description: Handles the sanitized URLs that are passed via
#               the YTDL:// protocol and passes it to the dmenuhandler.
# --------------------------------------------------------

## Dynamic Clipboard

clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard -in; }

## Safeguards

[ "$#" -ne 1 ] && {
	printf >&2 '[❌] Error: one URL arg needed\n'
	exit 1
}
[ "$1" = "%u" ] && {
	printf >&2 '[❌] Error: placeholder arg\n'
	exit 1
}

## URL

feed=${1#ytdl://}

## Sanitize

if command -v python3 >/dev/null; then
	feed=$(printf '%s' "$feed" | python3 -c 'import sys, urllib.parse as u; print(u.unquote(sys.stdin.read().strip()))')
fi

case $feed in
*youtube.com/embed/*)
	id=${feed##*/embed/}
	id=${id%%\?*}
	feed="https://www.youtube.com/watch?v=$id"
	;;
*youtu.be/*)
	id=${feed##*/}
	id=${id%%\?*}
	feed="https://www.youtube.com/watch?v=$id"
	;;
esac

## Mini-menu

choice=$(printf '%s\n' 'copy url' ytf mpv cancel | dmenu -i -p 'ytdl:')

case "$choice" in
'copy url') printf '%s' "$feed" | wl-copy ;;
ytf) setsid -f "$TERMINAL" -e zsh -ic "ytf '$feed'; read -r -p '\nPress ENTER…'" ;;
mpv) setsid -f mpv -quiet "$feed" >/dev/null 2>&1 ;;
*) : ;;
esac
WH
	sudo chmod +x "$YTDL_HANDLER_FILE"
	GLOW "ytdl-handler.sh written → $YTDL_HANDLER_FILE"
}

## Dmenuhandler

write_dmenuhandler() {
	mkdir -p -- "$BIN_DIR"
	cat >"$DMENUHANDLER_FILE" <<'DM'
#!/usr/bin/env bash
# Version: 1.1.0
# Author: 4ndr0666

set -euo pipefail
# ========================== // DMENUHANDLER //
## Description: Feed a URL or file path and assign a program to launch it.
# Usage:
#       <Super> + <KEY_F9>
# -------------------------------------

## Dynamic Clipboard

clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard; }

## URL

feed="${1:-$(true | dmenu -p 'Paste URL or file path')}"

## Options

case "$(printf "copy url\\nytf\\nnsxiv\\nsetbg\\nPDF\\nbrowser\\nlynx\\nvim\\nmpv\\nmpv loop\\nmpv float\\nqueue download\\nqueue yt-dlp\\nqueue yt-dlp audio" | dmenu -i -p "Open it with?")" in

"copy url") echo "$feed" | clip ;;
ytf) setsid -f "$TERMINAL" -e zsh -ic "ytf '$feed'; read -r -p 'ENTER to close…'" ;;
mpv) setsid -f mpv -quiet "$feed" >/dev/null 2>&1 ;;
"mpv loop") setsid -f mpv -quiet --loop "$feed" >/dev/null 2>&1 ;;
"mpv float") setsid -f "$TERMINAL" -e mpv --geometry=+0-0 --autofit=30% --title="mpvfloat" "$feed" >/dev/null 2>&1 ;;
"queue yt-dlp") qndl "$feed" >/dev/null 2>&1 ;;
"queue yt-dlp audio") qndl "$feed" 'yt-dlp -o "%(title)s.%(ext)s" -f bestaudio --embed-metadata --restrict-filenames' ;;
"queue download") qndl "$feed" 'curl -LO' >/dev/null 2>&1 ;;
PDF) curl -sL "$feed" >"/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")" && zathura "/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")" >/dev/null 2>&1 ;;
nsxiv) curl -sL "$feed" >"/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")" && nsxiv -a "/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")" >/dev/null 2>&1 ;;
vim) curl -sL "$feed" >"/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")" && setsid -f "$TERMINAL" -e "$EDITOR" "/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")" >/dev/null 2>&1 ;;
setbg)
	curl -L "$feed" >$XDG_CACHE_HOME/pic
	swaybg -i $XDG_CACHE_HOME/pic --mode fill >/dev/null 2>&1
	;;
browser) setsid -f "$BROWSER" "$feed" >/dev/null 2>&1 ;;
lynx) lynx "$feed" >/dev/null 2>&1 ;;
esac
DM
	chmod +x "$DMENUHANDLER_FILE"
	GLOW "dmenuhandler written → $DMENUHANDLER_FILE"
}

## Desktop File

write_desktop() {
	mkdir -p -- "$APP_DIR"
	cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.1
Name=YTDLC protocol
Exec=$YTDL_HANDLER_FILE %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF
	echo ""
	INFO "Writting Desktop File For Registration..."
}

## Xdg-mime registration

register_xdg() {
	xdg-mime default ytdl.desktop x-scheme-handler/ytdl
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
	echo ""
	GLOW "YTDLC protocol registered"
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

	GLOW "💥 System Ready For Installation!"
	echo ""

	printf "⚡=== // YTDLC PROTOCOL INSTALLER by 4ndr0666 //\n\n"
	read -r -p "Press ENTER to continue…"
	echo ""

	cleanup_old
	install_pkgs
	bootstrap_cookies
	write_ytdl_plugin
	write_handler
	write_dmenuhandler
	write_desktop
	register_xdg
	echo ""

	printf "Validating installation...\n"
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e $f ]] && echo "[OK] $f exists" || echo "[MISSING] $f missing"
	done

	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e "$f" ]] && lock "$f"
	done
	echo ""
	GLOW "Installation complete"
	echo -e "$(tput setaf 6)\n💡 Alright $(whoami)... all you need to do now is save this bookmarlet:\n$(tput sgr0)"
	bookmarklet
}

main "$@"
