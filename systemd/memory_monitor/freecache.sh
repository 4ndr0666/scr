#!/bin/bash

# Set robust error handling
set -euo pipefail

log_file="/var/log/freecache.log"

# Ensure the logging directory and file exist
mkdir -p "$(dirname "$log_file")"
touch "$log_file"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Check for sudo availability
if ! command -v sudo &> /dev/null; then
    echo "sudo command not found. This script requires sudo to run."
    exit 1
fi

# Automatically escalate privileges if not run as root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

adjust_swappiness() {
    local current_swappiness=$(sysctl vm.swappiness | awk '{print $3}')
    local target_swappiness=60
    local free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')

    if [[ "$free_ram_mb" -lt 1000 ]]; then
        target_swappiness=80
    elif [[ "$free_ram_mb" -gt 2000 ]]; then
        target_swappiness=40
    fi

    if [[ "$current_swappiness" -ne "$target_swappiness" ]]; then
        sysctl vm.swappiness="$target_swappiness"
        log_action "Swappiness adjusted to $target_swappiness."
    fi
}

clear_ram_cache() {
    local free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')

    if [ "$free_ram_mb" -lt 500 ]; then
        echo 3 > /proc/sys/vm/drop_caches
        log_action "RAM cache cleared due to low free memory."
    fi
}

clear_swap() {
    local swap_usage_percent=$(free | awk '/^Swap:/{printf "%.0f", $3/$2 * 100}')

    if [ "$swap_usage_percent" -gt 80 ]; then
        swapoff -a && swapon -a
        log_action "Swap cleared due to high swap usage."
    fi
}

# Main
adjust_swappiness
clear_ram_cache
clear_swap

# Log final state
log_action "Memory and Swap Usage After Operations:"
free -h | tee -a "$log_file"
