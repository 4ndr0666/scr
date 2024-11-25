#!/bin/bash
# File: optimize_db_tools.sh
# Author: 4ndr0666
# Edited: 11-24-24
# Description: Optimizes database tools environment in alignment with XDG Base Directory Specifications.

# Function to optimize database tools environment
function optimize_db_tools_service() {
    echo "Optimizing database tools environment..."

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
    export PSQL_HOME="$XDG_DATA_HOME/postgresql"
    export MYSQL_HOME="$XDG_DATA_HOME/mysql"
    export SQLITE_HOME="$XDG_DATA_HOME/sqlite"
    export PATH="$PSQL_HOME/bin:$MYSQL_HOME/bin:$SQLITE_HOME/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.

    # Step 5: Check permissions for database tool directories
    check_directory_writable "$PSQL_HOME"
    check_directory_writable "$MYSQL_HOME"
    check_directory_writable "$SQLITE_HOME"

    # Step 6: Backup current database tool configurations (optional)
    backup_db_tools_configuration

    # Step 7: Testing and Verification
    echo "Verifying database tools setup..."
    verify_db_tools_setup

    # Step 8: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Database tools optimization complete."
    echo "PSQL_HOME: $PSQL_HOME"
    echo "MYSQL_HOME: $MYSQL_HOME"
    echo "SQLITE_HOME: $SQLITE_HOME"
}

# Helper function to install PostgreSQL
install_postgresql() {
    if command -v psql &> /dev/null; then
        echo "PostgreSQL is already installed."
    else
        echo "Installing PostgreSQL..."
        if sudo pacman -S --noconfirm postgresql; then
            echo "PostgreSQL installed successfully."
            # Initialize PostgreSQL database (optional)
            sudo -iu postgres initdb --locale en_US.UTF-8 -D /var/lib/postgres/data
            # Enable and start PostgreSQL service
            sudo systemctl enable --now postgresql
        elif sudo apt-get install -y postgresql; then
            echo "PostgreSQL installed successfully."
            # Enable and start PostgreSQL service
            sudo systemctl enable --now postgresql
        elif sudo dnf install -y postgresql-server; then
            echo "PostgreSQL installed successfully."
            # Initialize PostgreSQL database (optional)
            sudo postgresql-setup --initdb
            # Enable and start PostgreSQL service
            sudo systemctl enable --now postgresql
        else
            echo "Error: Failed to install PostgreSQL."
            exit 1
        fi
    fi
}

# Helper function to install MySQL
install_mysql() {
    if command -v mysql &> /dev/null; then
        echo "MySQL is already installed."
    else
        echo "Installing MySQL..."
        if sudo pacman -S --noconfirm mysql; then
            echo "MySQL installed successfully."
            # Initialize MySQL database (optional)
            sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
            # Enable and start MySQL service
            sudo systemctl enable --now mysqld
        elif sudo apt-get install -y mysql-server; then
            echo "MySQL installed successfully."
            # Enable and start MySQL service
            sudo systemctl enable --now mysql
        elif sudo dnf install -y mysql-server; then
            echo "MySQL installed successfully."
            # Initialize MySQL database (optional)
            sudo mysqld --initialize
            # Enable and start MySQL service
            sudo systemctl enable --now mysqld
        else
            echo "Error: Failed to install MySQL."
            exit 1
        fi
    fi
}

# Helper function to install SQLite
install_sqlite() {
    if command -v sqlite3 &> /dev/null; then
        echo "SQLite is already installed."
    else
        echo "Installing SQLite..."
        if sudo pacman -S --noconfirm sqlite; then
            echo "SQLite installed successfully."
        elif sudo apt-get install -y sqlite3; then
            echo "SQLite installed successfully."
        elif sudo dnf install -y sqlite; then
            echo "SQLite installed successfully."
        else
            echo "Error: Failed to install SQLite."
            exit 1
        fi
    fi
}

# Helper function to backup current database tool configurations
backup_db_tools_configuration() {
    echo "Backing up database tool configurations..."

    local backup_dir="$XDG_STATE_HOME/backups/db_tools_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$PSQL_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $PSQL_HOME"
    cp -r "$MYSQL_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $MYSQL_HOME"
    cp -r "$SQLITE_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $SQLITE_HOME"

    echo "Backup completed: $backup_dir"
}

# Helper function to verify database tools setup
verify_db_tools_setup() {
    echo "Verifying database tools setup..."

    # Check PostgreSQL installation
    if command -v psql &> /dev/null; then
        echo "PostgreSQL is installed: $(psql --version)"
    else
        echo "Error: PostgreSQL is not functioning correctly."
        exit 1
    fi

    # Check MySQL installation
    if command -v mysql &> /dev/null; then
        echo "MySQL is installed: $(mysql --version)"
    else
        echo "Error: MySQL is not functioning correctly."
        exit 1
    fi

    # Check SQLite installation
    if command -v sqlite3 &> /dev/null; then
        echo "SQLite is installed: $(sqlite3 --version)"
    else
        echo "Error: SQLite is not functioning correctly."
        exit 1
    fi
}
