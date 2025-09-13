#!/usr/bin/env bash
# BraveClean.sh — Brave-only profile vacuum & cache janitor (safe, idempotent)
# Author: 4ndr0666 (refined)
# - Vacuums *.sqlite (VACUUM + REINDEX + PRAGMA optimize)
# - Cleans Brave caches (safe defaults)
# - Adds Nightly support (Brave-Browser-Development)
# - Optional deep cache purge via BRAVE_DEEP_CLEAN=1
# Usage:
#   ./BraveClean.sh
#   BRAVE_DEEP_CLEAN=1 ./BraveClean.sh   # also clears GPUCache, Code Cache, Service Worker/CacheStorage

set -euo pipefail
export LC_ALL=C
IFS=$'\n\t'

# ----- TTY-aware colors -----
if [[ -t 1 ]]; then RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; RST=$'\e[0m'; else RED=; GRN=; YLW=; RST=; fi

LOG_FILE="/tmp/BraveClean.log"
log(){ printf "%s %s\n" "$(date +%FT%T%z)" "$1" >>"$LOG_FILE"; }
die(){ printf "%sError:%s %s\n" "$RED" "$RST" "$1" >&2; log "ERROR: $1"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "$1 not found."; }

need sqlite3  # notify-send optional

# ----- spinner -----
_spid=""
spin_start(){ ( local g='|/-\' i=0; while :; do printf '%s\b' "${g:i++%4:1}"; sleep 0.1; done ) & _spid=$!; }
spin_stop(){ [[ -n "${_spid}" ]] && { kill "${_spid}" 2>/dev/null || true; wait "${_spid}" 2>/dev/null || true; _spid=""; printf ' \b'; }; }
trap 'spin_stop' EXIT INT TERM

# ----- process control -----
confirm_kill(){
  local proc="brave" user="${USER}" tries=0
  pgrep -u "$user" "$proc" >/dev/null 2>&1 || return 0
  printf "Waiting for %s to exit" "$proc"
  while pgrep -u "$user" "$proc" >/dev/null 2>&1; do
    ((tries++))
    if (( tries >= 5 )); then
      printf "\nKill %s now? [y/N]: " "$proc"
      local a; read -r a
      if [[ "$a" =~ ^[Yy]$ ]]; then
        pkill -TERM -u "$user" "$proc" || true; sleep 4
        pgrep -u "$user" "$proc" >/dev/null 2>&1 && pkill -KILL -u "$user" "$proc" || true
      else
        printf "Please close %s and re-run.\n" "$proc"; exit 1
      fi
      break
    fi
    printf "."; sleep 2
  done
  printf "\n"
}

# ----- DB vacuum -----
vacuum_db(){
  local db="$1"
  rm -f -- "${db}-wal" "${db}-shm" 2>/dev/null || true
  sqlite3 "$db" "PRAGMA journal_mode=DELETE; VACUUM; REINDEX; PRAGMA optimize;" >/dev/null 2>&1 || true
}

run_cleaner(){
  local total_kb=0 db s_old s_new diff_kb
  while IFS= read -r -d '' db; do
    [[ -s "$db" ]] || continue
    printf "%s Cleaning%s  %s " "$GRN" "$RST" "${db##*/}"
    s_old=$(stat -c%s "$db" 2>/dev/null || echo 0)
    spin_start
    vacuum_db "$db"
    spin_stop
    s_new=$(stat -c%s "$db" 2>/dev/null || echo 0)
    diff_kb=$(( (s_old - s_new)/1024 )); total_kb=$(( total_kb + diff_kb ))
    if   (( diff_kb > 0 )); then printf "— %s%skb%s\n" "$YLW" "$diff_kb" "$RST"
    elif (( diff_kb < 0 )); then printf "— %s+%skb grew%s\n" "$RED" $((-diff_kb)) "$RST"
    else                         printf "— ∘\n"; fi
  done < <(find . -maxdepth 1 -type f -name '*.sqlite' -print0)
  (( total_kb > 0 )) && printf "Reclaimed: %s%skb%s in this profile\n" "$YLW" "$total_kb" "$RST" \
                     || printf "No reclaimable space in this profile\n"
}

# ----- Brave paths (stable, beta, nightly) -----
brave_dirs=(
  "$HOME/.config/BraveSoftware/Brave-Browser"
  "$HOME/.config/BraveSoftware/Brave-Browser-Beta"
  "$HOME/.config/BraveSoftware/Brave-Browser-Development"
)

# ----- Brave-specific cache cleanup -----
clean_brave_dir(){
  local dir="$1"
  printf "Brave path: %s\n" "$dir"
  pushd "$dir" >/dev/null || { log "pushd failed: $dir"; return; }

  # Always-safe removals
  local -a rm_dirs=(
    component_crx_cache extensions_crx_cache "Crash Reports"
    Greaselion GrShaderCache ShaderCache GraphiteDawnCache "Local Traces"
  )
  for d in "${rm_dirs[@]}"; do
    [[ -d "$d" ]] || continue
    printf "rm -rf -- %q\n" "$d"; rm -rf -- "$d"
  done

  # Deep cache (opt-in)
  if [[ "${BRAVE_DEEP_CLEAN:-0}" = "1" ]]; then
    local -a deep=(
      "GPUCache" "Code Cache" "Service Worker/CacheStorage" "DawnCache"
    )
    for d in "${deep[@]}"; do
      [[ -e "$d" ]] || continue
      printf "DEEP: rm -rf -- %q\n" "$d"; rm -rf -- "$d"
    done
  fi

  # Keep folder, clear contents
  if [[ -d "Guest Profile" ]]; then
    printf "clear %q/*\n" "Guest Profile"
    find "Guest Profile" -mindepth 1 -delete
  fi

  popd >/dev/null || true
}

# ----- Vacuum Brave profiles -----
vacuum_brave_profiles(){
  local found=0
  confirm_kill
  for base in "${brave_dirs[@]}"; do
    [[ -d "$base" ]] || continue
    found=1
    printf "[%s] %s [%s]\n" "$USER" "${base##*/}" "${GRN}found${RST}"
    # Default + Profile*
    local -a profs=()
    while IFS= read -r -d '' d; do profs+=("$d"); done \
      < <(find "$base" -maxdepth 1 -type d \( -iname 'Default' -o -iname 'Profile*' \) -print0)
    if ((${#profs[@]}==0)); then
      printf "No profiles in %s\n" "$base"; continue
    fi
    for pd in "${profs[@]}"; do
      printf "[%s]\n" "${pd##*/}"
      pushd "$pd" >/dev/null || { log "pushd failed: $pd"; continue; }
      run_cleaner
      popd >/dev/null || true
    done
    clean_brave_dir "$base"
  done
  (( found )) || { printf "[%s] Brave %s\n" "$USER" "[${RED}none${RST}]"; log "No Brave dirs"; }
}

main(){
  if [[ $EUID -eq 0 ]]; then
    read -r -p "${YLW}Warning:${RST} running as root may break profile perms. Continue? [y/N]: " a
    [[ "$a" =~ ^[Yy]$ ]] || exit 1
  fi
  vacuum_brave_profiles
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "BraveClean" "Brave profiles cleaned."
  else
    printf "\n%sCleanup complete.%s\n" "$GRN" "$RST"
  fi
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
