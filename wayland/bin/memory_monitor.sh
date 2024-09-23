#!/bin/bash
while true; do
    FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
    if [ "$FREE_RAM" -lt 1000 ]; then
        touch /tmp/low_memory
    else
        rm -f /tmp/low_memory
    fi
    sleep 60
done
