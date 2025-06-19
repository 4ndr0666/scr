#!/bin/bash
# shellcheck disable=all

# --- // Colors:
GRE="\033[32m" # Green
RED="\033[31m" # Red
c0="\033[0m"   # Reset color

# --- // validation:
validate_input() {
    if [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 17 ]; then
        return 0
    else
        echo "Invalid input. Please enter a number between 1 and 17."
        return 1
    fi
}

# --- // Visual_feedback:
executeFunctionWithFeedback() {
    echo -e "\033[1;33m" # Yellow color
    echo "Starting: $1"
    echo -e "\033[0m" # Reset color

    eval "$1"

    echo -e "\033[1;32m" # Green color
    echo "$1 completed successfully."
    echo -e "\033[0m" # Reset color
    read -rp "Press any key to continue..." -n 1
}

# --- // Set_trap_for_SIGINT:
trap 'echo -e "\nExiting..."; cleanup; exit 1' SIGINT

# --- // Cleanup_tasks:
cleanup() {
    echo -e "\033[0m"
}

# --- // Menu:
display_menu() {
    clear
    echo -e "${GRE}# ===================== // Fixgpg.sh //"
    echo ""
    echo "1) Backup .gnupg Directory"
    echo "2) Create New .gnupg Directory"
    echo "3) Restore GnuPG Data"
    echo "4) Set Correct Permissions"
    echo "5) List GPG Keys"
    echo "6) Generate GPG Key"
    echo "7) Create Armored Key"
    echo "8) Export GPG Key"
    echo "9) Export and Add GPG Key to Service"
    echo "10) Reinitialize GPG Agent"
    echo "11) Clean Up Test Directory"
    echo "12) Incremental Backup"
    echo "13) Change Keyserver"
    echo "14) Generate Advanced GPG Key"
    echo "15) Export Keys in Different Formats"
    echo "16) Automated Security Audit"
    echo "17) Exit"
    echo ""
    echo -e "By your command: ${RED}\c"
}    
    
# --- // Backup_dir:
backupGnupgDir() {
    local backupDir="$1"
    if [ ! -d "$backupDir" ]; then
        echo "Invalid directory path: $backupDir"
        return 1
    fi
    echo "Backing up the .gnupg directory to $backupDir"
    if [ "$(id -u)" -ne 0 ]; then
        sudo rsync -a --backup ~/.gnupg/ "$backupDir" || { echo "Backup failed"; exit 1; }
    else
        rsync -a --backup ~/.gnupg/ "$backupDir" || { echo "Backup failed"; exit 1; }
    fi
    echo "Backup completed successfully."
}

# --- // New_dir:
createNewGnupgDir() {
    if [ -d "$HOME/.gnupg" ]; then
        echo "A .gnupg directory already exists. Please rename or remove it before creating a new one."
        exit 1
    fi

    echo "Creating a new .gnupg directory..."
    mkdir -pv ~/.gnupg && chmod 700 ~/.gnupg
    if [ -d "$HOME/.gnupg" ]; then
        echo ".gnupg directory created successfully."
    else
        echo "Failed to create .gnupg directory"
        exit 1
    fi
}

# --- // Restore_backup:
restoreGnupgData() {
    local backupDir="$1"
    if [ ! -d "$backupDir" ]; then
        echo "Invalid backup directory path: $backupDir"
        return 1
    fi
    echo "Restoring GnuPG data from $backupDir..."
    if [ "$(id -u)" -ne 0 ]; then
        sudo cp -r "$backupDir"/.gnupg/* ~/.gnupg/ || { echo "Restore failed"; exit 1; }
    else
        cp -r "$backupDir"/.gnupg/* ~/.gnupg/ || { echo "Restore failed"; exit 1; }
    fi
    echo "Data restored successfully."
}

# --- // Permissions:
setCorrectPermissions() {
    echo "Setting correct permissions for .gnupg directory and its contents..."
    chmod 700 ~/.gnupg
    if [ "$(id -u)" -ne 0 ]; then
        sudo find "$HOME"/.gnupg -type f -exec chmod 600 {} \;
    else
        find "$HOME"/.gnupg -type f -exec chmod 600 {} \;
    fi
    echo "Permissions set successfully."
}

# --- // List_keys:
listGpgKeys() {
    echo "Listing GnuPG keys..."
    gpg --list-keys
}

# --- // New_key:
generateGpgKey() {
    echo "Generating a new GnuPG key pair..."
    gpg --full-generate-key
}

# --- // Armor_key:
createArmoredKey() {
    local keyId="$1"
    echo "Creating an armored GPG key for $keyId..."
    gpg --armor --export "$keyId"
}

# --- // Export:
exportGpgKey() {
    local keyId="$1"
    echo "Exporting GPG key $keyId in armored format..."
    gpg --armor --export "$keyId"
}

# --- // Export_key_and_add:
exportAndAddGpgKey() {
    local keyId="$1"
    local service="$2"
    echo "Exporting GPG key $keyId and adding it to $service..."
    gpg --armor --export "$keyId" | gh gpg-key add -
}

# --- // Restart_agent:
reinitializeGpgAgent() {
    echo "Reinitializing the GPG agent..."
    gpgconf --kill gpg-agent
    gpg-agent --daemon
}

# --- // Clean_testdir:
cleanUpTestDir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "Removing the test GnuPG directory $dir..."
        rm -rf "$dir"
    else
        echo "Test directory $dir does not exist."
    fi
}

# --- // Incremental_backups:
incrementalBackupGnupg() {
    local backupDir="$1"
    echo "Performing incremental backup of .gnupg directory..."
    if [ "$(id -u)" -ne 0 ]; then
        sudo rsync -a --backup ~/.gnupg/ "$backupDir"
    else
        rsync -a --backup ~/.gnupg/ "$backupDir"
    fi
    echo "Incremental backup completed."
}

# --- // Keyserverss:
applySecurityTemplate() {
    local template="$1"
    echo "Applying security template: $template..."

    case "$template" in
        "high-security")
            gpgconf --change-options gpg > ~/.gnupg/gpg.conf
            echo "use-agent" >> ~/.gnupg/gpg.conf
            echo "keyserver hkps://keyserver.ubuntu.com" >> ~/.gnupg/gpg.conf
#            gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 5680CA389D365A88
            echo "keyserver-options auto-key-retrieve" >> ~/.gnupg/gpg.conf
            ;;
        "standard")
            gpgconf --change-options gpg > ~/.gnupg/gpg.conf
            echo "use-agent" >> ~/.gnupg/gpg.conf
            echo "keyserver hkps://keys.opnpgp.org" >> ~/.gnupg/gpg.conf
#            gpg --keyserver hkps://keys.openpgp.org --recv-keys 5680CA389D365A88
            echo "keyserver-options auto-key-retrieve" >> ~/.gnupg/gpg.conf
            ;;
        *)
            echo "Unknown template. Exiting."
            exit 1
            ;;
    esac
    echo "Security template applied successfully."
}

# --- // Advanced_key:
generateAdvancedGpgKey() {
    local keyType="$1"
    local keyLength="$2"
    echo "Generating an advanced GPG key of type $keyType and length $keyLength..."
    gpg --full-gen-key --key-type "$keyType" --key-length "$keyLength"
}

# --- // Export_keys:
exportKeysToFormats() {
    local keyId="$1"
    local format="$2"
    echo "Exporting keys to format: $format..."

    case "$format" in
        "ascii-armored")
            gpg --armor --export "$keyId"
            ;;
        "binary")
            gpg --export "$keyId"
            ;;
        *)
            echo "Unknown format. Exiting."
            exit 1
            ;;
    esac
    echo "Keys exported in $format format."
}

# --- // Security_audit:
automatedSecurityAudit() {
    echo "Performing automated security audit..."

    # Check for weak keys
    if gpg --list-keys | grep -q 'RSA2048'; then
        echo "Warning: Weak RSA keys found. Consider using RSA 4096 or ECC keys for stronger security."
    else
        echo "No weak RSA keys in use."
    fi

    # Check for improper permissions
    local hasIncorrectPermissions=0
    find ~/.gnupg -type d ! -perm 700 -exec echo "Incorrect directory permissions: {}" \; -exec bash -c 'hasIncorrectPermissions=1' \;
    find ~/.gnupg -type f ! -perm 600 -exec echo "Incorrect file permissions: {}" \; -exec bash -c 'hasIncorrectPermissions=1' \;

    if [ "$hasIncorrectPermissions" -eq 1 ]; then
        echo "Warning: Improper permissions found in .gnupg directory."
    else
        echo "All permissions are correctly set."
    fi

    echo "Automated security audit completed."
}

# --- // Enhanced Input Prompt Handling:
prompt_for_input() {
    local prompt="$1"
    local timeout="$2"
    local default="$3"

    # If no input within timeout, use default
    read -rp "$prompt" -t "$timeout" choice || choice="$default"

    echo "$choice"
}

# --- // Menu_logic:
main() {
    while true; do
        display_menu

        # Use the prompt_for_input function with a 10-second timeout and a default choice of '17'
        choice=$(prompt_for_input "By your command: " 10 "17")

        if ! validate_input "$choice"; then
            continue
        fi

        case "$choice" in
            1)
                read -rp "Enter backup directory path: " backupDir
                executeFunctionWithFeedback "backupGnupgDir '$backupDir'"
                ;;
            2)
                executeFunctionWithFeedback "createNewGnupgDir"
                ;;
            3)
                read -rp "Enter restore directory path: " restoreDir
                executeFunctionWithFeedback "restoreGnupgData '$restoreDir'"
                ;;
            4)
                executeFunctionWithFeedback "setCorrectPermissions"
                ;;
            5)
                executeFunctionWithFeedback "listGpgKeys"
                ;;
            6)
                executeFunctionWithFeedback "generateGpgKey"
                ;;
            7)
                read -rp "Enter key ID for armored key creation: " keyId
                executeFunctionWithFeedback "createArmoredKey '$keyId'"
                ;;
            8)
                read -rp "Enter key ID for exporting GPG key: " keyId
                executeFunctionWithFeedback "exportGpgKey '$keyId'"
                ;;
            9)
                read -rp "Enter key ID for exporting and adding to service: " keyId
                read -rp "Enter service name: " serviceName
                executeFunctionWithFeedback "exportAndAddGpgKey '$keyId' '$serviceName'"
                ;;
            10)
                executeFunctionWithFeedback "reinitializeGpgAgent"
                ;;
            11)
                read -rp "Enter path to test dir for cleanup: " testDir
                executeFunctionWithFeedback "cleanUpTestDir '$testDir'"
                ;;
            12)
                read -rp "Enter path to incremental backup dir: " backupDir
                executeFunctionWithFeedback "incrementalBackupGnupg '$backupDir'"
                ;;
            13)
                printf "Select security template:\n1) high-security\n2) standard\n"
                printf "Enter your choice (1 or 2): "
                read -rp templateChoice
                if [ "$templateChoice" -eq 1 ]; then
                    template="high-security"
                else
                    template="standard"
                fi
                executeFunctionWithFeedback "applySecurityTemplate '$template'"
                ;;
            14)
                read -rp "Enter key type for advanced GPG key (e.g., RSA): " keyType
                read -rp "Enter key length for advanced GPG key (e.g., 4096): " keyLength
                executeFunctionWithFeedback "generateAdvancedGpgKey '$keyType' '$keyLength'"
                ;;
            15)
                read -rp "Enter key ID for export: " keyId
                echo "Select format: 1) ascii-armored 2) binary"
                read -rp "Enter your choice (1 or 2): " formatChoice
                if [ "$formatChoice" -eq 1 ]; then
                    format="ascii-armored"
                else
                    format="binary"
                fi
                executeFunctionWithFeedback "exportKeysToFormats '$keyId' '$format'"
                ;;
            16)
                executeFunctionWithFeedback "automatedSecurityAudit"
                ;;
            17)
                echo "Exiting program."
                cleanup
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# --- // Execute:
main
