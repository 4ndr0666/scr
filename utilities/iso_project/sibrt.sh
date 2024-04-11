#!/bin/bash

# System Image Backup and Restoration Tool (SIBRT)
# This script enables the creation of a system image backup in ISO format.
# Usage requires root privileges.

# Configuration
backup_dir="/path/to/backup"    # Directory to store intermediate backup files
iso_path="/path/to/system_image.iso"   # Path to output ISO file
exclude_file="/path/to/exclude.lst"    # File containing paths to exclude from backup

# Define a function to setup environment
setup_environment() {
    # Ensure running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root." >&2
        exit 1
    fi

    # Verify necessary tools are installed (e.g., genisoimage, mksquashfs)
    for tool in genisoimage mksquashfs rsync; do
        if ! command -v $tool &> /dev/null; then
            echo "Error: Required tool $tool is not installed." >&2
            exit 1
        fi
    done
}

# Function to create the exclude file dynamically based on common paths to exclude
create_exclude_file() {
    cat > "$exclude_file" << EOF
/dev/*
/proc/*
/sys/*
/tmp/*
/mnt/*
/media/*
/run/*
EOF
}

# Function to create backup
create_backup() {
    # Ensure backup directory exists
    mkdir -p "$backup_dir"
    
    # Create exclude file
    create_exclude_file

    # Use rsync to copy filesystem to backup directory, excluding some paths
    rsync -aAXv --exclude-from="$exclude_file" / "$backup_dir"
    
    # Handle rsync errors
    if [ $? -ne 0 ]; then
        echo "Error: rsync operation failed." >&2
        exit 1
    fi
}

# Function to create SquashFS image from backup
create_squashfs() {
    mksquashfs "$backup_dir" "$backup_dir/filesystem.squashfs" -comp xz -noappend
    
    # Handle mksquashfs errors
    if [ $? -ne 0 ]; then
        echo "Error: mksquashfs operation failed." >&2
        exit 1
    fi
}

# Function to create ISO from SquashFS image
create_iso() {
    genisoimage -o "$iso_path" -r -J -V "BackupISO" -cache-inodes -J -l "$backup_dir"
    
    # Handle genisoimage errors
    if [ $? -ne 0 ]; then
        echo "Error: genisoimage operation failed." >&2
        exit 1
    fi

    echo "Backup ISO created successfully at $iso_path"
}

main() {
    setup_environment
    create_backup
    create_squashfs
    create_iso
}

main "$@"

