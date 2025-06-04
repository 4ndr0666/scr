#!/bin/bash
# shellcheck disable=all

echo "Btrfs Snapshot Management Script"
echo "================================="

# Function to create a read-only snapshot
create_snapshot() {
    local snapshot_dir=$1
    local current_date=$(date +%Y-%m-%d-%H%M%S)
    local snapshot_name="system_backup_${current_date}"

    sudo btrfs subvolume snapshot -r / "${snapshot_dir}/${snapshot_name}"
    echo "Snapshot created at ${snapshot_dir}/${snapshot_name}"
}

# Function to send a snapshot to external storage
send_snapshot() {
    local snapshot_path=$1
    local external_storage_path=$2

    sudo btrfs send "${snapshot_path}" | gzip > "${external_storage_path}/${snapshot_name}.img.gz"
    echo "Snapshot sent to ${external_storage_path}/${snapshot_name}.img.gz"
}

# Function to restore from a snapshot
restore_snapshot() {
    local snapshot_path=$1

    echo "Restoring from ${snapshot_path}..."
    # Placeholder for restoration commands
}

# Main menu
while true; do
    echo "1) Create a new snapshot"
    echo "2) Send a snapshot to external storage"
    echo "3) Restore from a snapshot"
    echo "4) Exit"
    read -rp "Enter your choice [1-4]: " choice

    case $choice in
        1)
            read -rp "Enter the directory to store the snapshot: " snapshot_dir
            create_snapshot "${snapshot_dir}"
            ;;
        2)
            read -rp "Enter the full path of the snapshot: " snapshot_path
            read -rp "Enter the external storage path: " external_storage_path
            send_snapshot "${snapshot_path}" "${external_storage_path}"
            ;;
        3)
            read -rp "Enter the full path of the snapshot to restore: " snapshot_path
            restore_snapshot "${snapshot_path}"
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
