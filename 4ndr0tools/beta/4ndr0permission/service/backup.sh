#!/bin/bash
# shellcheck disable=all

LOG_FILE="/var/log/4ndr0update_backup.log"

# Function to log messages
log_message() {
    local message="$1"
    printf "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}


# Function to execute the system backup
execute_backup() {
	if [[ -d "$BACKUP_LOCATION" ]]; then
		read -r -p "Do you want to backup the system to $BACKUP_LOCATION? [y/N]"
		if [[ "$REPLY" =~ [yY] ]]; then
				log_message "\nBacking up the system...\n"

				rsync -aAXHS --info=progress2 --delete \
				--exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
				--exclude={"/swapfile","/lost+found","$BACKUP_LOCATION"} \
                                / "$BACKUP_LOCATION" || { log_message "Error: Backup failed."; return 1; }

				touch "$BACKUP_LOCATION/verified_backup_image.lock"
				log_message "...Done backing up to $BACKUP_LOCATION\n"

		fi
	else
		log_message "\n$BACKUP_LOCATION is not an existing directory\n"
		read -r -p "Do you want to create backup directory at $BACKUP_LOCATION? [y/N]"
		if [[ "$REPLY" =~ [yY] ]]; then
			mkdir -p "$BACKUP_LOCATION"
			execute_backup
		fi
	fi
}

execute_restore() {
	read -r -p "Do you want to restore the system from $BACKUP_LOCATION? [y/N]"
	if [[ "$REPLY" =~ [yY] ]]; then
		if [[ -a "$BACKUP_LOCATION/verified_backup_image.lock" ]]; then
                        log_message "\nStarting system restore...\n"


			rsync -aAXHS --info=progress2 --delete \
			--exclude-from <(printf '%s\n' "${BACKUP_EXCLUDE[@]}") \
			--exclude={"/swapfile","/lost+found","/verified_backup_image.lock","$BACKUP_LOCATION"} \
                        "$BACKUP_LOCATION/" / || { log_message "Error: Restore failed."; return 1; }
			log_message "...Done restoring from $BACKUP_LOCATION\n"
		else
                        log_message "Error: No verified backup found at $BACKUP_LOCATION."
		fi
	fi
}
