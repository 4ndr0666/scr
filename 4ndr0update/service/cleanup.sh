#!/bin/bash

# Function to remove orphaned packages
remove_orphaned_packages() {
    printf "\nChecking for orphaned packages...\n"
    mapfile -t orphaned < <(pacman -Qtdq)
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
    read -r -p "Do you want to clean up the package cache? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        printf "Cleaning up the package cache...\n"
        if paccache -r; then
            printf "...Package cache cleaned up successfully.\n"
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
        
        # Start the spinner in the background
        spinner &
        spinner_pid=$!
        
        # Collect broken symlinks
        mapfile -t broken_symlinks < <(find "${SYMLINKS_CHECK[@]}" -xtype l -print)
        
        # Stop the spinner
        kill "$spinner_pid"
        wait "$spinner_pid" 2>/dev/null

        if [[ "${broken_symlinks[*]}" ]]; then
            printf "BROKEN SYMLINKS FOUND:\n"
            printf '%s\n' "${broken_symlinks[@]}"
            read -r -p "Do you want to remove the broken symlinks above? [y/N] "
            if [[ "$REPLY" =~ [yY] ]]; then
                printf "Removing broken symlinks...\n"
                
                # Start the spinner again
                spinner &
                spinner_pid=$!

                if rm "${broken_symlinks[@]}"; then
                    # Stop the spinner
                    kill "$spinner_pid"
                    wait "$spinner_pid" 2>/dev/null
                    
                    printf "...Broken symlinks removed successfully.\n"
                    log_cleanup "Removed broken symlinks: ${broken_symlinks[*]}"
                else
                    kill "$spinner_pid"
                    wait "$spinner_pid" 2>/dev/null
                    
                    printf "...Failed to remove some broken symlinks. Check logs for details.\n"
                    log_cleanup "Failed to remove some broken symlinks."
                fi
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

# Function to show a spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep "$pid")" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to log cleanup actions
log_cleanup() {
    local log_file="/var/log/4ndr0update_cleanup.log"
    echo "$(date): $1" >> "$log_file"
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
