#!/bin/bash
# Enhanced Dependency Checker and Installer for Arch Linux with CLI and Improved Logic

LOGFILE="/var/log/dependency-checker.log"
PACMAN_LOCK="/var/lib/pacman/db.lck"
RETRIES=3
PKGLIST=""

# Function to log messages
log_message() {
    echo "$(date +"%Y-%m-%d %T") - $1" | tee -a "$LOGFILE"
}

# Function to check if a package is installed
is_installed() {
    pacman -Q "$1" &> /dev/null
}

# Function to check if a package is from AUR
is_aur_package() {
    yay -Qm "$1" &> /dev/null
}

# Function to gather dependencies of a package
gather_dependencies() {
    pactree -u -d1 "$1" 2>/dev/null | tail -n +2
}

# Function to remove pacman lock file if it exists
remove_pacman_lock() {
    if [ -e "$PACMAN_LOCK" ]; then
        log_message "Removing Pacman lock file..."
        sudo rm "$PACMAN_LOCK"
    fi
}

# Spinner for visual feedback
start_spinner() {
    global_spinner_active=true
    while $global_spinner_active; do
        for c in '/' '-' '\' '|'; do
            printf "\r$c"
            sleep 0.1
        done
    done
}

stop_spinner() {
    global_spinner_active=false
    printf "\r"
}

# Handle file conflicts and duplicated database entries
handle_pacman_output() {
    stderr="$1"
    duplicated_entries=$(echo "$stderr" | grep -oP "(?<=error: duplicated database entry ')[^']+")
    if [ ! -z "$duplicated_entries" ]; then
        log_message "Duplicated database entries detected: $duplicated_entries"
        for entry in $duplicated_entries; do
            log_message "Removing duplicated entry: $entry"
            sudo pacman -Rdd "$entry" --noconfirm
        done
    fi
    handle_file_conflicts "$stderr"
}

handle_file_conflicts() {
    stderr="$1"
    conflicts=$(echo "$stderr" | grep 'exists in filesystem')
    if [[ ! -z "$conflicts" ]]; then
        log_message "Resolving file conflicts..."
        files=$(echo "$conflicts" | awk '{print $5}')
        sudo pacman -Syu --overwrite "$files" --noconfirm
    fi
}

# Retry logic for package installation
install_with_retry() {
    local pkg="$1"
    local count=0
    until [ "$count" -ge "$RETRIES" ]; do
        sudo pacman -S "$pkg" --noconfirm && break
        count=$((count+1))
        log_message "Retrying installation of $pkg ($count/$RETRIES)..."
    done
    if [ "$count" -eq "$RETRIES" ]; then
        log_message "Failed to install $pkg after $RETRIES attempts."
    fi
}

# Ensure package installation based on whether it is a system or AUR package
ensure_package_installed() {
    local pkg="$1"
    if ! pacman -Qs "$pkg" > /dev/null; then
        log_message "Installing missing package: $pkg..."
        if is_aur_package "$pkg"; then
            yay -S "$pkg" --noconfirm
        else
            install_with_retry "$pkg"
        fi
    else
        log_message "Package $pkg is already installed."
    fi
}

# CLI Menu
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -i             Install missing dependencies"
    echo "  -c             Check missing dependencies"
    echo "  -h             Show this help message"
    exit 0
}

# Process input flags
if [[ $# -eq 0 ]]; then
    print_help
fi

while getopts "ich" option; do
    case $option in
        i)
            log_message "Installing missing dependencies..."
            ;;
        c)
            log_message "Checking missing dependencies..."
            ;;
        h)
            print_help
            ;;
        *)
            print_help
            ;;
    esac
done

# Graceful exit handling
graceful_exit() {
    stop_spinner
    remove_pacman_lock
    log_message "Script interrupted. Exiting gracefully..."
    exit 1
}

trap graceful_exit SIGINT SIGTERM

# Root privilege check
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Automatically create package list if none provided
if [ -z "$PKGLIST" ]; then
    log_message "No package list provided, generating from pacman -Qqe..."
    PKGLIST=$(pacman -Qqe)
fi

# Check missing dependencies
check_missing_dependencies() {
    for pkg in $PKGLIST; do
        log_message "Processing package: $pkg..."
        if is_installed "$pkg"; then
            log_message "$pkg is installed. Checking dependencies..."
            deps=$(gather_dependencies "$pkg")
            for dep in $deps; do
                if ! is_installed "$dep"; then
                    if [[ "$dep" == *"[unresolvable]"* ]]; then
                        log_message "Missing dependency: $dep (unresolvable)"
                    else
                        log_message "Missing dependency: $dep"
                        MISSING_DEPS+=("$dep")
                    fi
                fi
            done
        else
            log_message "$pkg is not installed. Skipping."
        fi
    done
}

# Install missing dependencies
install_missing_dependencies() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_message "Missing dependencies found: ${MISSING_DEPS[*]}"
        sudo yay -S "${MISSING_DEPS[@]}" --noconfirm
    else
        log_message "All dependencies are satisfied!"
    fi
}

# Main process
main() {
    log_message "Starting dependency check..."
    remove_pacman_lock
    check_missing_dependencies
    install_missing_dependencies
    log_message "Dependency check completed."
}

main
