#!/bin/bash

system_upgrade() {
	configure_reflector
	setup_yay_and_hooks
	aur_setup
	rebuild_aur
	handle_pacfiles
	system_update
	printf "\n"
}

system_clean() {
	remove_orphaned_packages
	clean_package_cache
	clean_broken_symlinks
	clean_old_config
	printf "\n"
}

backup_system() {
	execute_backup
	printf "\n"
}

restore_system() {
	execute_restore
	printf "\n"
}

update_settings() {
	modify_settings
	source_settings
	printf "\n"
}
