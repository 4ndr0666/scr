#!/bin/bash

# Function to display the menu
display_menu() {
    echo "1. Sync Data from Old Home Partition to New Home Directory"
    echo "2. Move Large Media Files to Backup Directory"
    echo "3. Delete Old Partition"
    echo "4. Expand Current Home Partition"
    echo "5. Convert ext4 to Btrfs"
    echo "6. Exit"
    echo -n "Please enter your choice: "
}

# Function to sync data
sync_data() {
    read -p "Enter the old home partition (e.g., /dev/sdXY): " old_partition
    read -p "Enter the mount point for the old partition (e.g., /mnt/old_home): " mount_point
    read -p "Enter the path to the new home directory: " new_home

    if mount | grep $mount_point > /dev/null; then
        echo "Mount point $mount_point is already in use."
    else
        sudo mount $old_partition $mount_point
    fi

    sudo rsync -av --ignore-existing --ignore-times --update --progress --recursive \
        --exclude='*.mp4' --exclude='*.png' --exclude='*.jpg' --exclude='*.mov' \
        --exclude='*.mkv' --exclude='*.gif' --exclude='*.zip' \
        $mount_point/ $new_home/
    sudo umount $mount_point
    sudo rsync -ac --progress $mount_point/ $new_home/
    sudo chown -R $USER:$USER $new_home

    echo "Data sync completed."
}

# Function to move large media files
move_media() {
    read -p "Enter the path to the new home directory: " new_home
    read -p "Enter the path to the media backup directory: " media_backup

    mkdir -p $media_backup
    mv $new_home/*.mp4 $media_backup/ 2>/dev/null
    mv $new_home/*.png $media_backup/ 2>/dev/null
    mv $new_home/*.jpg $media_backup/ 2>/dev/null
    mv $new_home/*.mov $media_backup/ 2>/dev/null
    mv $new_home/*.mkv $media_backup/ 2>/dev/null
    mv $new_home/*.gif $media_backup/ 2>/dev/null
    mv $new_home/*.zip $media_backup/ 2>/dev/null

    echo "Media files moved to backup directory."
}

# Function to delete old partition
delete_partition() {
    read -p "Enter the old partition (e.g., /dev/sdXY): " old_partition

    echo "Warning: This will delete the old partition. Ensure you have backups."
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        echo -e "d\nw" | sudo fdisk $old_partition
        echo "Old partition deleted."
    else
        echo "Operation canceled."
    fi
}

# Function to expand current home partition
expand_home_partition() {
    read -p "Enter the disk (e.g., /dev/sdX): " disk
    read -p "Enter the partition number of the home directory: " partition_number

    echo "Warning: This will resize the partition. Ensure you have backups."
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        echo -e "d\n$partition_number\nn\np\n$partition_number\n\n\nw" | sudo fdisk $disk
        sudo resize2fs ${disk}${partition_number}
        sudo fsck ${disk}${partition_number}
        echo "Home partition expanded."
    else
        echo "Operation canceled."
    fi
}

# Function to convert ext4 to Btrfs
convert_to_btrfs() {
    read -p "Enter the ext4 partition to convert (e.g., /dev/sdXY): " ext4_partition

    echo "Warning: This will convert the ext4 partition to Btrfs. Ensure you have backups."
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        sudo umount $ext4_partition
        sudo btrfs-convert $ext4_partition
        echo "Conversion to Btrfs completed."
    else
        echo "Operation canceled."
    fi
}

# Main script loop
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