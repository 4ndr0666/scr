#!/bin/bash
set -e


# Function to set up a cron job
setup_cron_job() {
    local script_path="$(realpath "$0")"
    local cron_job="*/30 * * * * $script_path >> /path/to/freecache.log 2>&1"

    # Check if the cron job already exists
    if ! crontab -l | grep -Fq "$script_path"; then
        # Add the cron job
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "Cron job added: $cron_job"
    else
        echo "Cron job already exists."
    fi
}

# Adjust swappiness dynamically based on system conditions
adjust_swappiness() {
    local current_swappiness=$(sysctl vm.swappiness | awk '{print $3}')
    local target_swappiness=60
    if [[ "$FREE_RAM" -lt 1000 ]]; then
        target_swappiness=80
    elif [[ "$FREE_RAM" -gt 2000 ]]; then
        target_swappiness=40
    fi
    [[ "$current_swappiness" -ne "$target_swappiness" ]] && sudo sysctl vm.swappiness="$target_swappiness"
}

# Clear RAM cache if needed
clear_ram_cache() {
    if [ "$FREE_RAM" -lt 500 ]; then
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        echo "RAM cache cleared due to low free memory."
    fi
}

# Clear swap if needed
clear_swap() {
    if [ "$SWAP_USAGE" -gt 80 ]; then
        read -p "High swap usage detected. Clear swap? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo swapoff -a && sudo swapon -a
            echo "Swap cleared."
        else
            echo "Swap clear canceled by user."
        fi
    fi
}

# Main logic
FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
SWAP_USAGE=$(free | awk '/^Swap:/{printf "%.0f", $3/$2 * 100}')

adjust_swappiness
clear_ram_cache
clear_swap

# Add cron job setup at the end of the script
if [[ "$1" != "--skip-cron" ]]; then
    setup_cron_job
fi


echo "Memory and Swap Usage After Operations:"
free -h

