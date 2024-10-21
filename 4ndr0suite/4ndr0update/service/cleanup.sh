#!/bin/bash

# Function to log cleanup actions
log_cleanup() {
    local log_file="/var/log/4ndr0update_cleanup.log"
    echo "$(date): $1" >> "$log_file"
}

# Function to show a spinner
spinner() {
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to remove orphaned packages with a timeout
remove_orphaned_packages() {
    printf "\nChecking for orphaned packages...\n"

    # Run the orphan check in the background
    (mapfile -t orphaned < <(pacman -Qtdq)) &
    pid=$!

    # Start the spinner
    spinner $pid &
    spinner_pid=$!

    # Set a timeout of 60 seconds
    ( sleep 60 && kill -9 $pid 2>/dev/null && kill -9 $spinner_pid 2>/dev/null && printf "\nTimeout reached. Process killed.\n" ) &
    timeout_pid=$!

    # Wait for the orphan check to complete
    wait $pid
    kill $spinner_pid 2>/dev/null
    kill $timeout_pid 2>/dev/null

    if [[ "${orphaned[*]}" ]]; then
        printf "ORPHANED PACKAGES FOUND:\n"
        printf '%s\n' "${orphaned[@]}"
        read -r -p "Do you want to remove the above orphaned packages? [y/N] "
        if [[ "$REPLY" =~ [yY] ]]; then
            if pacman -Rns --noconfirm "${orphaned[@]}"; then
                printf "...Successfully removed orphaned packages.\n"
                log_cleanup "Removed orphaned packages: ${orphaned[*]}"
            else
                printf "...Failed to remove some orphaned packages. Check logs for details.\n"
                log_cleanup "Failed to remove some orphaned packages."
            fi
        else
            printf "...Orphaned packages were not removed.\n"
        fi
    else
        printf "...No orphaned packages found.\n"
    fi
}

# Function to clean up the package cache
clean_package_cache() {
    printf "\n"
    read -r -p "Do you want to clean up the package cache? [y/N]"
    if [[ "$REPLY" =~ [yY] ]]; then
        printf "Cleaning up the package cache...\n"
        if paccache -r; then
            log_cleanup "Cleaned up package cache."
        else
            printf "...Failed to clean up the package cache. Check logs for details.\n"
            log_cleanup "Failed to clean up package cache."
        fi
    else
        printf "...Package cache cleanup was skipped.\n"
    fi
}

# Function to clean broken symlinks
clean_broken_symlinks() {
    printf "\n"
    read -r -p "Do you want to search for broken symlinks? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        printf "Checking for broken symlinks...\n"
        
        # Start the search in the background
        (mapfile -t broken_symlinks < <(find "${SYMLINKS_CHECK[@]}" -xtype l -print)) &
        pid=$!
        
        # Start the spinner
        spinner $pid
        
        wait $pid

        if [[ "${broken_symlinks[*]}" ]]; then
            printf "BROKEN SYMLINKS FOUND:\n"
            printf '%s\n' "${broken_symlinks[@]}"
            read -r -p "Do you want to remove the broken symlinks above? [y/N]"
            if [[ "$REPLY" =~ [yY] ]]; then
                # Handle removal failure by skipping problematic symlinks
                for symlink in "${broken_symlinks[@]}"; do
                    if rm "$symlink"; then
                        printf "...Removed broken symlink: %s\n" "$symlink"
                        log_cleanup "Removed broken symlink: $symlink"
                    else
                        printf "...Failed to remove symlink: %s. Check permissions or filesystem status.\n" "$symlink"
                        log_cleanup "Failed to remove broken symlink: $symlink"
                    fi
                done
            else
                printf "...Broken symlinks were not removed.\n"
            fi
        else
            printf "...No broken symlinks found.\n"
        fi
    else
        printf "...Search for broken symlinks was skipped.\n"
    fi
}

# Function to remind user to check for old configuration files
clean_old_config() {
    user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    test -z "$user_home" && user_home="~"
    printf "\nREMINDER: Check the following directories for old configuration files:\n"
    printf "$user_home/\n"
    printf "$user_home/.config/\n"
    printf "$user_home/.cache/\n"
    printf "$user_home/.local/share/\n"
}

