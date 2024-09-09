#!/bin/bash

# Common function to check for missing dependencies
function check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to check if a directory is writable
function check_directory_writable() {
    local dir=$1
    if [[ ! -w "$dir" ]]; then
        echo "Error: $dir is not writable. Please check permissions."
        exit 1
    fi
}

# Function to update the package list using the appropriate package manager
function update_package_list() {
    if command -v pacman &> /dev/null; then
        echo "Updating package list with pacman..."
        sudo pacman -Syu
    elif command -v apt-get &> /dev/null; then
        echo "Updating package list with apt-get..."
        sudo apt-get update && sudo apt-get upgrade -y
    else
        echo "Unsupported package manager. Please update the package list manually."
        exit 1
    fi
}

# Create a directory if it doesn't exist
create_directory_if_not_exists() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Consolidate directories by moving files from the source to the target
consolidate_directories() {
    local source_dir=$1
    local target_dir=$2

    if [[ -d "$source_dir" && "$source_dir" != "$target_dir" ]]; then
        echo "Consolidating $source_dir into $target_dir"
        mv "$source_dir"/* "$target_dir" 2>/dev/null
        rmdir "$source_dir" 2>/dev/null
    fi
}

# Ensure a specific Go tool is installed
ensure_tool_installed() {
    local tool_name=$1
    local tool_source=$2

    if ! command -v "$tool_name" &> /dev/null; then
        echo "Installing $tool_name..."
        go install "$tool_source"
    else
        echo "$tool_name is already installed."
    fi
}

# Add an environment variable to the zenvironment config file if it's not already present
add_to_zenvironment() {
    local var_name=$1
    local var_value=$2

    if ! grep -q "$var_name" "$HOME/.config/shellz/zenvironment"; then
        echo "Adding $var_name to zenvironment configuration..."
        echo "export $var_name=\"$var_value\"" >> "$HOME/.config/shellz/zenvironment"
    else
        echo "$var_name is already set in zenvironment."
    fi
}

# Remove empty directories from the given list
remove_empty_directories() {
    for dir in "$@"; do
        if [[ -d "$dir" && ! "$(ls -A "$dir")" ]]; then
            echo "Removing empty directory: $dir"
            rmdir "$dir"
        fi
    done
}

# Ensure Rust is installed and manage updates if necessary
ensure_rust_installed() {
    if ! command -v rustup &> /dev/null; then
        echo "Rustup is not installed. Installing Rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    else
        echo "Rustup is already installed."
    fi
}

# Install or update Cargo tools
cargo_install_or_update() {
    local tool_name=$1

    if cargo install --list | grep "$tool_name" &> /dev/null; then
        echo "Updating $tool_name..."
        cargo install "$tool_name" --force
    else
        echo "Installing $tool_name..."
        cargo install "$tool_name"
    fi
}

# Backup a given directory
backup_directory() {
    local dir_to_backup=$1
    local backup_dir="$HOME/.backup_$(basename "$dir_to_backup")_$(date +%Y%m%d)"

    if [[ -d "$dir_to_backup" ]]; then
        echo "Backing up $dir_to_backup to $backup_dir..."
        mkdir -p "$backup_dir"
        cp -r "$dir_to_backup" "$backup_dir"
        echo "Backup completed: $backup_dir"
    else
        echo "Directory $dir_to_backup does not exist."
    fi
}

# Ensure PostgreSQL, MySQL, and SQLite are installed
install_db_tool() {
    local tool_name=$1

    if ! command -v "$tool_name" &> /dev/null; then
        echo "Installing $tool_name..."
        if command -v pacman &> /dev/null; then
            sudo pacman -S "$tool_name"
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install "$tool_name" -y
        elif command -v dnf &> /dev/null; then
            sudo dnf install "$tool_name" -y
        else
            echo "Unsupported package manager. Please install $tool_name manually."
            exit 1
        fi
    else
        echo "$tool_name is already installed."
    fi
}

# Ensure PostgreSQL, MySQL, and SQLite directories are writable
check_db_tool_directories() {
    local psql_home="$XDG_DATA_HOME/postgresql"
    local mysql_home="$XDG_DATA_HOME/mysql"
    local sqlite_home="$XDG_DATA_HOME/sqlite"

    check_directory_writable "$psql_home"
    check_directory_writable "$mysql_home"
    check_directory_writable "$sqlite_home"
}

# Verify the installation of a database tool
verify_db_tool_installation() {
    local tool_name=$1

    if command -v "$tool_name" &> /dev/null; then
        echo "$tool_name is installed: $($tool_name --version)"
    else
        echo "Error: $tool_name is not functioning correctly."
        exit 1
    fi
}
