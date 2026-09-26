#!/usr/bin/env bash
# File: settings_functions.sh
# Description: Interactive settings management for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

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
    local opt
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
                local _force
                read -rp "Write anyway? (y/N): " _force
                if [[ "${_force,,}" != "y" ]]; then
                    log_info "Aborted — config.json unchanged."
                    return 0
                fi
            fi
        fi
    fi

    local tmp
    tmp="$(mktemp)" || return $?
    local rc

    jq --arg k "$key" --arg v "$val" '.[$k]=$v' "$CONFIG_FILE" >"$tmp"
    rc=$?
    if (( rc != 0 )); then
        rm -f "$tmp"
        log_warn "Failed to update config.json for key: $key"
        return "$rc"
    fi

    mv "$tmp" "$CONFIG_FILE"
    rc=$?
    if (( rc != 0 )); then
        rm -f "$tmp"
        log_warn "Failed to replace config.json for key: $key"
        return "$rc"
    fi

    log_success "Set $key to $val"
    return 0
}
