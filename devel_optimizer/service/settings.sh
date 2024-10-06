#!/bin/bash

# Modify settings with the user's preferred editor
modify_settings() {
    # Check if the EDITOR is set and if we have a valid SUDO_USER
    if [[ -z "$EDITOR" && -n "$SUDO_USER" ]]; then
        EDITOR=$(sudo -H -u "$SUDO_USER" printenv EDITOR)
    fi

    # Use the determined or pre-set editor, or fallback if not valid
    if [[ -n "$EDITOR" && $(command -v "$EDITOR") ]]; then
        execute_editor "$EDITOR" "Error: The EDITOR environment variable ($EDITOR) is not valid or installed."
    elif [[ "$SETTINGS_EDITOR" =~ (vim|micro|nano) ]]; then
        execute_editor "$SETTINGS_EDITOR" "Error: The chosen SETTINGS_EDITOR ($SETTINGS_EDITOR) is not valid or installed."
    else
        fallback_editor
    fi
}

# Function to execute the chosen editor on the settings file
execute_editor() {
    editor="$1"
    error_message="$2"

    check_optdepends "$editor"  # Check if the editor is installed
    if [[ $? -eq 0 ]]; then
        "$editor" "$(pkg_path)/settings.sh"
    else
        echo -e "$error_message"
        fallback_editor
    fi
}

# service/settings.sh
find_editor() {
    local editors=("vim" "nano" "micro" "emacs" "code" "sublime" "gedit")
    for editor in "${editors[@]}"; do
        if command -v "$editor" &> /dev/null; then
            echo "$editor"
            return
        fi
    done
    echo "nano"  # Default fallback editor
}

# Function to fallback to a default editor if the chosen editor is not available
fallback_editor() {
    echo -e "\nFalling back to available editors..."
    PS3="Choose an available editor: "
    select editor in "vim" "nano" "micro" "Exit"; do
        case $REPLY in
            1) vim "$(pkg_path)/settings.sh" ;;
            2) nano "$(pkg_path)/settings.sh" ;;
            3) micro "$(pkg_path)/settings.sh" ;;
            4) exit 0 ;;
            *) echo "Invalid selection. Please choose a valid option." ;;
        esac
    done
}

# Automatically detect package manager for use in other scripts
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt-get &> /dev/null; then
        echo "apt-get"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "unsupported"
    fi
}

# Function to backup the settings file
backup_settings() {
    local backup_dir="$HOME/.config/settings_backups"
    mkdir -p "$backup_dir"
    cp "$(pkg_path)/settings.sh" "$backup_dir/settings_backup_$(date +%Y%m%d_%H%M%S).sh"
}

# Function to restore the most recent settings backup
restore_settings_backup() {
    local backup_dir="$HOME/.config/settings_backups"
    if [ -d "$backup_dir" ]; then
        latest_backup=$(ls -t "$backup_dir" | head -n 1)
        if [ -n "$latest_backup" ]; then
            cp "$backup_dir/$latest_backup" "$(pkg_path)/settings.sh"
            echo "Settings restored from backup: $latest_backup"
        else
            echo "No backups found to restore."
        fi
    else
        echo "No backup directory exists."
    fi
}

# Function to clean old backups, keeping only the 5 most recent
clean_old_backups() {
    local backup_dir="$HOME/.config/settings_backups"
    if [ -d "$backup_dir" ]; then
        backups_to_delete=$(ls -t "$backup_dir" | tail -n +6)  # Keep only the 5 most recent
        if [ -n "$backups_to_delete" ]; then
            echo "$backups_to_delete" | xargs -I {} rm "$backup_dir/{}"
        fi
    fi
}

# Helper function to check if an optional dependency (editor) is installed
check_optdepends() {
    if command -v "$1" &> /dev/null; then
        return 0  # Editor is found
    else
        return 1  # Editor is not found
    fi
}

# Function to get the package path dynamically (assumes this function exists elsewhere in the code)
pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink "$0")"
    else
        dirname "$0"
    fi
}

# Clean up old backups and perform a fresh backup each time settings are modified
backup_settings
clean_old_backups
