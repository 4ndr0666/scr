#!/usr/bin/env bash
# File: manage_files.sh
# Description: Batch execution logic for 4ndr0service.
# - Excised legacy backup functionality for lean operations.
# - Implemented dependency bridge for standalone execution.

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

manage_files_main() {
    # Ψ-Bridge: Ensure orchestrator functions are available if run directly
    if ! declare -f run_all_services >/dev/null; then
        # shellcheck source=./controller.sh
        source "$PKG_PATH/controller.sh"
    fi

    PS3="Manage Files: "
    local options=(
        "Batch Execute All Services"
        "Batch Execute All in Parallel"
        "Exit"
    )
    select opt in "${options[@]}"; do
        case "$opt" in
        "Batch Execute All Services") 
            run_all_services 
            ;;
        "Batch Execute All in Parallel") 
            run_parallel_services 
            ;;
        "Exit") 
            break 
            ;;
        *) 
            log_error "Invalid selection." 
            ;;
        esac
    done
}

# Standalone Entry Point
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    manage_files_main
fi
