#!/bin/bash

# Color Coding for Output
RED='\e[1;31m' # Red
GRE='\e[1;32m' # Green
c0='\e[0m'     # Reset Text

# Global Definitions
PROFILES_DIR="${HOME}/.config/BraveSoftware/Brave-Browser"
BACKUP_DIR="${HOME}/BraveBackups"
BOOKMARKS_LOCATION="${HOME}/bookmarks.md"

# Create Backup Directory if it doesn't exist
[ ! -d "${BACKUP_DIR}" ] && mkdir -p "${BACKUP_DIR}"

# List available profiles
list_profiles() {
    local profile_count=0
    local profiles=()
    for profile_path in "${PROFILES_DIR}"/Default "${PROFILES_DIR}"/Profile*; do
        if [ -d "${profile_path}" ]; then
            profiles+=("$(basename "${profile_path}")")
            ((profile_count++))
        fi
    done

    echo "...${profile_count} total profiles available!"
    local i=1
    for profile in "${profiles[@]}"; do
        echo "${i}. ${profile}"
        ((i++))
    done
}

# Error Handling Functions
yell() { echo -e "${RED}$0: $*${c0}" >&2; }
die() { yell "$*"; exit 111; }

# Select a profile
select_profile() {
    list_profiles
    local choice
    echo "Enter the profile number:"
    read -r choice
    if [[ "$choice" -gt 0 && "$choice" -le "${#profiles[@]}" ]]; then
        echo "${profiles[$choice-1]}"
    else
        die "Invalid profile number."
    fi
}

# Backup a profile
backup_profile() {
    local profile_name=$1
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    local backup_path

    if [ -d "${profile_dir}" ]; then
        backup_path="${BACKUP_DIR}/${profile_name}-$(date +%Y%m%d%H%M%S)" # Assigning separately
        if cp -r "${profile_dir}" "${backup_path}"; then
            echo "Profile ${profile_name} backed up successfully."
        else
            die "Failed to back up profile ${profile_name}."
        fi
    else
        die "Profile ${profile_name} not found."
    fi
}

# Restore a profile
restore_profile() {
    local profile_name=$1
    local restore_file=$2

    if [ -d "${PROFILES_DIR}/${profile_name}" ] && [ -f "${restore_file}" ]; then
        if cp -r "${restore_file}" "${PROFILES_DIR}/${profile_name}"; then
            echo "Profile ${profile_name} restored successfully."
        else
            die "Failed to restore profile ${profile_name}."
        fi
    else
        die "Backup file not found or profile does not exist."
    fi
}

# Function to create a new profile
create_profile() {
    local new_profile_name
    echo "Enter the new profile name:"
    read -r new_profile_name
    mkdir -p "${PROFILES_DIR}/${new_profile_name}"
    echo "New profile ${new_profile_name} created."
}

# Extract and save Brave bookmarks to Markdown
braveBookmarks() {
    local word=$1
    local file_path
    file_path=$(find "${PROFILES_DIR}/Default" -iname "Bookmarks")

    if [ -n "$file_path" ]; then
        echo -e "## Brave Browser Bookmarks\n" > "${BOOKMARKS_LOCATION}"
        local contents
        contents=$(grep -oP '"url": "\K[^"]+' "${file_path}" | grep -i "$word")
        echo "$contents" | awk '{print "-",$0}' >> "${BOOKMARKS_LOCATION}"
        echo "Bookmarks exported to ${BOOKMARKS_LOCATION}."
    else
        die "No bookmarks found or Brave browser not installed."
    fi
}

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
            echo "Do you want to back up profile ${selected_profile}? (yes/no)"
            read -r confirm
            if [[ "${confirm}" == "yes" ]]; then
                backup_profile "${selected_profile}"
            fi
            ;;
        2)
            echo "List of backups:"
            ls "${BACKUP_DIR}"
            local backup_file
            echo "Enter the backup file name:"
            read -r backup_file
            selected_profile=$(select_profile)
            echo "Do you want to restore profile ${selected_profile} from ${BACKUP_DIR}/${backup_file}? (yes/no)"
            read -r confirm
            if [[ "${confirm}" == "yes" ]]; then
                restore_profile "${selected_profile}" "${BACKUP_DIR}/${backup_file}"
            fi
            ;;
        3)
            create_profile
            ;;
        4)
            echo "Enter a keyword to search or select all:"
            read -r keyword
            braveBookmarks "$keyword"
            ;;
        0)
            exit 0
            ;;
        *)
            die "Invalid input"
            ;;
    esac
}

# Run the main function
main