#!/usr/bin/env bash
# shellcheck disable=all
# File: settings_functions.sh
# Description: Functions to modify/manage settings for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

# Determine PKG_PATH dynamically if not already set
if [ -z "${PKG_PATH:-}" ]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
    if [ -f "$SCRIPT_DIR/common.sh" ]; then
        PKG_PATH="$SCRIPT_DIR"
    elif [ -f "$SCRIPT_DIR/../common.sh" ]; then
        PKG_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
    elif [ -f "$SCRIPT_DIR/../../common.sh" ]; then
        PKG_PATH="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
    else
        echo "Error: Could not determine package path." >&2
        exit 1
    fi
    export PKG_PATH
fi

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
