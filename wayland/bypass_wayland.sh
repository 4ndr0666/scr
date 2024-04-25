#!/bin/bash

#File: run_application.sh
#Purpose: Securely run applications requiring Xorg on Wayland and handle optional root access.
#Author: Your Name
#Date: Today's Date

function grant_access {
    local user=$1
    if ! xhost +SI:localuser:$user; then
        echo "Failed to grant access for $user."
        exit 1
    fi
    echo "Access granted for $user."
}

function revoke_access {
    local user=$1
    if ! xhost -SI:localuser:$user; then
        echo "Failed to revoke access for $user."
        exit 1
    fi
    echo "Access revoked for $user."
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
        echo "Trying to run $app_name with $env_var..."
        if GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb "$app_name" "$@"; then
            echo "$app_name executed successfully with $env_var."
            return 0
        fi
        echo "Failed to run $app_name with $env_var. Trying next option..."
    done
    echo "Failed to run the application with both Xorg compatibility options."
    return 1
}

# Main Execution
if [[ $1 == "--root" ]]; then
    shift
    run_as_root "$@"
else
    run_with_xorg "$@"
fi

