#!/bin/bash

# Enable strict error handling
set -euo pipefail

log_file="/var/log/freecache.log"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "${@:-}"
fi

# Create log directory and file with appropriate error handling
mkdir -p "/var/log" || { echo "Failed to create log directory"; exit 1; }
touch "$log_file" || { echo "Failed to create log file"; exit 1; }

# Adjust the system's swappiness value
adjust_swappiness() {
    local target_swappiness=10
    if sysctl vm.swappiness="$target_swappiness" >/dev/null 2>&1; then
        log_action "Swappiness adjusted to $target_swappiness."
    else
        log_action "Failed to adjust swappiness."
    fi
}

# Clear the RAM cache if free memory is below 500MB
clear_ram_cache() {
    local free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    if [[ -z "$free_ram_mb" ]]; then
        free_ram_mb=0
    fi

    if [ "$free_ram_mb" -lt 500 ]; then
        echo 3 > /proc/sys/vm/drop_caches
        log_action "RAM cache cleared due to low free memory: $free_ram_mb MB."
    else
        log_action "Sufficient free memory: $free_ram_mb MB. No cache clearing needed."
    fi
}

# Clear swap if more than 80% is in use
clear_swap() {
    local swap_total=$(free | awk '/^Swap:/{print $2}')
    local swap_used=$(free | awk '/^Swap:/{print $3}')
    local swap_usage_percent=0

    if [ "$swap_total" -gt 0 ]; then
        swap_usage_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total) * 100}")
    fi

    if [ "$swap_usage_percent" -gt 80 ]; then
        swapoff -a && swapon -a
        log_action "Swap cleared due to high usage ($swap_usage_percent%)."
    else
        log_action "Swap usage is under control ($swap_usage_percent%)."
    fi
}

# Kill processes using more than 10% of memory if total memory usage exceeds 80%
kill_memory_hogs() {
    local mem_threshold=80
    local current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Killing memory hogs..."

        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            local mem_usage=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_usage" -gt 10 ]; then
                kill -9 "$pid" && log_action "Killed process $cmd (PID $pid) using $mem% memory."
            fi
        done
    else
        log_action "Memory usage is under control at $current_mem_usage%."
    fi
}

# Execute the functions
adjust_swappiness
clear_ram_cache
clear_swap
kill_memory_hogs

# Log memory and swap usage after all operations
log_action "Memory and Swap Usage After Operations:"
free -h | tee -a "$log_file"
