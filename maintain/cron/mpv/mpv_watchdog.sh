#!/bin/bash
# shellcheck disable=all

# Define the maximum number of mpv instances allowed
max_instances=3

# Directory where mpv sockets are stored
socket_dir="/tmp/mpvSockets"

# Check if the socket directory exists
if [[ ! -d "$socket_dir" ]]; then
    echo "Socket directory not found."
    exit 1
fi

# Ensure there are sockets to manage
sockets=($(ls -tr $socket_dir/* 2>/dev/null))
if [[ ${#sockets[@]} -eq 0 ]]; then
    echo "No mpv instances found."
    exit 0
fi


# Get a list of mpv sockets sorted by modification time (oldest first)
sockets=($(ls -tr $socket_dir/*))

# Calculate the number of mpv instances to kill
num_to_kill=$((${#sockets[@]} - max_instances))

# Kill excess mpv instances
for ((i=0; i<num_to_kill; i++)); do
    echo '{ "command": ["set_property", "quit", true] }' | netcat -U "${sockets[i]}"
done

echo "Killing mpv instance with PID: $pid at socket ${sockets[i]}"

# This script will maintain up to 3 newest mpv instances and quit older ones
