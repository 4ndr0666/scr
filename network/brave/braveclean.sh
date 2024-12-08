#!/usr/bin/env bash
# Author: (Your Name)
# Date: (Date)
# Description: Vacuum and reindex SQLite DBs for Firefox, Chrome, Brave, and related browsers.
#              Gracefully handles browser shutdown prompts and environment checks.

set -euo pipefail
IFS=$'\n\t'

# ========================== COLORS ==========================
RED="\e[01;31m"
GRN="\e[01;32m"
YLW="\e[01;33m"
RST="\e[00m"

# ========================== GLOBAL VARS ======================
total=0

# ========================== DEPENDENCY CHECK ================
dep_check() {
  local deps=(bc find sqlite3 xargs file stat rm head rsync pgrep awk grep sed)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      echo "Error: Required dependency '$dep' is not installed. Aborting." >&2
      exit 1
    fi
  done
}

# ========================== SPINNER ==========================
# spinner <pid>
# Displays a spinner while process with PID <pid> is running.
spinner() {
    local pid=$1
    local chars="oO0o.."
    local delay=0.05
    echo -en "\e[00;31m "
    while kill -0 "$pid" 2>/dev/null; do
        for c in $(echo "$chars" | grep -o .); do
            printf "%c" "$c"
            sleep $delay
            printf "\b"
        done
    done
    echo -en "\e[00m"
}

# ========================== RUN CLEANER ======================
run_cleaner() {
    local db_found=false
    # Find SQLite databases in current directory
    # Using 'file' to detect SQLite DB; ensuring maxdepth=1 to avoid deep scans
    mapfile -t dbs < <(find . -maxdepth 1 -type f -print0 | xargs -0 file | sed -n "s/:.*SQLite.*//p")

    if (( ${#dbs[@]} == 0 )); then
        echo "No SQLite databases found to vacuum."
        return 0
    fi

    for db in "${dbs[@]}"; do
        db_found=true
        db=${db#./} # Remove leading ./ if present
        echo -en "${GRN}Cleaning${RST}  ${db}"
        s_old=$(stat -c%s "$db" 2>/dev/null || echo "4096")
        (
            trap '' INT TERM
            rm -f "${db}-wal" "${db}-shm" 2>/dev/null || true
            sqlite3 "$db" "VACUUM;"
            sqlite3 "$db" "REINDEX;"
        ) & spinner $!
        wait || true
        s_new=$(stat -c%s "$db" 2>/dev/null || echo "$s_old")
        diff=$(((s_old - s_new) / 1024))
        total=$((total + diff))
        if ((diff > 0)); then
            diff_msg="\e[01;33m- ${diff}${RST} KB"
        elif ((diff < 0)); then
            diff_msg="\e[01;30m+ $((diff * -1)) KB${RST}"
        else
            diff_msg="\e[00;33m∘${RST}"
        fi
        echo -e " ${GRN}done${RST} ${diff_msg}"
    done

    $db_found || echo "No DBs processed."
    echo
}

# ========================== IF_RUNNING =======================
# Waits for a browser process to exit or offers to kill it.
if_running() {
    local process_name="$1"
    local i=6 # Timeout in loops (each loop ~2s)
    # If browser is running, wait or prompt kill
    if pgrep -u "$user" "$process_name" &>/dev/null; then
        echo -n "Waiting for $process_name to exit"
        while pgrep -u "$user" "$process_name" &>/dev/null; do
            if ((i == 0)); then
                read -rp " kill it? [y|n]: " ans
                case "$ans" in
                    [Yy]*)
                        pkill -TERM -u "$user" "$process_name" || true
                        sleep 4
                        if pgrep -u "$user" "$process_name" &>/dev/null; then
                            pkill -KILL -u "$user" "$process_name" || true
                        fi
                        break
                        ;;
                    *)
                        echo "Please close the browser manually and re-run the script."
                        exit 1
                        ;;
                esac
            fi
            echo -n "."
            sleep 2
            ((i--))
        done
        echo
    fi
}

# ========================== MAIN LOGIC =======================
dep_check

# Determine which user(s) to run against
priv="$USER"
if [[ "$EUID" = 0 ]]; then
    # If root, run against all users with home directories
    priv=$(find /home -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
fi

for user in $priv; do
    # Ensure user's home directory exists
    user_home="/home/$user"
    [[ -d "$user_home" ]] || continue

    # FIREFOX/ICECAT/SEAMONKEY/AURORA
    for b in firefox icecat seamonkey aurora; do
        echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
        ini="$user_home/.mozilla/$b/profiles.ini"
        if [[ -f "$ini" ]]; then
            echo " [${GRN}found${RST}]"
            if_running "$b"
            # Extract profiles from profiles.ini
            mapfile -t mozilla_profiles < <(grep '^Path=' "$ini" | sed 's/Path=//')
            for profiledir in "${mozilla_profiles[@]}"; do
                # If profile directory doesn't exist, skip
                if [[ ! -d "$user_home/.mozilla/$b/$profiledir" ]]; then
                    echo "Profile directory '$profiledir' not found, skipping."
                    continue
                fi
                echo -e "[${YLW}${profiledir##'./'}${RST}]"
                cd "$user_home/.mozilla/$b/$profiledir" || continue
                run_cleaner
            done
        else
            echo " [${RED}none${RST}]"
        fi
    done

    # CHROMIUM/GOOGLE-CHROME
    for b in chromium chromium-beta chromium-dev google-chrome google-chrome-beta google-chrome-unstable; do
        echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
        base_dir="$user_home/.config/$b"
        if [[ -d "$base_dir/Default" ]]; then
            echo " [${GRN}found${RST}]"
            if_running "$b"
            # Profiles: Default and Profile*
            mapfile -t chrome_profiles < <(find "$base_dir" -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \) -printf '%f\n')
            for profiledir in "${chrome_profiles[@]}"; do
                echo -e "[${YLW}${profiledir}${RST}]"
                cd "$base_dir/$profiledir" || continue
                run_cleaner
            done
        else
            echo " [${RED}none${RST}]"
        fi
    done

    # BRAVE
    for b in Brave-Browser-Beta Brave-Browser; do
        echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
        brave_dir="$user_home/.config/BraveSoftware/$b"
        if [[ -d "$brave_dir/Default" ]]; then
            echo " [${GRN}found${RST}]"
            if_running "brave"
            # Profiles: Default and Profile*
            mapfile -t brave_profiles < <(find "$brave_dir" -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \) -printf '%f\n')
            for profiledir in "${brave_profiles[@]}"; do
                echo -e "[${YLW}${profiledir}${RST}]"
                cd "$brave_dir/$profiledir" || continue
                run_cleaner
            done
        else
            echo " [${RED}none${RST}]"
        fi
    done

done

if ((total > 0)); then
    echo -e "Total Space Cleaned: ${YLW}${total}${RST} KB"
else
    echo "Nothing done."
fi
