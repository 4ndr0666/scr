#!/bin/bash
# File: controller.sh
# Author: 4ndr0666
# Date: 2024-11-01
# Description: Central orchestration script for the 4ndr0service Suite.

# ==================================== // CONTROLLER.SH //

# Function: pkg_path
# Purpose: Determine the absolute directory path of the current script.
pkg_path() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$script_dir"
}

# Define Settings File
SETTINGS_FILE="$(pkg_path)/settings.sh"

# Define Log File Path based on XDG_CACHE_HOME
export LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/logs/service_optimization.log"

# Define Backup Directory based on XDG_DATA_HOME
export BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/4ndr0service/backups/settings_backups/"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" || handle_error "Failed to create log directory."

# Logging Function
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Error Handling Function
handle_error() {
    local message="$1"
    log "ERROR: $message"
    exit 1
}

# Backup Directory Function
backup_directory() {
    local dir_to_backup="$1"
    local backup_dir
    backup_dir="${BACKUP_DIR}/$(basename "$dir_to_backup")_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -d "$dir_to_backup" ]]; then
        log "Backing up '$dir_to_backup' to '$backup_dir'..."
        mkdir -p "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
        rsync -av --progress "$dir_to_backup/" "$backup_dir/" || handle_error "Failed to backup '$dir_to_backup' to '$backup_dir'."
        log "Backup completed: '$backup_dir'"
    else
        log "Directory '$dir_to_backup' does not exist. Skipping backup."
    fi
}

# Determine Editor Function
determine_editor() {
    # Check if EDITOR is set and valid
    if [[ -n "$EDITOR" && $(command -v "$EDITOR") ]]; then
        log "Using EDITOR from environment: $EDITOR"
    elif [[ -n "$SETTINGS_EDITOR" && "$SETTINGS_EDITOR" =~ ^(vim|nano|emacs|micro|nvim)$ && $(command -v "$SETTINGS_EDITOR") ]]; then
        export EDITOR="$SETTINGS_EDITOR"
        log "Using SETTINGS_EDITOR: $SETTINGS_EDITOR"
    else
        log "No valid editor found in EDITOR or SETTINGS_EDITOR. Initiating fallback."
        fallback_editor
    fi
}

# Fallback Editor Selection
fallback_editor() {
    log "Falling back to available editors..."
    PS3="Choose an available editor: "
    select editor in "vim" "nano" "micro" "emacs" "Exit"; do
        case $REPLY in
            1) 
                if command -v vim &> /dev/null; then
                    vim "$SETTINGS_FILE"
                    break
                else
                    echo "vim is not installed."
                fi
                ;;
            2) 
                if command -v nano &> /dev/null; then
                    nano "$SETTINGS_FILE"
                    break
                else
                    echo "nano is not installed."
                fi
                ;;
            3) 
                if command -v micro &> /dev/null; then
                    micro "$SETTINGS_FILE"
                    break
                else
                    echo "micro is not installed."
                fi
                ;;
            4) 
                if command -v emacs &> /dev/null; then
                    emacs "$SETTINGS_FILE"
                    break
                else
                    echo "emacs is not installed."
                fi
                ;;
            5) 
                log "Exiting editor selection."
                exit 0
                ;;
            *) 
                echo "Invalid selection. Please choose a valid option."
                ;;
        esac
    done
}

# Find Available Editor Function
find_editor() {
    local editors=("vim" "nano" "micro" "emacs" "code" "sublime" "gedit")
    for editor in "${editors[@]}"; do
        if command -v "$editor" &> /dev/null; then
            echo "$editor"
            return 0
        fi
    done
    echo "micro"  # Default fallback editor
}

# Detect Package Manager Function
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt-get &> /dev/null; then
        echo "apt-get"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unsupported"
    fi
}

# Backup Settings Function
backup_settings() {
    backup_directory "$SETTINGS_FILE"
}

# Restore Settings Backup Function
restore_settings_backup() {
    local backup_dir="${BACKUP_DIR}/"
    if [ -d "$backup_dir" ]; then
        local latest_backup
        latest_backup=$(find "$backup_dir" -type f -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)
        if [ -n "$latest_backup" ]; then
            cp "$latest_backup" "$SETTINGS_FILE" || handle_error "Failed to restore settings from '$latest_backup'."
            log "Settings restored from backup: '$latest_backup'"
        else
            log "No backups found to restore."
        fi
    else
        log "Backup directory '$backup_dir' does not exist."
    fi
}

# Clean Old Backups Function
clean_old_backups() {
    local backup_dir="${BACKUP_DIR}/"
    if [ -d "$backup_dir" ]; then
        # Using find to list backups sorted by modification time
        local backups_to_delete
        backups_to_delete=$(find "$backup_dir" -type f -printf '%T@ %p\n' | sort -nr | tail -n +6 | cut -d' ' -f2-)
        if [ -n "$backups_to_delete" ]; then
            echo "$backups_to_delete" | while read -r backup; do
                rm "$backup" || log "Warning: Failed to delete backup '$backup'."
            done
            log "Old backups cleaned up. Kept the 5 most recent backups."
        else
            log "No old backups to clean up."
        fi
    else
        log "Backup directory '$backup_dir' does not exist. Skipping cleanup."
    fi
}

# Check Dependency Function
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log "ERROR: Dependency '$1' is not installed. Please install it first."
        return 1
    fi
}

# Check Directory Writable Function
check_directory_writable() {
    local dir="$1"
    if [[ ! -w "$dir" ]]; then
        log "Directory '$dir' is not writable. Attempting to fix permissions..."
        sudo chown -R "$USER":"$USER" "$dir" || handle_error "Failed to change ownership of '$dir'."
        if [[ -w "$dir" ]]; then
            log "Directory '$dir' is now writable."
        else
            handle_error "Directory '$dir' remains unwritable after attempting to fix permissions."
        fi
    else
        log "Directory '$dir' is writable."
    fi
}

# Update Package List Function
update_package_list() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    case "$pkg_manager" in
        pacman)
            log "Updating package list with pacman..."
            if sudo pacman -Syu --noconfirm; then
                :
            else
                handle_error "Failed to update package list with pacman."
            fi
            ;;
        apt-get)
            log "Updating package list with apt-get..."
            if sudo apt-get update && sudo apt-get upgrade -y; then
                :
            else
                handle_error "Failed to update package list with apt-get."
            fi
            ;;
        dnf)
            log "Updating package list with dnf..."
            if sudo dnf upgrade --refresh -y; then
                :
            else
                handle_error "Failed to update package list with dnf."
            fi
            ;;
        zypper)
            log "Updating package list with zypper..."
            if sudo zypper refresh && sudo zypper update -y; then
                :
            else
                handle_error "Failed to update package list with zypper."
            fi
            ;;
        unsupported)
            log "Unsupported package manager. Please update the package list manually."
            exit 1
            ;;
    esac
}

# Create Directory If Not Exists Function
create_directory_if_not_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log "Creating directory: $dir"
        if mkdir -p "$dir"; then
            :
        else
            handle_error "Failed to create directory '$dir'."
        fi
    else
        log "Directory '$dir' already exists. Skipping creation."
    fi
}

# Consolidate Directories Function
consolidate_directories() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ -d "$source_dir" && "$source_dir" != "$target_dir" ]]; then
        log "Consolidating contents from '$source_dir' to '$target_dir'..."
        # Ensure target directory exists
        create_directory_if_not_exists "$target_dir"

        # Move files while avoiding overwriting existing files
        if rsync -av --remove-source-files "$source_dir/" "$target_dir/"; then
            :
        else
            handle_error "Failed to consolidate directories from '$source_dir' to '$target_dir'."
        fi

        # Remove the source directory if empty
        if [[ -z "$(ls -A "$source_dir")" ]]; then
            if rmdir "$source_dir"; then
                log "Removed empty directory '$source_dir'."
            else
                log "Warning: Failed to remove empty directory '$source_dir'. It may not be empty."
            fi
        else
            log "Directory '$source_dir' is not empty after consolidation. Skipping removal."
        fi
    else
        log "Source directory '$source_dir' does not exist or is the same as target directory. Skipping consolidation."
    fi
}

# Add to Shell Config Function
add_to_shell_config() {
    local var_name="$1"
    local var_value="$2"
    local shell_config

    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_config="$HOME/.bashrc"
    else
        log "Unsupported shell. Please manually add environment variables."
        return
    fi

    # Check if the export line already exists
    if ! grep -Fxq "export $var_name=\"$var_value\"" "$shell_config"; then
        echo "export $var_name=\"$var_value\"" >> "$shell_config" || handle_error "Failed to add $var_name to '$shell_config'."
        log "Added 'export $var_name=\"$var_value\"' to '$shell_config'."
        # Source the shell configuration file to apply changes to the current session
        # shellcheck disable=SC1090
        if source "$shell_config"; then
            :
        else
            handle_error "Failed to source '$shell_config'."
        fi
    else
        log "Environment variable '$var_name' already set in '$shell_config'. Skipping."
    fi
}

# Cargo Install or Update Function
cargo_install_or_update() {
    local tool_name="$1"
    log "Installing or updating Cargo tool: $tool_name"

    if cargo install --list | grep -q "^$tool_name v"; then
        log "Updating Cargo tool: $tool_name"
        if cargo install "$tool_name" --force; then
            :
        else
            handle_error "Failed to update Cargo tool '$tool_name'."
        fi
    else
        log "Installing Cargo tool: $tool_name"
        if cargo install "$tool_name"; then
            :
        else
            handle_error "Failed to install Cargo tool '$tool_name'."
        fi
    fi
}

# Install Database Tool Function
install_db_tool() {
    local tool_name="$1"

    log "Ensuring database tool '$tool_name' is installed..."
    if ! command -v "$tool_name" &> /dev/null; then
        local pkg_manager
        pkg_manager=$(detect_package_manager)
        case "$pkg_manager" in
            pacman)
                if sudo pacman -S --noconfirm "$tool_name"; then
                    :
                else
                    handle_error "Failed to install '$tool_name' with pacman."
                fi
                ;;
            apt-get)
                if sudo apt-get install -y "$tool_name"; then
                    :
                else
                    handle_error "Failed to install '$tool_name' with apt-get."
                fi
                ;;
            dnf)
                if sudo dnf install -y "$tool_name"; then
                    :
                else
                    handle_error "Failed to install '$tool_name' with dnf."
                fi
                ;;
            zypper)
                if sudo zypper install -y "$tool_name"; then
                    :
                else
                    handle_error "Failed to install '$tool_name' with zypper."
                fi
                ;;
            *)
                handle_error "Unsupported package manager. Please install '$tool_name' manually."
                ;;
        esac
        log "Database tool '$tool_name' installed successfully."
    else
        log "Database tool '$tool_name' is already installed. Skipping installation."
    fi
}

# Check Database Tool Directories Function
check_db_tool_directories() {
    local psql_home="${XDG_DATA_HOME:-$HOME/.local/share}/4ndr0service/data/postgresql"
    local mysql_home="${XDG_DATA_HOME:-$HOME/.local/share}/4ndr0service/data/mysql"
    local sqlite_home="${XDG_DATA_HOME:-$HOME/.local/share}/4ndr0service/data/sqlite"

    create_directory_if_not_exists "$psql_home"
    create_directory_if_not_exists "$mysql_home"
    create_directory_if_not_exists "$sqlite_home"

    check_directory_writable "$psql_home"
    check_directory_writable "$mysql_home"
    check_directory_writable "$sqlite_home"
}

# Verify Database Tool Installation Function
verify_db_tool_installation() {
    local tool_name="$1"

    if command -v "$tool_name" &> /dev/null; then
        local version
        version=$("$tool_name" --version 2>/dev/null)
        log "Database tool '$tool_name' is installed: $version"
    else
        handle_error "Database tool '$tool_name' is not functioning correctly."
    fi
}

# Modify Settings Function
modify_settings() {
    determine_editor
    execute_editor "$EDITOR" "Error: The EDITOR environment variable is not valid or installed."
}

# Execute Editor Function
execute_editor() {
    local editor="$1"
    local error_message="$2"

    # shellcheck disable=SC2034
    local error_message="$2"  # Suppress SC2034 as it's used within the function

    if [[ -x "$(command -v "$editor")" ]]; then
        if "$editor" "$SETTINGS_FILE"; then
            log "Settings successfully modified."
        else
            log "Error: Failed to modify settings with $editor."
        fi
    else
        log "Error: $editor is not installed."
        fallback_editor
    fi
}

# Optimize Service Function
optimize_service() {
    local service_name="$1"
    local optimize_function="$2"

    log "Starting optimization for $service_name..."
    if "$optimize_function"; then
        log "Successfully optimized $service_name."
    else
        log "ERROR: Optimization for $service_name failed!"
    fi
}

# Backup and Clean Settings Function
backup_and_clean_settings() {
    backup_settings
    clean_old_backups
}

# Source All Service Scripts Function
source_all_services() {
    local services_dir
    services_dir="$(pkg_path)/service/"
    for script in "$services_dir"optimize_*.sh; do
        if [[ -f "$script" ]]; then
            # shellcheck disable=SC1090
            source "$script" || { log "Failed to source '$script'"; exit 1; }
            log "Sourced service script: '$script'"
        else
            log "No service script found matching 'optimize_*.sh' in '$services_dir'. Skipping."
        fi
    done
}

# Source Settings Functions
SETTINGS_FUNCTIONS_SCRIPT="$(pkg_path)/functions/settings_functions.sh"
if [[ -f "$SETTINGS_FUNCTIONS_SCRIPT" ]]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FUNCTIONS_SCRIPT" || { log "Failed to source 'settings_functions.sh'"; exit 1; }
    log "Sourced settings_functions.sh"
else
    log "Settings functions script '$SETTINGS_FUNCTIONS_SCRIPT' not found. Exiting."
    exit 1
fi

# Main Controller Function
main_controller() {
    optimize_service "Go" "optimize_go_service"
    optimize_service "Ruby" "optimize_ruby_service"
    optimize_service "Cargo" "optimize_cargo_service"
    optimize_service "Node.js" "optimize_node_service"
    optimize_service "NVM" "optimize_nvm_service"
    optimize_service "Meson" "optimize_meson_service"
    optimize_service "Python (Poetry)" "optimize_venv_service"
    optimize_service "Rust Tooling" "optimize_rust_tooling_service"
    optimize_service "Database Tools" "optimize_db_tools_service"
}

# Call source_all_services to source service scripts and define optimize_* functions
source_all_services

# Export Functions for Use in Other Scripts
export -f log
export -f handle_error
export -f optimize_service
export -f main_controller
export -f create_directory_if_not_exists
export -f check_directory_writable
export -f backup_settings
export -f clean_old_backups
export -f modify_settings
export -f source_all_services
export -f optimize_cargo_service
export -f optimize_db_tools_service
export -f optimize_electron_service
export -f optimize_go_service
export -f optimize_meson_service
export -f optimize_node_service
export -f optimize_nvm_service
export -f optimize_ruby_service
export -f optimize_rust_tooling_service
export -f optimize_venv_service

# ==================================== // END CONTROLLER.SH //
