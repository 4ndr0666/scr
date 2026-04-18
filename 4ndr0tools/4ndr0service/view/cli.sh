#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

main_cli() {
    log_info "Starting 4ndr0service CLI..."
    PS3="4ndr0service > "

    # FIX: Renamed opaque internal terms to user-facing descriptions.
    # "Ascension Sync"   → "Sync Python Hive & Ghost Links"
    # "Inject Hive Tool" → "Install Isolated Python Tool"
    # "Purge Matrix"     → "Deep Clean: Remove Dead Artifacts"
    local options=(
        "Go Optimization"
        "Ruby Optimization"
        "Cargo Optimization"
        "Node.js Optimization"
        "Meson Optimization"
        "Python Optimization"
        "Electron Optimization"
        "Venv Optimization"
        "Audit/Verification"
        "Sync Python Hive & Ghost Links"
        "Install Isolated Python Tool"
        "Deep Clean: Remove Dead Artifacts"
        "File Management"
        "Settings"
        "Exit"
    )

    # FIX: Declare shared script path variables once outside the select loop to
    # avoid duplicate `local` declarations across case branches (SC2155).
    local asc_script="$PKG_PATH/ascension.sh"
    local purge_script="$PKG_PATH/purge_matrix.sh"

    select opt in "${options[@]}"; do
        case "$opt" in
        "Go Optimization")       optimize_go_service ;;
        "Ruby Optimization")     optimize_ruby_service ;;
        "Cargo Optimization")    optimize_cargo_service ;;
        "Node.js Optimization")  optimize_node_service ;;
        "Meson Optimization")    optimize_meson_service ;;
        "Python Optimization")   optimize_python_service ;;
        "Electron Optimization") optimize_electron_service ;;
        "Venv Optimization")     optimize_venv_service ;;
        "Audit/Verification")
            read -rp "Run audit in fix mode? (y/N): " fix_choice
            if [[ "${fix_choice,,}" == "y" ]]; then
                export FIX_MODE="true"
            else
                export FIX_MODE="false"
            fi
            run_verification
            ;;
        "Sync Python Hive & Ghost Links")
            # Runs ascension.sh --sync: enforces Ghost Links, sanitizes the
            # virtualenv hive, and audits the Python environment layout.
            if [[ -x "$asc_script" ]]; then
                "$asc_script" --sync
            else
                log_warn "ascension.sh not found at $asc_script"
            fi
            ;;
        "Install Isolated Python Tool")
            # Installs a Python package into its own isolated virtualenv and
            # creates a Ghost Link in ~/.local/bin for PATH access.
            read -rp "Package name to install into isolated Hive venv: " inject_tool
            if [[ -n "$inject_tool" ]]; then
                if [[ -x "$asc_script" ]]; then
                    "$asc_script" --inject "$inject_tool"
                else
                    log_warn "ascension.sh not found at $asc_script"
                fi
            else
                log_warn "No package name provided."
            fi
            ;;
        "Deep Clean: Remove Dead Artifacts")
            # Removes broken symlinks from ~/.local/bin, liquidates stale
            # virtualenv garbage dirs, rebuilds AUR packages against the current
            # Python runtime, and clears __pycache__ trees.
            read -rp "Proceed with deep clean? This removes dead artifacts. (y/N): " purge_choice
            if [[ "${purge_choice,,}" == "y" ]]; then
                if [[ -x "$purge_script" ]]; then
                    "$purge_script" --force
                else
                    log_warn "purge_matrix.sh not found at $purge_script"
                fi
            else
                log_info "Deep clean aborted."
            fi
            ;;
        "File Management") manage_files_main ;;
        "Settings")        modify_settings ;;
        "Exit")
            log_info "Goodbye!"
            exit 0
            ;;
        *) echo "Invalid option." ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_VIEW_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_VIEW_DIR
        PKG_PATH="$(dirname "$_CURRENT_VIEW_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # shellcheck source=/dev/null
    source "$PKG_PATH/controller.sh"

    if declare -f main_cli >/dev/null; then
        main_cli
    fi
fi
