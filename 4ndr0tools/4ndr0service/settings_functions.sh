#!/usr/bin/env bash
# File: settings_functions.sh
# Description: Interactive settings management for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH set by common.sh
# shellcheck source=./common.sh
source "${PKG_PATH:-.}/common.sh"

modify_settings() {
    load_config
    local editor
    editor=$(jq -r '.settings_editor // "vim"' "$CONFIG_FILE")
    
    if ! command -v "$editor" &>/dev/null; then
        log_warn "Editor '$editor' not found. Falling back."
        fallback_editor
    else
        "$editor" "$CONFIG_FILE"
        log_success "Settings modified."
    fi
}

fallback_editor() {
    PS3="Select editor: "
    local editors=("vim" "nano" "emacs" "micro" "lite-xl" "Exit")
    select opt in "${editors[@]}"; do
        case $opt in
            "Exit") break ;;
            *) 
                if [[ -n "$opt" ]]; then
                    if command -v "$opt" &>/dev/null; then
                        "$opt" "$CONFIG_FILE"
                        break
                    else
                        log_warn "$opt not installed."
                    fi
                else
                    echo "Invalid selection."
                fi
                ;;
        esac
    done
}

prompt_config_value() {
    local key="$1"
    local default="$2"
    local val
    read -rp "Enter value for $key [$default]: " val
    val="${val:-$default}"
    
    local tmp
    tmp="$(mktemp)"
    jq --arg k "$key" --arg v "$val" '.[$k]=$v' "$CONFIG_FILE" >"$tmp" && mv "$tmp" "$CONFIG_FILE"
    log_success "Set $key to $val"
}
