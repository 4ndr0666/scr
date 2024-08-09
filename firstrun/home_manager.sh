#!/bin/bash

# --- CONSTANTS AND VARIABLES:
LOG_FILE="/var/log/home_manager.log"
BACKUP_DIR="/var/recover"
MOUNT_POINT=""
NEW_HOME=""
MEDIA_BACKUP=""
DISK=""
PARTITION_NUMBER=""
EXT4_PARTITION=""

# --- LOGGING:
log_action() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# --- INPUT VALIDATION:
validate_input() {
    if [ -z "$1" ]; then
        echo "Invalid input. Please try again."
        return 1
    fi
    return 0
}

# --- USER CONFIRMATION:
confirm_action() {
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Operation canceled."
        return 1
    fi
    return 0
}

# --- DISPLAY HELP:
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

Home Directory Manager

Options:
  -h, --help             Display this help message and exit.
  sync                   Sync data from the old home partition to the new home directory.
  move                   Move large media files to a backup directory.
  delete                 Delete the old partition.
  expand                 Expand the current home partition.
  convert                Convert an ext4 partition to Btrfs.
  menu                   Display the interactive menu for these options.

Example Usage:
  ${0##*/} sync           Sync data from the old home partition to the new home directory.
  ${0##*/} menu           Display the interactive menu.

EOF
}

# --- MODULE: Sync Data
sync_data() {
    echo "=== Sync Data from Old Home Partition to New Home Directory ==="
    read -p "Enter the old home partition (e.g., /dev/sdXY): " old_partition
    validate_input "$old_partition" || return
    read -p "Enter the mount point for the old partition (e.g., /mnt/old_home): " mount_point
    validate_input "$mount_point" || return
    read -p "Enter the path to the new home directory: " new_home
    validate_input "$new_home" || return

    if mount | grep -q "$mount_point"; then
        echo "Mount point $mount_point is already in use."
    else
        sudo mount "$old_partition" "$mount_point" || { echo "Failed to mount $old_partition"; return; }
    fi

    echo "Syncing data..."
    sudo rsync -av --ignore-existing --ignore-times --update --progress --recursive \
        --exclude='*.mp4' --exclude='*.png' --exclude='*.jpg' --exclude='*.mov' \
        --exclude='*.mkv' --exclude='*.gif' --exclude='*.zip' \
        "$mount_point/" "$new_home/" || { echo "Data sync failed"; return; }

    sudo umount "$mount_point" || { echo "Failed to unmount $mount_point"; return; }
    sudo chown -R "$USER:$USER" "$new_home" || { echo "Failed to set ownership"; return; }

    echo "Data sync completed."
    log_action "Data synced from $old_partition to $new_home."
}

# --- MODULE: Move Media
move_media() {
    echo "=== Move Large Media Files to Backup Directory ==="
    read -p "Enter the path to the new home directory: " new_home
    validate_input "$new_home" || return
    read -p "Enter the path to the media backup directory: " media_backup
    validate_input "$media_backup" || return

    mkdir -p "$media_backup" || { echo "Failed to create backup directory"; return; }

    echo "Moving media files..."
    mv "$new_home"/*.{mp4,png,jpg,mov,mkv,gif,zip} "$media_backup/" 2>/dev/null || { echo "No media files found to move"; }

    echo "Media files moved to backup directory."
    log_action "Media files moved from $new_home to $media_backup."
}

# --- MODULE: Delete Old Partition
delete_partition() {
    echo "=== Delete Old Partition ==="
    read -p "Enter the old partition (e.g., /dev/sdXY): " old_partition
    validate_input "$old_partition" || return

    echo "Warning: This will delete the old partition. Ensure you have backups."
    confirm_action || return

    echo "Deleting partition..."
    echo -e "d\nw" | sudo fdisk "$old_partition" || { echo "Failed to delete partition"; return; }
    echo "Old partition deleted."
    log_action "Deleted partition $old_partition."
}

# --- MODULE: Expand Home Partition
expand_home_partition() {
    echo "=== Expand Current Home Partition ==="
    read -p "Enter the disk (e.g., /dev/sdX): " disk
    validate_input "$disk" || return
    read -p "Enter the partition number of the home directory: " partition_number
    validate_input "$partition_number" || return

    echo "Warning: This will resize the partition. Ensure you have backups."
    confirm_action || return

    echo "Expanding home partition..."
    echo -e "d\n$partition_number\nn\np\n$partition_number\n\n\nw" | sudo fdisk "$disk" || { echo "Failed to resize partition"; return; }
    sudo resize2fs "${disk}${partition_number}" || { echo "Failed to resize filesystem"; return; }
    sudo fsck "${disk}${partition_number}" || { echo "Filesystem check failed"; return; }
    echo "Home partition expanded."
    log_action "Expanded partition ${disk}${partition_number}."
}

# --- MODULE: Convert ext4 to Btrfs
convert_to_btrfs() {
    echo "=== Convert ext4 to Btrfs ==="
    read -p "Enter the ext4 partition to convert (e.g., /dev/sdXY): " ext4_partition
    validate_input "$ext4_partition" || return

    echo "Warning: This will convert the ext4 partition to Btrfs. Ensure you have backups."
    confirm_action || return

    sudo umount "$ext4_partition" || { echo "Failed to unmount partition"; return; }
    sudo btrfs-convert "$ext4_partition" || { echo "Conversion to Btrfs failed"; return; }
    echo "Conversion to Btrfs completed."
    log_action "Converted $ext4_partition to Btrfs."
}

# --- MODULE: Display Menu
display_menu() {
    clear
    echo "Home Directory Manager"
    echo "======================"
    echo "1. Sync Data from Old Home Partition to New Home Directory"
    echo "2. Move Large Media Files to Backup Directory"
    echo "3. Delete Old Partition"
    echo "4. Expand Current Home Partition"
    echo "5. Convert ext4 to Btrfs"
    echo "6. Exit"
    echo -n "Please enter your choice: "
}

# --- MAIN LOGIC:
main() {
    case "$1" in
        sync) sync_data ;;
        move) move_media ;;
        delete) delete_partition ;;
        expand) expand_home_partition ;;
        convert) convert_to_btrfs ;;
        menu|"")  # Default action is to display the menu if no option is provided
            while true; do
                display_menu
                read choice
                case $choice in
                    1) sync_data ;;
                    2) move_media ;;
                    3) delete_partition ;;
                    4) expand_home_partition ;;
                    5) convert_to_btrfs ;;
                    6) exit 0 ;;
                    *) echo "Invalid choice, please try again." ;;
                esac
            done
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unrecognized command '$1'"
            show_help
            exit 1
            ;;
    esac
}

# --- EXECUTE MAIN:
main "$@"
