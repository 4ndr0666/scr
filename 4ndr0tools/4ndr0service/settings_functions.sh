#!/usr/bin/env bash
# File: settings_functions.sh
# Description: Functions to modify/manage settings for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

modify_settings() {
    local editor
    editor=$(jq -r '.settings_editor' "$CONFIG_FILE" || echo "vim")
    if [[ -z "$editor" || ! $(command -v "$editor") ]]; then
        editor="vim"
    fi
    "$editor" "$CONFIG_FILE"
    log_info "Settings modified with $editor."
}

fallback_editor() {
    select editor in "vim" "nano" "emacs" "micro" "lite-xl" "Exit"; do
        case $REPLY in
            1) vim "$CONFIG_FILE" && break ;;
            2) nano "$CONFIG_FILE" && break ;;
            3) emacs "$CONFIG_FILE" && break ;;
            4) micro "$CONFIG_FILE" && break ;;
            5) lite-xl "$CONFIG_FILE" && break ;;
            6) break ;;
            *) echo "Invalid selection." ;;
        esac
    done
}
