#!/bin/bash
# shellcheck disable=all
# Automation Script for X11/Wayland Setup and Execution Environment
# IMPORTANT: Run this script as your user (e.g., `andro`) to ensure proper setup.

# Log Functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Function to configure /etc/X11/Xwrapper.config
configure_xwrapper() {
    log_info "Configuring /etc/X11/Xwrapper.config..."
    sudo bash -c 'cat <<EOF >/etc/X11/Xwrapper.config
allowed_users=anybody
needs_root_rights=yes
EOF'
    if [[ $? -eq 0 ]]; then
        log_info "/etc/X11/Xwrapper.config configured successfully."
    else
        log_error "Failed to configure /etc/X11/Xwrapper.config."
        exit 1
    fi
}

# Function to create Polkit rule
create_polkit_rule() {
    log_info "Creating Polkit rule in /etc/polkit-1/rules.d/50-x11-access.rules..."
    sudo bash -c 'cat <<EOF >/etc/polkit-1/rules.d/50-x11-access.rules
// /etc/polkit-1/rules.d/50-x11-access.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.DisplayManager.XServer" && subject.isInGroup("andro")) {
        return polkit.Result.YES;
    }
});
EOF'
    if [[ $? -eq 0 ]]; then
        log_info "Polkit rule created successfully."
    else
        log_error "Failed to create Polkit rule."
        exit 1
    fi
}

# Function to create the unified script for managing X11/Wayland applications
create_unified_script() {
    log_info "Creating the unified script for running X11/Wayland apps..."
    mkdir -p ~/.local/bin
    cat <<'EOF' >~/.local/bin/xrun
#!/bin/bash
# Unified Script for running X11/Wayland apps with root access management and environment setup

log_info() {
    echo "[INFO] \$1"
}

log_error() {
    echo "[ERROR] \$1" >&2
}

run_with_env_vars() {
    app_name=\$1
    shift
    GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb "\$app_name" "\$@"
}

run_as_root() {
    sudo -E "\$@"
}

main() {
    if [[ \$1 == "--root" ]]; then
        shift
        if [[ \$# -eq 0 ]]; then
            log_error "No application specified to run as root."
            exit 1
        fi
        run_as_root "\$@"
    elif [[ \$# -eq 0 ]]; then
        log_error "No application specified to run."
        exit 1
    else
        run_with_env_vars "\$@"
    fi
}

main "\$@"
EOF

    chmod +x ~/.local/bin/xrun
    if [[ $? -eq 0 ]]; then
        log_info "Unified script created and made executable successfully."
    else
        log_error "Failed to create the unified script."
        exit 1
    fi
}

# Main execution flow
main() {
    log_info "Starting the X11/Wayland setup process..."

    # Step 1: Configure /etc/X11/Xwrapper.config
    configure_xwrapper

    # Step 2: Create the Polkit rule for X11 access
    create_polkit_rule

    # Step 3: Create the unified script (xrun) for managing applications
    create_unified_script

    log_info "Setup completed successfully."
    log_info "You can now use 'xrun' to run X11/Wayland applications with environment setup and optional root access."
    log_info "Examples:"
    log_info "  1. Run a regular application: xrun your_application"
    log_info "  2. Run an application as root: xrun --root your_application"
}

# Run the main function
main
