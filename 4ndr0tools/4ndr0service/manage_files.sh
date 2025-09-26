#!/usr/bin/env bash
# File: manage_files.sh
# Provides batch execution of services and optional backup steps.

# ==================== // 4ndr0service manage_files.sh //
# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# SCRIPT_DIR is not needed here as PKG_PATH is available.

# Source shared module(s)

# Default backup directory (override with BACKUP_DIR env var if set)
backup_dir="${BACKUP_DIR:-$HOME/.local/share/4ndr0service/backups}"

optional_backup() {
	log_info "Performing optional backup to: $backup_dir"
	# In a real scenario, this would contain actual backup logic,
	# e.g., `mkdir -p "$backup_dir"` and then copying files.
	# For now, just logging the action.
}

manage_files_main() {
	PS3="Manage Files: "
	options=(
		"Batch Execute All Services"
		"Batch Execute All in Parallel (Example)"
		"Optional Backups"
		"Exit"
	)
	# shellcheck disable=SC2034
	select opt in "${options[@]}"; do
		case "$REPLY" in
		1) run_all_services ;;
		2) run_parallel_services ;;
		3) optional_backup ;;
		4) break ;;
		*) echo "Invalid option." ;;
		esac
	done
}

# If run directly, launch the manage files menu
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	manage_files_main
fi
