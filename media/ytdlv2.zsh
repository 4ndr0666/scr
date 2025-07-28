#!/usr/bin/zsh
# Author: 4ndr0666
# Version: 1.2.0 · Date: 2025.07.27
# ytdlc – Intelligent yt-dlp wrapper with fzf format picker, cookies, aria2c, and archive prevention

# ── Logging ─────────────────────────────────────────────────
typeset -f GLOW >/dev/null || GLOW(){ print "[✔️] $*"; }
typeset -f BUG  >/dev/null || BUG(){  print "[❌] $*"; }
typeset -f INFO >/dev/null || INFO(){ print "[→]  $*"; }

# ── Cookie Mapping ──────────────────────────────────────────
typeset -A YTDLP_COOKIES_MAP=(
  [boosty.to]=${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp/boosty_cookies.txt
  [dzen.com]=$XDG_CONFIG_HOME/yt-dlp/dzen.cookies.txt
  [fanvue.com]=$XDG_CONFIG_HOME/yt-dlp/fanvue_cookies.txt
  [instagram.com]=$XDG_CONFIG_HOME/yt-dlp/instagram_cookies.txt
  [patreon.com]=$XDG_CONFIG_HOME/yt-dlp/patreon_cookies.txt
  [redgifs.com]=$XDG_CONFIG_HOME/yt-dlp/redgifs_cookies.txt
  [vimeo.com]=$XDG_CONFIG_HOME/yt-dlp/vimeo_cookies.txt
  [youtube.com]=$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt
  [youtu.be]=$XDG_CONFIG_HOME/yt-dlp/youtube_cookies.txt
)

for p in ${(v)YTDLP_COOKIES_MAP}; do [[ -e $p ]] || { : >|"$p"; chmod 600 "$p"; }; done

# ── Helpers ─────────────────────────────────────────────────
validate_url() [[ $1 == http*://* ]]
get_domain_from_url(){ local r=${1#*://}; r=${r%%/*}; r=${r#www.}; r=${r#m.}; print -r -- ${r:l}; }
get_cookie(){ print -r -- "${YTDLP_COOKIES_MAP[$1]}"; }

prompt_cookie_update(){
  local domain cookie grab
  print "Select domain to refresh cookie:"
  if command -v fzf >/dev/null; then
    domain=$(print -rl -- ${(k)YTDLP_COOKIES_MAP} | fzf --prompt="Domain: ")
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

# ── Core ytdl ───────────────────────────────────────────────
ytdl(){
  local usecookie=0 args=()
  while (( $# )); do case $1 in -c) usecookie=1 ;; *) args+=("$1") ;; esac; shift; done
  (( ${#args[@]} )) || { BUG "ytdl: URL required"; return 1; }
  local url=$args[1]
  local -a base=(yt-dlp --add-metadata --embed-metadata
    --external-downloader aria2c
    --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M'
    --newline --ignore-config --no-playlist)
  if (( usecookie )); then
    local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
    [[ -f $ck ]] && "${base[@]}" --cookies "$ck" "$url" && return
  fi
  "${base[@]}" "$url"
}

# ── Format Picker ───────────────────────────────────────────
ytf(){
  local url=$1
  validate_url "$url" || { BUG "ytf: bad URL"; return 1; }
  local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
  local format_line fid
  format_line=$(yt-dlp --list-formats ${ck:+--cookies "$ck"} "$url" | fzf --ansi --prompt="🎞 Select format: ") || return 1
  fid=$(awk '{print $1}' <<< "$format_line")
  [[ -z $fid || $fid == 'ID' ]] && { ytdl "$url"; return; }
  GLOW "Selected format: $fid"
  yt-dlp --add-metadata --embed-metadata \
         --external-downloader aria2c \
         --external-downloader-args 'aria2c:-c -j8 -x8 -s8 -k2M' \
         -f "$fid+bestaudio" \
         --newline --ignore-config --no-playlist --no-mtime \
         ${ck:+--cookies "$ck"} \
         --output '%(title)s.%(ext)s' "$url"
}

# ── Main Command ────────────────────────────────────────────
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
  local archive="${XDG_DATA_HOME:-$HOME/.local/share}/ytdlc/archive.log"
  mkdir -p -- "${archive:h}"; touch "$archive"

  for url in "${urls[@]}"; do
    validate_url "$url" || { BUG "Bad URL: $url"; continue; }
    [[ $url == *embed/* ]] && url="https://www.youtube.com/watch?v=${url##*/embed/}"
    local dom=$(get_domain_from_url "$url") ck=$(get_cookie "$dom")
    [[ -f $ck ]] || { BUG "Missing cookie for $dom"; continue; }

    local id=$(yt-dlp --get-id --no-playlist --ignore-config "$url" 2>/dev/null)
    [[ -z "$id" ]] && { BUG "Could not extract ID"; continue; }
    if grep -qxF "$id" "$archive"; then
      INFO "Already downloaded: $id"
      continue
    fi

    if (( list )); then ytf "$url"; continue; fi
    ytdl -c "$url" && echo "$id" >> "$archive" || BUG "Download failed: $url"
  done
}

# ── Help ─────────────────────────────────────────────────────
show_ytdlc_help(){
cat <<'USAGE'
ytdlc – cookie-aware yt-dlp wrapper
  -l | --list-formats        list only (fzf-select)
  -o | --output-dir DIR      set output directory
       --update              interactively refresh cookie
  -f ID                      pass -f to yt-dlp
  -h | --help                this help
USAGE
}
