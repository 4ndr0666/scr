#!/bin/bash

# --- Colors ---
GRE="\033[32m" # Green
RED="\033[31m" # Red
YEL="\033[33m" # Yellow
c0="\033[0m"   # Reset color

# --- Error Handling ---
error_exit() {
    echo -e "${RED}$1${c0}" 1>&2
    exit 1
}

# --- Input Validation ---
validate_input() {
    if [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 18 ]; then
        return 0
    else
        echo -e "${RED}Invalid input. Please enter a number between 1 and 18.${c0}"
        return 1
    fi
}

# --- Confirmation Prompt ---
confirm() {
    read -rp "$1 (y/n): " choice
    case "$choice" in
        y|Y ) return 0 ;;
        n|N ) return 1 ;;
        * ) echo -e "${RED}Invalid input. Please enter y or n.${c0}" ;;
    esac
}

# --- Visual Feedback ---
executeFunctionWithFeedback() {
    echo -e "${YEL}Starting: $1${c0}"
    if $1; then
        echo -e "${GRE}$1 completed successfully.${c0}"
    else
        echo -e "${RED}$1 failed.${c0}"
    fi
    read -rp "Press any key to continue..." -n 1
}

# --- Display Help ---
display_help() {
    echo "Usage: $0 [option]"
    echo
    echo "Options:"
    echo "  1) Backup .gnupg Directory"
    echo "  2) Create New .gnupg Directory"
    echo "  3) Restore GnuPG Data"
    echo "  4) Set Correct Permissions"
    echo "  5) List GPG Keys"
    echo "  6) Generate GPG Key"
    echo "  7) Create Armored Key"
    echo "  8) Export GPG Key"
    echo "  9) Export and Add GPG Key to Service"
    echo " 10) Reinitialize GPG Agent"
    echo " 11) Clean Up Test Directory"
    echo " 12) Incremental Backup"
    echo " 13) Apply Security Template"
    echo " 14) Generate Advanced GPG Key"
    echo " 15) Export Keys in Different Formats"
    echo " 16) Automated Security Audit"
    echo " 17) Total Automation Workflow"
    echo " 18) Exit"
    echo
}

# --- Menu ---
display_menu() {
    clear
    echo -e "${GRE}====================================================="
    echo -e "FIXGPG.SH - A gpg management script by 4ndr0666"
    echo -e "====================================================="
    echo -e "${c0}=============== // ${GRE}Main Menu${c0} // ====================="
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
    echo "13) Apply Security Template"
    echo "14) Generate Advanced GPG Key"
    echo "15) Export Keys in Different Formats"
    echo "16) Automated Security Audit"
    echo "17) Total Automation Workflow"
    echo "18) Exit"
    echo -e "By your command: ${RED}\c"
}

# --- Function Definitions ---
backupGnupgDir() {
    local backupDir="$1"
    [ -d "$backupDir" ] || error_exit "Invalid directory path: $backupDir"
    echo "Backing up the .gnupg directory to $backupDir..."
    sudo cp -r ~/.gnupg "$backupDir" || error_exit "Backup failed."
}

createNewGnupgDir() {
    echo "Creating a new .gnupg directory..."
    sudo rm -rf "$HOME/.gnupg" || error_exit "Failed to remove existing .gnupg directory."
    sudo mkdir -m 700 "$HOME/.gnupg" || error_exit "Failed to create .gnupg directory."
    sudo chown -R "$USER:$USER" "$HOME/.gnupg" || error_exit "Failed to set ownership of .gnupg directory."
    gpg --list-keys || error_exit "Failed to list GPG keys."
}

restoreGnupgData() {
    local backupDir="$1"
    [ -d "$backupDir" ] || error_exit "Invalid directory path: $backupDir"
    echo "Restoring .gnupg data from $backupDir..."
    sudo cp -r "$backupDir/.gnupg" "$HOME/" || error_exit "Failed to restore .gnupg data."
    sudo chown -R "$USER:$USER" "$HOME/.gnupg" || error_exit "Failed to set ownership of .gnupg directory."
}

setCorrectPermissions() {
    echo "Setting correct permissions for .gnupg directory and home directory..."
    sudo chown -R "$USER:$USER" "$HOME/.gnupg" || error_exit "Failed to set ownership of .gnupg directory."
    sudo chmod 700 "$HOME/.gnupg" || error_exit "Failed to set permissions on .gnupg directory."
    sudo chmod 600 "$HOME/.gnupg/private-keys-v1.d/"* || error_exit "Failed to set permissions on private keys."
    sudo chmod 755 "$HOME" || error_exit "Failed to set permissions on home directory."
}

listGpgKeys() {
    echo "Public keys:"
    gpg --list-keys --keyid-format=long || error_exit "Failed to list public keys."
    echo "Secret keys:"
    gpg --list-secret-keys --keyid-format=long || error_exit "Failed to list secret keys."
}

generateGpgKey() {
    echo "Generating a new GPG key..."
    gpg --full-generate-key || error_exit "Failed to generate GPG key."
}

createArmoredKey() {
    local keyId="$1"
    local outputDir="$HOME/.cache/gpg"
    mkdir -p "$outputDir" || error_exit "Failed to create output directory."
    gpg --export -a "$keyId" > "$outputDir/$keyId.pub.asc" || error_exit "Failed to export public key."
    gpg --export-secret-keys -a "$keyId" > "$outputDir/$keyId.sec.asc" || error_exit "Failed to export secret key."
    echo "Armored public key:"
    cat "$outputDir/$keyId.pub.asc"
}

exportGpgKey() {
    local keyId="$1"
    local outputDir="$HOME/.cache/gpg"
    mkdir -p "$outputDir" || error_exit "Failed to create output directory."
    echo "Exporting GPG key $keyId..."
    gpg --export -a "$keyId" > "$outputDir/$keyId.pub.asc" || error_exit "Failed to export public key."
    echo "Exported public key:"
    cat "$outputDir/$keyId.pub.asc"
}

exportAndAddGpgKey() {
    local keyId="$1"
    echo "Exporting GPG key $keyId and adding it to GitHub..."

    # Ensure correct permissions for GPG and home directory
    sudo chmod 700 "$HOME/.gnupg" || error_exit "Failed to set permissions on .gnupg directory."
    sudo chmod 755 "$HOME" || error_exit "Failed to set permissions on home directory."

    # Export the GPG key in ASCII armor format
    key="$(gpg --armor --export "$keyId")"
    [ -n "$key" ] || error_exit "Failed to export GPG key."

    echo "Armored public key:"
    echo "$key"

    # Add the GPG key to GitHub using GitHub CLI
    echo "$key" | gh gpg-key add - || error_exit "Failed to add GPG key to GitHub."

    echo -e "${GRE}GPG key added to GitHub successfully.${c0}"
}

reinitializeGpgAgent() {
    echo "Reinitializing GPG agent..."
    sudo gpgconf --kill gpg-agent || error_exit "Failed to kill GPG agent."
    sudo gpgconf --launch gpg-agent || error_exit "Failed to launch GPG agent."
}

cleanUpTestDir() {
    local testDir="$1"
    echo "Cleaning up test directory: $testDir..."
    sudo rm -rf "$testDir" || error_exit "Failed to clean up test directory."
}

incrementalBackupGnupg() {
    local backupDir="$1"
    echo "Performing incremental backup to $backupDir..."
    sudo rsync -av --progress "$HOME/.gnupg" "$backupDir" || error_exit "Failed to perform incremental backup."
}

applySecurityTemplate() {
    local template="$1"
    echo "Applying security template: $template..."

    case "$template" in
        "high-security")
            sudo tee "$HOME/.gnupg/gpg.conf" > /dev/null <<EOL
use-agent
keyserver hkp://keys.gnupg.net
keyserver-options auto-key-retrieve
EOL
            ;;
        "standard")
            sudo tee "$HOME/.gnupg/gpg.conf" > /dev/null <<EOL
use-agent
EOL
            ;;
        "paranoid")
            sudo tee "$HOME/.gnupg/gpg.conf" > /dev/null <<EOL
use-agent
keyserver hkp://keys.gnupg.net
keyserver-options auto-key-retrieve
personal-digest-preferences SHA512
cert-digest-algo SHA512
EOL
            sudo chattr +i "$HOME/.gnupg" || error_exit "Failed to make .gnupg directory immutable."
            ;;
        "minimal")
            sudo tee "$HOME/.gnupg/gpg.conf" > /dev/null <<EOL
use-agent
EOL
            ;;
        *)
            error_exit "Invalid security template specified."
            ;;
    esac
    echo "Security template applied successfully."
}

generateAdvancedGpgKey() {
    local keyType="$1"
    local keyLength="$2"
    echo "Generating advanced GPG key with type $keyType and length $keyLength..."
    gpg --full-generate-key --key-type "$keyType" --key-length "$keyLength" || error_exit "Failed to generate advanced GPG key."
}

exportKeysToFormats() {
    local keyId="$1"
    local format="$2"
    local outputDir="$HOME"
    if [ "$format" == "ascii-armored" ]; then
        gpg --export -a "$keyId" > "$outputDir/$keyId.pub.asc" || error_exit "Failed to export public key in ASCII armor format."
        echo "Exported public key in ASCII armor format:"
        cat "$outputDir/$keyId.pub.asc"
    else
        gpg --export "$keyId" > "$outputDir/$keyId.pub.bin" || error_exit "Failed to export public key in binary format."
        echo "Exported public key in binary format:"
        hexdump -C "$outputDir/$keyId.pub.bin"
    fi
}

automatedSecurityAudit() {
    echo "Running automated security audit..."

    echo "Checking GPG version..."
    gpg --version || error_exit "Failed to get GPG version."

    echo "Listing all public keys..."
    gpg --list-keys || error_exit "Failed to list public keys."

    echo "Listing all secret keys..."
    gpg --list-secret-keys || error_exit "Failed to list secret keys."

    echo "Checking GPG configuration files..."
    [ -f "$HOME/.gnupg/gpg.conf" ] && echo "gpg.conf found." || echo "gpg.conf not found."
    [ -f "$HOME/.gnupg/gpg-agent.conf" ] && echo "gpg-agent.conf found." || echo "gpg-agent.conf not found."

    echo "Checking key trust levels..."
    gpg --list-keys --with-colons | grep '^pub' | awk -F: '{ print $2 " " $3 " " $5 }' || error_exit "Failed to list key trust levels."

    echo "Verifying ownership and permissions of .gnupg directory..."
    ls -ld "$HOME/.gnupg" || error_exit "Failed to verify ownership and permissions of .gnupg directory."
    ls -l "$HOME/.gnupg" || error_exit "Failed to list .gnupg directory."

    echo "Security audit completed successfully."
}

totalAutomationWorkflow() {
    echo "Starting total automation workflow..."

    # Verify GPG Installation
    if ! gpg --version; then
        error_exit "GPG is not installed. Please install GPG and try again."
    fi

    # Initialize GPG Directory
    gpg --list-keys

    # List Existing Keys
    echo "Listing all public keys..."
    gpg --list-keys
    echo "Listing all secret keys..."
    gpg --list-secret-keys

    # Change Ownership and Permissions
    echo "Setting correct permissions for .gnupg directory..."
    sudo chown -R "$USER:$USER" "$HOME/.gnupg"
    sudo chmod 700 "$HOME/.gnupg"
    sudo chmod 600 "$HOME/.gnupg/private-keys-v1.d/"*

    # Generate a New Key
    echo "Generating a new GPG key..."
    gpg --full-generate-key

    # Backup and Restore GPG Keys
    echo "Backing up all keys and trust database..."
    gpg --export -a > all_public_keys.asc
    gpg --export-secret-keys -a > all_secret_keys.asc
    gpg --export-ownertrust > trustdb.txt

    echo "Restoring all keys and trust database..."
    gpg --import all_public_keys.asc
    gpg --import all_secret_keys.asc
    gpg --import-ownertrust trustdb.txt

    # Common Troubleshooting
    echo "Common troubleshooting steps..."
    gpg --list-keys | grep key_id
    sudo chown -R "$USER:$USER" "$HOME/.gnupg"
    sudo chmod 700 "$HOME/.gnupg"
    sudo chmod 600 "$HOME/.gnupg/private-keys-v1.d/"*
    sudo gpgconf --kill gpg-agent
    sudo gpgconf --launch gpg-agent

    echo "Total automation workflow completed successfully."
}

# --- Main Execution ---
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        display_help
        exit 0
    fi

    while true; do
        display_menu
        read -rp "Enter your choice: " choice

        case "$choice" in
            1)
                read -rp "Enter path to backup dir: " backupDir
                executeFunctionWithFeedback "backupGnupgDir '$backupDir'"
                ;;
            2) executeFunctionWithFeedback "createNewGnupgDir" ;;
            3)
                read -rp "Enter path to backup dir: " backupDir
                executeFunctionWithFeedback "restoreGnupgData '$backupDir'"
                ;;
            4) executeFunctionWithFeedback "setCorrectPermissions" ;;
            5) executeFunctionWithFeedback "listGpgKeys" ;;
            6) executeFunctionWithFeedback "generateGpgKey" ;;
            7)
                read -rp "Enter key ID for armored export: " keyId
                executeFunctionWithFeedback "createArmoredKey '$keyId'"
                ;;
            8)
                read -rp "Enter key ID for export: " keyId
                executeFunctionWithFeedback "exportGpgKey '$keyId'"
                ;;
            9)
                read -rp "Enter key ID for exporting and adding to service: " keyId
                executeFunctionWithFeedback "exportAndAddGpgKey '$keyId' 'GitHub'"
                ;;
            10) executeFunctionWithFeedback "reinitializeGpgAgent" ;;
            11)
                read -rp "Enter path to test dir for cleanup: " testDir
                executeFunctionWithFeedback "cleanUpTestDir '$testDir'"
                ;;
            12)
                read -rp "Enter path to incremental backup dir: " backupDir
                executeFunctionWithFeedback "incrementalBackupGnupg '$backupDir'"
                ;;
            13)
                echo "Select security template:"
                echo "1) high-security"
                echo "2) standard"
                echo "3) paranoid"
                echo "4) minimal"
                read -rp "Enter your choice (1-4): " templateChoice
                case "$templateChoice" in
                    1) template="high-security" ;;
                    2) template="standard" ;;
                    3) template="paranoid" ;;
                    4) template="minimal" ;;
                    *) echo -e "${RED}Invalid choice.${c0}" ;;
                esac
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
            16) executeFunctionWithFeedback "automatedSecurityAudit" ;;
            17) executeFunctionWithFeedback "totalAutomationWorkflow" ;;
            18) echo "Exiting program."
                exit 0
                ;;
            *) display_help ;;
        esac
    done
}

# Execute:
main "$@"
