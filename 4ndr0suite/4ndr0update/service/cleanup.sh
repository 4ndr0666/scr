#!/bin/bash

# Function to log cleanup actions
log_cleanup() {
    local log_file="/var/log/4ndr0update_cleanup.log"
    echo "$(date): $1" >> "$log_file"
}

# Function to remove orphaned packages with a timeout
remove_orphans() {
    printf "Do you want to remove orphan packages? [y/N] "
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        printf "Removing orphan packages...\n"
        orphans=$(pacman -Qtdq)
        if [[ -n "$orphans" ]]; then
            sudo pacman -Rns $orphans
            printf "Orphan packages removed.\n"
        else
            printf "No orphan packages found.\n"
        fi
    else
        printf "Skipping orphan package removal.\n"
    fi
}


# Function to clean up the package cache
clean_package_cache() {
    printf "\n"
    read -r -p "Do you want to clean up the package cache? [y/N] "
    if [[ "$REPLY" =~ ^[yY]$ ]]; then
        printf "Cleaning up the package cache...\n"
        retry_command sudo pacman -Sc --noconfirm
        log_cleanup "Cleaned up package cache."
    else
        printf "...Skipping package cache clean.\n"
        log_cleanup "Skipped cleaning package cache."
    fi
    printf "\n"

    read -r -p "Do you want to remove unused AUR packages in the $AUR_DIR? [y/N] "
    if [[ "$REPLY" =~ ^[yY]$ ]]; then
        if [[ -d "$AUR_DIR" ]]; then
            rm -rf "$AUR_DIR"/*
            printf "...Unused AUR packages removed from %s\n" "$AUR_DIR"
            log_cleanup "Removed unused AUR packages"
        else
            printf "...AUR directory %s does not exist.\n" "$AUR_DIR"
            log_cleanup "Failed to remove unused AUR packages because directory does not exist."
        fi
    else
        printf "...Skipping removal of unused AUR packages.\n"
    fi
}

# Function to clean broken symlinks
clean_broken_symlinks() {
    printf "\n"
    read -r -p "Do you want to search for broken symlinks? [y/N] "
    if [[ "$REPLY" =~ ^[yY]$ ]]; then
        printf "Checking for broken symlinks...\n"
        for dir in "${SYMLINKS_CHECK[@]}"; do
            if [[ -d "$dir" ]]; then
                find "$dir" -xtype l
            else
                printf "Directory %s does not exist.\n" "$dir"
                log_cleanup "Failed to remove symlinks because directory does not exist."
            fi
        done
        printf "...Done checking for broken symlinks.\n"
    else
        printf "...Skipping check for broken symlinks.\n"
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
