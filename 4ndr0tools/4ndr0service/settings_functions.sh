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

    # Schema guard: validate python_version against live pyenv versions
    # so a typo cannot silently poison the config that every optimize_*
    # service reads on the next run.
    if [[ "$key" == "python_version" && -n "$val" ]]; then
        if command -v pyenv &>/dev/null; then
            local _known_versions
            _known_versions=$(pyenv versions --bare 2>/dev/null || true)
            if [[ -n "$_known_versions" ]] && ! echo "$_known_versions" | grep -qxF "$val"; then
                log_warn "python_version '$val' not found in pyenv versions:"
                pyenv versions --bare 2>/dev/null | sed 's/^/    /'
                read -rp "Write anyway? (y/N): " _force
                if [[ "${_force,,}" != "y" ]]; then
                    log_info "Aborted — config.json unchanged."
                    return 0
                fi
            fi
        fi
    fi

    local tmp
    tmp="$(mktemp)"
    # 4.4 FIX: guarantee temp file cleanup on all exit paths —
    # jq failure leaves $tmp on disk without the explicit || rm -f.
    if jq --arg k "$key" --arg v "$val" '.[$k]=$v' "$CONFIG_FILE" >"$tmp"; then
        mv "$tmp" "$CONFIG_FILE"
        log_success "Set $key to $val"
    else
        rm -f "$tmp"
        log_warn "Failed to update config.json for key: $key"
    fi
}
