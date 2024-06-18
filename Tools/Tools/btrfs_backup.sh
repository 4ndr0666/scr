#!/bin/bash

validate() {
    command=$1
    echo "Running: $command"
    eval $command
    if [ $? -ne 0 ]; then
        echo "Error: Command failed - $command"
        exit 1
    fi
}

# Function to mount Btrfs subvolumes
btrfsmount() {
    read -rp "Enter the device (e.g., /dev/sdx): " device
    read -rp "Enter the mount point (e.g., /mnt/point): " mount_point
    echo "Mounting subvolumes to $mount_point..."
    validate "sudo mount -o defaults,subvol=@ $device $mount_point"
    validate "sudo mount -o defaults,subvol=@cache $device $mount_point/var/cache"
    validate "sudo mount -o defaults,subvol=@home $device $mount_point/home"
    validate "sudo mount -o defaults,subvol=@log $device $mount_point/var/log"
    sleep 2
    echo "Mounted!"
}

# Function to unmount Btrfs subvolumes
btrfsumount() {
    read -rp "Enter the mount point (e.g., /mnt/point): " mount_point
    echo "Unmounting subvolumes from $mount_point..."
    validate "sudo umount $mount_point/var/cache"
    validate "sudo umount $mount_point/home"
    validate "sudo umount $mount_point/var/log"
    validate "sudo umount $mount_point"
    sleep 2
    echo "Unmounted!"
}

# Function to make a snapshot read-only
rosnap() {
    read -rp "Enter the snapshot path (autocomplete is enabled): " -e snapshot_path
    snapshot_path=${snapshot_path:-$(pwd)}
    validate "sudo btrfs property set -ts $snapshot_path ro true"
    echo "Snapshot $snapshot_path is now read-only."
}

# Function to send a snapshot to external storage
sndsnap() {
    read -rp "Enter the snapshot path (autocomplete is enabled): " -e snapshot_path
    snapshot_path=${snapshot_path:-$(pwd)}
    read -rp "Enter the target directory for backup: " -e target_dir
    snapshot_name=$(basename "$snapshot_path")
    validate "sudo btrfs send $snapshot_path | gzip > $target_dir/$snapshot_name.img.gz"
    echo "Snapshot sent to $target_dir/$snapshot_name.img.gz successfully."
}

# Function to restore a snapshot from a gzip archive
restoresnap() {
    read -rp "Enter the path to the gzip file: " gz_file
    read -rp "Enter the target directory to restore to (must be a Btrfs volume): " target_dir

    # Check if the target directory is a Btrfs volume
    if [ "$(sudo findmnt -n -o FSTYPE -T $target_dir)" != "btrfs" ]; then
        echo "Error: Target directory is not a Btrfs volume."
        exit 1
    fi

    # Decompress the gzip file
    img_file="${gz_file%.gz}"
    echo "Decompressing $gz_file to $img_file..."
    validate "gunzip -c $gz_file > $img_file"

    # Restore the snapshot
    echo "Restoring snapshot to $target_dir..."
    validate "sudo btrfs receive $target_dir < $img_file"

    # Clean up decompressed image file
    rm -f $img_file
    echo "Snapshot restored successfully and temporary files cleaned up."
}

# Main menu
while true; do
    echo ""
    echo "Btrfs Snapshot Management Menu"
    echo "=============================="
    echo "1. Mount Btrfs subvolumes"
    echo "2. Unmount Btrfs subvolumes"
    echo "3. Make a snapshot read-only"
    echo "4. Send a snapshot to external storage"
    echo "5. Restore a snapshot from gzip archive"
    echo "6. Exit"
    read -rp "Enter your choice: " choice

    case $choice in
        1)
            btrfsmount
            ;;
        2)
            btrfsumount
            ;;
        3)
            rosnap
            ;;
        4)
            sndsnap
            ;;
        5)
            restoresnap
            ;;
        6)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done
