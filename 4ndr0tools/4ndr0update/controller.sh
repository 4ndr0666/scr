#!/usr/bin/env bash
# shellcheck disable=all
set -euo pipefail

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
    handle_pacfiles
    system_update || { fixgpg && system_update; }
    printf "\n"

    printf "\n"
}

system_clean() {
    printf "➡️ Cleaning system..."
    remove_orphaned_packages
    clean_package_cache
    clean_broken_symlinks
    clean_old_config
    printf "\n"
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
