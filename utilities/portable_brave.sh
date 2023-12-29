
#!/bin/bash

# Color Coding for Output
YEL='\033[1;33m' # Yellow
RED='\033[1;31m' # Red
GRE='\033[1;32m' # Green
c0=$'\033[0m'    # Reset Text

# Global Definitions
PROFILES_DIR="${HOME}/.config/BraveSoftware/Brave-Browser"
BACKUP_DIR="${HOME}/BraveBackups"
BOOKMARKS_LOCATION="${HOME}/bookmarks.md"

# Create Backup Directory if it doesn't exist
[ ! -d "${BACKUP_DIR}" ] && mkdir -p "${BACKUP_DIR}"

# List available profiles
list_profiles() {
    local profiles=($(find "${PROFILES_DIR}" -maxdepth 1 -type d -name 'Default' -o -name 'Profile [0-9]+' | xargs -n1 basename))
    echo "...${#profiles[@]} total profiles available!"
    local i=1
    for profile in "${profiles[@]}"; do
        echo "${i}. ${profile}"
        ((i++))
    done
}

# Error Handling Functions
yell() { echo -e "${RED}$0: $*${c0}" >&2; }
die() { yell "$*"; exit 111; }

# ... (rest of the functions including select_profile, backup_profile, restore_profile, braveBookmarks, create_profile)

# Main function with GUI enhancement
main() {
    clear
    echo -e "${GRE}========================================================================================${c0}"
    echo -e "${GRE}BRAVE PROFILE MANAGER${c0}"
    echo -e "${GRE}========================================================================================${c0}"
    list_profiles
    echo "=============== // Main Menu // ====================="
    echo "1) Backup             3) Create           0) Exit"
    echo "2) Restore            4) Bookmarks"
    echo "By your command:"
    read -r command

    case ${command} in
        1)
            local selected_profile
            selected_profile=$(select_profile)
            backup_profile "${selected_profile}"
            ;;
        2)
            echo "List of backups:"
            ls "${BACKUP_DIR}"
            local backup_file
            echo "Enter the backup file name:"
            read -r backup_file
            selected_profile=$(select_profile)
            restore_profile "${selected_profile}" "${BACKUP_DIR}/${backup_file}"
            ;;
        3)
            create_profile
            ;;
        4)
            echo "Enter a keyword to search in bookmarks (leave blank for all):"
            read -r keyword
            braveBookmarks "$keyword"
            ;;
        0)
            exit 0
            ;;
        *)
            die "Invalid operation."
            ;;
    esac
}

# Run the main function
main
