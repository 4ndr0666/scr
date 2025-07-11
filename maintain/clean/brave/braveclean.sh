#!/usr/bin/env bash
# shellcheck disable=all
# Author: 4ndr0666
set -euo pipefail
IFS=$'\n\t'
#
# ========================== // BRAVECLEAN.SH //

## Colors

RED="\e[01;31m" # error
GRN="\e[01;32m" # success/info
YLW="\e[01;33m" # warnings/diffs
RST="\e[00m"    # reset

## Logging

log() {
  local msg
  msg="$1"
  printf "%s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$msg" >> "$LOG_FILE"
}

error_exit() {
  local msg
  msg="$1"
  echo -e "${RED}Error:${RST} $msg" >&2
  log "ERROR: $msg"
  exit 1
}

## Dependencies

dep_check_vacuum() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    error_exit "sqlite3 not found. Please install it."
  fi
}

dep_check_all() {
  dep_check_vacuum
}

## Spinner

spinner() {
  local pid delay spin i
  pid="$1"; delay=0.1; spin='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    for i in {0..3}; do
      printf "%s" "${spin:$i:1}"
      sleep "$delay"
      printf "\b"
    done
  done
}

## Cleaner

run_cleaner() {
  local total diff diff_str s_old s_new db
  total=0

  while read -r db; do
    [[ -z "$db" ]] && continue
    echo -en "${GRN} Cleaning${RST}  ${db##./}"
    if ! s_old=$(stat -c%s "$db" 2>/dev/null); then
      s_old=0
    fi

    (
      rm -f "${db}-wal" "${db}-shm" 2>/dev/null || true
      sqlite3 "$db" "VACUUM;" >/dev/null 2>&1
      sqlite3 "$db" "REINDEX;" >/dev/null 2>&1
    ) & spinner $!; wait

    s_new=$(stat -c%s "$db")
    diff=$(( (s_old - s_new) / 1024 ))
    total=$(( total + diff ))
    if (( diff > 0 )); then
      diff_str="${YLW}- ${diff} KB${RST}"
    elif (( diff < 0 )); then
      diff_str="${RED}+ $(( -diff )) KB${RST}"
    else
      diff_str="${RST}∘${RST}"
    fi

    echo -e "$(tput cr)$(tput cuf 46) ${GRN}done${RST} ${diff_str}"
  done < <(
    find . -maxdepth 1 -type f -print0 \
      | xargs -0 file \
      | grep -i 'SQLite' \
      | sed 's/:.*SQLite.*/\0/' \
      | cut -d: -f1
  )

  if (( total > 0 )); then
    echo -e "Total Space Cleaned: ${YLW}${total}${RST} KB"
  else
    echo "No space reclaimed."
  fi
}

## Check Process

if_running() {
  local process_name user tries ans
  process_name="$1"; user="$USER"; tries=6

  if pgrep -u "$user" "$process_name" >/dev/null 2>&1; then
    echo -n "Waiting for $process_name to exit"
    while pgrep -u "$user" "$process_name" >/dev/null 2>&1; do
      if (( tries-- == 0 )); then
        read -rp " Kill $process_name now? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy] ]]; then
          pkill -TERM -u "$user" "$process_name" || true
          sleep 4
          pkill -KILL -u "$user" "$process_name" || true
        else
          echo "Please close the browser manually and re-run the script."
          exit 1
        fi
      fi
      echo -n "."; sleep 2
    done
    echo
  fi
}

## Brave

perform_brave_cleanup() {
  local brave_dir dd
  brave_dir="$HOME/.config/BraveSoftware/Brave-Browser-Beta"
  if [[ ! -d "$brave_dir" ]]; then
    echo "Brave directory not found. Skipping additional Brave cleanup."
    return
  fi
  echo "Performing additional Brave cleanup steps..."
  cd "$brave_dir" || return

  local dirs_to_remove=(
    component_crx_cache
    extensions_crx_cache
    "Crash Reports"
    Greaselion
    GrShaderCache
    ShaderCache
    GraphiteDawnCache
    "Local Traces"
  )
  for dd in "${dirs_to_remove[@]}"; do
    if [[ -d "$dd" ]]; then
      rm -rf -- "$dd"
      echo "Removed $dd"
    fi
  done
  if [[ -d "Guest Profile" ]]; then
    rm -rf "Guest Profile"/* && echo "Guest Profile cleaned."
  fi
}

## Vacuum

vacuum_browsers() {
  dep_check_vacuum
  local user b ini profiledir cfg

  user="$USER"
  for b in firefox icecat seamonkey aurora; do
    echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
    ini="$HOME/.mozilla/$b/profiles.ini"
    if [[ -f "$ini" ]]; then
      echo -e "$(tput cr)$(tput cuf 45) [${GRN}found${RST}]"
      if_running "$b"
      grep '^Path=' "$ini" | sed 's/Path=//' | while read -r profiledir; do
        echo -e "[${YLW}${profiledir%%=*}${RST}]"
        cd "$HOME/.mozilla/$b/$profiledir" || continue
        run_cleaner
      done
    else
      echo -e "$(tput cr)$(tput cuf 45) [${RED}none${RST}]"
      sleep 0.1
    fi
  done

  for b in chromium chromium-beta chromium-dev google-chrome google-chrome-beta google-chrome-unstable; do
    echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
    cfg="$HOME/.config/$b/Default"
    if [[ -d "$cfg" ]]; then
      echo -e "$(tput cr)$(tput cuf 45) [${GRN}found${RST}]"
      if_running "$b"
      find "$cfg" -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \) -print0 \
        | while IFS= read -r -d '' profiledir; do
            echo -e "[${YLW}${profiledir##*/}${RST}]"
            cd "$profiledir" || continue
            run_cleaner
          done
    else
      echo -e "$(tput cr)$(tput cuf 45) [${RED}none${RST}]"
      sleep 0.1
    fi
  done
  ### Brave
  for b in Brave-Browser-Beta Brave-Browser; do
    echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
    cfg="$HOME/.config/BraveSoftware/$b/Default"
    if [[ -d "$cfg" ]]; then
      echo -e "$(tput cr)$(tput cuf 45) [${GRN}found${RST}]"
      if_running "brave"
      dep_check_all
      find "$(dirname "$cfg")" -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \) -print0 \
        | while IFS= read -r -d '' profiledir; do
            echo -e "[${YLW}${profiledir##*/}${RST}]"
            cd "$profiledir" || continue
            run_cleaner
          done
    else
      echo -e "$(tput cr)$(tput cuf 45) [${RED}none${RST}]"
      sleep 0.1
    fi
  done

  echo "Browser vacuuming complete."
}

## Main Entrypoint

main() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${YLW}Warning:${RST} Running as root can cause permission issues."
    read -rp "Continue? [y/N]: " ans
    [[ "$ans" =~ ^[Yy] ]] || exit 1
  fi
  vacuum_browsers
  perform_brave_cleanup
  echo -e "\n${GRN}BraveClean complete.${RST}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
