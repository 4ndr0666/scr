#!/usr/bin/env bash

# Define colors for output
RED="\e[01;31m"
GRN="\e[01;32m"
YLW="\e[01;33m"
RST="\e[00m"
format="$(tput cr)$(tput cuf 45)"
total=0

# Spinner for indicating progress
spinner() {
    local _format="$(tput cr)$(tput cuf 51)"
    local str="oO0o.." tmp
    echo -en "$_format"
    while [[ -d /proc/$1 ]]; do
        tmp=${str#?}
        printf "\e[00;31m %c " "$str"
        str="$tmp${str%$tmp}"
        sleep 0.05
        printf "\b\b\b"
    done
    printf "  \b\b\e[00m"
}

# Function to clean databases by vacuuming and reindexing
run_cleaner() {
    local _format="$(tput cr)$(tput cuf 46)"
    while read -r db; do
        echo -en "${GRN} Cleaning${RST}  ${db##'./'}"
        # Record size of each file before and after vacuuming
        s_old=$(stat -c%s "$db" 2>/dev/null) || s_old=4096
        (
            trap '' INT TERM
            # Remove possible locks
            rm -f "${db}-wal" "${db}-shm"
            sqlite3 "$db" "VACUUM;" && sqlite3 "$db" "REINDEX;"
        ) & spinner $!
        wait
        s_new=$(stat -c%s "$db")
        # Convert to kilobytes
        diff=$(((s_old - s_new) / 1024))
        total=$((diff + total))
        if ((diff > 0)); then
            diff="\e[01;33m- ${diff}${RST} KB"
        elif ((diff < 0)); then
            diff="\e[01;30m+ $((diff * -1)) KB${RST}"
        else
            diff="\e[00;33m∘${RST}"
        fi
        echo -e "${_format} ${GRN}done ${diff}"
    done < <(find . -maxdepth 1 -type f -print0 | xargs -0 file -e ascii | sed -n "s/:.*SQLite.*//p")
    echo
}

dep_check() {
  for dep in bc find sqlite3 xargs; do
    if ! command -v "$dep" > /dev/null 2>&1; then
      echo "I require $dep but it's not installed. Aborting." >&2
      exit 1
    fi
  done
}

# Function to check if a browser is running
if_running() {
    local process_name="$1"
    i=6 # Timeout for process termination
    if pgrep -u "$user" "$process_name" > /dev/null; then
        echo -n "Waiting for $process_name to exit"
    fi

    # Wait for the browser to terminate
    while pgrep -u "$user" "$process_name" > /dev/null; do
        if ((i == 0)); then
            read -p " kill it? [y|n]: " ans
            if [[ "$ans" =~ ^(y|Y|yes)$ ]]; then
                pkill -TERM -u "$user" "$process_name"
                sleep 4
                if pgrep -u "$user" "$process_name" > /dev/null; then
                    pkill -KILL -u "$user" "$process_name"
                fi
                break
            else
                echo "Please close the browser manually and re-run the script."
                exit 1
            fi
        fi
        echo -n "."
        sleep 2
        ((i--))
    done
}

# If ran with sudo, then run against all users on system
priv="$USER"
[[ "$EUID" = 0 ]] &&
    # Assumes user names are same as the user's home directory
    priv=$(find /home -maxdepth 1 -type d | tail -n+2 | cut -c7-)

# Iterate through each user to perform cleanup
for user in $priv; do

    # [FIREFOX ICECAT SEAMONKEY]
    for b in {firefox,icecat,seamonkey,aurora}; do
        echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
        if [[ -f "/home/$user/.mozilla/$b/profiles.ini" ]]; then
            echo -e "$format [${GRN}found${RST}]"
            if_running "$b"
            while read -r profiledir; do
                echo -e "[${YLW}$(echo "$profiledir" | cut -d'.' -f2)${RST}]"
                cd "/home/$user/.mozilla/$b/$profiledir" || continue
                run_cleaner
            done < <(grep Path "/home/$user/.mozilla/$b/profiles.ini" | sed 's/Path=//')
        else
            echo -e "$format [${RED}none${RST}]"
            sleep 0.1
            tput cuu 1
            tput el
        fi
    done

    # [CHROMIUM GOOGLE-CHROME]
    for b in {chromium,chromium-beta,chromium-dev,google-chrome,google-chrome-beta,google-chrome-unstable}; do
        echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
        if [[ -d "/home/$user/.config/$b/Default" ]]; then
            cd "/home/$user/.config/$b" || continue
            echo -e "$format [${GRN}found${RST}]"
            if_running "$b"
            while read -r profiledir; do
                echo -e "[${YLW}${profiledir##'./'}${RST}]"
                cd "/home/$user/.config/$b/$profiledir" || continue
                run_cleaner
            done < <(find . -maxdepth 1 -type d -iname "Default" -o -iname "Profile*")
        else
            echo -e "$format [${RED}none${RST}]"
            sleep 0.1
            tput cuu 1
            tput el
        fi
    done

    # [BRAVE]
    for b in {BraveSoftware/Brave-Browser,Brave-Browser,Brave-Browser-Beta,Brave-Browser-Nightly}; do
        echo -en "[${YLW}$user${RST}] ${GRN}Scanning for $b${RST}"
        if [[ -d "/home/$user/.config/$b/Default" ]]; then
            echo "Debug: Entering Brave directory: /home/$user/.config/$b"
            cd "/home/$user/.config/$b" || continue
            echo -e "$format [${GRN}found${RST}]"
            if_running "brave"
            while read -r profiledir; do
                echo -e "[${YLW}${profiledir##'./'}${RST}]"
                cd "/home/$user/.config/$b/$profiledir" || continue
		dep_check
                run_cleaner
            done < <(find . -maxdepth 1 -type d -iname "Default" -o -iname "Profile*")
        else
            echo "Debug: Brave directory not found: /home/$user/.config/$b/Default"
            echo -e "$format [${RED}none${RST}]"
            sleep 0.1
            tput cuu 1
            tput el
        fi
    done

done

((total > 0)) && echo -e "Total Space Cleaned: ${YLW}${total}${RST} KB" || echo "Nothing done."
