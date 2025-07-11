#!/bin/bash
# shellcheck disable=all

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi
sleep 1
echo "💀WARNING💀 - you are now operating as root..."
sleep 1
echo

set -e

# Function to display usage
usage() {
    echo "Usage: $0 [install|uninstall|clean] [source_directory]"
    exit 1
}

# Check if user is root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Ensure the correct number of arguments
if [ $# -lt 1 ] || { [ "$1" != "clean" ] && [ $# -ne 2 ]; }; then
    usage
fi

ACTION=$1
SOURCE_DIR=$2
LOG_DIR="/var/log/install_manager"
LOG_FILE="$LOG_DIR/$(basename $SOURCE_DIR).log"

# Ensure the source directory exists
if [ "$ACTION" != "clean" ] && [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Function to install software and log installed files
install_software() {
    mkdir -p "$LOG_DIR"

    # Find files before installation
    echo "Finding files before installation..."
    find /usr /bin /sbin > /tmp/before_install_part1.txt 2>/dev/null
    find /lib /lib64 /opt > /tmp/before_install_part2.txt 2>/dev/null
    find /usr/local > /tmp/before_install_part3.txt 2>/dev/null
    cat /tmp/before_install_part1.txt /tmp/before_install_part2.txt /tmp/before_install_part3.txt > /tmp/before_install.txt
    rm /tmp/before_install_part1.txt /tmp/before_install_part2.txt /tmp/before_install_part3.txt

    echo "Running install script..."
    (cd "$SOURCE_DIR" && ./install.sh)

    # Find files after installation
    echo "Finding files after installation..."
    find /usr /bin /sbin > /tmp/after_install_part1.txt 2>/dev/null
    find /lib /lib64 /opt > /tmp/after_install_part2.txt 2>/dev/null
    find /usr/local > /tmp/after_install_part3.txt 2>/dev/null
    cat /tmp/after_install_part1.txt /tmp/after_install_part2.txt /tmp/after_install_part3.txt > /tmp/after_install.txt
    rm /tmp/after_install_part1.txt /tmp/after_install_part2.txt /tmp/after_install_part3.txt

    # Compare and log the installed files
    echo "Logging installed files..."
    comm -13 /tmp/before_install.txt /tmp/after_install.txt > "$LOG_FILE"
    echo "Installation complete. Installed files logged to $LOG_FILE."
}

# Function to uninstall software using the log
uninstall_software() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "Log file $LOG_FILE not found. Cannot uninstall."
        exit 1
    fi

    echo "Uninstalling the package using log file $LOG_FILE..."
    while read -r file; do
        rm -rf "$file"
    done < "$LOG_FILE"
    echo "Uninstallation complete."
}

# Function to clean up temporary files and logs
clean_up() {
    echo "Cleaning up..."
    rm -f /tmp/before_install.txt /tmp/after_install.txt
    rm -f "$LOG_FILE"
    echo "Clean up complete."
}

# Perform the action specified by the user
case $ACTION in
    install)
        echo "Starting installation..."
        install_software
        ;;
    uninstall)
        echo "Starting uninstallation..."
        uninstall_software
        ;;
    clean)
        echo "Starting cleanup..."
        clean_up
        ;;
    *)
        usage
        ;;
esac
