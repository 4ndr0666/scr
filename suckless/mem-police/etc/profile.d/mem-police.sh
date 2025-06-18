#!/bin/sh
# /etc/profile.d/mem-police.sh
# Starts mem-police as root on login, if not already running.

if [ "$(id -u)" -eq 0 ]; then
    if ! pgrep -x mem-police >/dev/null 2>&1; then
        /usr/local/bin/mem-police &
    fi
fi
