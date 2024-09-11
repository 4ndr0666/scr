#!/bin/bash

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

    add_to_zenvironment "PSQL_HOME" "$PSQL_HOME"
    add_to_zenvironment "MYSQL_HOME" "$MYSQL_HOME"
    add_to_zenvironment "SQLITE_HOME" "$SQLITE_HOME"
    add_to_zenvironment "PATH" "$PSQL_HOME/bin:$MYSQL_HOME/bin:$SQLITE_HOME/bin:$PATH"

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
}

# Helper function to install PostgreSQL
install_postgresql() {
    if command -v psql &> /dev/null; then
        echo "PostgreSQL is already installed."
    else
        echo "Installing PostgreSQL..."
        sudo pacman -S postgresql || sudo apt-get install postgresql || sudo dnf install postgresql
    fi
}

# Helper function to install MySQL
install_mysql() {
    if command -v mysql &> /dev/null; then
        echo "MySQL is already installed."
    else
        echo "Installing MySQL..."
        sudo pacman -S mysql || sudo apt-get install mysql-server || sudo dnf install mysql-server
    fi
}

# Helper function to install SQLite
install_sqlite() {
    if command -v sqlite3 &> /dev/null; then
        echo "SQLite is already installed."
    else
        echo "Installing SQLite..."
        sudo pacman -S sqlite || sudo apt-get install sqlite || sudo dnf install sqlite
    fi
}

# Helper function to backup current database tool configurations
backup_db_tools_configuration() {
    echo "Backing up database tool configurations..."

    local backup_dir="$HOME/.db_tools_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$PSQL_HOME" "$backup_dir"
    cp -r "$MYSQL_HOME" "$backup_dir"
    cp -r "$SQLITE_HOME" "$backup_dir"

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

# The controller script will call optimize_db_tools_service as needed, so there is no need for direct invocation in this file.
