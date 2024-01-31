#!/bin/bash
set -e

# AUTO_ESCALATE
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/freecache.log
}

adjust_swappiness() {
    local current_swappiness=$(sysctl vm.swappiness | awk '{print $3}')
    local target_swappiness=60
    if [[ "$FREE_RAM" -lt 1000 ]]; then
        target_swappiness=80
    elif [[ "$FREE_RAM" -gt 2000 ]]; then
        target_swappiness=40
    fi
    if [[ "$current_swappiness" -ne "$target_swappiness" ]]; then
        sudo sysctl vm.swappiness="$target_swappiness"
        log_action "Swappiness adjusted to $target_swappiness"
    fi
}

clear_ram_cache() {
    if [ "$FREE_RAM" -lt 500 ]; then
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        log_action "RAM cache cleared due to low free memory."
    fi
}

clear_swap() {
    if [ "$SWAP_USAGE" -gt 80 ]; then
        sudo swapoff -a && sudo swapon -a
        log_action "Swap cleared due to high swap usage."
    fi
}

FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
SWAP_USAGE=$(free | awk '/^Swap:/{printf "%.0f", $3/$2 * 100}')

adjust_swappiness
clear_ram_cache
clear_swap

log_action "Memory and Swap Usage After Operations:"
free -h | tee -a /var/log/freecache.log
