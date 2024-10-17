#!/bin/bash

# Function to handle system upgrade process
system_upgrade() {
	echo "Starting system upgrade..."

	if configure_reflector; then
		echo "Reflector configured successfully."
	else
		echo "Error: Failed to configure reflector."
		exit 1
	fi

	if aur_setup; then
		echo "AUR setup completed successfully."
	else
		echo "Error: Failed to set up AUR."
		exit 1
	fi

	if rebuild_aur; then
		echo "AUR packages rebuilt successfully."
	else
		echo "Error: Failed to rebuild AUR packages."
		exit 1
	fi

	if handle_pacfiles; then
		echo "Pacfiles handled successfully."
	else
		echo "Error: Failed to handle pacfiles."
		exit 1
	fi

	if system_update; then
		echo "System update completed successfully."
	else
		echo "Error: System update failed."
		exit 1
	fi

	echo "System upgrade finished successfully."
	printf "\n"
}

# Function to handle system cleaning process
system_clean() {
	echo "Starting system cleaning..."

	if remove_orphaned_packages; then
		echo "Orphaned packages removed."
	else
		echo "Error: Failed to remove orphaned packages."
		exit 1
	fi

	if clean_package_cache; then
		echo "Package cache cleaned."
	else
		echo "Error: Failed to clean package cache."
		exit 1
	fi

	if clean_broken_symlinks; then
		echo "Broken symlinks cleaned."
	else
		echo "Error: Failed to clean broken symlinks."
		exit 1
	fi

	if clean_old_config; then
		echo "Old configuration files cleaned."
	else
		echo "Error: Failed to clean old configuration files."
		exit 1
	fi

	echo "System cleaning finished successfully."
	printf "\n"
}

# Function to backup system
backup_system() {
	echo "Starting system backup..."
	if execute_backup; then
		echo "System backup completed successfully."
	else
		echo "Error: System backup failed."
		exit 1
	fi
	printf "\n"
}

# Function to restore system
restore_system() {
	echo "Starting system restore..."
	if execute_restore; then
		echo "System restored successfully."
	else
		echo "Error: System restore failed."
		exit 1
	fi
	printf "\n"
}

# Function to update system settings
update_settings() {
	echo "Updating settings..."
	modify_settings
	source_settings
	echo "Settings updated successfully."
	printf "\n"
}
