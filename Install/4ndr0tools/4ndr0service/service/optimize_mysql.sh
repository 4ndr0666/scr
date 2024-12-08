#!/bin/bash
# File: optimize_sql.sh
# Author: 4ndr0666
# Date: 2024-12-06
# Description: Finalizes and optimizes a unified SQL environment. Assumes optimize_db_tools.sh has been run.
#              Verifies psql, mysql, and sqlite3 installations, sets environment variables, optionally installs
#              additional SQL CLI tools (mycli, pgcli, litecli) if pipx is available, and backs up configurations.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$XDG_STATE_HOME/backups}"
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [ -w "$dir_path" ]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

create_directory_if_not_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || handle_error "Failed to create directory '$dir'."
        log "Created directory: '$dir'."
    fi
}

consolidate_directories() {
    local source_dir=$1
    local target_dir=$2

    if [ -d "$source_dir" ]; then
        rsync -av "$source_dir/" "$target_dir/" || log "Warning: Failed to consolidate $source_dir to $target_dir."
        echo "Consolidated directories from $source_dir to $target_dir."
        log "Consolidated directories from '$source_dir' to '$target_dir'."
    else
        echo "Source directory $source_dir does not exist. Skipping consolidation."
    fi
}

remove_empty_directories() {
    local dirs=("$@")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -type d -empty -delete
            echo "Removed empty directories in $dir."
            log "Removed empty directories in '$dir'."
        fi
    done
}

backup_sql_configuration() {
    echo "Backing up SQL configurations..."
    local backup_dir="$BACKUP_BASE_DIR/sql_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."

    # Backup directories if they exist
    for dir in "$SQL_DATA_HOME" "$SQL_CONFIG_HOME" "$SQL_CACHE_HOME"; do
        if [[ -d "$dir" ]]; then
            cp -r "$dir" "$backup_dir/" 2>/dev/null || echo "Warning: Could not copy $dir"
        fi
    done

    echo "Backup completed: $backup_dir"
    log "SQL configuration backed up to '$backup_dir'."
}

npm_global_install_or_update() {
    local package_name=$1
    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "Updating $package_name..."
        if npm update -g "$package_name"; then
            echo "$package_name updated successfully."
            log "$package_name updated successfully."
        else
            echo "Warning: Failed to update $package_name."
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "Installing $package_name globally..."
        if npm install -g "$package_name"; then
            echo "$package_name installed successfully."
            log "$package_name installed successfully."
        else
            echo "Warning: Failed to install $package_name."
            log "Warning: Failed to install $package_name."
        fi
    fi
}

pipx_install_or_update() {
    local tool_name=$1
    if pipx list | grep "$tool_name" &> /dev/null; then
        echo "Updating $tool_name..."
        if pipx upgrade "$tool_name"; then
            echo "$tool_name updated successfully."
            log "$tool_name updated successfully."
        else
            echo "Warning: Failed to update $tool_name."
            log "Warning: Failed to update $tool_name."
        fi
    else
        echo "Installing $tool_name via pipx..."
        if pipx install "$tool_name"; then
            echo "$tool_name installed successfully."
            log "$tool_name installed successfully."
        else
            echo "Warning: Failed to install $tool_name via pipx."
            log "Warning: Failed to install $tool_name via pipx."
        fi
    fi
}

verify_sql_tools() {
    echo "Verifying presence of SQL CLI tools (psql, mysql, sqlite3)..."

    if ! command -v psql &> /dev/null; then
        handle_error "psql not found. Please run optimize_db_tools.sh first."
    else
        echo "PostgreSQL CLI (psql): $(psql --version)"
    fi

    if ! command -v mysql &> /dev/null; then
        handle_error "mysql not found. Please run optimize_db_tools.sh first."
    else
        echo "MySQL CLI (mysql): $(mysql --version)"
    fi

    if ! command -v sqlite3 &> /dev/null; then
        handle_error "sqlite3 not found. Please run optimize_db_tools.sh first."
    else
        echo "SQLite CLI (sqlite3): $(sqlite3 --version)"
    fi
    log "SQL CLI tools verified."
}

install_optional_sql_clis() {
    # Optional step: install mycli, pgcli, litecli for enhanced SQL CLI experiences
    # Only if pipx is available
    if command -v pipx &> /dev/null; then
        echo "Installing optional SQL CLI tools (mycli, pgcli, litecli) via pipx..."
        pipx_install_or_update "mycli"
        pipx_install_or_update "pgcli"
        pipx_install_or_update "litecli"
    else
        echo "pipx not found. Skipping optional SQL CLI tools installation."
        log "pipx not found. Skipped optional SQL CLI tools."
    fi
}

optimize_sql_service() {
    echo "🔧 Optimizing SQL environment..."

    # Set up unified SQL environment variables
    export SQL_DATA_HOME="$XDG_DATA_HOME/sql"
    export SQL_CONFIG_HOME="$XDG_CONFIG_HOME/sql"
    export SQL_CACHE_HOME="$XDG_CACHE_HOME/sql"

    create_directory_if_not_exists "$SQL_DATA_HOME"
    create_directory_if_not_exists "$SQL_CONFIG_HOME"
    create_directory_if_not_exists "$SQL_CACHE_HOME"

    # Check directories writable
    check_directory_writable "$SQL_DATA_HOME"
    check_directory_writable "$SQL_CONFIG_HOME"
    check_directory_writable "$SQL_CACHE_HOME"

    # Verify that psql, mysql, sqlite3 are installed and functional
    verify_sql_tools

    # Optionally install additional CLI tools if desired
    # If user wants to skip this step, they can comment it out
    install_optional_sql_clis

    # Backup SQL configuration
    backup_sql_configuration

    # Perform cleanup if needed (no placeholders)
    # For now, we don't have temp directories to clean here, but let's just log completion
    echo "Performing final cleanup for SQL environment..."
    # If there were temporary directories, we'd remove them similarly to other scripts
    # Since we aren't creating any temporary directories here, we just finalize.

    echo "🎉 SQL environment optimization complete."
    log "SQL environment optimization completed successfully."
    echo -e "${CYAN}SQL_DATA_HOME:${NC} $SQL_DATA_HOME"
    echo -e "${CYAN}SQL_CONFIG_HOME:${NC} $SQL_CONFIG_HOME"
    echo -e "${CYAN}SQL_CACHE_HOME:${NC} $SQL_CACHE_HOME"
}

# Now we have completed all service scripts.

