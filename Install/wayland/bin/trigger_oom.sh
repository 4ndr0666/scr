#!/bin/bash

# --- // Trigger-OOM-Killer //
trigger() {
    if echo "f" > /proc/sysrq-trigger; then
#    if sudo sh -c 'echo "f" > /proc/sysrq-trigger'; then
        notify-send "OOM Killer Executed!"
    else
        notify-send "OOM Killer Failed!"
        return 1
    fi
}
trigger
