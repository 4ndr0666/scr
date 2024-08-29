#!/bin/bash

# Set robust error handling
set -euo pipefail

log_file="/var/log/freecache.log"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Automatically escalate privileges if not run as root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Ensure the logging directory and file exist, now that we have root privileges
mkdir -p "$(dirname "$log_file")"
touch "$log_file"

adjust_swappiness() {
    local target_swappiness=10
    sysctl vm.swappiness="$target_swappiness"
    log_action "Swappiness adjusted to $target_swappiness."
}

clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')

    if [ "$free_ram_mb" -lt 500 ]; then
        echo 3 > /proc/sys/vm/drop_caches
        log_action "RAM cache cleared due to low free memory."
    fi
}

clear_swap() {
    local swap_total
    local swap_used
    local swap_usage_percent

    swap_total=$(free | awk '/^Swap:/{print $2}')
    swap_used=$(free | awk '/^Swap:/{print $3}')

    if [ "$swap_total" -ne 0 ]; then
        swap_usage_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total) * 100}")
        if [ "$swap_usage_percent" -gt 80 ]; then
            swapoff -a && swapon -a
            log_action "Swap cleared due to high swap usage."
        fi
    fi
}

kill_memory_hogs() {
    local mem_threshold=80
    local current_mem_usage
    current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Killing memory hogs..."
        # Identify and kill the top memory-consuming processes
        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            if [ "$(echo $mem | cut -d. -f1)" -gt 10 ]; then
                kill -9 "$pid"
                log_action "Killed process $cmd (PID $pid) using $mem% memory."
            fi
        done
    fi
}

# Main
adjust_swappiness
clear_ram_cache
clear_swap
kill_memory_hogs

# Log final state
log_action "Memory and Swap Usage After Operations:"
free -h | tee -a "$log_file"
