#!/bin/bash
while true; do
    FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
    FREE_RAM=${FREE_RAM:-0}  # Default to 0 if undefined
    if [ "$FREE_RAM" -lt 1000 ]; then
        touch /tmp/low_memory
    else
        rm -f /tmp/low_memory
    fi
    sleep 60
done
