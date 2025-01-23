#!/bin/bash

set -euo pipefail

LOG_FILE="/home/andro/.local/share/logs/freecache.log"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "${@:-}"
fi

mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory"; exit 1; }
touch "$LOG_FILE" || { echo "Failed to create log file"; exit 1; }

adjust_swappiness() {
    local target_swappiness=10
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined
    sysctl -w vm.swappiness="$target_swappiness" || { echo "Error: Failed to set swappiness."; exit 1; }
    log_action "Swappiness adjusted to $target_swappiness. Free memory: ${free_ram_mb}MB"
}

# Clear the RAM cache if free memory is below 800MB
clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined

    if [ "$free_ram_mb" -lt 800 ]; then
        echo 3 > /proc/sys/vm/drop_caches || { echo "Error: Failed to drop caches."; exit 1; }
        log_action "RAM cache cleared due to low free memory (${free_ram_mb}MB)."
    fi
}

# Clear swap if more than 65% is in use
clear_swap() {
    local swap_total swap_used swap_usage_percent

    swap_total=$(free | awk '/^Swap:/{print $2}')
    swap_used=$(free | awk '/^Swap:/{print $3}')

    if [[ -z "$swap_total" || -z "$swap_used" || "$swap_total" -eq 0 ]]; then
        swap_usage_percent=0  # Set to 0 if swap values can't be determined
    else
        swap_usage_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total) * 100}")
    fi

    if [ "$swap_usage_percent" -gt 65 ]; then
        swapoff -a && swapon -a || { echo "Error: Failed to clear swap."; exit 1; }
        log_action "Swap cleared due to high swap usage (${swap_usage_percent}%)."
    fi
}

# Kill processes using more than 10% of memory if total memory usage exceeds 65%
kill_memory_hogs() {
    local mem_threshold=65
    local current_mem_usage
    current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Initiating process termination..."
        # Prioritize terminating Brave and Chromium first
        for process in brave chromium; do
            pkill -f "$process" && log_action "Terminated $process to free up memory."
        done
        # If memory usage still high, terminate other high-memory processes
        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            mem_int=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_int" -gt 10 ]; then
                kill "$pid" && log_action "Sent SIGTERM to process $cmd (PID $pid) using $mem% memory."
                sleep 5
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" && log_action "Sent SIGKILL to process $cmd (PID $pid) using $mem% memory."
                fi
            fi
        done
    fi
}

adjust_swappiness
clear_ram_cache
clear_swap
kill_memory_hogs

log_action "Memory and Swap Usage After Operations:"
free -h | tee -a "$LOG_FILE"
