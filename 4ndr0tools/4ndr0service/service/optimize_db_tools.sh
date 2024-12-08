#!/bin/bash
# File: optimize_db_tools.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes database tools environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default backup directory (can be overridden if needed)
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$XDG_STATE_HOME/backups}"

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

install_postgresql() {
    if command -v psql &> /dev/null; then
        echo "PostgreSQL is already installed."
        log "PostgreSQL is already installed."
    else
        echo "Installing PostgreSQL..."
        if command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm postgresql || handle_error "Failed to install PostgreSQL with pacman."
            sudo -iu postgres initdb --locale en_US.UTF-8 -D /var/lib/postgres/data || log "Warning: Failed to initdb."
            sudo systemctl enable --now postgresql || log "Warning: Failed to enable/start PostgreSQL."
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y postgresql || handle_error "Failed to install PostgreSQL with apt-get."
            sudo systemctl enable --now postgresql || log "Warning: Failed to enable/start PostgreSQL."
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y postgresql-server || handle_error "Failed to install PostgreSQL with dnf."
            sudo postgresql-setup --initdb || log "Warning: Failed to initdb."
            sudo systemctl enable --now postgresql || log "Warning: Failed to enable/start PostgreSQL."
        else
            handle_error "Unsupported package manager or failed to install PostgreSQL."
        fi
        echo "PostgreSQL installed successfully."
        log "PostgreSQL installed successfully."
    fi
}

install_mysql() {
    if command -v mysql &> /dev/null; then
        echo "MySQL is already installed."
        log "MySQL is already installed."
    else
        echo "Installing MySQL..."
        if command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm mysql || handle_error "Failed to install MySQL with pacman."
            sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql || log "Warning: Failed to mysql_install_db."
            sudo systemctl enable --now mysqld || log "Warning: Failed to enable/start MySQL."
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y mysql-server || handle_error "Failed to install MySQL with apt-get."
            sudo systemctl enable --now mysql || log "Warning: Failed to enable/start MySQL."
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y mysql-server || handle_error "Failed to install MySQL with dnf."
            sudo mysqld --initialize || log "Warning: Failed to initialize MySQL database."
            sudo systemctl enable --now mysqld || log "Warning: Failed to enable/start MySQL."
        else
            handle_error "Unsupported package manager or failed to install MySQL."
        fi
        echo "MySQL installed successfully."
        log "MySQL installed successfully."
    fi
}

install_sqlite() {
    if command -v sqlite3 &> /dev/null; then
        echo "SQLite is already installed."
        log "SQLite is already installed."
    else
        echo "Installing SQLite..."
        if command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm sqlite || handle_error "Failed to install SQLite with pacman."
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y sqlite3 || handle_error "Failed to install SQLite with apt-get."
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y sqlite || handle_error "Failed to install SQLite with dnf."
        else
            handle_error "Unsupported package manager or failed to install SQLite."
        fi
        echo "SQLite installed successfully."
        log "SQLite installed successfully."
    fi
}

backup_db_tools_configuration() {
    echo "Backing up database tool configurations..."
    local backup_dir="$BACKUP_BASE_DIR/db_tools_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
    cp -r "$PSQL_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $PSQL_HOME"
    cp -r "$MYSQL_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $MYSQL_HOME"
    cp -r "$SQLITE_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $SQLITE_HOME"
    echo "Backup completed: $backup_dir"
    log "Database tools configuration backed up to '$backup_dir'."
}

verify_db_tools_setup() {
    echo "Verifying database tools setup..."

    if ! command -v psql &> /dev/null; then
        handle_error "PostgreSQL is not functioning correctly."
    else
        echo "PostgreSQL is installed: $(psql --version)"
    fi

    if ! command -v mysql &> /dev/null; then
        handle_error "MySQL is not functioning correctly."
    else
        echo "MySQL is installed: $(mysql --version)"
    fi

    if ! command -v sqlite3 &> /dev/null; then
        handle_error "SQLite is not functioning correctly."
    else
        echo "SQLite is installed: $(sqlite3 --version)"
    fi
    log "Database tools verification complete."
}

optimize_db_tools_service() {
    echo "🔧 Optimizing database tools environment..."

    # Ensure directories exist for database tools before installing
    export PSQL_HOME="$XDG_DATA_HOME/postgresql"
    export MYSQL_HOME="$XDG_DATA_HOME/mysql"
    export SQLITE_HOME="$XDG_DATA_HOME/sqlite"
    create_directory_if_not_exists "$PSQL_HOME"
    create_directory_if_not_exists "$MYSQL_HOME"
    create_directory_if_not_exists "$SQLITE_HOME"

    # Step 1: Ensure PostgreSQL is installed
    echo "Ensuring PostgreSQL is installed..."
    install_postgresql

    # Step 2: Ensure MySQL is installed
    echo "Ensuring MySQL is installed..."
    install_mysql

    # Step 3: Ensure SQLite is installed
    echo "Ensuring SQLite is installed..."
    install_sqlite

    # Step 4: Set up environment variables for database tools
    echo "Setting up environment variables for database tools..."
    export PATH="$PSQL_HOME/bin:$MYSQL_HOME/bin:$SQLITE_HOME/bin:$PATH"

    # Step 5: Check permissions
    check_directory_writable "$PSQL_HOME"
    check_directory_writable "$MYSQL_HOME"
    check_directory_writable "$SQLITE_HOME"

#    # Step 6: Backup configurations
#    backup_db_tools_configuration

    # Step 7: Verify setup
    verify_db_tools_setup

    # Step 8: Final cleanup
    echo "Performing final cleanup..."
    echo "Database tools optimization complete."
    log "Database tools optimization completed successfully."
    echo -e "${CYAN}PSQL_HOME:${NC} $PSQL_HOME"
    echo -e "${CYAN}MYSQL_HOME:${NC} $MYSQL_HOME"
    echo -e "${CYAN}SQLITE_HOME:${NC} $SQLITE_HOME"
}
