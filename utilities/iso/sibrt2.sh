
#!/bin/bash

# Enhanced System Image Backup and Restoration Tool (ESIBRT) for Arch Linux
# This script creates a system image backup in ISO format, tailored for Arch Linux.
# Usage requires root privileges. Ensure you have 'archiso' installed for this script to function correctly.

# Configuration
backup_dir="/path/to/backup"                          # Directory to store intermediate backup files
iso_path="/path/to/arch_system_image.iso"             # Path to output ISO file
exclude_file="/path/to/exclude.lst"                   # File containing paths to exclude from backup
live_iso_label="ArchBackup"                           # Label for the ISO volume

# Ensure the script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Verify necessary tools are installed (archiso required for Arch Linux)
if ! command -v mkarchiso &> /dev/null; then
    echo "Error: 'mkarchiso' is not installed. Please install 'archiso' package." >&2
    exit 1
fi

# Create exclude file with common paths to exclude
create_exclude_file() {
    cat > "$exclude_file" << EOF
/dev/*
/proc/*
/sys/*
/tmp/*
/mnt/*
/media/*
/run/*
/var/run/*
EOF
}

# Function to prepare the working directory
prepare_working_directory() {
    echo "Preparing working directory..."
    mkdir -p "$backup_dir"
    create_exclude_file
}

# Create backup using rsync
create_backup() {
    echo "Creating backup..."
    rsync -aAXv --exclude-from="$exclude_file" / "$backup_dir" --delete
    # Note: --delete ensures that the backup directory mirrors the system without accumulating outdated files
}

# Generate the ISO from the backup directory
create_iso() {
    echo "Generating ISO..."
    mkarchiso -v -w "$backup_dir" -o "$(dirname "$iso_path")" -l "$live_iso_label" "$backup_dir"
    # mkarchiso is used for creating live and installable ISO images for Arch Linux
}

# Main function to orchestrate backup creation
main() {
    prepare_working_directory
    create_backup
    create_iso
    echo "Backup ISO created successfully at $iso_path"
}

main "$@"
