#!/bin/bash

# --- // Trigger-OOM-Killer //
trigger_oom_killer() {
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$0" "$@"
        exit $?
    fi
    echo "f" > /proc/sysrq-trigger && notify-send "OOM Killer Executed!" || echo "Failed to trigger OOM Killer."
}

trigger_oom_killer
