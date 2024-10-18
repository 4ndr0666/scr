# ---- // BACKUP_PERMISSIONS FUNCTION:
backup_permissions() {
    local backup_base_dir="/Nas/Backups/permission_backups/"
    local backup_dir="${backup_base_dir}$(date '+%Y%m%d_%H%M%S')"
    
    mkdir -p "$backup_dir"
    echo "🔄 Backing up current permissions..."
    log_action "Backing up current permissions to $backup_dir."
    
    # Backup /boot
    sudo getfacl -R /boot > "${backup_dir}/boot_acl_backup.txt" 2>/dev/null
    
    # Backup Python site-packages
    local python_version
    python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null)
    local site_packages_dir="/usr/lib/python${python_version}/site-packages"
    if [[ -d "$site_packages_dir" ]]; then
        sudo getfacl -R "$site_packages_dir" > "${backup_dir}/python_site_packages_acl_backup.txt" 2>/dev/null
    fi
    
    # Backup user-specific directories
    sudo getfacl -R ~/.config > "${backup_dir}/config_acl_backup.txt" 2>/dev/null
    sudo getfacl -R ~/.local > "${backup_dir}/local_acl_backup.txt" 2>/dev/null
    sudo getfacl -R ~/.ssh > "${backup_dir}/ssh_acl_backup.txt" 2>/dev/null
    sudo getfacl -R ~/.gnupg > "${backup_dir}/gnupg_acl_backup.txt" 2>/dev/null
    
    echo "✅ Backup completed at $backup_dir."
    log_action "Backup completed at $backup_dir."
}
