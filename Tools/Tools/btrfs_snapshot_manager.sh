#!/bin/bash

# Define the mount points and snapshot directory
BTRFS_PARTITION="/dev/sdd3"
MOUNT_POINT="/mnt/dev"
SNAPSHOT_DIR="$MOUNT_POINT/timeshift-btrfs/snapshots"
SUBVOLUMES=("@" "@cache" "@home" "@log")

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Function to mount the Btrfs partition
mount_btrfs() {
    echo "Mounting Btrfs partition..."
    mount $BTRFS_PARTITION $MOUNT_POINT
}

# Function to unmount the Btrfs partition
unmount_btrfs() {
    echo "Unmounting Btrfs partition..."
    umount $MOUNT_POINT
}

# Function to list available snapshots
list_snapshots() {
    echo "Available snapshots:"
    ls -Al $SNAPSHOT_DIR
}

# Function to restore from a snapshot
restore_snapshot() {
    local snapshot_name=$1

    # Ensure the snapshot exists
    if [ ! -d "$SNAPSHOT_DIR/$snapshot_name" ]; then
        echo "Snapshot $snapshot_name does not exist."
        exit 1
    fi

    # Unmount current subvolumes
    echo "Unmounting current subvolumes..."
    for subvol in "${SUBVOLUMES[@]}"; do
        if mountpoint -q "$MOUNT_POINT/$subvol"; then
            umount "$MOUNT_POINT/$subvol"
        fi
    done

    # Perform the restoration
    echo "Restoring snapshot $snapshot_name..."
    btrfs subvolume delete "$MOUNT_POINT/@"
    btrfs subvolume snapshot "$SNAPSHOT_DIR/$snapshot_name" "$MOUNT_POINT/@"

    # Remount subvolumes
    echo "Remounting subvolumes..."
    for subvol in "${SUBVOLUMES[@]}"; do
        mount -o subvol=$subvol $BTRFS_PARTITION "$MOUNT_POINT/$subvol"
    done

    echo "Snapshot $snapshot_name restored successfully."
}

# Main menu
while true; do
    echo "1) List available snapshots"
    echo "2) Restore from a snapshot"
    echo "3) Exit"
    read -rp "Enter your choice [1-3]: " choice

    case $choice in
        1)
            mount_btrfs
            list_snapshots
            unmount_btrfs
            ;;
        2)
            read -rp "Enter the snapshot name to restore: " snapshot_name
            mount_btrfs
            restore_snapshot "$snapshot_name"
            unmount_btrfs
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
