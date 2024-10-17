# ---- // RESTORE_PERMISSIONS FUNCTION WITH FZF AND HARDCODED PATH:
restore_permissions() {
    local backup_base_dir="/Nas/Backups/permission_backups/"
    
    # Check if fzf is installed
    if ! command -v fzf >/dev/null 2>&1; then
        echo -e "\033[1;31mError: fzf is not installed. Please install it to use restore_permissions.\033[0m"
        log_action "restore_permissions: fzf not installed."
        return 1
    fi
    
    # Check if backup directory exists
    if [[ ! -d "$backup_base_dir" ]]; then
        echo -e "\033[1;31mError: Backup directory '$backup_base_dir' does not exist.\033[0m"
        log_action "restore_permissions: Backup directory '$backup_base_dir' does not exist."
        return 1
    fi
    
    # List available backups sorted by date descending
    local backups=($(ls -d "${backup_base_dir}"*/ | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "\033[1;31mNo backups found in '$backup_base_dir'.\033[0m"
        log_action "restore_permissions: No backups found in '$backup_base_dir'."
        return 1
    fi
    
    # Use fzf to select a backup
    echo "🔍 Select a backup to restore:"
    local selected_backup=$(printf '%s\n' "${backups[@]}" | fzf --prompt="Choose backup: ")
    
    if [[ -z "$selected_backup" ]]; then
        echo -e "\033[1;33mNo backup selected. Aborting restore.\033[0m"
        log_action "restore_permissions: No backup selected. Aborting restore."
        return 0
    fi
    
    echo -e "\033[1;34mSelected backup: $selected_backup\033[0m"
    log_action "restore_permissions: Selected backup: $selected_backup"
    
    # Define the list of backup files to restore
    local backup_files=(
        "boot_acl_backup.txt"
        "python_site_packages_acl_backup.txt"
        "config_acl_backup.txt"
        "local_acl_backup.txt"
        "ssh_acl_backup.txt"
        "gnupg_acl_backup.txt"
    )
    
    # Iterate over each backup file and restore if exists
    for backup_file in "${backup_files[@]}"; do
        local backup_file_path="${selected_backup}${backup_file}"
        if [[ -f "$backup_file_path" ]]; then
            echo -e "🔄 Restoring ${backup_file}..."
            sudo setfacl --restore="$backup_file_path" 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "\033[1;31m❌ Error: Failed to restore ${backup_file}.\033[0m"
                log_action "restore_permissions: Failed to restore ${backup_file}."
            else
                echo -e "\033[1;32m✅ Successfully restored ${backup_file}.\033[0m"
                log_action "restore_permissions: Successfully restored ${backup_file}."
            fi
        else
            echo -e "\033[1;31m❌ Error: Backup file '$backup_file_path' not found.\033[0m"
            log_action "restore_permissions: Backup file '$backup_file_path' not found."
        fi
    done
    
    echo -e "\033[1;34m🔚 Permissions restoration process completed.\033[0m"
    log_action "restore_permissions: Permissions restoration process completed."
    
    return 0
}
