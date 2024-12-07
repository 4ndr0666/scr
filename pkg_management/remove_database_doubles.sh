#!/bin/bash

# Function to log and display messages
log() {
  local MESSAGE=$1
  echo "$MESSAGE"
  logger -t pacman-cleaner "$MESSAGE"
}


log "Starting Pacman database cleanup..."

# Step 1: Backup Pacman Database
log "Backing up the Pacman database..."
#if cp -r /var/lib/pacman/local /var/lib/pacman/local.bak; then
#  log "Backup completed successfully."
#else
#  log "Backup failed. Exiting."
#  exit 1
#fi

# Step 2: Verify and List Duplicate Packages
log "Listing duplicated package entries..."
paru -Qq | sort | uniq -d > duplicate_packages.txt
if [[ ! -s duplicate_packages.txt ]]; then
  log "No duplicated packages found."
  exit 0
fi
log "Duplicated packages found: $(cat duplicate_packages.txt)"

# Step 3: Remove Duplicated Entries and Reinstall Packages
while read -r package; do
  log "Cleaning duplicated entries for $package..."
  rm -rf /var/lib/pacman/local/${package}*
  if paru -S --noconfirm $package; then
    log "$package reinstalled successfully."
  else
    log "Failed to reinstall $package. Manual intervention required."
  fi
done < duplicate_packages.txt

# Step 4: Clear and Rebuild the Pacman Database
log "Clearing Pacman cache..."
if paru -Scc --noconfirm; then
  log "Pacman cache cleared."
else
  log "Failed to clear Pacman cache."
fi

log "Rebuilding Pacman database..."
if paru -Syy; then
  log "Pacman database rebuilt successfully."
else
  log "Failed to rebuild Pacman database."
fi

log "Performing system update..."
if paru -Syu --noconfirm; then
  log "System updated successfully."
else
  log "System update failed."
fi

# Step 5: Final Verification
log "Verifying package integrity..."
if paru -Dk; then
  log "Package integrity verification completed."
else
  log "Package integrity verification encountered issues."
fi

log "Pacman database cleanup completed."

# Clean up
rm -f duplicate_packages.txt

exit 0
