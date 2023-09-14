#!/bin/bash
set -e

# Set swappiness to 60
sudo sysctl vm.swappiness=60

# Get free memory in MB
FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')

# If free RAM is less than 500MB, clear cache
if [ "$FREE_RAM" -lt 500 ]; then
    sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
    echo "RAM cache cleared due to low free memory."
fi

# Get swap usage percentage
SWAP_USAGE=$(free | awk '/^Swap:/{printf "%.0f", $3/$2 * 100}')

# If swap usage is more than 80%, clear swap
if [ "$SWAP_USAGE" -gt 80 ]; then
    sudo swapoff -a && sudo swapon -a
    echo "Swap cleared due to high swap usage."
fi

# Display memory and swap usage after operations
echo "Memory and Swap Usage After Operations:"
free -h
