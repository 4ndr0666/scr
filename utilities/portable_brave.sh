#!/bin/bash

# Define directories
old_dir="$HOME/.config/BraveSoftware/Brave-Browser"
backup_dir="$HOME/.config/BraveSoftware/Brave-Browser-Backup"
temp_dir="/tmp/brave_temp"
portable_dir="/path/to/portable/Brave-Browser"  # Define the path for portable directory

# Check if Brave is running
is_brave_running() {
    pgrep -x brave > /dev/null
}

# Confirm and backup existing Brave profile to a portable directory
backup_to_portable() {
    if [ -d "$portable_dir" ]; then
        read -p "Portable backup already exists. Overwrite? (y/n): " overwrite_choice
        if [[ ! "$overwrite_choice" =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    if cp -r "$old_dir" "$portable_dir"; then
        echo "Backup completed successfully."
    else
        echo "Error occurred during backup. Exiting."
        exit 1
    fi
}

# Rename and handle old directory
handle_old_directory() {
    if [ -d "$old_dir" ] && [ ! -d "$backup_dir" ]; then
        mv "$old_dir" "$backup_dir"
    elif [ ! -d "$old_dir" ]; then
        echo "Old directory does not exist. Creating a new profile."
        mkdir -p "$old_dir"
    fi
}

# Start and manage Brave process
manage_brave_process() {
    if is_brave_running; then
        echo "Brave is already running. Please close it before proceeding."
        exit 1
    fi

    brave --user-data-dir="$temp_dir" &
    sleep 10  # Wait for Brave to initialize

    while is_brave_running; do
        killall brave
        sleep 5
    done
}

# Restore from portable profile
restore_from_portable() {
    if [ -d "$old_dir" ]; then
        echo "The profile has already been restored."
        return
    fi

    read -p "Restore from portable profile? (y/n): " restore_choice
    if [[ "$restore_choice" =~ ^[Yy]$ ]]; then
        if [ -d "$portable_dir" ]; then
            cp -r "$portable_dir" "$old_dir"
            echo "Brave profile restored from portable directory."
        else
            echo "Portable directory not found."
        fi
    fi
}

# Main function to control the workflow
main() {
    backup_to_portable
    handle_old_directory
    manage_brave_process
    restore_from_portable
    echo "Brave setup completed."
}

# Run the main function
main
