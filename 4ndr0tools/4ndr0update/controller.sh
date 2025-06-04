#!/usr/bin/env bash
# shellcheck disable=all

fetch_news() {
	arch_news
	printf "\n"
}

fixgpg() {
	4ndr0keyfix
	printf "\n"
}

system_upgrade() {
       printf "➡️ Starting system upgrade..."
       fetch_news
       fetch_warnings
#       configure_reflector
#       aur_setup
#       rebuild_aur
       handle_pacfiles
       system_update || { fixgpg && system_update; }
       printf "\n"

#	if configure_reflector; then
#		echo "Reflector configured successfully."
#	else
#		echo "Error: Failed to configure reflector."
#		exit 1
#	fi

#	if aur_setup; then
#		echo "AUR setup completed successfully."
#	else
#		echo "Error: Failed to set up AUR."
#		exit 1
#	fi

#	if rebuild_aur; then
#		echo "AUR packages rebuilt successfully."
#	else
#		echo "Error: Failed to rebuild AUR packages."
#		exit 1
#	fi

#	if handle_pacfiles; then
#		echo "Pacfiles handled successfully."
#	else
#		echo "Error: Failed to handle pacfiles."
#		exit 1
#	fi
#
#	if system_update; then
#		echo "System update completed successfully."
#	else
#		echo "Error: System update failed."
#		exit 1
#	fi
#	printf "✔️ System updated!"
	printf "\n"
}

system_clean() {
	printf "➡️ Cleaning system..."
        remove_orphaned_packages
        clean_package_cache
        clean_broken_symlinks
        clean_old_config
#        printf "✔️ System cleaning complete!"
        printf "\n"
#	if remove_orphaned_packages; then
#		echo "Orphaned packages removed."
#	else
#		echo "Error: Failed to remove orphaned packages."
#		exit 1
#	fi

#	if clean_package_cache; then
#		echo "Package cache cleaned."
#	else
#		echo "Error: Failed to clean package cache."
#		exit 1
#	fi
#
#	if clean_broken_symlinks; then
#		echo "Broken symlinks cleaned."
#	else
#		echo "Error: Failed to clean broken symlinks."
#		exit 1
#	fi
}

system_errors() {
	printf "➡️ Scanning system errors\n"
	failed_services
	journal_errors
	printf "\n"
}

backup_system() {
	printf "➡️ Starting system backup\n"
	if execute_backup; then
		printf "✔️ System backup completed successfully.\n"
	else
		printf "❌ System backup failed.\n"
		exit 1
	fi
	printf "\n"
}

restore_system() {
	printf "➡️ Starting system restore\n"
	if execute_restore; then
		printf "✔️ System restored successfully\n"
	else
		printf "❌ System restore failed.\n"
		exit 1
	fi
	printf "\n"
}

update_settings() {
	printf "➡️ Updating settings\n"
	modify_settings
	source_settings
	printf "✔️ Settings updated successfully."
	printf "\n"
}
