# shellcheck disable=all
# ---- // FACTORY_BOOT FUNCTION:
factory_boot() {
    echo "🔧 Resetting ownership and permissions for /boot/..."
    log_action "factory_boot: Starting."
    
    # Ensure the /boot directory exists
    if [[ ! -d "/boot" ]]; then
        echo -e "\033[1;31m❌ Error: /boot directory does not exist.\033[0m"
        log_action "factory_boot: Error - /boot directory does not exist."
        return 1
    fi
    
    # Reset ownership
    sudo chown -R root:root /boot
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to reset ownership for /boot.\033[0m"
        log_action "factory_boot: Failed to reset ownership."
        return 1
    fi
    
    # Set permissions for directories to 755
    sudo find /boot -type d -exec chmod 755 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set directory permissions for /boot.\033[0m"
        log_action "factory_boot: Failed to set directory permissions."
        return 1
    fi
    
    # Set permissions for files to 644
    sudo find /boot -type f -exec chmod 644 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set file permissions for /boot.\033[0m"
        log_action "factory_boot: Failed to set file permissions."
        return 1
    fi
    
    echo -e "\033[1;32m✅ Successfully reset ownership and permissions for /boot.\033[0m"
    log_action "factory_boot: Completed successfully."
}

# ---- // FACTORY_USER FUNCTION:
factory_user() {
    echo "🔧 Resetting ownership and permissions for ~/.config and ~/.local..."
    log_action "factory_user: Starting."
    
    # Reset ownership
    sudo chown -R "$USER":"$USER" ~/.config ~/.local
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to reset ownership for ~/.config and ~/.local.\033[0m"
        log_action "factory_user: Failed to reset ownership."
        return 1
    fi
    
    # Set permissions for directories to 755
    sudo find ~/.config ~/.local -type d -exec chmod 755 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set directory permissions for ~/.config and ~/.local.\033[0m"
        log_action "factory_user: Failed to set directory permissions."
        return 1
    fi
    
    # Set permissions for files to 644
    sudo find ~/.config ~/.local -type f -exec chmod 644 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set file permissions for ~/.config and ~/.local.\033[0m"
        log_action "factory_user: Failed to set file permissions."
        return 1
    fi
    
    echo -e "\033[1;32m✅ Successfully reset ownership and permissions for ~/.config and ~/.local.\033[0m"
    log_action "factory_user: Completed successfully."
}

# ---- // FACTORY_GPG FUNCTION:
factory_gpg() {
    echo "🔧 Resetting ownership and permissions for ~/.gnupg..."
    log_action "factory_gpg: Starting."
    
    # Reset ownership
    sudo chown -R "$USER":"$USER" ~/.gnupg
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to reset ownership for ~/.gnupg.\033[0m"
        log_action "factory_gpg: Failed to reset ownership."
        return 1
    fi
    
    # Set permissions for ~/.gnupg directory
    chmod 700 ~/.gnupg
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for ~/.gnupg.\033[0m"
        log_action "factory_gpg: Failed to set ~/.gnupg permissions."
        return 1
    fi
    
    # Set permissions for subdirectories
    sudo find ~/.gnupg -type d -exec chmod 700 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for subdirectories in ~/.gnupg.\033[0m"
        log_action "factory_gpg: Failed to set subdirectory permissions."
        return 1
    fi
    
    # Set permissions for private key files
    if [[ -d ~/.gnupg/private-keys-v1.d ]]; then
        sudo chmod 600 ~/.gnupg/private-keys-v1.d/*
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31m❌ Error: Failed to set permissions for private keys in ~/.gnupg/private-keys-v1.d/.\033[0m"
            log_action "factory_gpg: Failed to set private key permissions."
            return 1
        fi
    else
        echo -e "\033[1;33m⚠️ Warning: ~/.gnupg/private-keys-v1.d/ directory does not exist. Skipping.\033[0m"
        log_action "factory_gpg: Warning - private-keys-v1.d/ directory does not exist."
    fi
    
    # Set permissions for other files
    sudo find ~/.gnupg -type f ! -path "~/.gnupg/private-keys-v1.d/*" -exec chmod 600 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for files in ~/.gnupg.\033[0m"
        log_action "factory_gpg: Failed to set file permissions."
        return 1
    fi
    
    echo -e "\033[1;32m✅ Successfully reset ownership and permissions for ~/.gnupg.\033[0m"
    log_action "factory_gpg: Completed successfully."
}

# --- // FACTORY_SSH_FUNCTION:
factory_ssh() {
    echo "🔧 Resetting ownership and permissions for ~/.ssh..."
    log_action "factory_ssh: Starting."
    
    # Reset ownership (without sudo if possible)
    chown -R "$USER":"$USER" ~/.ssh
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to reset ownership for ~/.ssh.\033[0m"
        log_action "factory_ssh: Failed to reset ownership."
        return 1
    fi
    
    # Set permissions for ~/.ssh directory
    chmod 700 ~/.ssh
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for ~/.ssh.\033[0m"
        log_action "factory_ssh: Failed to set ~/.ssh permissions."
        return 1
    fi
    
    # Set permissions for subdirectories
    find ~/.ssh -type d -exec chmod 700 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for subdirectories in ~/.ssh.\033[0m"
        log_action "factory_ssh: Failed to set subdirectory permissions."
        return 1
    fi
    
    # Set permissions for private key files
    chmod 600 ~/.ssh/id_rsa ~/.ssh/id_dsa ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa ~/.ssh/id_* 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;33m⚠️ Warning: Some private key files may not exist. Skipping missing files.\033[0m"
        log_action "factory_ssh: Warning - some private key files may not exist."
    fi
    
    # Set permissions for public key files
    chmod 644 ~/.ssh/id_rsa.pub ~/.ssh/id_dsa.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub ~/.ssh/*.pub 2>/dev/null
    
    # Set permissions for known_hosts and config
    chmod 600 ~/.ssh/authorized_keys ~/.ssh/known_hosts ~/.ssh/config 2>/dev/null
    
    echo -e "\033[1;32m✅ Successfully reset ownership and permissions for ~/.ssh.\033[0m"
    log_action "factory_ssh: Completed successfully."
}

# ---- // FACTORY_PYTHON FUNCTION:
factory_python() {
    echo "🔧 Resetting ownership and permissions for Python site-packages..."
    log_action "factory_python: Starting."
    
    # Detect Python version
    if ! python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null); then
        echo -e "\033[1;31m❌ Error: Unable to determine Python version.\033[0m"
        log_action "factory_python: Error - Unable to determine Python version."
        return 1
    fi
    
    local site_packages_dir="/usr/lib/python${python_version}/site-packages"
    
    # Check if site-packages directory exists
    if [[ -d "$site_packages_dir" ]]; then
        echo "🐍 Detected Python version: $python_version"
        echo "📁 Site-packages directory: $site_packages_dir"
        log_action "factory_python: Detected Python version $python_version and site-packages directory $site_packages_dir."
    
        # Reset ownership
        sudo chown -R root:root "$site_packages_dir"
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31m❌ Error: Failed to reset ownership for $site_packages_dir.\033[0m"
            log_action "factory_python: Failed to reset ownership for $site_packages_dir."
            return 1
        fi
    
        # Set permissions for directories to 755
        sudo find "$site_packages_dir" -type d -exec chmod 755 {} \;
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31m❌ Error: Failed to set directory permissions for $site_packages_dir.\033[0m"
            log_action "factory_python: Failed to set directory permissions for $site_packages_dir."
            return 1
        fi
    
        # Set permissions for files to 644
        sudo find "$site_packages_dir" -type f -exec chmod 644 {} \;
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31m❌ Error: Failed to set file permissions for $site_packages_dir.\033[0m"
            log_action "factory_python: Failed to set file permissions for $site_packages_dir."
            return 1
        fi
    
        echo -e "\033[1;32m✅ Successfully reset ownership and permissions for $site_packages_dir.\033[0m"
        log_action "factory_python: Completed successfully."
    else
        echo -e "\033[1;31m❌ Error: Directory $site_packages_dir not found for Python version $python_version.\033[0m"
        log_action "factory_python: Error - Directory $site_packages_dir not found."
        return 1
    fi
}

# --- // FACTORY_SYSTEM_FUNCTION:
factory_system() {
    echo "🔧 Resetting ownership and permissions for entire system..."
    log_action "factory_system: Starting."
    
    # Reset ownership (without sudo if possible)
    chown -R "$USER":"$USER" ~/.ssh
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to reset ownership for ~/.ssh.\033[0m"
        log_action "factory_ssh: Failed to reset ownership."
        return 1
    fi
    
    # Set permissions for ~/.ssh directory
    chmod 700 ~/.ssh
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for ~/.ssh.\033[0m"
        log_action "factory_ssh: Failed to set ~/.ssh permissions."
        return 1
    fi
    
    # Set permissions for subdirectories
    find ~/.ssh -type d -exec chmod 700 {} \;
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Failed to set permissions for subdirectories in ~/.ssh.\033[0m"
        log_action "factory_ssh: Failed to set subdirectory permissions."
        return 1
    fi
    
    # Set permissions for private key files
    chmod 600 ~/.ssh/id_rsa ~/.ssh/id_dsa ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa ~/.ssh/id_* 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;33m⚠️ Warning: Some private key files may not exist. Skipping missing files.\033[0m"
        log_action "factory_ssh: Warning - some private key files may not exist."
    fi
    
    # Set permissions for public key files
    chmod 644 ~/.ssh/id_rsa.pub ~/.ssh/id_dsa.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub ~/.ssh/*.pub 2>/dev/null
    
    # Set permissions for known_hosts and config
    chmod 600 ~/.ssh/authorized_keys ~/.ssh/known_hosts ~/.ssh/config 2>/dev/null
    
    echo -e "\033[1;32m✅ Successfully reset ownership and permissions for ~/.ssh.\033[0m"
    log_action "factory_ssh: Completed successfully."
}
