#!/usr/bin/env bash
# shellcheck disable=all

#set -e

# 1. Check for root; if not, re-invoke with sudo -E
if [ "$(id -u)" -ne 0 ]; then
    sudo -E "$0" "$@"
    exit $?
fi

# 2. Ensure /proc/sysrq-trigger is writable
[ -w /proc/sysrq-trigger ]

# 3. Trigger the OOM killer
echo f > /proc/sysrq-trigger

# 4. Notify user on success
notify-send "OOM Killer Triggered" "System OOM killer triggered successfully"
