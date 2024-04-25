#!/bin/bash

# File: run_app_securely.sh
# Purpose: Securely run applications requiring Xorg on Wayland with optional root access management.
# Author: Your Name
# Date: Today's Date
# This script uses best practices for error handling, security, and operational efficiency.

function log_info {
    echo "[INFO] $1"
}

function log_error {
    echo "[ERROR] $1" >&2
}

function grant_access {
    local user=$1
    if xhost +SI:localuser:$user; then
        log_info "Access granted for $user."
    else
        log_error "Failed to grant access for $user."
        exit 1
    fi
}

function revoke_access {
    local user=$1
    if xhost -SI:localuser:$user; then
        log_info "Access revoked for $user."
    else
        log_error "Failed to revoke access for $user."
        exit 1
    fi
}

function run_as_root {
    grant_access root
    sudo -E "$@"
    local status=$?
    revoke_access root
    return $status
}

function run_with_xorg {
    local app_name=$1
    shift
    local env_vars=("GDK_BACKEND=x11" "QT_QPA_PLATFORM=xcb")
    local run_command=("$app_name" "$@")

    for env_var in "${env_vars[@]}"; do
        log_info "Trying to run $app_name with $env_var..."
        if GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb "$app_name" "$@"; then
            log_info "$app_name executed successfully with $env_var."
            return 0
        fi
        log_info "Failed to run $app_name with $env_var. Trying next option..."
    done
    log_error "Failed to run the application with both Xorg compatibility options."
    return 1
}

# Main execution logic with user prompts and structured error handling
if [[ $1 == "--root" ]]; then
    shift
    if [[ $# -eq 0 ]]; then
        log_error "No application specified to run as root."
        exit 1
    fi
    run_as_root "$@"
elif [[ $# -eq 0 ]]; then
    log_error "No application specified to run."
    exit 1
else
    run_with_xorg "$@"
fi

