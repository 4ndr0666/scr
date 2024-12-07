#!/usr/bin/env bash
# File: install_env_maintenance.sh
# Author: 4ndr0666
# Date: 12-06-24
# Description: Installs and configures a systemd user service and timer for environment maintenance.
#              Configures auditd rules if auditctl is available.
#              Ensures environment verification runs daily via a user timer.
set -euo pipefail
IFS=$'\n\t'

# ================================= // INSTALL_ENV_MAINTENANCE.SH //
# --- // Constants:
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

# --- // Deps:
check_dependencies() {
    if ! systemctl --user > /dev/null 2>&1; then
        echo "Error: systemd user sessions not supported or not active."
        echo "Try 'loginctl enable-linger $USER' and re-login."
        exit 1
    fi
}

create_systemd_units() {
    local systemd_user_dir="$XDG_CONFIG_HOME/systemd/user"
    mkdir -p "$systemd_user_dir"

    cat > "$systemd_user_dir/env_maintenance.service" <<EOF
[Unit]
Description=Environment Maintenance Service

[Service]
Type=oneshot
ExecStart=$HOME/.local/bin/verify_environment.sh
EOF

    cat > "$systemd_user_dir/env_maintenance.timer" <<EOF
[Unit]
Description=Run Environment Maintenance Daily

[Timer]
OnCalendar=daily
Persistent=true
Unit=env_maintenance.service

[Install]
WantedBy=timers.target
EOF
}

enable_systemd_units() {
    systemctl --user daemon-reload
    systemctl --user enable env_maintenance.timer
    systemctl --user start env_maintenance.timer
    echo "Systemd user timer 'env_maintenance.timer' enabled and started."
}

configure_auditd() {
    if command -v auditctl &>/dev/null; then
        echo "Configuring auditd rules for key directories..."
        # Remove old rules first to avoid duplicates
        sudo auditctl -D

        # Add new rules
        sudo auditctl -w "$XDG_CONFIG_HOME" -p war -k config_watch || echo "Warning: Could not add audit rule for $XDG_CONFIG_HOME"
        sudo auditctl -w "$XDG_DATA_HOME" -p war -k data_watch || echo "Warning: Could not add audit rule for $XDG_DATA_HOME"
        sudo auditctl -w "$XDG_CACHE_HOME" -p war -k cache_watch || echo "Warning: Could not add audit rule for $XDG_CACHE_HOME"

        echo "Audit rules configured. Use 'ausearch -k config_watch' etc. to view logs."
    else
        echo "Skipping audit configuration since auditctl not found."
    fi
}

finalize_setup() {
    mkdir -p "$HOME/.local/bin"
    if [[ ! -x "$HOME/.local/bin/verify_environment.sh" ]]; then
        echo "Error: $HOME/.local/bin/verify_environment.sh not found or not executable."
        echo "Please place a verified verify_environment.sh script into $HOME/.local/bin and make it executable."
        exit 1
    fi

    # Run once to verify environment now
    "$HOME/.local/bin/verify_environment.sh" || echo "Warning: initial verification encountered issues."

    echo "Environment maintenance setup complete."
    echo "Your environment will be checked daily via env_maintenance.timer."
}

main() {
    check_dependencies
    create_systemd_units
    enable_systemd_units
    configure_auditd
    finalize_setup
}

main
