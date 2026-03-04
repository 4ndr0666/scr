#!/bin/bash
# 4NDR0666OS - Port Termination Utility
# Version: 1.5.0
# Description: Interactively identify and kill processes listening on TCP ports.

set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check Root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Root privileges required to view/kill all processes.${NC}"
    # We continue, but warn, as user might only want to kill their own procs.
fi

echo -e "${CYAN}[*] Scanning TCP Listening Ports...${NC}"

# Get listening ports formatted as "Port:ProcessName(PID)"
# lsof flags: -P (no port names), -n (no host names), -iTCP -sTCP:LISTEN
mapfile -t LISTENING_OPTS < <(lsof -PniTCP -sTCP:LISTEN -F pcLn | \
    awk '
    /^p/ {pid=substr($0,2)} 
    /^c/ {cmd=substr($0,2)} 
    /^n/ {
        split($0, a, ":"); 
        port=a[length(a)]; 
        print port " : " cmd " (" pid ")"
    }' | sort -n -u)

if [ ${#LISTENING_OPTS[@]} -eq 0 ]; then
    echo -e "${RED}[-] No listening TCP ports found or permission denied.${NC}"
    exit 0
fi

PS3=$'\n'"${GREEN}Select a target to terminate (or Ctrl+C to exit): ${NC}"

select opt in "${LISTENING_OPTS[@]}"; do
    if [ -n "$opt" ]; then
        # Extract Port and PID from the selection string "80 : nginx (1234)"
        PORT=$(echo "$opt" | awk '{print $1}')
        PID=$(echo "$opt" | awk -F'[()]' '{print $2}')
        PROC_NAME=$(echo "$opt" | awk '{print $3}')

        echo -e "${RED}[*] TARGET ACQUIRED:${NC} $PROC_NAME (PID: $PID) on Port $PORT"
        read -p "Confirm termination? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill -9 "$PID"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[+] Target eliminated.${NC}"
            else
                echo -e "${RED}[-] Failed to kill PID $PID. Check permissions.${NC}"
            fi
            break
        else
            echo -e "${CYAN}[*] Engagement cancelled.${NC}"
            break
        fi
    else
        echo -e "${RED}[!] Invalid selection.${NC}"
    fi
done
