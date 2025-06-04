#!/bin/bash
# shellcheck disable=all

set -e

# Function to display usage
usage() {
    echo "Usage: $0 [install|uninstall] /path/to/source_directory"
    echo "Example:"
    echo "  $0 install /home/user/source/project"
    echo "  $0 uninstall /home/user/source/project"
    exit 1
}

# Check if user is root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Ensure the correct number of arguments
if [ $# -ne 2 ]; then
    usage
fi

ACTION=$1
SOURCE_DIR=$2

# Ensure the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Move to the source directory
cd "$SOURCE_DIR"

# Function to install software and log installed files
install_software() {
    local log_file="/var/log/make_installer/$(basename $SOURCE_DIR).log"
    mkdir -p /var/log/make_installer

    # Find files before installation
    find /usr /bin /sbin /lib /lib64 /opt /usr/local > /tmp/before_install.txt

    echo "Configuring the package..."
    ./configure
    echo "Building the package..."
    make
    echo "Installing the package..."
    sudo make install

    # Find files after installation
    find /usr /bin /sbin /lib /lib64 /opt /usr/local > /tmp/after_install.txt

    # Compare and log the installed files
    comm -13 /tmp/before_install.txt /tmp/after_install.txt > "$log_file"
    echo "Installation complete. Installed files logged to $log_file."
}

# Function to uninstall software using the log
uninstall_software() {
    local log_file="/var/log/make_installer/$(basename $SOURCE_DIR).log"
    if [ ! -f "$log_file" ]; then
        echo "Log file $log_file not found. Cannot uninstall."
        exit 1
    fi

    echo "Uninstalling the package using log file $log_file..."
    while read -r file; do
        sudo rm -rf "$file"
    done < "$log_file"
    echo "Uninstallation complete."
}

# Perform the action specified by the user
case $ACTION in
    install)
        install_software
        ;;
    uninstall)
        uninstall_software
        ;;
    *)
        usage
        ;;
esac
