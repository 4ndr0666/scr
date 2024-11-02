#!/usr/bin/env bash

# --- Home Directory Manager ---

LOG_FILE="/var/log/home_manager.log"

# Function to log messages with timestamp
log_action() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to validate user input
validate_input() {
    local input="$1"
    if [[ -z "$input" ]]; then
        whiptail --msgbox "Invalid input. Please try again." 8 40
        return 1
    fi
    return 0
}

# Function to confirm action
confirm_action() {
    if ! whiptail --yesno "Are you sure you want to proceed?" 8 40; then
        whiptail --msgbox "Operation canceled." 8 40
        return 1
    fi
    return 0
}

# Function to display help
show_help() {
    whiptail --msgbox "Home Directory Manager

Usage:
  - Sync data from old home partition to new home directory.
  - Move large media files to backup directory.
  - Delete old partition.
  - Expand current home partition.
  - Convert ext4 partition to Btrfs.

Run the script without arguments to display the interactive menu." 15 60
}

# Module: Sync Data
sync_data() {
    local old_partition mount_point new_home
    old_partition=$(whiptail --inputbox "Enter the old home partition (e.g., /dev/sdXY):" 8 60 3>&1 1>&2 2>&3)
    validate_input "$old_partition" || return
    mount_point=$(whiptail --inputbox "Enter the mount point for the old partition (e.g., /mnt/old_home):" 8 60 3>&1 1>&2 2>&3)
    validate_input "$mount_point" || return
    new_home=$(whiptail --inputbox "Enter the path to the new home directory:" 8 60 "$HOME" 3>&1 1>&2 2>&3)
    validate_input "$new_home" || return

    if mount | grep -q "$mount_point"; then
        whiptail --msgbox "Mount point $mount_point is already in use." 8 40
    else
        sudo mount "$old_partition" "$mount_point" || { whiptail --msgbox "Failed to mount $old_partition" 8 40; return; }
    fi

    whiptail --infobox "Syncing data..." 8 40
    sudo rsync -a --ignore-existing --update --progress --recursive \
        --exclude='*.mp4' --exclude='*.png' --exclude='*.jpg' --exclude='*.mov' \
        --exclude='*.mkv' --exclude='*.gif' --exclude='*.zip' \
        "$mount_point/" "$new_home/" || { whiptail --msgbox "Data sync failed" 8 40; return; }

    sudo umount "$mount_point" || { whiptail --msgbox "Failed to unmount $mount_point" 8 40; return; }
    sudo chown -R "$USER:$USER" "$new_home" || { whiptail --msgbox "Failed to set ownership" 8 40; return; }

    whiptail --msgbox "Data sync completed." 8 40
    log_action "Data synced from $old_partition to $new_home."
}

# Module: Move Media
move_media() {
    local new_home media_backup
    new_home=$(whiptail --inputbox "Enter the path to the new home directory:" 8 60 "$HOME" 3>&1 1>&2 2>&3)
    validate_input "$new_home" || return
    media_backup=$(whiptail --inputbox "Enter the path to the media backup directory:" 8 60 "$HOME/media_backup" 3>&1 1>&2 2>&3)
    validate_input "$media_backup" || return

    mkdir -p "$media_backup" || { whiptail --msgbox "Failed to create backup directory" 8 40; return; }

    whiptail --infobox "Moving media files..." 8 40
    find "$new_home" -type f \( -iname "*.mp4" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.gif" -o -iname "*.zip" \) -exec mv {} "$media_backup/" \; || { whiptail --msgbox "No media files found to move" 8 40; }

    whiptail --msgbox "Media files moved to backup directory." 8 40
    log_action "Media files moved from $new_home to $media_backup."
}

# Module: Delete Old Partition
delete_partition() {
    local old_partition
    old_partition=$(whiptail --inputbox "Enter the old partition (e.g., /dev/sdXY):" 8 60 3>&1 1>&2 2>&3)
    validate_input "$old_partition" || return

    whiptail --msgbox "Warning: This will delete the old partition. Ensure you have backups." 8 60
    confirm_action || return

    whiptail --infobox "Deleting partition..." 8 40
    sudo parted "$old_partition" rm 1 || { whiptail --msgbox "Failed to delete partition" 8 40; return; }

    whiptail --msgbox "Old partition deleted." 8 40
    log_action "Deleted partition $old_partition."
}

# Module: Expand Home Partition
expand_home_partition() {
    local disk partition_number
    disk=$(whiptail --inputbox "Enter the disk (e.g., /dev/sdX):" 8 60 3>&1 1>&2 2>&3)
    validate_input "$disk" || return
    partition_number=$(whiptail --inputbox "Enter the partition number of the home directory:" 8 60 3>&1 1>&2 2>&3)
    validate_input "$partition_number" || return

    whiptail --msgbox "Warning: This will resize the partition. Ensure you have backups." 8 60
    confirm_action || return

    whiptail --infobox "Expanding home partition..." 8 40
    sudo parted "$disk" resizepart "$partition_number" 100% || { whiptail --msgbox "Failed to resize partition" 8 40; return; }
    sudo resize2fs "${disk}${partition_number}" || { whiptail --msgbox "Failed to resize filesystem" 8 40; return; }

    whiptail --msgbox "Home partition expanded." 8 40
    log_action "Expanded partition ${disk}${partition_number}."
}

# Module: Convert ext4 to Btrfs
convert_to_btrfs() {
    local ext4_partition
    ext4_partition=$(whiptail --inputbox "Enter the ext4 partition to convert (e.g., /dev/sdXY):" 8 60 3>&1 1>&2 2>&3)
    validate_input "$ext4_partition" || return

    whiptail --msgbox "Warning: This will convert the ext4 partition to Btrfs. Ensure you have backups." 8 60
    confirm_action || return

    sudo umount "$ext4_partition" || { whiptail --msgbox "Failed to unmount partition" 8 40; return; }
    sudo btrfs-convert "$ext4_partition" || { whiptail --msgbox "Conversion to Btrfs failed" 8 40; return; }

    whiptail --msgbox "Conversion to Btrfs completed." 8 40
    log_action "Converted $ext4_partition to Btrfs."
}

# Module: Display Menu
display_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "Home Directory Manager" --menu "Choose an option:" 15 60 6 \
            "1" "Sync Data from Old Home Partition" \
            "2" "Move Large Media Files to Backup" \
            "3" "Delete Old Partition" \
            "4" "Expand Current Home Partition" \
            "5" "Convert ext4 to Btrfs" \
            "6" "Exit" 3>&1 1>&2 2>&3)

        case $choice in
            1) sync_data ;;
            2) move_media ;;
            3) delete_partition ;;
            4) expand_home_partition ;;
            5) convert_to_btrfs ;;
            6) exit 0 ;;
            *) whiptail --msgbox "Invalid choice, please try again." 8 40 ;;
        esac
    done
}

# Main logic
main() {
    if [ "$(id -u)" -ne 0 ]; then
        whiptail --msgbox "This script must be run as root." 8 40
        exit 1
    fi

    case "$1" in
        sync) sync_data ;;
        move) move_media ;;
        delete) delete_partition ;;
        expand) expand_home_partition ;;
        convert) convert_to_btrfs ;;
        -h|--help) show_help ;;
        *) display_menu ;;
    esac
}

# Execute main function
main "$@"
