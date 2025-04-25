#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ====================== // INSTALL_YTDLC.SH //

## Constants (will be validated by ensure_xdg)

BIN_DIR="/usr/local/bin"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$XDG_DATA_HOME/applications"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
YTDL_FILE="$ZSH_DIR/ytdl.zsh"
HANDLER_FILE="$BIN_DIR/ytdl-handler.sh"
DMENU_FILE="$BIN_DIR/dmenuhandler"
DESKTOP_FILE="$APP_DIR/ytdl.desktop"

## Portable Colors (fallbacks)

GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
BUG() { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }

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
}

## Auto-Cleanup Old Installation

cleanup_old() {
	for f in "$YTDL_FILE" "$HANDLER_FILE" "$DMENU_FILE" "$DESKTOP_FILE"; do
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

	((${#missing[@]} == 0)) && {
		GLOW "Dependencies present"
		return
	}

	INFO "Installing: ${missing[*]}"
	sudo pacman -Sy --needed --noconfirm "${missing[@]}"
}

## Bootstrap

### Create empty cookie files so ytdl.zsh never errors on load

bootstrap_cookies() {
	local dir="$XDG_CONFIG_HOME/yt-dlp"
	mkdir -p -- "$dir"

	# list kept alphabetic for quick grep
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
	INFO "Cookie store initialised → $dir"
}

## YTDL.zsh

write_ytdl_zsh() {
	mkdir -p -- "$ZSH_DIR"

	cat >"$YTDL_FILE" <<'ZSH'
#!/usr/bin/env zsh
# Author: 4ndr0666
# ======================== // YTDL.ZSH //

## Fallback
typeset -f GLOW >/dev/null || GLOW(){ print "[✔️] $*"; }
typeset -f BUG  >/dev/null || BUG(){  print "[❌] $*"; }
typeset -f INFO >/dev/null || INFO(){ print "[→]  $*"; }

## Cookie Map

typeset -A YTDLP_COOKIES_MAP
YTDLP_COOKIES_MAP=(
  [boosty.to]     "$XDG_CONFIG_HOME/yt-dlp/boosty_cookies.txt"
  [dzen.com]      "$XDG_CONFIG_HOME/yt-dlp/dzen.cookies.txt"
  [fanvue.com]    "$XDG_CONFIG_HOME/yt-dlp/fanvue_cookies.txt"
  [instagram.com] "$XDG_CONFIG_HOME/yt-dlp/instagram_cookies.txt"
  [patreon.com]   "$XDG_CONFIG_HOME/yt-dlp/patreon_cookies.txt"
  [redgifs.com]   "$XDG_CONFIG_HOME/yt-dlp/redgifs_cookies.txt"
  [vimeo.com]     "$XDG_CONFIG_HOME/yt-dlp/vimeo_cookies.txt"
  [youtube.com]   "$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt"
  [youtu.be]      "$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt"
)

## Validate Cookies

for p in ${(v)YTDLP_COOKIES_MAP}; do [[ -e $p ]] || : >| "$p"; chmod 600 "$p"; done


## Validate URL

validate_url() [[ $1 == http*://* ]]

## Get Domain

get_domain_from_url() {
	local raw="$1" proto_less pathless norm
	raw=${raw#*://}; raw=${raw%%/*}
	norm=${raw#www.}; norm=${norm#m.}
	print -r -- "${norm:l}"
}

get_cookie() {	print -r -- "${YTDLP_COOKIES_MAP[$1]}"; }

## Cookie Update

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
	local url="${args[0]}"

	local -a base_cmd=(
		yt-dlp
		--add-metadata --embed-metadata
		--external-downloader aria2c
		--external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M'
		-f '335/315/313/308/303/299/271/248/137+bestaudio+bestaudio'
		--newline --ignore-config --no-playlist --no-mtime
	)

	if (( usecookie )); then
		local dom ck
		dom=$(get_domain_from_url "$url")
		ck=$(get_cookie "$dom")
		if [[ -f $ck ]]; then
			"${base_cmd[@]}" --cookies "$ck" "${args[@]}"
			return $?
		fi
	fi
	"${base_cmd[@]}" "${args[@]}"
}

## YTF

ytf() {
	local url=$1; validate_url "$url" || { BUG "ytf: bad URL"; return 1; }
	local dom ck; dom=$(get_domain_from_url "$url"); ck=$(get_cookie "$dom")

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
		-f "$fid+bestaudio" --newline --ignore-config --no-playlist --no-mtime \
		${ck:+--cookies "$ck"} --output '%(title)s.%(ext)s' "$url"
}

## YTDLC

ytdlc() {
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
		[[ $url == *embed/* ]] && \
			url="https://www.youtube.com/watch?v=${url##*/embed/}"

		local dom ck; dom=$(get_domain_from_url "$url"); ck=$(get_cookie "$dom")
		[[ -f $ck ]] || { BUG "Missing cookie for $dom"; continue; }

		if (( list )); then ytf "$url"; continue; fi

		if [[ $dom == fanvue.com ]]; then
			yt-dlp --cookies "$ck" --output "$odir/%(title)s.%(ext)s" \
			       "${extra[@]}" "$url" && continue
		fi
		ytdl -c "$url" || BUG "Download failed: $url"
	done
}

## Help

show_ytdlc_help() {
cat <<'EOF'
ytdlc – cookie-aware yt-dlp wrapper
  -l | --list-formats        list only
  -o | --output-dir DIR      set output directory
       --update              interactively refresh cookie
  -f ID                      pass -f to yt-dlp
  -h | --help                this help
EOF
}
ZSH
	chmod +x "$YTDL_FILE"
	INFO "ytdl.zsh written"
}

## Ytdl-handler.sh

write_handler() {
	sudo tee "$HANDLER_FILE" >/dev/null <<'SH'
#!/bin/sh
# Author: 4ndr0666
set -eu
DMENU=$(command -v dmenu) || { printf >&2 'dmenu missing\n'; exit 1; }
clip() { command -v wl-copy >/dev/null && wl-copy || xclip -selection clipboard -in; }

[ "$#" -ne 1 ]   && { printf >&2 'Error: one URL arg needed\n'; exit 1; }
[ "$1" = "%u" ]  && { printf >&2 'Error: placeholder arg\n';   exit 1; }

## Strip scheme & Percent-decode
feed=${1#ytdl://}
command -v python3 >/dev/null && \
	feed=$(printf '%s' "$feed" | python3 -c '
import sys,urllib.parse as u;print(u.unquote(sys.stdin.read().strip()))')
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

choice=$(printf '%s\n' 'copy url' ytf mpv cancel |
         "$DMENU" -i -p 'ytdl:')

case $choice in
	'copy url') printf '%s' "$feed" | clip ;;
	ytf)   setsid -f "${TERMINAL:-st}" -e zsh -c \
		   "ytf '$feed'; read -r -p '\nPress ENTER…'" ;;
	mpv)   setsid -f mpv -quiet "$feed" >/dev/null 2>&1 ;;
	*) : ;;
esac
SH
	sudo chmod +x "$HANDLER_FILE"
	INFO "handler written"
}

## Dmenuhandler

write_dmenuhandler() {
	sudo tee "$DMENU_FILE" >/dev/null <<'DM'
#!/bin/sh
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

feed="${1:-$(true | dmenu -p 'Paste URL or file path')}"

## Dmenu Options

choice=$(printf "copy url\nytf\nnsxiv\nsetbg\nPDF\nbrowser\nlynx\nvim\nmpv\nmpv loop\nmpv float\nqueue download\nqueue yt-dlp\nqueue yt-dlp audio" | dmenu -i -p "Open it with?")

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
	sudo chmod +x "$DMENU_FILE"
	INFO "dmenuhandler written"
}

## Desktop File

write_desktop() {
	mkdir -p -- "$APP_DIR"
	cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=YTDL handler
Exec=/usr/local/bin/ytdl-handler.sh %u
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
Save this bookmarklet as **YTF**:

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
	GLOW "💥 === // INSTALL YTDLC //"
	read -r -p "Press ENTER to continue…"

	cleanup_old
	install_pkgs
	bootstrap_cookies
	write_ytdl_zsh
	write_handler
	write_dmenuhandler
	write_desktop
	register_xdg

	lock "$YTDL_FILE" "$HANDLER_FILE" "$DMENU_FILE" "$DESKTOP_FILE"
	GLOW "Installation complete"
	echo
	bookmarklet
}

main "$@"
