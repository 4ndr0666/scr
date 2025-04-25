#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail

# ====================== // INSTALL_YTDLC.SH // Version: 1.0.0

## Constants (will be validated by ensure_xdg)

YTDL_HANDLER_FILE="/usr/local/bin/ytdl-handler.sh"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$XDG_DATA_HOME/applications"
BIN_DIR="$HOME/.local/bin"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
YTDL_PLUGIN="$ZSH_DIR/ytdl.zsh"
DMENUHANDLER_FILE="$BIN_DIR/dmenuhandler"
DESKTOP_FILE="$APP_DIR/ytdl.desktop"

## Debugging

[[ "${DEBUG:-0}" -eq 1 ]] && set -x

## Portable Colors (fallbacks)

GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
BUG() { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
[[ "${DEBUG:-0}" -eq 1 ]] && DEBUG_LOG() { echo "[DEBUG] $*"; } || DEBUG_LOG() { :; }

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
	[[ -d $XDG_CONFIG_HOME && -d $XDG_DATA_HOME ]] || {
		BUG "XDG directories missing"
		exit 1
	}
	GLOW "XDG compliance detected"
	echo ""
}

## Auto-Cleanup Old Installation

cleanup_old() {
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e $f ]] || continue
		unlock "$f"
		INFO "Removing old → $f"
		sudo rm -f -- "$f"
	done
}

## Deps

install_pkgs() {
	local -a missing=()
	command -v yt-dlp >/dev/null || missing+=(yt-dlp)
	command -v aria2c >/dev/null || missing+=(aria2)
	command -v jq >/dev/null || missing+=(jq)
	command -v dmenu >/dev/null || missing+=(dmenu)
	{ command -v wl-paste || command -v xclip; } >/dev/null ||
		missing+=(wl-clipboard xclip)

	if ((${#missing[@]})); then
		INFO "Installing missing packages: ${missing[*]}"
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
	### list kept alphabetic for quick grep
	local -a files=(
		boosty_cookies.txt
		dzen.cookies.txt
		fanvue_cookies.txt
		instagram_cookies.txt
		patreon_cookies.txt
		redgifs_cookies.txt
		vimeo_cookies.txt
		youtube_cookies.txt
		youtu.be_cookies.txt
	)
	for f in "${files[@]}"; do
		: >|"$dir/$f"
		chmod 600 "$dir/$f"
	done
	INFO "Cookie store initialized → $dir"
}

## YTDL.zsh

write_ytdl_zsh() {
	mkdir -p -- "$ZSH_DIR"
	cat >"$YTDL_PLUGIN" <<'ZSH'
#!/usr/bin/env zsh
# Version: 1.0.0
# Built: 2025-04-25
# Author: 4ndr0666
# ======================== // YTDL.ZSH //

## Fallback
typeset -f GLOW >/dev/null || GLOW(){ print "[✔️] $*"; }
typeset -f BUG  >/dev/null || BUG(){  print "[❌] $*"; }
typeset -f INFO >/dev/null || INFO(){ print "[→]  $*"; }

## Cookie Map

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

for p in ${(v)YTDLP_COOKIES_MAP}; do [[ -e $p ]] || : >| "$p"; chmod 600 "$p"; done

## Validate URL
## Get Domain
get_domain_from_url() {
	local raw="$1"
	raw=${raw#*://}; raw=${raw%%/*}
	raw=${raw#www.}; raw=${raw#m.}
	print -r -- "${raw:l}"
}

get_cookie() {
	print -r -- "${YTDLP_COOKIES_MAP[$1]}"
}

## Cookie Update

validate_url() [[ $1 == http*://* ]]

prompt_cookie_update() {
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

## YTDL
ytdl() {
	local usecookie=0 args=()
	while (( $# )); do
		case $1 in
			-c) usecookie=1 ;;
			*)  args+=("$1") ;;
		esac; shift
	done
	(( ${#args[@]} )) || { BUG "ytdl: URL required"; return 1; }
	local url="${args[0]}"
	local base_cmd=(yt-dlp --add-metadata --embed-metadata
		--external-downloader aria2c
		--external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M'
		-f '335/315/313/308/303/299/271/248/137+bestaudio+bestaudio'
		--newline --ignore-config --no-playlist --no-mtime)

	if (( usecookie )); then
		local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
		if [[ -f $ck ]]; then
			"${base_cmd[@]}" --cookies "$ck" "${args[@]}"
			return $?
		fi
	fi
	"${base_cmd[@]}" "${args[@]}"
}
## YTF
ZSH
	chmod +x "$YTDL_PLUGIN"
	INFO "ytdl.zsh written"
}

## Ytdl-handler.sh

write_handler() {
	sudo tee "$YTDL_HANDLER_FILE" >/dev/null <<'SH'
#!/bin/sh
# Version: 1.0.0
# Built: 2025-04-25
# Author: 4ndr0666
set -eu

DMENU=$(command -v dmenu) || { printf >&2 '[❌] dmenu missing\n'; exit 1; }

clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard -in; }

[ "$#" -ne 1 ]   && { printf >&2 '[❌] Error: one URL arg needed\n'; exit 1; }
[ "$1" = "%u" ]  && { printf >&2 '[❌] Error: placeholder arg\n';   exit 1; }

## Strip scheme & Percent-decode
feed=${1#ytdl://}

command -v python3 >/dev/null && feed=$(printf '%s' "$feed" | python3 -c '
import sys, urllib.parse as u; print(u.unquote(sys.stdin.read().strip()))')
## Options

case $feed in
	*youtube.com/embed/*)
		id=${feed##*/embed/}; id=${id%%\?*}
		feed="https://www.youtube.com/watch?v=$id" ;;
	*youtu.be/*)
		id=${feed##*/}; id=${id%%\?*}
		feed="https://www.youtube.com/watch?v=$id" ;;
	*redgifs.com/*) ;;
esac

## Mini-menu

choice=$(printf '%s\n' 'copy url' ytf mpv cancel | "$DMENU" -i -p 'ytdl:')

case $choice in
	'copy url') printf '%s' "$feed" | clip ;;
	ytf)   setsid -f "$TERMINAL" -e zsh -c "ytf '$feed'; read -r -p '\nPress ENTER…'" ;;
	mpv)   setsid -f mpv -quiet "$feed" >/dev/null 2>&1 ;;
	*) : ;;
esac
SH
	sudo chmod +x "$YTDL_HANDLER_FILE"
	INFO "The ytdl-handler.sh file has been written."
}

## Dmenuhandler

write_dmenuhandler() {
	mkdir -p -- "$BIN_DIR"
	cat >"$DMENUHANDLER_FILE" <<'DM'
#!/bin/sh
# Version: 1.0.0
# Built: 2025-04-25
# Author: 4ndr0666
set -eu
# ========================== // DMENUHANDLER //
## Description: Feed a URL or file path to the dmenu
#               and choose and app to open it with.
# Usage:
#       <Super> + <KEY_F9>
# -------------------------------------

## Dynamic Clipboard

clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard; }

## URL & File Path

feed="${1:-$(printf '' | dmenu -p 'Paste URL or file path')}"

choice=$(printf "copy url\nytf\nnsxiv\nsetbg\nPDF\nbrowser\nlynx\nvim\nmpv\nmpv loop\nmpv float\nqueue download\nqueue yt-dlp\nqueue yt-dlp audio" |
         dmenu -i -p "Open it with?")

case "$choice" in
    copy*)
        printf '%s' "$feed" | clip
        ;;

    ytf)
        setsid -f "$TERMINAL" -e zsh -c "ytf '$feed'; read -r -p '\nENTER to close…'" ;;
        ;;

    mpv)
        setsid -f mpv -quiet "$feed" >/dev/null 2>&1
        ;;

    "mpv loop")
        setsid -f mpv -quiet --loop "$feed" >/dev/null 2>&1
        ;;

    "mpv float")
        setsid -f "$TERMINAL" -e mpv --geometry=30% --title="mpvfloat" "$feed" >/dev/null 2>&1
        ;;

    "queue yt-dlp")
        qndl "$feed" >/dev/null 2>&1
        ;;

    "queue yt-dlp audio")
        qndl "$feed" 'yt-dlp -o "%(title)s.%(ext)s" -f bestaudio --embed-metadata --restrict-filenames'
        ;;

    "queue download")
        qndl "$feed" 'curl -LO' >/dev/null 2>&1
        ;;

    PDF)
        tmpfile="/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")"
        curl -sL "$feed" > "$tmpfile" && zathura "$tmpfile" >/dev/null 2>&1
        ;;

    nsxiv)
        tmpfile="/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")"
        curl -sL "$feed" > "$tmpfile" && nsxiv -a "$tmpfile" >/dev/null 2>&1
        ;;

    vim)
        tmpfile="/tmp/$(echo "$feed" | sed "s|.*/||;s/%20/ /g")"
        curl -sL "$feed" > "$tmpfile" && setsid -f "$TERMINAL" -e "$EDITOR" "$tmpfile" >/dev/null 2>&1
        ;;

    setbg)
        curl -L "$feed" > "$XDG_CACHE_HOME/pic" && swaybg -i "$XDG_CACHE_HOME/pic" --mode fill >/dev/null 2>&1
        ;;

    browser)
        setsid -f "$BROWSER" "$feed" >/dev/null 2>&1
        ;;

    lynx)
        setsid -f "$TERMINAL" -e lynx "$feed" >/dev/null 2>&1
        ;;
esac
DM
	chmod +x "$DMENUHANDLER_FILE"
	INFO "dmenuhandler script written"
}

## Desktop File

write_desktop() {
	mkdir -p -- "$APP_DIR"
	cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=YTDL handler
Exec=$DMENUHANDLER_FILE %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF
	INFO "desktop entry written"
}

## Xdg-mime registration

register_xdg() {
	xdg-mime default ytdl.desktop x-scheme-handler/ytdl
	update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
	INFO "xdg-mime handler registered"
}

## Bookmarklet

bookmarklet() {
	cat <<'BM'
➡️ javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();
BM
}

## Main entry point

main() {
	[[ $EUID -eq 0 ]] && {
		BUG "Do **NOT** run installer as root"
		exit 1
	}

	ensure_xdg
	GLOW "💥 Configured!"
	echo ""
	printf "⚡=== // YTDLC PROTOCOL INSTALLER by 4ndr0666 //\n\n"
	read -r -p "Press ENTER to continue…"

	cleanup_old
	install_pkgs
	bootstrap_cookies
	write_ytdl_zsh
	write_handler
	write_dmenuhandler
	write_desktop
	register_xdg
	for f in "$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE"; do
		[[ -e "$f" ]] && lock "$f"
	done

	GLOW "Installation complete"
	echo -e "$(tput setaf 6)\n💡 Alright $(whoami)... all you need to do now is save this bookmarlet:\n$(tput sgr0)"
	bookmarklet
}

main "$@"
