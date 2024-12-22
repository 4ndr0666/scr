#!/usr/bin/env bash
# File: BraveClean.sh
# Author: 4ndr0666
# Date: 2024-12-06

# ========================== // BRAVECLEAN.SH //
set -euo pipefail
IFS=$'\n\t'
RED="\e[01;31m"
GRN="\e[01;32m"
YLW="\e[01;33m"
RST="\e[00m"
LOG_FILE="/tmp/BraveClean.log"

log() {
  local msg="$1"
  printf "%s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$msg" >> "$LOG_FILE"
}

error_exit() {
  local msg="$1"
  echo -e "${RED}Error:${RST} $msg" >&2
  log "ERROR: $msg"
  exit 1
}

dep_check_vacuum() {
  # Ensure sqlite3 is available for vacuuming
  command -v sqlite3 &>/dev/null || error_exit "sqlite3 not found. Please install it."
}

dep_check_all() {
  # Extend or customize if additional dependencies are required
  dep_check_vacuum
  # Example:
  # command -v xargs &>/dev/null || error_exit "xargs not found. Please install it."
}

spinner() {
  local pid="$1"
  local delay=0.1
  local spin='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    for i in {0..3}; do
      printf "%s" "${spin:$i:1}"
      sleep "$delay"
      printf "\b"
    done
  done
}

run_cleaner() {
  local total=0

  # Find all files recognized as SQLite DBs in the current directory
  while read -r db; do
    [[ -z "$db" ]] && continue

    echo -en "${GRN} Cleaning${RST}  ${db##'./'}"
    local s_old
    s_old=$(stat -c%s "$db" 2>/dev/null || echo 4096)

    (
      # Remove ephemeral files if present
      rm -f "${db}-wal" "${db}-shm" 2>/dev/null || true
      # Vacuum & reindex the database
      sqlite3 "$db" "VACUUM;" && sqlite3 "$db" "REINDEX;"
    ) & spinner $!
    wait

    local s_new
    s_new=$(stat -c%s "$db")
    local diff=$(((s_old - s_new) / 1024))
    total=$((total + diff))

    local diff_str
    if (( diff > 0 )); then
      diff_str="${YLW}- ${diff} KB${RST}"
    elif (( diff < 0 )); then
      diff_str="\e[01;30m+ $((diff * -1)) KB${RST}"
    else
      diff_str="\e[00;33m∘${RST}"
    fi

    # Move cursor to the right, display "done" & difference
    echo -e "$(tput cr)$(tput cuf 46) ${GRN}done${RST} ${diff_str}"
  done < <(
    find . -maxdepth 1 -type f -print0 \
    | xargs -0 file \
    | grep -i 'SQLite' \
    | sed 's/:.*SQLite.*/''/'
  )

  echo
  (( total > 0 )) && echo -e "Total Space Cleaned: ${YLW}${total}${RST} KB" || echo "No space reclaimed."
}

# --------------[ Process Checking & Graceful Kill ]------------
if_running() {
  local process_name="$1"
  local user="$USER"
  local tries=6

  if pgrep -u "$user" "$process_name" >/dev/null; then
    echo -n "Waiting for $process_name to exit"
  fi

  while pgrep -u "$user" "$process_name" >/dev/null; do
    if (( tries == 0 )); then
      read -rp " Kill $process_name now? [y|n]: " ans
      if [[ "$ans" =~ ^[Yy](es)?$ ]]; then
        pkill -TERM -u "$user" "$process_name" || true
        sleep 4
        # Force if still alive
        if pgrep -u "$user" "$process_name" >/dev/null; then
          pkill -KILL -u "$user" "$process_name" || true
        fi
        break
      else
        echo "Please close the browser manually and re-run the script."
        exit 1
      fi
    fi
    echo -n "."
    sleep 2
    ((tries--))
  done
}

# --------------[ Optional Brave-Specific Cleanup ]-------------
perform_brave_cleanup() {
  local brave_dir="$HOME/.config/BraveSoftware/Brave-Browser-Beta"
  [[ ! -d "$brave_dir" ]] && {
    echo "Brave directory not found. Skipping additional Brave cleanup."
    return
  }

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
    [[ -d "$dd" ]] && rm -rf "$dd" && echo "Removed $dd"
  done

  if [[ -d "$brave_dir/Guest Profile" ]]; then
    rm -rf "$brave_dir/Guest Profile"/* && echo "Guest Profile cleaned."
  fi

  echo "Brave additional cleanup done."
}

# --------------[ Main Vacuuming Logic ]------------------------
vacuum_browsers() {
  dep_check_vacuum
  local user="$USER"

  # ------[ Firefox / IceCat / Seamonkey / Aurora ]------
  for b in firefox icecat seamonkey aurora; do
    echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
    local ini_path="/home/$user/.mozilla/$b/profiles.ini"

    if [[ -f "$ini_path" ]]; then
      echo -e "$(tput cr)$(tput cuf 45) [${GRN}found${RST}]"
      if_running "$b"
      while read -r profiledir; do
        echo -e "[${YLW}$(echo "$profiledir" | cut -d'.' -f2)${RST}]"
        cd "/home/$user/.mozilla/$b/$profiledir" || continue
        run_cleaner
      done < <(grep '^Path=' "$ini_path" | sed 's/Path=//')
    else
      echo -e "$(tput cr)$(tput cuf 45) [${RED}none${RST}]"
      sleep 0.1
    fi
  done

  # ------[ Chromium Variants ]------
  for b in chromium chromium-beta chromium-dev google-chrome google-chrome-beta google-chrome-unstable; do
    echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
    local config_path="/home/$user/.config/$b/Default"

    if [[ -d "$config_path" ]]; then
      echo -e "$(tput cr)$(tput cuf 45) [${GRN}found${RST}]"
      if_running "$b"
      cd "/home/$user/.config/$b" || continue

      while read -r profiledir; do
        echo -e "[${YLW}${profiledir##'./'}${RST}]"
        cd "/home/$user/.config/$b/$profiledir" || continue
        run_cleaner
      done < <(find . -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \))
    else
      echo -e "$(tput cr)$(tput cuf 45) [${RED}none${RST}]"
      sleep 0.1
    fi
  done

  # ------[ Brave Variants ]------
  for b in Brave-Browser-Beta Brave-Browser; do
    echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
    local brave_path="/home/$user/.config/BraveSoftware/$b/Default"

    if [[ -d "$brave_path" ]]; then
      echo -e "$(tput cr)$(tput cuf 45) [${GRN}found${RST}]"
      if_running "brave"
      dep_check_all
      cd "/home/$user/.config/BraveSoftware/$b" || continue

      while read -r profiledir; do
        echo -e "[${YLW}${profiledir##'./'}${RST}]"
        cd "/home/$user/.config/BraveSoftware/$b/$profiledir" || continue
        run_cleaner
      done < <(find . -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \))
    else
      echo -e "$(tput cr)$(tput cuf 45) [${RED}none${RST}]"
      sleep 0.1
    fi
  done

  echo "Browser vacuuming complete."
}

# --------------[ Main Entrypoint ]-----------------------------
main() {
  # Optional: discourage running as root
  if [[ $EUID -eq 0 ]]; then
    echo -e "${YLW}Warning:${RST} Running as root can cause permission problems. Continue? (y/n)"
    read -r ans
    [[ ! "$ans" =~ ^[Yy](es)?$ ]] && exit 1
  fi

  # 1) Vacuum browsers
  vacuum_browsers

  # 2) Perform extra Brave cleanup if applicable
  perform_brave_cleanup

  echo -e "\n${GRN}BraveClean complete.${RST} Enjoy your tidy browser!"
}

# Execute main if this script is run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
