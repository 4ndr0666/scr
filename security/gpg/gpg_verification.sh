#!/bin/bash
# shellcheck disable=all

 config_file="/etc/pacman.conf"
 backup_file="/etc/pacman.conf.bak"

 # Function to bypass signature verification
 bypass_verification() {
     sudo cp "$config_file" "$backup_file"
     sudo awk '/^\[/{p=0} /^\[core\]/{p=1} p && /^SigLevel/{sub(/Required/, "Never")} 1' "$config_file" | sudo tee
 "$config_file" > /dev/null
     echo "PGP signature verification bypassed."
 }

 # Function to restore original configuration
 restore_verification() {
     sudo cp "$backup_file" "$config_file"
     sudo rm "$backup_file"
     echo "PGP signature verification restored."
 }

 # Check if the backup file exists
 if [ -f "$backup_file" ]; then
     restore_verification
 else
     bypass_verification
 fi
