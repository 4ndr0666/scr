#!/usr/bin/env bash
# File: install_env_maintenance.sh
# Description: Sets up systemd user service and timer, configures auditd if available.

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

check_dependencies() {
    if ! systemctl --user > /dev/null 2>&1; then
        handle_error "Systemd user sessions not active. Try 'loginctl enable-linger $USER' and re-login."
    fi
}

create_systemd_units() {
    local systemd_user_dir="$LOG_FILE_DIR/systemd/user"
    ensure_dir "$systemd_user_dir"

    cat > "$systemd_user_dir/env_maintenance.service" <<EOF
[Unit]
Description=Environment Maintenance Service

[Service]
Type=oneshot
ExecStart=$PKG_PATH/test/src/verify_environment.sh
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
    log_info "Created env_maintenance service and timer units."
}

enable_systemd_units() {
    systemctl --user daemon-reload
    systemctl --user enable env_maintenance.timer
    systemctl --user start env_maintenance.timer
    log_info "Systemd user timer 'env_maintenance.timer' enabled and started."
}

configure_auditd() {
    if command -v auditctl &>/dev/null; then
        log_info "Configuring auditd..."
        sudo auditctl -D || true
        sudo auditctl -w "$XDG_CONFIG_HOME" -p war -k config_watch || log_warn "Failed rule: config_watch"
        sudo auditctl -w "$XDG_DATA_HOME" -p war -k data_watch || log_warn "Failed rule: data_watch"
        sudo auditctl -w "$XDG_CACHE_HOME" -p war -k cache_watch || log_warn "Failed rule: cache_watch"
    else
        log_warn "auditctl not found."
    fi
}

finalize_setup() {
    ensure_dir "$PKG_PATH/test/src"
    if [[ ! -x "$PKG_PATH/test/src/verify_environment.sh" ]]; then
        handle_error "$PKG_PATH/test/src/verify_environment.sh not found or not executable."
    fi

    "$PKG_PATH/test/src/verify_environment.sh" || log_warn "Initial verification encountered issues."
    log_info "Env maintenance setup complete."
    echo "Maintenance setup complete."
}

main_install() {
    check_dependencies
    create_systemd_units
    enable_systemd_units
    configure_auditd
    finalize_setup
}

main_install
