# System Functions

# Reset Permissions on Critical System Directories
reset_permissions() {
    # Ensure the script is run as root
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Error: This function must be run with root privileges. Please use sudo."
        return 1
    fi

    # Define directory permissions
    declare -A dir_permissions=(
        ["/boot"]=755
        ["/dev"]=755
        ["/etc"]=755
        ["/home"]=755
        ["/media"]=755
        ["/mnt"]=755
        ["/opt"]=755
        ["/proc"]=555
        ["/root"]=700
        ["/run"]=755
        ["/srv"]=755
        ["/sys"]=555
        ["/tmp"]=1777
        ["/usr"]=755
        ["/var"]=755
        ["/boot/efi"]=755
    )

    # Backup current permissions
    backup_permissions() {
        local backup_file="/tmp/permissions_backup_$(date +%Y%m%d%H%M%S).txt"
        echo "Backing up current permissions to $backup_file..."
        for dir in "${!dir_permissions[@]}"; do
            if [[ -d $dir ]]; then
                find "$dir" -exec stat -c "%a %n" {} \; >> "$backup_file" 2>/dev/null
            fi
        done
        echo "Backup completed."
    }

    # Reset directory permissions
    reset_dir_permissions() {
        local dry_run=$1
        for dir in "${!dir_permissions[@]}"; do
            if [[ -d $dir ]]; then
                local current_perm
                current_perm=$(stat -c "%a" "$dir" 2>/dev/null)
                if [[ "$current_perm" -ne "${dir_permissions[$dir]}" ]]; then
                    if [[ "$dry_run" == true ]]; then
                        echo "Dry Run: chmod ${dir_permissions[$dir]} $dir"
                    else
                        if chmod "${dir_permissions[$dir]}" "$dir"; then
                            echo "✔️ Permissions set for $dir to ${dir_permissions[$dir]}."
                        else
                            echo "❌ Failed to set permissions for $dir." >&2
                        fi
                    fi
                else
                    echo "✔️ Permissions for $dir are already correct."
                fi
            else
                echo "⚠️ Directory $dir does not exist; skipping."
            fi
        done
    }

    # Reset file permissions within directories
    reset_file_permissions() {
        local dry_run=$1
        local dir=$2

        if [[ -d "$dir" ]]; then
            if [[ "$dry_run" == true ]]; then
                echo "Dry Run: find $dir -type d -exec chmod 755 {} \;"
                echo "Dry Run: find $dir -type f -exec chmod 644 {} \;"
                echo "Dry Run: find $dir -type f -perm /u+x -exec chmod 755 {} \;"
            else
                find "$dir" -type d -exec chmod 755 {} \; && \
                find "$dir" -type f -exec chmod 644 {} \; && \
                find "$dir" -type f -perm /u+x -exec chmod 755 {} \;
                echo "✔️ Permissions reset for files and subdirectories in $dir."
            fi
        fi
    }

    # User confirmation
    echo "⚠️ This will reset permissions on critical system directories to their defaults."
    read -r -p "Are you sure you want to continue? (y/N) " REPLY
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Operation canceled."
        return 0
    fi

    # Dry run prompt
    read -r -p "Would you like to perform a dry run first? (y/N) " DRY_RUN
    echo
    if [[ "$DRY_RUN" =~ ^[Yy]$ ]]; then
        dry_run=true
        echo "🔍 Performing a dry run..."
    else
        dry_run=false
        # Backup permissions before making changes
        backup_permissions
    fi

    # Execute permission resets
    echo "🔄 Setting default permissions for main directories..."
    reset_dir_permissions "$dry_run"

    echo "🔄 Setting appropriate permissions for files and subdirectories..."
    reset_file_permissions "$dry_run" "/etc"
    reset_file_permissions "$dry_run" "/var"

    # Handle /boot/efi separately
    if [[ -d "/boot/efi" ]]; then
        local current_perm
        current_perm=$(stat -c "%a" "/boot/efi" 2>/dev/null)
        if [[ "$current_perm" -ne "755" ]]; then
            if [[ "$dry_run" == true ]]; then
                echo "Dry Run: chmod 755 /boot/efi"
            else
                if chmod 755 /boot/efi; then
                    echo "✔️ Permissions reset for /boot/efi."
                else
                    echo "❌ Failed to set permissions for /boot/efi. Please check manually." >&2
                fi
            fi
        else
            echo "✔️ Permissions for /boot/efi are already set correctly."
        fi
    fi

    echo "✅ Permissions reset process completed."
}

# Search for any process
any() {
    # Function to display help
    show_help() {
        echo "Usage: any [options] <process name>"
        echo "Options:"
        echo "  -i    Case-insensitive search"
        echo "  -h    Show this help message"
        echo ""
        echo "Example:"
        echo "  any ssh     # Find all running SSH processes"
        echo "  any -i ssh  # Case-insensitive search for SSH processes"
    }

    # Default options
    local case_insensitive=false

    # Parse options
    while getopts ":ih" opt; do
        case $opt in
            i)
                case_insensitive=true
                ;;
            h)
                show_help
                return 0
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                show_help
                return 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Check if a process name was provided
    if [[ -z $1 ]]; then
        echo "Error: No process name provided."
        show_help
        return 1
    fi

    # Search for processes
    local processes
    if [[ $case_insensitive == true ]]; then
        processes=$(pgrep -fil "$1" | grep -v grep)
    else
        processes=$(pgrep -fl "$1" | grep -v grep)
    fi

    # Check if any processes were found
    if [[ -z $processes ]]; then
        echo "No running processes found for '$1'."
        return 1
    fi

    # Print the found processes with formatting
    echo "Running processes matching '$1':"
    echo "--------------------------------"
    echo "$processes" | awk '{printf "%-10s %s\n", $1, $2}'
}

# System Optimization
sysboost() {
    # Ensure the script exits on any error
    set -e

    # Function to log messages with an optional delay
    log_and_wait() {
        local message=$1
        local delay=${2:-2}  # Default delay is 2 seconds
        echo "$message"
        sleep "$delay"
    }

    log_and_wait "Optimizing resources in 3 seconds."
    log_and_wait "3..."
    log_and_wait "2.."
    log_and_wait "1"

    # Reset failed systemd units
    if command -v systemctl &> /dev/null; then
        log_and_wait "Resetting all failed SystemD units..."
        systemctl reset-failed || true
    else
        log_and_wait "systemctl not found, skipping reset of failed units."
    fi

    # Clear unnecessary Dbus sockets if the command is available
    if command -v dbus-cleanup-sockets &> /dev/null; then
        log_and_wait "Clearing unnecessary Dbus sockets..."
        sudo dbus-cleanup-sockets
    else
        log_and_wait "Dbus-cleanup-sockets not found, skipping cleanup."
    fi

    # Remove broken SystemD links
    log_and_wait "Removing broken SystemD links..."
    if ! sudo find -L /etc/systemd/ -type l -delete; then
        log_and_wait "Unable to search SystemD for broken links."
    fi

    # Kill zombie processes if the zps command is available
    if command -v zps &> /dev/null; then
        log_and_wait "Killing all zombies..."
        sudo zps -r --quiet
    else
        log_and_wait "To kill zombies, zps is required. Install it with 'sudo pacman -S zps --noconfirm'. Skipping."
    fi

    # Reload the system daemon if systemctl is available
    if command -v systemctl &> /dev/null; then
        log_and_wait "Reloading system daemon..."
        sudo systemctl daemon-reload
    else
        log_and_wait "systemctl not found, skipping daemon reload."
    fi

    # Remove old logs using journalctl if available
    if command -v journalctl &> /dev/null; then
        log_and_wait "Removing logs older than 2 days..."
        sudo journalctl --vacuum-time=2d
    else
        log_and_wait "journalctl not found, skipping log cleanup."
    fi

    # Clear /tmp files using tmpwatch or tmpreaper if available
    if command -v tmpwatch &> /dev/null; then
        log_and_wait "Clearing /tmp files older than 2 hours..."
        sudo tmpwatch 2h /tmp
    elif command -v tmpreaper &> /dev/null; then
        log_and_wait "Clearing /tmp files older than 2 hours..."
        sudo tmpreaper 2h /tmp
    else
        log_and_wait "Neither tmpwatch nor tmpreaper found, skipping /tmp cleanup."
    fi

    log_and_wait "Resources optimized."

    # Disable exit on error
    set +e
}

# Swap Optimization
swapboost() {
    # Initialize log file
    log_file="/tmp/swapboost_log.txt"
    echo "Logging to $log_file"
    echo "Starting swapboost process..." > "$log_file"

    echo "Scanning accessible file mappings..."
    sleep 2
    local file_count=0
    local cmd_prefix=""
    [[ $EUID -ne 0 ]] && cmd_prefix="sudo"

    # Touch only accessible memory-mapped files
    if command -v parallel &> /dev/null; then
        sed -ne 's:.* /:/:p' /proc/[0-9]*/maps 2>/dev/null | sort -u | grep -v '^/dev/' | grep -v '(deleted)' | \
        parallel "$cmd_prefix cat {} > /dev/null 2>/dev/null && echo 'Accessed {}' >> \"$log_file\""
    else
        for file in $(sed -ne 's:.* /:/:p' /proc/[0-9]*/maps 2>/dev/null | sort -u | grep -v '^/dev/' | grep -v '(deleted)'); do
            if $cmd_prefix cat "$file" > /dev/null 2>/dev/null; then
                ((file_count++))
                echo "Accessed $file" >> "$log_file"
            fi
        done
    fi

    echo "Accessed $file_count files from mappings..."
    sleep 2

    echo 'Refreshing swap spaces...'
    sleep 2

    # Refresh swap spaces
    if $cmd_prefix swapoff -a && $cmd_prefix swapon -a; then
        echo "Swap spaces refreshed!"
    else
        echo "Failed to refresh swap spaces" >> "$log_file"
    fi

    # Final message
    echo "Swapboost process completed." >> "$log_file"
    echo "Swapboost process completed."
}

# Full System Boost
fullboost() {
    # Run sysboost for general optimization
    echo "Running sysboost..."
    sysboost

    # Run swapboost to refresh swap spaces and access memory-mapped files
    echo "Running swapboost..."
    swapboost

    echo "Full system boost completed."
}
