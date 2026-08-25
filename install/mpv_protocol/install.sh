#!/usr/bin/env bash
# Version: 4.0.0                 === INSTALL MEDIA PROTOCOLS === #
# 4NDR0666
set -euo pipefail
# Desc: Installs unified ytdl:// and mpv:// protocol handlers
#

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_DIR="$XDG_DATA_HOME/applications"
BIN_DIR="$HOME/.local/bin"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
COOKIE_DIR="$XDG_CONFIG_HOME/yt-dlp"

YTDL_PLUGIN="$ZSH_DIR/ytdl.zsh"
YTDL_HANDLER_FILE="/usr/local/bin/ytdl-handler.sh"
DMENUHANDLER_FILE="$BIN_DIR/dmenuhandler"
YTDL_DESKTOP_FILE="$APP_DIR/ytdl.desktop"

MPV_HANDLER_FILE="/usr/local/bin/mpv-uri-handler"
MPV_DESKTOP_FILE="$APP_DIR/mpv-handler.desktop"

FILES=(
	"$YTDL_PLUGIN"
	"$YTDL_HANDLER_FILE"
	"$DMENUHANDLER_FILE"
	"$YTDL_DESKTOP_FILE"
	"$MPV_HANDLER_FILE"
	"$MPV_DESKTOP_FILE"
)

COOKIE_DOMAINS=(
	boosty.to
	dzen.com
	fanvue.com
	instagram.com
	patreon.com
	redgifs.com
	vimeo.com
	youtube.com
	youtu.be
)

# logging
if command -v tput >/dev/null && [[ -t 1 ]]; then
	GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
	BUG()  { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
	INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
else
	GLOW() { printf '[OK] %s\n' "$*"; }
	BUG()  { printf '[ERR] %s\n' "$*"; }
	INFO() { printf '[..] %s\n' "$*"; }
fi

if [[ "${DEBUG:-0}" -eq 1 ]]; then
	set -x
	DEBUG_LOG() { printf '[DEBUG] %s\n' "$*"; }
else
	DEBUG_LOG() { :; }
fi

# Immutable
unlock() { [[ -e $1 ]] && sudo chattr -i "$1" 2>/dev/null || true; }
lock()   { [[ -e $1 ]] && sudo chattr +i "$1" 2>/dev/null || true; }

# XDG Spec
ensure_xdg() {
	INFO "Checking XDG specifications..."
	mkdir -p -- "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
		"$APP_DIR" "$BIN_DIR" "$ZSH_DIR" "$COOKIE_DIR"
	GLOW "XDG compliant"
}

# Env
preinstall_check() {
	INFO "Running preinstall environment check..."
	local ok=1

	# Verify all required directories are reachable.
	for dir in "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$BIN_DIR" "$ZSH_DIR" "$APP_DIR"; do
		if [[ ! -d "$dir" ]]; then
			BUG "Required directory missing: $dir"
			ok=0
		fi
	done

	# Verify critical runtime tools are available.
	local -a critical=(yt-dlp aria2c dmenu python3 mpv xdg-mime update-desktop-database)
	for cmd in "${critical[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			BUG "Required command missing: $cmd"
			ok=0
		fi
	done

	if [[ "$ok" -eq 0 ]]; then
		BUG "Preinstall check failed. Run with DEBUG=1 for details."
		return 1
	fi
	GLOW "Preinstall environment validated"
}

# Idempotent
cleanup_old() {
	INFO "Cleaning previous installation..."
	for f in "${FILES[@]}"; do
		if [[ -e "$f" ]]; then
			# Ensure we strip the immutable flag before trying to remove
			unlock "$f"
			INFO "Removing → $f"
			sudo rm -f -- "$f"
		fi
	done
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
	GLOW "Environment cleaned and ready for fresh deployment."
}

# Deps
install_pkgs() {
	local -a need=()
	local cmd pkg
	# Format: "command:package" — command probed, package name passed to pacman.
	for pair in \
		yt-dlp:yt-dlp \
		aria2c:aria2 \
		dmenu:dmenu \
		wl-paste:wl-clipboard \
		xclip:xclip \
		fzf:fzf \
		mpv:mpv \
		python3:python \
		curl:curl; do
		cmd="${pair%%:*}"
		pkg="${pair##*:}"
		command -v "$cmd" >/dev/null 2>&1 || need+=("$pkg")
	done

if (( ${#need[@]} )); then
		INFO "Installing missing packages: ${need[*]}"
		sudo pacman -Sy --needed --noconfirm "${need[@]}"
	else
		GLOW "All dependencies satisfied"
	fi
}

# Cookies
bootstrap_cookies() {
	mkdir -p -- "$COOKIE_DIR"
	local domain fname
	for domain in "${COOKIE_DOMAINS[@]}"; do
		# Normalize domain to filename: replace . with _
		fname="${domain//\./_}_cookies.txt"
		# Special case: youtu.be maps to youtube_cookies.txt (same jar as youtube.com)
		[[ "$domain" == "youtu.be" ]] && fname="youtube_cookies.txt"
		[[ "$domain" == "youtube.com" ]] && fname="youtube_cookies.txt"
		: >|"$COOKIE_DIR/$fname"
		chmod 600 "$COOKIE_DIR/$fname"
	done
	GLOW "Cookie storage initialized → $COOKIE_DIR"
}

# ytdl.zsh
write_ytdl_plugin() {
	mkdir -p -- "$ZSH_DIR"
	cat >"$YTDL_PLUGIN" <<'ZSH'
#!/usr/bin/env zsh
# Version: 4.0.0                === YTDL.ZSH === #
# 4NDR0666
# Desc: cookie-aware ytdl:// zsh wrapper functions
#

typeset -f GLOW >/dev/null || GLOW(){ print "[✔️] $*"; }
typeset -f BUG  >/dev/null || BUG(){  print "[❌] $*"; }
typeset -f INFO >/dev/null || INFO(){ print "[→]  $*"; }
typeset -A YTDLP_COOKIES_MAP=(
  [boosty.to]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/boosty_to_cookies.txt
  [dzen.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/dzen_com_cookies.txt
  [fanvue.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/fanvue_com_cookies.txt
  [instagram.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/instagram_com_cookies.txt
  [patreon.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/patreon_com_cookies.txt
  [redgifs.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/redgifs_com_cookies.txt
  [vimeo.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/vimeo_com_cookies.txt
  [youtube.com]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/youtube_cookies.txt
  [youtu.be]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/youtu.be_cookies.txt
)

for _p in ${(v)YTDLP_COOKIES_MAP}; do
  [[ -e $_p ]] || { : >|"$_p"; chmod 600 "$_p"; }
done
unset _p

# Helpers
validate_url()        { [[ $1 == http*://* ]]; }
get_domain_from_url() { local r=${1#*://}; r=${r%%/*}; r=${r#www.}; r=${r#m.}; print -r -- ${r:l}; }
get_cookie()          { print -r -- "${YTDLP_COOKIES_MAP[$1]}"; }

# Update
prompt_cookie_update() {
  local domain cookie grab
  print "Select domain to refresh cookie:"
  if command -v fzf >/dev/null; then
    domain=$(print -rl -- ${(k)YTDLP_COOKIES_MAP} | fzf --prompt='Domain: ')
  else
    print -rl -- ${(k)YTDLP_COOKIES_MAP} | nl -ba
    read -r "?Choice: " domain
  fi
[[ -n $domain ]] || return 1
  cookie=$(get_cookie "$domain") || return 1
  printf "➡  Copy cookie for %s in your browser, then press ENTER… " "$domain"
  read -r _
  grab=$(command -v wl-paste || echo 'xclip -selection clipboard -o')
  eval "$grab" >|"$cookie" && chmod 600 "$cookie"
  GLOW "Cookie updated for $domain"
}

# ytdl primary download function
ytdl() {
  emulate -LR zsh
  local usecookie=0
  local -a args=()
  while (( $# )); do
    case $1 in
      -c) usecookie=1 ;;
      *)  args+=("$1") ;;
    esac
    shift
  done
  (( ${#args[@]} )) || { BUG "ytdl: URL required"; return 1; }
  local url=$args[1]
  local -a base=(
    yt-dlp --add-metadata --embed-metadata
    --external-downloader aria2c
    --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M'
    -f '335/315/313/308/303/299/271/248/137+bestaudio'
    --newline --ignore-config --no-playlist --no-mtime
  )
  if (( usecookie )); then
    local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
    [[ -f $ck ]] && base+=(--cookies "$ck")
  fi
  "${base[@]}" "${args[@]}"
}

# ytf to list formats, prompt for format ID, then download
ytf() {
  emulate -LR zsh
  local url=$1
  validate_url "$url" || { BUG "ytf: bad URL"; return 1; }
  local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
  yt-dlp --list-formats ${ck:+--cookies "$ck"} "$url" || {
    prompt_cookie_update || return 1
    ck=$(get_cookie "$dom")
    yt-dlp --list-formats ${ck:+--cookies "$ck"} "$url" || return 1
  }
  local fid
  read -r "?Format ID (ENTER=default): " fid
  if [[ -z $fid ]]; then
    ytdl -c "$url"
    return
  fi
  yt-dlp --add-metadata --embed-metadata \
         --external-downloader aria2c \
         --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
         -f "${fid}+bestaudio" \
         --newline --ignore-config --no-playlist --no-mtime \
         ${ck:+--cookies "$ck"} \
         --output '%(title)s.%(ext)s' "$url"
}

# ytdlc cookie-aware multi-URL dl w format selection and update
ytdlc() {
  emulate -LR zsh
  (( $# )) || { show_ytdlc_help; return 1; }
  local list=0 odir="$HOME/Downloads" upd=0
  local -a extra=() urls=()
  while (( $# )); do
case $1 in
      -l|--list-formats) list=1 ;;
      -o|--output-dir)   odir=$2; shift ;;
      --update)          upd=1 ;;
      -f)                extra+=("$1" "$2"); shift ;;
      -h|--help)         show_ytdlc_help; return 0 ;;
      *)                 urls+=("$1") ;;
    esac
    shift
  done
  (( upd )) && { prompt_cookie_update; return; }
  mkdir -p -- "$odir"
  local url dom ck
  for url in "${urls[@]}"; do
    validate_url "$url" || { BUG "Bad URL: $url"; continue; }
    [[ $url == *embed/* ]] && url="https://www.youtube.com/watch?v=${url##*/embed/}"
    dom=$(get_domain_from_url "$url")
    ck=$(get_cookie "$dom")
    [[ -f $ck ]] || { BUG "Missing cookie for $dom — run: ytdlc --update"; continue; }
    if (( list )); then ytf "$url"; continue; fi
    if [[ $dom == fanvue.com ]]; then
      yt-dlp --cookies "$ck" --output "$odir/%(title)s.%(ext)s" "${extra[@]}" "$url" && continue
    fi
    ytdl -c "$url" || BUG "Download failed: $url"
  done
}

show_ytdlc_help() {
  cat <<'USAGE'
ytdlc — cookie-aware yt-dlp wrapper
  -l | --list-formats        List available formats only
  -o | --output-dir DIR      Set output directory (default: ~/Downloads)
       --update              Interactively refresh a domain cookie
  -f ID                      Pass -f flag to yt-dlp
  -h | --help                Show this help
USAGE
}
ZSH
	chmod +x "$YTDL_PLUGIN"
	GLOW "ytdl.zsh written → $YTDL_PLUGIN"
}

# ytdl-handler.sh
write_ytdl_handler() {
	sudo tee "$YTDL_HANDLER_FILE" >/dev/null <<'WH'
#!/usr/bin/env bash
# Version: 4.0.0           === YTDL-HANDLER.SH === #
# 4NDR0666
set -euo pipefail
# decodes ytdl:// URIs -> normalizes URLs ->dmenuhandler via a mini-menu.
#

# clipboard
clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard -in; }

# Toast
require_terminal() {
	if command -v notify-send >/dev/null; then
		notify-send "ytdl-handler" "Notice: Terminal action requested."
	fi
}

menu_call() {
if command -v wofi >/dev/null 2>&1; then
		wofi --dmenu --prompt "$1" --width 500 --lines 15
	else
		dmenu -i -p "$1"
	fi
}

[ "$#" -ne 1 ] && { printf >&2 '[❌] Usage: ytdl-handler.sh <ytdl://URL>\n'; exit 1; }
[ "$1" = "%u" ] && { printf >&2 '[❌] Placeholder arg — not invoked from browser\n'; exit 1; }

## Strip ytdl:// prefix.
feed="${1#ytdl://}"

# deps
if command -v python3 >/dev/null; then
	feed=$(printf '%s' "$feed" | \
		python3 -c 'import sys,urllib.parse as u; print(u.unquote(sys.stdin.read().strip()))')
fi

# normalize YouTube short/embed URLs to canonical watch URLs.
case "$feed" in
	*youtube.com/embed/*)
		id="${feed##*/embed/}"; id="${id%%\?*}"
		feed="https://www.youtube.com/watch?v=$id" ;;
	*youtu.be/*)
		id="${feed##*/}"; id="${id%%\?*}"
		feed="https://www.youtube.com/watch?v=$id" ;;
esac

choice=$(printf '%s\n' 'copy url' ytf mpv cancel | menu_call 'ytdl:')

# Determine a fallback terminal if $TERMINAL is unset
TERM_CMD="${TERMINAL:-x-terminal-emulator}"
command -v "$TERM_CMD" >/dev/null 2>&1 || TERM_CMD="alacritty"

case "$choice" in
	'copy url')
		printf '%s' "$feed" | clip ;;
	ytf)
		require_terminal
		setsid -f "$TERM_CMD" -e zsh -ic "ytf '$feed'; read -r -p $'\nPress ENTER to close…'" ;;
	mpv)
		setsid -f mpv --quiet "$feed" >/dev/null 2>&1 ;;
	*)
		: ;;
esac
WH
	sudo chmod +x "$YTDL_HANDLER_FILE"
	GLOW "ytdl-handler.sh written → $YTDL_HANDLER_FILE"
}

# mpv-uri-handler
write_mpv_handler() {
	sudo tee "$MPV_HANDLER_FILE" >/dev/null <<'MH'
#!/usr/bin/env bash
# Version: 4.0.0           === MPV-URI-HANDLER === #
# 4NDR0666
set -euo pipefail
# decodes mpv:// URIs -> executes detached mpv instance.
#

[ "$#" -ne 1 ] && { printf >&2 '[❌] Usage: mpv-uri-handler <mpv://URL>\n'; exit 1; }
[ "$1" = "%u" ] && { printf >&2 '[❌] Placeholder arg — not invoked from browser\n'; exit 1; }

RAW_URI="$1"
STRIPPED_URI="${RAW_URI#mpv://}"

DECODED_URI=$(python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))" "$STRIPPED_URI")

exec /usr/bin/mpv --force-window=yes "$DECODED_URI" >/dev/null 2>&1
MH
sudo chmod +x "$MPV_HANDLER_FILE"
	GLOW "mpv-uri-handler written → $MPV_HANDLER_FILE"
}

# dmenuhandler
write_dmenuhandler() {
	mkdir -p -- "$BIN_DIR"
	cat >"$DMENUHANDLER_FILE" <<'DM'
#!/bin/sh
# Version: 4.0.0                 === DMENUHANDLER === #
# 4NDR0666
set -eu
# Desc: feed a URL or file path; select a program to open it.
# Usage: dmenuhandler [URL_or_path]  (called by ytdl-handler.sh)
#

menu_call() {
	if command -v wofi >/dev/null 2>&1; then
		wofi --dmenu --prompt "$1" --width 500 --lines 15
	else
		dmenu -i -p "$1"
	fi
}

# Source input: provided argument, or current Wayland clipboard
if [ -n "${1:-}" ]; then
	feed="$1"
else
	feed=$(wl-paste 2>/dev/null || printf "" | menu_call "Paste URL or Path:")
fi

[ -z "$feed" ] && exit 1

## Action menu.
choice=$(printf '%s\n' \
	'copy url' ytf swayimg mpv 'mpv loop' 'mpv float' \
	'queue yt-dlp' 'queue yt-dlp audio' 'queue download' \
	PDF vim setbg browser lynx |
	menu_call 'Open it with?')

# Determine a fallback terminal
TERM_CMD="${TERMINAL:-x-terminal-emulator}"
command -v "$TERM_CMD" >/dev/null 2>&1 || TERM_CMD="alacritty"

case "$choice" in
'copy url')
	printf '%s' "$feed" | command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard -in
	;;
ytf)
	setsid -f "$TERM_CMD" -e zsh -ic "ytf '$feed'; read -r -p $'\nENTER to close…'"
	;;
swayimg)
	setsid -f swayimg -s real "$feed" >/dev/null 2>&1
	;;
mpv)
	setsid -f mpv --quiet "$feed" >/dev/null 2>&1
	;;
'mpv loop')
	setsid -f mpv --quiet --loop "$feed" >/dev/null 2>&1
	;;
'mpv float')
	setsid -f "$TERM_CMD" -e mpv --geometry=+0-0 --autofit=30% \
		--title='mpvfloat' "$feed" >/dev/null 2>&1
	;;
'queue yt-dlp')
	qndl "$feed" >/dev/null 2>&1
	;;
'queue yt-dlp audio')
	qndl "$feed" 'yt-dlp -o "%(title)s.%(ext)s" -f bestaudio --embed-metadata --restrict-filenames'
	;;
'queue download')
qndl "$feed" 'curl -LO' >/dev/null 2>&1
	;;
PDF)
	target_pdf="/tmp/$(printf '%s' "$feed" | sed 's|.*/||;s/%20/ /g;s/?.*//')"
	curl -sL "$feed" >"$target_pdf" && setsid -f zathura "$target_pdf" >/dev/null 2>&1
	;;
vim)
	target_edit="/tmp/$(printf '%s' "$feed" | sed 's|.*/||;s/%20/ /g;s/?.*//')"
	curl -sL "$feed" >"$target_edit" && setsid -f "$TERM_CMD" -e "${EDITOR:-vim}" "$target_edit"
	;;
setbg)
	curl -L "$feed" -o "${XDG_CACHE_HOME:-$HOME/.cache}/pic" &&
		swaybg -i "${XDG_CACHE_HOME:-$HOME/.cache}/pic" --mode fill >/dev/null 2>&1
	;;
browser)
	setsid -f "${BROWSER:-firefox}" "$feed" >/dev/null 2>&1
	;;
lynx)
	setsid -f "$TERM_CMD" -e lynx "$feed" >/dev/null 2>&1
	;;
*)
	exit 0
	;;
esac
DM
	chmod +x "$DMENUHANDLER_FILE"
	GLOW "dmenuhandler written → $DMENUHANDLER_FILE"
}

# desktop files
write_desktops() {
	mkdir -p -- "$APP_DIR"

	cat >"$YTDL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=4.0.0
Name=YTDLC Protocol Handler
Exec=$YTDL_HANDLER_FILE %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
Terminal=false
EOF
	INFO "Desktop entry written → $YTDL_DESKTOP_FILE"

	cat >"$MPV_DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=4.0.0
Name=MPV Protocol Handler
Exec=$MPV_HANDLER_FILE %u
Type=Application
MimeType=x-scheme-handler/mpv;
NoDisplay=true
Terminal=false
EOF
	INFO "Desktop entry written → $MPV_DESKTOP_FILE"
}

# xdg register
register_xdg() {
	xdg-mime default ytdl.desktop x-scheme-handler/ytdl
	xdg-mime default mpv-handler.desktop x-scheme-handler/mpv
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
	GLOW "ytdl:// and mpv:// protocols registered"
}

# bookmarklet
bookmarklet() {
	cat <<'BM'
YTDL: javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('Bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();
MPV:  javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('Bad URL');return;}location.href=`mpv://${encodeURIComponent(u)}`})();
BM
}

# main entry
main() {
	[[ $EUID -eq 0 ]] && {
		BUG "Do NOT run installer as root"
		exit 1
	}

	ensure_xdg

	if ! preinstall_check; then
		BUG "Preinstall check failed. Attempting repair..."
		sleep 1
		ensure_xdg
		if ! preinstall_check; then
			BUG "Cannot repair environment. Exiting."
			exit 1
		fi
	fi

	printf "\n⚡=== // MEDIA PROTOCOLS INSTALLER by 4ndr0666 //\n\n"
	read -r -p "Press ENTER to continue…"
	echo ""

	cleanup_old
	install_pkgs
	bootstrap_cookies
	write_ytdl_plugin
	write_ytdl_handler
	write_mpv_handler
	write_dmenuhandler
	write_desktops
	register_xdg

	echo ""
	INFO "Validating installation..."
	local all_ok=1
	for f in "${FILES[@]}"; do
		if [[ -e "$f" ]]; then
			printf "[OK]      %s\n" "$f"
		else
			printf "[MISSING] %s\n" "$f"
			all_ok=0
		fi
	done

	for f in "${FILES[@]}"; do
		[[ -e "$f" ]] && lock "$f"
	done

	echo ""
	if [[ "$all_ok" -eq 1 ]]; then
		GLOW "Installation complete"
	else
		BUG "One or more files missing after install — check output above"
		exit 1
	fi

	echo ""
	INFO "Save these bookmarklets in your browser:"
	echo ""
	bookmarklet
}
main "$@"
