#!/usr/bin/env bash
# shellcheck disable=all
# File: manage_files.sh
# Provides batch execution of services and optional backup steps.

# ==================== // 4ndr0service manage_files.sh //
### Debugging
set -euo pipefail
IFS=$'\n\t'

### Constants
# Determine PKG_PATH dynamically
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

# Source shared module(s)
source "$PKG_PATH/common.sh"

# Default backup directory (override with BACKUP_DIR env var if set)
backup_dir="${BACKUP_DIR:-$HOME/.local/share/4ndr0service/backups}"

batch_execute_all() {
    echo "Batch executing all services in sequence..."
    log_info "Batch executing all services in sequence..."

    local services=(
      "optimize_go_service"
      "optimize_ruby_service"
      "optimize_cargo_service"
      "optimize_node_service"
      "optimize_meson_service"
      "optimize_python_service"
      "optimize_electron_service"
      "optimize_venv_service"
    )

    for svc in "${services[@]}"; do
        if command -v "$svc" &>/dev/null; then
            echo "Running $svc..."
            log_info "Running $svc..."
            if ! "$svc"; then
                echo "Warning: $svc encountered an issue."
                log_warn "$svc encountered an issue."
            else
                echo "$svc completed successfully."
                log_info "$svc completed successfully."
            fi
        else
            echo "Warning: $svc not found. Skipping."
            log_warn "$svc not found."
        fi
    done

    echo "Batch execution completed."
    log_info "Batch execution completed."
}

batch_execute_all_parallel() {
    echo "Batch executing some services in parallel..."
    log_info "Batch executing some services in parallel..."

    run_parallel_checks \
        "optimize_go_service" \
        "optimize_ruby_service" \
        "optimize_cargo_service"

    echo "Parallel batch execution completed."
    log_info "Parallel batch execution completed."
}

optional_backup() {
    read -rp "Perform backups to $backup_dir? (y/n): " backup_choice
    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        echo "Performing backups..."
        log_info "Performing backups..."
        ensure_dir "$backup_dir"
        local timestamp
        timestamp="$(date +%Y%m%d_%H%M%S)"

        # Example: backup python venv
        if [[ -d "$VENV_HOME" ]]; then
            tar --exclude='__pycache__' --exclude-vcs \
                -czf "$backup_dir/venv_backup_$timestamp.tar.gz" \
                -C "$VENV_HOME" . || log_warn "Could not backup venv."
            echo "Venv data backed up."
            log_info "Venv data backed up."
        fi

        echo "Backups completed."
        log_info "Backups completed."
    else
        echo "Skipping backups."
        log_info "User skipped backups."
    fi
}

run_verification() {
    local audit_script="$PKG_PATH/test/final_audit.sh"
    if [[ -x "$audit_script" ]]; then
        echo "Running final_audit.sh..."
        "$audit_script"
    else
        echo "final_audit.sh not found in $PKG_PATH/test."
        log_warn "final_audit.sh not found."
    fi
}

manage_files_main() {
    PS3="Manage Files: "
    options=(
      "Batch Execute All Services"
      "Batch Execute All in Parallel (Example)"
      "Optional Backups"
      "Exit"
    )
    select opt in "${options[@]}"; do
        case "$REPLY" in
            1) batch_execute_all ;;
            2) batch_execute_all_parallel ;;
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
