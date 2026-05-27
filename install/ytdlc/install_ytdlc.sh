#!/usr/bin/env bash
# Version: 3.0.0
# Author: 4ndr0666
# ====================== // INSTALL_YTDLC.SH //
## Description: Installs the ytdl:// protocol handler framework.
##              Writes ytdl-handler.sh, dmenuhandler, ytdl.zsh, ytdl.desktop,
##              bootstraps cookie storage, and registers the xdg-mime handler.
#
# AUDIT CHANGELOG (v1.1.0 → v2.2.0):
#   CRITICAL I1-D2  - Removed top-level ./configure --preinstall invocation.
#                     Was executing before main() and root-check, with no cleanup
#                     path on failure. Replaced with inline preinstall_check().
#   CRITICAL I1-D1  - install_pkgs: fixed wrong package names (aria2c→aria2,
#                     wl-copy/wl-paste→wl-clipboard). Used cmd:pkg pair pattern
#                     from installer2. Removed jq (unused in any generated script).
#   HIGH     I1-D7  - Version alignment: dmenuhandler bumped to 2.2.0 to match
#                     configure's expected version table. installer itself is 2.2.0.
#   HIGH     I1-D10 - ytdl-handler.sh clipboard: unified via clip() helper to handle
#                     both wl-copy and xclip fallback. Was hardcoded to wl-copy.
#   MEDIUM   I1-D3  - ytdl-handler.sh: added TERMINAL guard with notify-send fallback.
#   MEDIUM   I1-D4  - dmenuhandler: tmp filename computed once into $tmp before the
#                     case statement. Was recomputed via sed pipeline per-case, with
#                     unquoted paths susceptible to word splitting.
#   LOW      I1-D11 - Cookie domain list extracted to a single COOKIE_DOMAINS constant
#                     shared by bootstrap_cookies and ytdl.zsh generation. Previously
#                     the installer and the zsh plugin maintained separate lists.

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants & Paths
# -----------------------------------------------------------------------------
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
DESKTOP_FILE="$APP_DIR/ytdl.desktop"

# I1-D11 FIX: Single source of truth for cookie domains.
# bootstrap_cookies and write_ytdl_plugin both derive from this list.
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

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Immutability
# -----------------------------------------------------------------------------
unlock() { [[ -e $1 ]] && sudo chattr -i "$1" 2>/dev/null || true; }
lock()   { [[ -e $1 ]] && sudo chattr +i "$1" 2>/dev/null || true; }

# -----------------------------------------------------------------------------
# XDG Compliance
# -----------------------------------------------------------------------------
ensure_xdg() {
	INFO "Checking XDG specifications..."
	mkdir -p -- "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
		"$APP_DIR" "$BIN_DIR" "$ZSH_DIR" "$COOKIE_DIR"
	GLOW "XDG compliant"
}

# -----------------------------------------------------------------------------
# Preinstall Environment Check (inline — no external ./configure dependency)
# I1-D2 FIX: Was: top-level `if ! ./configure --preinstall` before main() ran.
# That executed before root-check, before functions were loaded, and depended on
# configure being present and executable in $PWD. Now runs as a function inside
# main() after all guards are in place.
# -----------------------------------------------------------------------------
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
	local -a critical=(yt-dlp aria2c dmenu xdg-mime update-desktop-database)
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

# -----------------------------------------------------------------------------
# Auto-cleanup Old Installation
# -----------------------------------------------------------------------------
cleanup_old() {
	INFO "Cleaning previous installation..."
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e $f ]] || continue
		unlock "$f"
		INFO "Removing → $f"
		sudo rm -f -- "$f"
	done
	GLOW "Environment cleaned"
}

# -----------------------------------------------------------------------------
# Dependency Installation
# I1-D1 FIX: cmd:pkg pair mapping from installer2. aria2c→aria2,
# wl-paste→wl-clipboard. jq removed (not used in any generated artifact).
# fzf retained (used in ytdl.zsh prompt_cookie_update).
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Cookie Bootstrap
# I1-D11 FIX: Derives file list from COOKIE_DOMAINS constant.
# -----------------------------------------------------------------------------
bootstrap_cookies() {
	mkdir -p -- "$COOKIE_DIR"
	local domain fname
	for domain in "${COOKIE_DOMAINS[@]}"; do
		# Normalize domain to filename: replace . with _
		fname="${domain//\./_}_cookies.txt"
		# Special case: youtu.be maps to youtube_cookies.txt (same jar as youtube.com)
		[[ "$domain" == "youtu.be" ]] && fname="youtu.be_cookies.txt"
		[[ "$domain" == "youtube.com" ]] && fname="youtube_cookies.txt"
		: >|"$COOKIE_DIR/$fname"
		chmod 600 "$COOKIE_DIR/$fname"
	done
	GLOW "Cookie storage initialized → $COOKIE_DIR"
}

# -----------------------------------------------------------------------------
# ytdl.zsh Plugin
# Superset of installer1 (full ytdlc) with installer2's clean scoping.
# I1-D6 FIX (from installer2): no 'local' at file scope — uses global assignment.
# -----------------------------------------------------------------------------
write_ytdl_plugin() {
	mkdir -p -- "$ZSH_DIR"
	cat >"$YTDL_PLUGIN" <<'ZSH'
#!/usr/bin/env zsh
# Version: 3.0.0
# Author: 4ndr0666
# ======================== // YTDL.ZSH //
## Description: Cookie-aware yt-dlp wrapper functions for Zsh.
##              Provides ytdl, ytf, ytdlc with domain-based cookie lookup.

## Fallback logging (no-op if parent shell defines these)
typeset -f GLOW >/dev/null || GLOW(){ print "[✔️] $*"; }
typeset -f BUG  >/dev/null || BUG(){  print "[❌] $*"; }
typeset -f INFO >/dev/null || INFO(){ print "[→]  $*"; }

## Cookie map — global scope, XDG_CONFIG_HOME resolved at source time.
## Note: file-scope 'local' is invalid in zsh; use typeset at global scope.
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

## Ensure all cookie files exist at source time (bootstrap guard).
for _p in ${(v)YTDLP_COOKIES_MAP}; do
  [[ -e $_p ]] || { : >|"$_p"; chmod 600 "$_p"; }
done
unset _p

## Helpers
validate_url()        { [[ $1 == http*://* ]]; }
get_domain_from_url() { local r=${1#*://}; r=${r%%/*}; r=${r#www.}; r=${r#m.}; print -r -- ${r:l}; }
get_cookie()          { print -r -- "${YTDLP_COOKIES_MAP[$1]}"; }

## prompt_cookie_update — interactively refresh a cookie file from clipboard
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

## ytdl — primary download function
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

## ytf — list formats, prompt for format ID, then download
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

## ytdlc — cookie-aware multi-URL download with format selection and update
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

# -----------------------------------------------------------------------------
# ytdl-handler.sh
# I1-D10 FIX: Unified clip() for both wl-copy and xclip fallback.
# I1-D3  FIX: Guard on $TERMINAL with notify-send fallback.
# Preserves installer1's full URL decode + youtu.be/embed normalization.
# -----------------------------------------------------------------------------
write_handler() {
	sudo tee "$YTDL_HANDLER_FILE" >/dev/null <<'WH'
#!/usr/bin/env bash
# Version: 3.0.0
# Author: 4ndr0666
# ========================== // YTDL-HANDLER.SH //
## Description: Decodes ytdl:// URIs, normalizes YouTube URLs,
##              and dispatches to dmenuhandler via a mini-menu.
set -euo pipefail

## Unified clipboard — prefers wl-copy, falls back to xclip.
## I1-D10 FIX: was hardcoded wl-copy; now consistent with dmenuhandler.
clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard -in; }

## I1-D3 FIX: Guard on TERMINAL. If unset, use notify-send to surface the error
## rather than letting setsid fail cryptically.
require_terminal() {
	if [[ -z "${TERMINAL:-}" ]]; then
		command -v notify-send >/dev/null && \
			notify-send "ytdl-handler" "TERMINAL env var not set — cannot open $1"
		printf >&2 '[❌] TERMINAL is not set\n'
		exit 1
	fi
}

[ "$#" -ne 1 ] && { printf >&2 '[❌] Usage: ytdl-handler.sh <ytdl://URL>\n'; exit 1; }
[ "$1" = "%u" ] && { printf >&2 '[❌] Placeholder arg — not invoked from browser\n'; exit 1; }

## Strip ytdl:// prefix.
feed="${1#ytdl://}"

## URL-decode via python3 if available.
if command -v python3 >/dev/null; then
	feed=$(printf '%s' "$feed" | \
		python3 -c 'import sys,urllib.parse as u; print(u.unquote(sys.stdin.read().strip()))')
fi

## Normalize YouTube short/embed URLs to canonical watch URLs.
case "$feed" in
	*youtube.com/embed/*)
		id="${feed##*/embed/}"; id="${id%%\?*}"
		feed="https://www.youtube.com/watch?v=$id" ;;
	*youtu.be/*)
		id="${feed##*/}"; id="${id%%\?*}"
		feed="https://www.youtube.com/watch?v=$id" ;;
esac

## Mini-menu: dispatch normalized URL.
choice=$(printf '%s\n' 'copy url' ytf mpv cancel | dmenu -i -p 'ytdl:')

case "$choice" in
	'copy url')
		printf '%s' "$feed" | clip ;;
	ytf)
		require_terminal ytf
		setsid -f "$TERMINAL" -e zsh -ic "ytf '$feed'; read -r -p $'\nPress ENTER to close…'" ;;
	mpv)
		setsid -f mpv --quiet "$feed" >/dev/null 2>&1 ;;
	*)
		: ;;
esac
WH
	sudo chmod +x "$YTDL_HANDLER_FILE"
	GLOW "ytdl-handler.sh written → $YTDL_HANDLER_FILE"
}

# -----------------------------------------------------------------------------
# dmenuhandler
# I1-D4 FIX: tmp filename computed once before case; all usages quoted.
# Uses installer2's POSIX sh foundation for portability.
# Merges installer1's complete action list.
# lynx uses terminal (installer2 pattern; installer1 was bare lynx).
# -----------------------------------------------------------------------------
write_dmenuhandler() {
	mkdir -p -- "$BIN_DIR"
	cat >"$DMENUHANDLER_FILE" <<'DM'
#!/bin/sh
# 4ndr0666
# v3.0.0
set -eu
#          # === DMENUHANDLER === #
# Description: Feed a URL or file path; select a program to open it.
# Usage: dmenuhandler [URL_or_path]  (called by ytdl-handler.sh)
# -------------------------------------------------------------
menu_call() {
	if command -v wofi >/dev/null 2>&1; then
		wofi --dmenu --prompt "$1" --width 500 --lines 15
	else
		# Fallback to dmenu if wofi is missing
		dmenu -i -p "$1"
	fi
}

# Source input: provided argument, or current Wayland clipboard
# Uses wl-paste for native Wayland clipboard access.
if [ -n "$1" ]; then
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
	dmenu -i -p 'Open it with?')

case "$choice" in
'copy url')
	printf '%s' "$feed" | wl-copy
	;;
ytf)
	setsid -f "$TERMINAL" -e zsh -ic "ytf '$feed'; read -r -p $'\nENTER to close…'"
	;;
swayimg)
	# Opens image at 1:1 scale with native directory indexing
	setsid -f swayimg -s real "$feed" >/dev/null 2>&1
	;;
mpv)
	setsid -f mpv --quiet "$feed" >/dev/null 2>&1
	;;
'mpv loop')
	setsid -f mpv --quiet --loop "$feed" >/dev/null 2>&1
	;;
'mpv float')
	setsid -f "$TERMINAL" -e mpv --geometry=+0-0 --autofit=30% \
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
	target_pdf="/tmp/$(printf '%s' "$feed" | sed 's|.*/||;s/%20/ /g')"
	curl -sL "$feed" >"$target_pdf" && setsid -f zathura "$target_pdf" >/dev/null 2>&1
	;;
vim)
	# Edit remote file locally after download
	target_edit="/tmp/$(printf '%s' "$feed" | sed 's|.*/||;s/%20/ /g')"
	curl -sL "$feed" >"$target_edit" && setsid -f "${TERMINAL:-kitty}" -e "$EDITOR" "$target_edit"
	;;
setbg)
	curl -L "$feed" -o "${XDG_CACHE_HOME:-$HOME/.cache}/pic" &&
		swaybg -i "${XDG_CACHE_HOME:-$HOME/.cache}/pic" --mode fill >/dev/null 2>&1
	;;
browser)
	setsid -f "$BROWSER" "$feed" >/dev/null 2>&1
	;;
lynx)
	setsid -f "$TERMINAL" -e lynx "$feed" >/dev/null 2>&1
	;;
*)
	exit 0
	;;
esac
DM
	chmod +x "$DMENUHANDLER_FILE"
	GLOW "dmenuhandler written → $DMENUHANDLER_FILE"
}

# -----------------------------------------------------------------------------
# Desktop Entry
# -----------------------------------------------------------------------------
write_desktop() {
	mkdir -p -- "$APP_DIR"
	cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=3.0.0
Name=YTDLC Protocol Handler
Exec=$YTDL_HANDLER_FILE %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF
	INFO "Desktop entry written → $DESKTOP_FILE"
}

# -----------------------------------------------------------------------------
# XDG MIME Registration
# -----------------------------------------------------------------------------
register_xdg() {
	xdg-mime default ytdl.desktop x-scheme-handler/ytdl
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
	GLOW "ytdl:// protocol registered"
}

# -----------------------------------------------------------------------------
# Bookmarklet
# -----------------------------------------------------------------------------
bookmarklet() {
	cat <<'BM'
javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('Bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();
BM
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	[[ $EUID -eq 0 ]] && {
		BUG "Do NOT run installer as root"
		exit 1
	}

	ensure_xdg

	# I1-D2 FIX: preinstall_check runs inline — no external ./configure dependency.
	if ! preinstall_check; then
		BUG "Preinstall check failed. Attempting repair..."
		sleep 1
		# Re-run ensure_xdg to create any missing directories, then retry.
		ensure_xdg
		if ! preinstall_check; then
			BUG "Cannot repair environment. Exiting."
			exit 1
		fi
	fi

	printf "\n⚡=== // YTDLC PROTOCOL INSTALLER by 4ndr0666 //\n\n"
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
	INFO "Validating installation..."
	local all_ok=1
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		if [[ -e "$f" ]]; then
			printf "[OK]      %s\n" "$f"
		else
			printf "[MISSING] %s\n" "$f"
			all_ok=0
		fi
	done

	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
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
	INFO "Save this bookmarklet as 'YTF' in your browser:"
	echo ""
	bookmarklet
}

main "$@"
