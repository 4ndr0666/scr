#!/bin/bash

# Function to perform a full system backup
execute_full_backup() {
    printf "\nPerforming a full system backup to $BACKUP_LOCATION...\n"
    rsync -aAXHS --info=progress2 --delete \
        --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
        --exclude={"/swapfile","/lost+found","$BACKUP_LOCATION"} \
        / "$BACKUP_LOCATION"
    touch "$BACKUP_LOCATION/verified_backup_image.lock"
    printf "...Full backup completed successfully\n"
}

# Function to perform an incremental backup
execute_incremental_backup() {
    printf "\nPerforming an incremental backup to $BACKUP_LOCATION...\n"
    rsync -aAXHS --info=progress2 --delete --link-dest="$BACKUP_LOCATION/latest" \
        --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
        --exclude={"/swapfile","/lost+found","$BACKUP_LOCATION"} \
        / "$BACKUP_LOCATION/backup-$(date +%Y%m%d-%H%M%S)"
    printf "...Incremental backup completed successfully\n"
    # Update the 'latest' symlink to point to the latest backup
    ln -sfn "$BACKUP_LOCATION/backup-$(date +%Y%m%d-%H%M%S)" "$BACKUP_LOCATION/latest"
}

# Function to handle backup execution
execute_backup() {
    if [[ -d "$BACKUP_LOCATION" ]]; then
        read -r -p "Do you want to perform a full or incremental backup? [full/incremental] "
        if [[ "$REPLY" =~ ^[Ff]ull$ ]]; then
            execute_full_backup
        elif [[ "$REPLY" =~ ^[Ii]ncremental$ ]]; then
            execute_incremental_backup
        else
            printf "\nInvalid selection. Please choose 'full' or 'incremental'.\n"
        fi
    else
        printf "\n$BACKUP_LOCATION is not an existing directory\n"
        read -r -p "Do you want to create the backup directory at $BACKUP_LOCATION? [y/N] "
        if [[ "$REPLY" =~ [yY] ]]; then
            mkdir -p "$BACKUP_LOCATION"
            execute_backup
        fi
    fi
}

# Function to restore the system from a backup
execute_restore() {
    read -r -p "Do you want to restore the system from $BACKUP_LOCATION? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        if [[ -f "$BACKUP_LOCATION/verified_backup_image.lock" ]]; then
            printf "\nRestoring the system...\n"
            rsync -aAXHS --info=progress2 --delete \
                --exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
                --exclude={"/swapfile","/lost+found","/verified_backup_image.lock","$BACKUP_LOCATION"} \
                "$BACKUP_LOCATION/latest/" /
            printf "...System restored successfully from $BACKUP_LOCATION\n"
        else
            printf "\nError: No verified backup image found at $BACKUP_LOCATION. Please create a backup before restoring.\n"
        fi
    fi
}
