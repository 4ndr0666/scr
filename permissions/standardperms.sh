#!/bin/bash

# Function to display verbose help and usage instructions
show_help() {
    echo "Usage: $(basename $0) [option] [directory]"
    echo "Enhanced permissions management for files and directories."
    echo
    echo "Options:"
    echo "  -a         Apply default permissions (files: 0600, directories: 0700)"
    echo "  -d         Apply directory permissions (0700)"
    echo "  -f         Apply file permissions (0600)"
    echo "  --chmod=   Apply custom chmod mode (e.g., --chmod=755)"
    echo "  --reset    Reset to factory settings for standard files and directories"
    echo "  -h         Display this help and exit"
    echo
    echo "Understanding Permissions:"
    echo "  Permissions are represented by three characters: r (read), w (write), x (execute)"
    echo "  Each character can be set for three different sets of users: owner, group, others"
    echo "  Example modes:"
    echo "    755 (rwxr-xr-x): Owner can read/write/execute, group/others can read/execute"
    echo "    644 (rw-r--r--): Owner can read/write, group/others can read"
    echo "  Use --chmod= for custom permissions like 751, 711, etc."
    echo
    echo "Examples:"
    echo "  $(basename $0) -a ./project   # Apply default permissions recursively to 'project'"
    echo "  $(basename $0) --chmod=644 ./file.txt   # Apply custom permissions to 'file.txt'"
    echo "  $(basename $0) --reset       # Reset permissions to factory settings"
    echo
    echo "Factory Settings Option ('--reset'):"
    echo "  This option simplifies permissions management for beginners. It resets permissions"
    echo "  of standard files and directories to safe, default values, correcting any accidental"
    echo "  modifications made by the user."
}

reset_to_factory_settings() {
    echo "Resetting to factory settings based on provided specifics and security best practices..."

    # Set permissions for system binaries and libraries
    chmod 755 /bin /etc /lib /opt /sbin /usr /var

    # Home directories: set to 700 for privacy, except for .local/bin in andro's home which requires special handling
    find /home -mindepth 1 -maxdepth 1 -type d ! -name andro -exec chmod 700 {} \;
    chmod 700 /home/andro
    chmod 755 /home/andro/.local/bin  # Make it similar to /usr/local/bin

    # Set permissions for essential configuration files in /etc
    find /etc -type f -exec chmod 644 {} \;  # Global read, owner write
    chmod 600 /etc/shadow /etc/gshadow /etc/sudoers /etc/passwd  # Restricted access

    # Ensure executability where appropriate and remove where not needed
    chmod +x /bin/* /usr/bin/* /usr/local/bin/*
    chmod -x /etc/shadow /etc/gshadow /etc/sudoers /etc/passwd

    echo "Permissions have been reset. Please review and adjust as needed for your specific security requirements."
}

# Auto-escalate to root if not already running as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

opt=${1:-'-h'}
dir=${2:-'.'}

# Process options
case "$opt" in
    -a)
        find "$dir" -type d -exec chmod 0700 "{}" \; -o -type f -exec chmod 0600 "{}" \;
        ;;
    -d)
        find "$dir" -type d -exec chmod 0700 "{}" \;
        ;;
    -f)
        find "$dir" -type f -exec chmod 0600 "{}" \;
        ;;
    --chmod=*)
        custom_mode="${opt#*=}"
        find "$dir" -exec chmod $custom_mode "{}" \;
        ;;
    --reset)
        reset_to_factory_settings
        ;;
    -h|*)
        show_help
        ;;
esac
