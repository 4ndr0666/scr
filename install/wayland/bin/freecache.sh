#!/usr/bin/env bash
# shellcheck disable=all
# File: freecache.sh
# Author: 4ndr0666
set -euo pipefail

# === // FREECACHE.SH //
## Auto-escalete:
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

## Logging:
#LOG_FILE="/home/andro/.local/share/logs/freecache.log"

log_action() {
    echo "$1" | systemd-cat -t freecache
}

#mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory"; exit 1; }
#touch "$LOG_FILE" || { echo "Failed to create log file"; exit 1; }

## System Swap:
adjust_swappiness() {
    local target_swappiness=10
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}
    sysctl -w vm.swappiness="$target_swappiness" || {
        log_action "Error: Failed to set swappiness."
        exit 1
    }
    log_action "Swappiness adjusted to $target_swappiness. Free memory: ${free_ram_mb}MB"
}

# RAM Cache:
###  Clears if free memory is below 800MB
clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}

    if [ "$free_ram_mb" -lt 800 ]; then
        echo 3 >/proc/sys/vm/drop_caches || {
            log_action "Error: Failed to drop caches."
            exit 1
        }
        log_action "RAM cache cleared due to low free memory (${free_ram_mb}MB)."
    fi
}

## Swap:
### Clear swap if more than 65% is in use
clear_swap() {
    local swap_total swap_used swap_usage_percent

    swap_total=$(free | awk '/^Swap:/{print $2}')
    swap_used=$(free | awk '/^Swap:/{print $3}')

    if [[ -z "$swap_total" || -z "$swap_used" || "$swap_total" -eq 0 ]]; then
        swap_usage_percent=0
    else
        swap_usage_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total) * 100}")
    fi

    if [ "$swap_usage_percent" -gt 65 ]; then
        if swapoff -a && swapon -a; then
            log_action "Swap cleared due to high swap usage (${swap_usage_percent}%)."
        else
            log_action "Error: Failed to clear swap."
            exit 1
        fi
    fi
}

## Memory:
### Kill processes using more than 10% of memory if total memory usage exceeds 65%
kill_memory_hogs() {
    local mem_threshold=65
    local current_mem_usage
    current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Initiating process termination..."

		for process in thunar mpv alacritty; do
            pkill -f "$process" && log_action "Terminated $process to free up memory."
        done

        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            mem_int=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_int" -gt 10 ]; then
                kill "$pid" && log_action "Sent SIGTERM to $cmd (PID $pid) using $mem% memory."
            fi
        done
    fi
}

## Main Entry Point:
adjust_swappiness
clear_ram_cache
clear_swap
kill_memory_hogs
free -h
