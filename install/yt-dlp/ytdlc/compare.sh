#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ================== // INSTALL_YTDLC.SH //

## Constants (will be validated by ensure_xdg)
BIN_DIR="/usr/local/bin"
APP_DIR="$XDG_DATA_HOME/applications"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
YTDL_FILE="$ZSH_DIR/ytdl.zsh"
DESKTOP_FILE="$APP_DIR/ytdl.desktop"
HANDLER_FILE="$BIN_DIR/ytdl-handler.sh"
DMENU_FILE="$BIN_DIR/dmenuhandler"

## Colors via tput
GLOW(){ printf ' %s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
BUG (){ printf ' %s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
INFO(){ printf ' %s\n' "$(tput setaf 4)[→] $*$(tput sgr0)"; }

## Ensure XDG compliance (or fall back)
ensure_xdg(){
  if [ -n "${XDG_DATA_HOME:-}" ] && [ -d "$XDG_DATA_HOME" ] \
     && [ -n "${XDG_CONFIG_HOME:-}" ] && [ -d "$XDG_CONFIG_HOME" ]; then
    GLOW "XDG compliance detected"
  else
    BUG "XDG_DATA_HOME or XDG_CONFIG_HOME unset/invalid; falling back"
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    INFO "XDG_DATA_HOME=$XDG_DATA_HOME"
    INFO "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
  fi
}

## Remove old immutable files so they can be cleaned
remove_immutability(){
  local file="$1"
  [ -f "$file" ] && sudo chattr -i "$file" 2>/dev/null || true
}
reapply_immutability(){
  local file="$1"
  [ -f "$file" ] && sudo chattr +i "$file" 2>/dev/null || true
}

## Cleanup any previous installs
cleanup_old(){
  for f in "$YTDL_FILE" "$HANDLER_FILE" "$DMENU_FILE" "$DESKTOP_FILE"; do
    if [ -e "$f" ]; then
      INFO "Removing old: $f"
      sudo rm -f "$f"
    fi
  done
}

## Dependencies
check_dependencies(){
  local -a pkgs=()
  command -v aria2c >/dev/null   || pkgs+=(aria2)
  { command -v xclip || command -v wl-paste; } >/dev/null || pkgs+=(xclip wl-clipboard)
  command -v jq     >/dev/null   || pkgs+=(jq)
  command -v yt-dlp >/dev/null   || pkgs+=(yt-dlp)
  if [ "${#pkgs[@]}" -gt 0 ]; then
    INFO "Installing dependencies: ${pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  else
    GLOW "Dependencies OK"
  fi
}

## Create empty cookie files so ytdl.zsh never errors on load
bootstrap_cookies(){
  local dir="$XDG_CONFIG_HOME/yt-dlp"
  mkdir -p "$dir"
  for file in youtube_cookies.txt youtu.be_cookies.txt patreon_cookies.txt \
              vimeo_cookies.txt boosty_cookies.txt instagram_cookies.txt \
              fanvue_cookies.txt redgifs_cookies.txt; do
    touch "$dir/$file"
    chmod 600 "$dir/$file"
  done
  INFO "Initialized cookie files in $dir"
}

## Write the zsh plugin
write_ytdl_zsh(){
  mkdir -p "$ZSH_DIR"
  cat >"$YTDL_FILE" <<'EOF_YTDL'
#!/usr/bin/env zsh
# Author: 4ndr0666
# ======================== // YTDL.ZSH //

typeset -A YTDLP_COOKIES_MAP=(
  [youtube.com]   ="$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt"
  [youtu.be]      ="$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt"
  [patreon.com]   ="$XDG_CONFIG_HOME/yt-dlp/patreon_cookies.txt"
  [vimeo.com]     ="$XDG_CONFIG_HOME/yt-dlp/vimeo_cookies.txt"
  [boosty.to]     ="$XDG_CONFIG_HOME/yt-dlp/boosty_cookies.txt"
  [instagram.com] ="$XDG_CONFIG_HOME/yt-dlp/instagram_cookies.txt"
  [fanvue.com]    ="$XDG_CONFIG_HOME/yt-dlp/fanvue_cookies.txt"
  [redgifs.com]   ="$XDG_CONFIG_HOME/yt-dlp/redgifs_cookies.txt"
)

validate_url(){ [[ $1 == http*://* ]]; }
get_domain_from_url(){
  local d=${1#*://}; d=${d%%/*}; d=${d##www.}; d=${d##m.}; d=${(L)d}
  [[ $d == fanvue.com ]] && print -r fanvue.com || print -r $d
}
get_cookie_path_for_domain(){ print -r ${YTDLP_COOKIES_MAP[$1]}; }

prompt_cookie_update(){
  local domain cookie cmd
  echo "Select domain to refresh cookie:"
  if command -v fzf >/dev/null; then
    domain=$(print -rl -- ${(@k)YTDLP_COOKIES_MAP} | fzf --prompt=Domain:)
  else
    print -rl -- ${(@k)YTDLP_COOKIES_MAP} | nl -w2 -ba
    read -rp "Choice: " domain
    domain=${(@k)YTDLP_COOKIES_MAP}[$domain]
  fi
  cookie=$(get_cookie_path_for_domain "$domain") || return 1
  printf "Copy cookie for %s then ENTER… " "$domain"
  read -r
  cmd=$(command -v wl-paste || echo 'xclip -selection clipboard -o')
  eval "$cmd" >| "$cookie" && chmod 600 "$cookie"
  echo "✅ Cookie updated."
}

ytdl(){
  local usecookie=0 args=() url domain cookie
  while (( $# )); do
    case $1 in -c) usecookie=1; shift;; *) args+=("$1"); shift;; esac
  done
  url=${args[1]}
  if (( usecookie )); then
    domain=$(get_domain_from_url $url)
    cookie=$(get_cookie_path_for_domain $domain)
    [[ -f $cookie ]] && yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
      --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
      -f '335/315/313/308/303/299/271/248/137+bestaudio+bestaudio' \
      --newline --ignore-config --no-playlist --no-mtime \
      --cookies "$cookie" "${args[@]}" && return
  fi
  yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
    --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
    -f '335/315/313/308/303/299/271/248/137+bestaudio+bestaudio' \
    --newline --ignore-config --no-playlist --no-mtime "${args[@]}"
}

ytf(){
  local url=$1 domain cookie fid
  validate_url "$url" || { echo "Bad URL"; return 1; }
  domain=$(get_domain_from_url "$url")
  cookie=$(get_cookie_path_for_domain "$domain")
  yt-dlp --list-formats ${cookie:+--cookies "$cookie"} "$url" || {
    prompt_cookie_update
    cookie=$(get_cookie_path_for_domain "$domain")
    yt-dlp --list-formats ${cookie:+--cookies "$cookie"} "$url" || return 1
  }
  read -rp "Format ID (ENTER=default): " fid
  if [[ -z $fid ]]; then
    ytdl "$url"
  else
    yt-dlp --add-metadata --embed-metadata --external-downloader aria2c \
      --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
      -f "$fid+bestaudio" --newline --ignore-config --no-playlist --no-mtime \
      ${cookie:+--cookies "$cookie"} \
      --output '%(title)s.%(ext)s' "$url"
  fi
}

ytdlc(){
  (( $# )) || { show_ytdlc_help; return 1; }
  local listfmt=0 odir="$HOME/Downloads" update=0
  typeset -a extra urls
  while (( $# )); do
    case $1 in
      -l|--list-formats)    listfmt=1;;
      -o|--output-dir)      odir=$2; shift;;
      --update)             update=1;;
      -f)                   extra+=("$1" "$2"); shift;;
      -h|--help)            show_ytdlc_help; return 0;;
      *)                    urls+=("$1");;
    esac; shift
  done
  (( update )) && { prompt_cookie_update; return; }
  mkdir -p "$odir"
  for url in "${urls[@]}"; do
    GLOW "──▶ $url"
    validate_url "$url" || { BUG "Bad URL"; continue; }
    [[ $url == *embed/* ]] && {
      url="https://www.youtube.com/watch?v=${url##*/embed/}"
      INFO "→ EMBED → $url"
    }
    local domain cookie
    domain=$(get_domain_from_url "$url")
    cookie=$(get_cookie_path_for_domain "$domain")
    [ -f "$cookie" ] || { BUG "Missing cookie for $domain"; continue; }
    chmod 600 "$cookie" 2>/dev/null||true

    if (( listfmt )); then
      ytf "$url"; continue
    fi

    if [[ $domain == fanvue.com ]]; then
      GLOW "Fanvue → native"
      yt-dlp --cookies "$cookie" --output "$odir/%(title)s.%(ext)s" "$url" && continue
    fi

    ytdl -c "$url" || { BUG "Both failed"; }
  done
}

## Helper: Protocol handler
write_protocol_handler(){
  sudo tee "$HANDLER_FILE" >/dev/null <<EOF
#!/bin/sh
# Author: 4ndr0666
set -eu
[ \$# -eq 1 ]&&[ "\$1" != "%u" ]||{ echo No URL; exit 1; }
feed=\${1#ytdl://}
command -v python3>/dev/null && \
  feed=\$(printf '%s' "\$feed" | python3 -c 'import sys,urllib.parse as u;print(u.unquote(sys.stdin.read()))')
case "\$feed" in
  *embed/*)     id=\${feed##*/embed/}; feed="https://www.youtube.com/watch?v=\${id%%\?*}" ;;
  *youtu.be/*)  id=\${feed##*/};          feed="https://www.youtube.com/watch?v=\$id" ;;
esac
exec "$DMENU_FILE" "\$feed"
EOF
  sudo chmod +x "$HANDLER_FILE"
  INFO " Wrote handler $HANDLER_FILE"
}

## Helper: dmenuhandler
write_dmenuhandler(){
  sudo tee "$DMENU_FILE" >/dev/null <<'EOF'
#!/bin/sh
# Author: 4ndr0666
feed="${1:-$(true | dmenu -p 'Paste URL or file path')}"
choice=$(printf "copy url\nytf\nytdlc\nnsxiv\nsetbg\nPDF\nbrowser\nlynx\nvim\nmpv\nmpv loop\nmpv float\nqueue yt-dlp\nqueue yt-dlp audio\nqueue download" \
  | dmenu -i -p "Open it with?")
case "$choice" in
  copy*)   printf '%s' "$feed" | { command -v wl-copy&&wl-copy||xclip -selection clipboard; } ;;
  ytf)     setsid -f "$TERMINAL" -e zsh -ic "ytf '$feed'; read -p 'ENTER to close…'" ;;
  ytdlc)   setsid -f "$TERMINAL" -e zsh -ic "ytdlc '$feed'; read -p 'ENTER to close…'" ;;
  nsxiv)   curl -sL "$feed" >/tmp/$(basename "$feed"|sed 's/%20/ /g') && nsxiv -a /tmp/$(basename "$feed"|sed 's/%20/ /g') ;;
  setbg)   curl -L "$feed" >"$XDG_CACHE_HOME/pic" && xwallpaper --zoom "$XDG_CACHE_HOME/pic" ;;
  PDF)     curl -sL "$feed" >/tmp/doc && zathura /tmp/doc ;;
  browser) setsid -f "$BROWSER" "$feed" ;;
  lynx)    setsid -f "$TERMINAL" -e lynx "$feed" ;;
  vim)     curl -sL "$feed" >/tmp/doc && setsid -f "$TERMINAL" -e "$EDITOR" /tmp/doc ;;
  mpv)     setsid -f mpv -quiet "$feed" ;;
  "mpv loop")  setsid -f mpv -quiet --loop "$feed" ;;
  "mpv float") setsid -f "$TERMINAL" -e mpv --geometry=+0-0 --autofit=30% --title=mpvfloat "$feed" ;;
  "queue yt-dlp")       qndl "$feed" ;;
  "queue yt-dlp audio") qndl "$feed" 'yt-dlp -o "%(title)s.%(ext)s" -f bestaudio --embed-metadata --restrict-filenames' ;;
  "queue download")     qndl "$feed" 'curl -LO' ;;
esac
EOF
  sudo chmod +x "$DMENU_FILE"
  INFO " Wrote dmenuhandler $DMENU_FILE"
}

## Desktop file
write_desktop_file(){
  mkdir -p "$APP_DIR"
  cat >"$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Name=YTDL Handler
Exec=/usr/local/bin/ytdl-handler.sh %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF
  INFO " Wrote desktop file $DESKTOP_FILE"
}

## Register protocol
register_protocol(){
  [ -f "$DESKTOP_FILE" ] || { BUG "Desktop file missing"; exit 1; }
  xdg-mime default ytdl.desktop x-scheme-handler/ytdl
  update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
  INFO " Registered ytdl:// protocol"
}

## Bookmarklet
print_bookmarklets(){
  cat <<'EOF'
Save this bookmarklet as YTF:

➡️ javascript:(function(){
  const url=window.location.href;
  if(!url.startsWith("http")){alert("Invalid URL.");return;}
  window.location.href=`ytdl://${encodeURIComponent(url)}`
})();
EOF
}

## Main entry point
main(){
  ensure_xdg
  GLOW "💥 === // INSTALL YTDLC //"
  read -rp "Press ENTER to continue…" _
  # remove immutability so we can clean up
  remove_immutability "$YTDL_FILE"
  remove_immutability "$HANDLER_FILE"
  remove_immutability "$DMENU_FILE"
  cleanup_old

  if [ "$EUID" -eq 0 ]; then
    BUG "Do not run as root. Press ENTER to continue."
    read -r
  fi

  check_dependencies
  write_ytdl_zsh
  bootstrap_cookies
  write_protocol_handler
  write_dmenuhandler
  write_desktop_file
  register_protocol

  reapply_immutability "$YTDL_FILE"
  reapply_immutability "$HANDLER_FILE"
  reapply_immutability "$DMENU_FILE"

  GLOW "Installation complete ✔️"
  echo
  print_bookmarklets
}

main
