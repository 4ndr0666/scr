#!/bin/bash
# File: manage_files.sh
# Description: Provides batch execution of all services and optional backup steps.

set -euo pipefail
IFS=$'\n\t'

source "$(dirname "$0")/common.sh"

batch_execute_all() {
    echo "Batch executing all services..."
    log_info "Batch executing all services..."
    services=("optimize_go_service" "optimize_ruby_service" "optimize_cargo_service" "optimize_node_service" "optimize_nvm_service" "optimize_meson_service" "optimize_python_service" "optimize_electron_service" "optimize_venv_service")

    for svc in "${services[@]}"; do
        if command -v "$svc" &>/dev/null; then
            echo "Running $svc..."
            log_info "Running $svc..."
            if ! $svc; then
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

optional_backup() {
    read -rp "Perform backups to $backup_dir? (y/n): " backup_choice
    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        echo "Performing backups..."
        log_info "Performing backups..."
        ensure_dir "$backup_dir"
        timestamp=$(date +%Y%m%d_%H%M%S)

        # Example backup: Python venv
        if [[ -d "$VENV_HOME" ]]; then
            tar --exclude='__pycache__' --exclude-vcs -czf "$backup_dir/venv_backup_$timestamp.tar.gz" -C "$VENV_HOME" . || log_warn "Could not backup venv."
            echo "Venv data backed up."
            log_info "Venv data backed up."
        fi

        # Add more backups as needed

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
    options=("Batch Execute All Services" "Optional Backups" "Run Verification" "Return")
    select opt in "${options[@]}"; do
        case $REPLY in
            1) batch_execute_all ;;
            2) optional_backup ;;
            3) run_verification ;;
            4) break ;;
            *) echo "Invalid option." ;;
        esac
    done
}

export -f batch_execute_all optional_backup run_verification manage_files_main
