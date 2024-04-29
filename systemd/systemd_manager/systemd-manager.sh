#!/bin/bash

# Comprehensive Systemd Management Tool
# This script provides advanced management for systemd units with features to manage, snapshot, restore, and manipulate unit states, covering a wide range of systemctl functionalities.


if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Check for fzf installation for interactive selection
if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install fzf to use this tool."
    exit 1
fi

# Define the directory for systemd state snapshots
STATE_DIR="/etc/systemd/state_snapshots"
mkdir -p "$STATE_DIR"

# Function to capture the current state of all systemd units
function snapshot_state() {
    echo "Snapshotting current systemd state..."
    systemctl list-unit-files --no-legend | awk '{print $1 " " $2}' > "$STATE_DIR/snapshot_$(date +%Y%m%d_%H%M%S).conf"
    echo "Snapshot saved in $STATE_DIR."
}

# Function to restore systemd state from a selected snapshot
function restore_state() {
    echo "Available snapshots in $STATE_DIR:"
    local snapshot=$(ls "$STATE_DIR" | fzf --prompt='Select a snapshot to restore: ')
    if [[ -z "$snapshot" ]]; then
        echo "No snapshot selected. Operation cancelled."
        return
    fi

    echo "Restoring state from $snapshot..."
    while IFS=' ' read -rp unit state; do
        sudo systemctl "$state" "$unit"
    done < "$STATE_DIR/$snapshot"
    echo "System state restored from snapshot."
}

# Function to manage systemd units interactively with full command integration
function manage_systemd() {
    # Full array of systemd commands including power management and system states
    local all_commands=(
        cat get-default help is-active is-enabled is-failed is-system-running
        list-dependencies list-jobs list-sockets list-timers list-unit-files
        list-units show show-environment status add-requires add-wants cancel
        daemon-reexec daemon-reload default disable edit emergency enable halt
        import-environment isolate kexec kill link list-machines load mask
        preset preset-all reenable reload reload-or-restart reset-failed rescue
        restart revert set-default set-environment set-property start stop
        switch-root try-reload-or-restart try-restart unmask unset-environment
        hibernate hybrid-sleep poweroff reboot suspend snapshot restore
    )

    echo "Available systemd commands:"
    local command=$(printf '%s\n' "${all_commands[@]}" | fzf --prompt='Select a command: ')

    # Handle snapshot and restore commands separately
    case "$command" in
        snapshot)
            snapshot_state
            ;;
        restore)
            restore_state
            ;;
        *)
            # Handle other systemctl commands
            if [[ -n "$command" && ! "$command" =~ ^(halt|poweroff|reboot|suspend|hibernate|hybrid-sleep|isolate|switch-root)$ ]]; then
                local unit=$(systemctl list-unit-files --type=service --no-legend | awk '{print $1}' | fzf --prompt='Select a unit: ')
                if [[ -n "$unit" ]]; then
                    echo "Executing command: $command on unit: $unit"
                    sudo systemctl $command "$unit"
                else
                    echo "No unit selected. Exiting."
                fi
            else
                echo "Executing system-wide command: $command"
                sudo systemctl $command
            fi
            ;;
    esac
}

# Main execution block
echo "Systemd Management Console Initialized..."
manage_systemd
