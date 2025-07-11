#!/bin/bash
# shellcheck disable=all
#File: skelrefresh.sh
#Author: 4ndr0666
#Date: 04-12-2024
#
# --- // SKELREFRESH.SH // ========


# --- // CONSTANTS:
#tput setaf 2 = green
#tput setaf 6 = cyan
name=$(id -u) || exit 1

if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# --- // MAIN:
tput setaf 6
echo "--- // skelrefresh.sh // ---"
sleep 2
echo "Backing up current configs in hidden dir \"$name\"_config_backup to the /home..."
cp -Rf ~/.config ~/."$name"_config_backup-"$(date +%Y.%m.%d-%H.%M.%S)"
sleep 2
echo "Resetting \"$name\"'s configs based on skel..."
cp -arf /etc/skel/. ~
sleep 2 
tput sgr0
tput setaf 2
echo "Completed."
tput sgr0

