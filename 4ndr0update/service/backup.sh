#!/bin/bash

LOG_FILE="/var/log/system_backup.log"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to check free space at the backup location
check_free_space() {
    local required_space=$(du -sx / | awk '{print $1}')
    local available_space=$(df --output=avail "$BACKUP_LOCATION" | tail -n1)
    
    if [[ $available_space -lt $required_space ]]; then
        log_message "Error: Not enough free space in $BACKUP_LOCATION."
        return 1
    else
        log_message "Sufficient space available for backup."
        return 0
    fi
}

# Function to generate a hash for backup integrity
generate_backup_hash() {
    log_message "Generating hash for backup verification..."
    find "$BACKUP_LOCATION" -type f -exec sha256sum {} \; > "$BACKUP_LOCATION/backup_hash.sha256"
    log_message "Backup hash saved at $BACKUP_LOCATION/backup_hash.sha256"
}

# Function to verify backup integrity
verify_backup_integrity() {
    if [[ -f "$BACKUP_LOCATION/backup_hash.sha256" ]]; then
        log_message "Verifying backup integrity..."
        cd "$BACKUP_LOCATION" || exit
        sha256sum -c backup_hash.sha256
        if [[ $? -eq 0 ]]; then
            log_message "Backup integrity verified."
            return 0
        else
            log_message "Error: Backup integrity verification failed."
            return 1
        fi
    else
        log_message "Warning: No hash found for backup integrity verification."
        return 2
    fi
}

# Function to execute the system backup
execute_backup() {
    if [[ -d "$BACKUP_LOCATION" ]]; then
        read -r -p "Do you want to backup the system to $BACKUP_LOCATION? [y/N] "
        if [[ "$REPLY" =~ [yY] ]]; then
            check_free_space || return 1

            log_message "Starting system backup..."
            rsync -aAXHS --info=progress2 --delete \
            --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
            --exclude={"/swapfile","/lost+found","$BACKUP_LOCATION"} \
            / "$BACKUP_LOCATION" || { log_message "Error: Backup failed."; return 1; }

            touch "$BACKUP_LOCATION/verified_backup_image.lock"
            log_message "Backup completed at $BACKUP_LOCATION."

            generate_backup_hash
        fi
    else
        log_message "Error: $BACKUP_LOCATION is not an existing directory."
        read -r -p "Do you want to create the backup directory at $BACKUP_LOCATION? [y/N] "
        if [[ "$REPLY" =~ [yY] ]]; then
            mkdir -p "$BACKUP_LOCATION"
            execute_backup
        fi
    fi
}

# Function to execute the system restore
execute_restore() {
    read -r -p "Do you want to restore the system from $BACKUP_LOCATION? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        if [[ -f "$BACKUP_LOCATION/verified_backup_image.lock" ]]; then
            log_message "Starting system restore..."

            verify_backup_integrity
            if [[ $? -ne 0 ]]; then
                log_message "Error: Backup integrity verification failed. Aborting restore."
                return 1
            fi

            rsync -aAXHS --info=progress2 --delete \
            --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
            --exclude={"/swapfile","/lost+found","/verified_backup_image.lock","$BACKUP_LOCATION"} \
            "$BACKUP_LOCATION/" / || { log_message "Error: Restore failed."; return 1; }

            log_message "System restore completed from $BACKUP_LOCATION."
        else
            log_message "Error: No verified backup found at $BACKUP_LOCATION."
        fi
    fi
}

# Function to dry-run backup/restore
dry_run() {
    read -r -p "Would you like to perform a dry run of the backup or restore? (backup/restore/none): " action
    if [[ "$action" == "backup" ]]; then
        log_message "Performing dry run of backup..."
        rsync -n -aAXHS --info=progress2 --delete \
        --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
        --exclude={"/swapfile","/lost+found","$BACKUP_LOCATION"} \
        / "$BACKUP_LOCATION"
    elif [[ "$action" == "restore" ]]; then
        log_message "Performing dry run of restore..."
        rsync -n -aAXHS --info=progress2 --delete \
        --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
        --exclude={"/swapfile","/lost+found","/verified_backup_image.lock","$BACKUP_LOCATION"} \
        "$BACKUP_LOCATION/" /
    else
        log_message "Skipping dry run."
    fi
}
