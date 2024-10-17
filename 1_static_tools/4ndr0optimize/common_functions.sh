#!/bin/bash

# --- Common Functions for Service Optimization Scripts ---

# --- Logging Setup ---
log_file="$HOME/.service_optimization.log"

# --- Logging Function ---
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}

# --- Error Handling Function ---
handle_error() {
    local message="$1"
    log "ERROR: $message"
    exit 1
}

# --- Function: check_dependency ---
# Purpose: Check if a command exists; if not, log an error and return failure.
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log "ERROR: Dependency '$1' is not installed. Please install it first."
        return 1
    fi
}

# --- Function: check_directory_writable ---
# Purpose: Check if a directory is writable; if not, attempt to fix permissions.
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

# --- Function: update_package_list ---
# Purpose: Update the system's package list using the available package manager.
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

# --- Function: create_directory_if_not_exists ---
# Purpose: Create a directory if it doesn't already exist.
create_directory_if_not_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log "Creating directory: $dir"
        mkdir -p "$dir" || handle_error "Failed to create directory '$dir'."
    else
        log "Directory '$dir' already exists. Skipping creation."
    fi
}

# --- Function: consolidate_directories ---
# Purpose: Move files from the source directory to the target directory safely.
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

# --- Function: add_to_shell_config ---
# Purpose: Add an environment variable to the appropriate shell configuration file if not already present.
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

# --- Function: remove_empty_directories ---
# Purpose: Remove empty directories from the given list.
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

# --- Function: cargo_install_or_update ---
# Purpose: Install or update a Cargo tool.
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

# --- Function: backup_directory ---
# Purpose: Backup a given directory using rsync.
backup_directory() {
    local dir_to_backup="$1"
    local backup_dir="$HOME/.backup_$(basename "$dir_to_backup")_$(date +%Y%m%d_%H%M%S)"

    if [[ -d "$dir_to_backup" ]]; then
        log "Backing up '$dir_to_backup' to '$backup_dir'..."
        mkdir -p "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
        rsync -av --progress "$dir_to_backup/" "$backup_dir/" || handle_error "Failed to backup '$dir_to_backup' to '$backup_dir'."
        log "Backup completed: '$backup_dir'"
    else
        log "Directory '$dir_to_backup' does not exist. Skipping backup."
    fi
}

# --- Function: install_db_tool ---
# Purpose: Install a database tool (PostgreSQL, MySQL, SQLite) using the system's package manager.
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

# --- Function: check_db_tool_directories ---
# Purpose: Ensure PostgreSQL, MySQL, and SQLite directories are writable.
check_db_tool_directories() {
    local psql_home="$XDG_DATA_HOME/postgresql"
    local mysql_home="$XDG_DATA_HOME/mysql"
    local sqlite_home="$XDG_DATA_HOME/sqlite"

    check_directory_writable "$psql_home"
    check_directory_writable "$mysql_home"
    check_directory_writable "$sqlite_home"
}

# --- Function: verify_db_tool_installation ---
# Purpose: Verify that a database tool is installed and functional.
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

# --- Function: find_editor ---
# Purpose: Dynamically find a valid editor from a list of common ones.
find_editor() {
    local editors=("vim" "nano" "micro" "emacs" "code" "sublime" "gedit")
    for editor in "${editors[@]}"; do
        if command -v "$editor" &> /dev/null; then
            echo "$editor"
            return 0
        fi
    done
    echo "nano"  # Default fallback editor
}

# --- Function: update_settings ---
# Purpose: Placeholder function to modify settings. Should be implemented as needed.
update_settings() {
    log "Updating settings..."
    # Implement the settings modification logic here.
    # For example, updating configuration files or environment variables.
}

# --- Function: source_settings ---
# Purpose: Source the settings.sh file to load configurations.
source_settings() {
    local settings_file="$HOME/.config/shellz/settings.sh"
    if [[ -f "$settings_file" ]]; then
        log "Sourcing settings from '$settings_file'..."
        # shellcheck source=/dev/null
        source "$settings_file" || handle_error "Failed to source '$settings_file'."
    else
        log "Settings file '$settings_file' does not exist. Skipping sourcing."
    fi
}

# --- Function: test ---
# Purpose: Placeholder for testing functions. Should be implemented as needed.
test_script() {
    # Implement testing logic here.
    :
}

# Note: Additional helper functions can be added below as needed.
