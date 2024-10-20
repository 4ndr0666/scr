#!/bin/bash

# File: controller.sh
# Author: 4ndr0666
# Date: 10-20-24

# ================================ // CONTROLLER.SH //
SETTINGS_FILE="$(pkg_path)/settings.sh"
log_file="/home/andro/.local/share/logs/service_optimization.log"

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}

handle_error() {
    local message="$1"
    log "ERROR: $message"
    exit 1
}

pkg_path() {
	if [[ -L "$0" ]]; then
		dirname "$(readlink $0)"
	else
		dirname "$0"
	fi
}


backup_directory() {
    local dir_to_backup="$1"
    local backup_dir="/Nas/Build/maint/.backup_$(basename "$dir_to_backup")_$(date +%Y%m%d_%H%M%S)"

    if [[ -d "$dir_to_backup" ]]; then
        log "Backing up '$dir_to_backup' to '$backup_dir'..."
        mkdir -p "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
        rsync -av --progress "$dir_to_backup/" "$backup_dir/" || handle_error "Failed to backup '$dir_to_backup' to '$backup_dir'."
        log "Backup completed: '$backup_dir'"
    else
        log "Directory '$dir_to_backup' does not exist. Skipping backup."
    fi
}

determine_editor() {
    # Check if EDITOR is set and valid
    if [[ -n "$EDITOR" && $(command -v "$EDITOR") ]]; then
        log "Using EDITOR from environment: $EDITOR"
    elif [[ -n "$SETTINGS_EDITOR" && $(command -v "$SETTINGS_EDITOR") ]]; then
        export EDITOR="$SETTINGS_EDITOR"
        log "Using SETTINGS_EDITOR: $SETTINGS_EDITOR"
    else
        log "No valid editor found in EDITOR or SETTINGS_EDITOR. Initiating fallback."
        fallback_editor
    fi
}


fallback_editor() {
    log "Falling back to available editors..."
    PS3="Choose an available editor: "
    select editor in "vim" "nano" "micro" "Exit"; do
        case $REPLY in
            1) vim "$(pkg_path)/settings.sh"; break ;;
            2) nano "$(pkg_path)/settings.sh"; break ;;
            3) micro "$(pkg_path)/settings.sh"; break ;;
            4) log "Exiting editor selection."; exit 0 ;;
            *) echo "Invalid selection. Please choose a valid option." ;;
        esac
    done
}

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

backup_settings() {
    local backup_dir="$BACKUP_DIR"
    create_directory_if_not_exists "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
    
    local backup_file="$backup_dir/settings_backup_$(date +%Y%m%d_%H%M%S).sh"
    cp "$(pkg_path)/settings.sh" "$backup_file" || handle_error "Failed to backup settings file to '$backup_file'."
    log "Settings backed up to '$backup_file'."
}

restore_settings_backup() {
    local backup_dir="$BACKUP_DIR"
    if [ -d "$backup_dir" ]; then
        local latest_backup
        latest_backup=$(ls -t "$backup_dir" | head -n 1)
        if [ -n "$latest_backup" ]; then
            cp "$backup_dir/$latest_backup" "$(pkg_path)/settings.sh" || handle_error "Failed to restore settings from '$latest_backup'."
            log "Settings restored from backup: '$latest_backup'"
        else
            log "No backups found to restore."
        fi
    else
        log "Backup directory '$backup_dir' does not exist."
    fi
}

clean_old_backups() {
    local backup_dir="$BACKUP_DIR"
    if [ -d "$backup_dir" ]; then
        local backups_to_delete
        backups_to_delete=$(ls -t "$backup_dir" | tail -n +6)  # Keep only the 5 most recent
        if [ -n "$backups_to_delete" ]; then
            echo "$backups_to_delete" | xargs -I {} rm "$backup_dir/{}" || log "Warning: Failed to delete some old backups."
            log "Old backups cleaned up. Kept the 5 most recent backups."
        else
            log "No old backups to clean up."
        fi
    else
        log "Backup directory '$backup_dir' does not exist. Skipping cleanup."
    fi
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log "ERROR: Dependency '$1' is not installed. Please install it first."
        return 1
    fi
}

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

update_package_list() {
    if command -v pacman &> /dev/null; then
        log "Updating package list with pacman..."
        sudo pacman -Syu --noconfirm || handle_error "Failed to update package list with pacman."
    elif command -v apt-get &> /dev/null; then
        log "Updating package list with apt-get..."
        sudo apt-get update && sudo apt-get upgrade -y || handle_error "Failed to update package list with apt-get."
    elif command -v dnf &> /dev/null; then
        log "Updating package list with dnf..."
        sudo dnf upgrade --refresh -y || handle_error "Failed to update package list with dnf."
    elif command -v zypper &> /dev/null; then
        log "Updating package list with zypper..."
        sudo zypper refresh && sudo zypper update -y || handle_error "Failed to update package list with zypper."
    else
        log "Unsupported package manager. Please update the package list manually."
        exit 1
    fi
}

create_directory_if_not_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log "Creating directory: $dir"
        mkdir -p "$dir" || handle_error "Failed to create directory '$dir'."
    else
        log "Directory '$dir' already exists. Skipping creation."
    fi
}

consolidate_directories() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ -d "$source_dir" && "$source_dir" != "$target_dir" ]]; then
        log "Consolidating contents from '$source_dir' to '$target_dir'..."
        # Ensure target directory exists
        create_directory_if_not_exists "$target_dir"

        # Move files while avoiding overwriting existing files
        rsync -av --remove-source-files "$source_dir/" "$target_dir/" || handle_error "Failed to consolidate directories from '$source_dir' to '$target_dir'."

        # Remove the source directory if empty
        if [[ -z "$(ls -A "$source_dir")" ]]; then
            rmdir "$source_dir" || log "Warning: Failed to remove empty directory '$source_dir'. It may not be empty."
        else
            log "Directory '$source_dir' is not empty after consolidation. Skipping removal."
        fi
    else
        log "Source directory '$source_dir' does not exist or is the same as target directory. Skipping consolidation."
    fi
}

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
        echo "export $var_name=\"$var_value\"" >> "$shell_config" || handle_error "Failed to add $var_name to $shell_config."
        log "Added 'export $var_name=\"$var_value\"' to '$shell_config'."
        # Source the shell configuration file to apply changes to the current session
        # shellcheck source=/dev/null
        source "$shell_config" || handle_error "Failed to source '$shell_config'."
    else
        log "Environment variable '$var_name' already set in '$shell_config'. Skipping."
    fi
}

remove_empty_directories() {
    for dir in "$@"; do
        if [[ -d "$dir" && -z "$(ls -A "$dir")" ]]; then
            log "Removing empty directory: $dir"
            rmdir "$dir" || log "Warning: Failed to remove empty directory '$dir'. It may not be empty."
        else
            log "Directory '$dir' is not empty or does not exist. Skipping removal."
        fi
    done
}

cargo_install_or_update() {
    local tool_name="$1"
    log "Installing or updating Cargo tool: $tool_name"

    if cargo install --list | grep -q "^$tool_name v"; then
        log "Updating Cargo tool: $tool_name"
        cargo install "$tool_name" --force || handle_error "Failed to update Cargo tool '$tool_name'."
    else
        log "Installing Cargo tool: $tool_name"
        cargo install "$tool_name" || handle_error "Failed to install Cargo tool '$tool_name'."
    fi
}

install_db_tool() {
    local tool_name="$1"

    log "Ensuring database tool '$tool_name' is installed..."
    if ! command -v "$tool_name" &> /dev/null; then
        if command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm "$tool_name" || handle_error "Failed to install '$tool_name' with pacman."
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install -y "$tool_name" || handle_error "Failed to install '$tool_name' with apt-get."
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$tool_name" || handle_error "Failed to install '$tool_name' with dnf."
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y "$tool_name" || handle_error "Failed to install '$tool_name' with zypper."
        else
            handle_error "Unsupported package manager. Please install '$tool_name' manually."
        fi
        log "Database tool '$tool_name' installed successfully."
    else
        log "Database tool '$tool_name' is already installed. Skipping installation."
    fi
}

check_db_tool_directories() {
    local psql_home="$XDG_DATA_HOME/postgresql"
    local mysql_home="$XDG_DATA_HOME/mysql"
    local sqlite_home="$XDG_DATA_HOME/sqlite"

    check_directory_writable "$psql_home"
    check_directory_writable "$mysql_home"
    check_directory_writable "$sqlite_home"
}

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

execute_editor() {
    local editor="$1"
    if [[ -x "$(command -v "$editor")" ]]; then
        "$editor" "$(pkg_path)/settings.sh"
        if [[ $? -eq 0 ]]; then
            echo "Settings successfully modified."
        else
            echo "Error: Failed to modify settings with $editor."
        fi
    else
        echo "Error: $editor is not installed."
        fallback_editor
    fi
}
          
source_settings() {
        if [[ -f "$SETTINGS_FILE" ]]; then
        log "Sourcing settings from '$SETTINGS_FILE'..."
       # shellcheck source=/dev/null
        source "$SETTINGS_FILE" || handle_error "Failed to source '$SETTINGS_FILE'."
    else
        log "Settings file '$SETTINGS_FILE' does not exist. Skipping sourcing."
    fi
}

update_settings() {
    log "Updating settings..."
    # Check if EDITOR is set and valid
    if [[ -n "$EDITOR" && $(command -v "$EDITOR") ]]; then
        execute_editor "$EDITOR"
    elif [[ "$SETTINGS_EDITOR" =~ (vim|nano|emacs|micro) && $(command -v "$SETTINGS_EDITOR") ]]; then
        execute_editor "$SETTINGS_EDITOR"
    else
        fallback_editor
    fi
}

# Purpose: General function to optimize a service and handle errors.
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

# --- Specific Optimization Functions ---
# These functions should be defined in their respective service scripts.

# Example:
# optimize_go_service() {
#     # Implementation...
# }
backup_and_clean_settings() {
    backup_settings
    clean_old_backups
}

modify_settings() {
    determine_editor
    execute_editor "$EDITOR" "Error: The EDITOR environment variable ($EDITOR) is not valid or installed."
}

update_settings() {
    log "Updating settings..."
    backup_and_clean_settings
    modify_settings || handle_error "Failed to modify settings."
    source_settings || handle_error "Failed to source settings after modification."
    log "Settings updated successfully."
}

main_controller() {
    optimize_service "Go" "optimize_go_service"
    optimize_service "Ruby" "optimize_ruby_service"
    optimize_service "Cargo" "optimize_cargo_service"
    optimize_service "Node.js" "optimize_node_service"
    optimize_service "NVM" "optimize_nvm_service"
    optimize_service "Meson" "optimize_meson_service"
    optimize_service "Python (Poetry)" "optimize_poetry_service"
    optimize_service "Rust Tooling" "optimize_rust_tooling_service"
    optimize_service "Database Tools" "optimize_db_tools_service"
}

# Note: Ensure that all optimize_xxx_service functions are defined and sourced before calling main_controller.

# --- Export Functions for Use in Other Scripts ---
# If other scripts need to access these functions, export them here.
export -f log
export -f handle_error
export -f optimize_service
export -f main_controller
