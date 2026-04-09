#!/usr/bin/env bash
# File: controller.sh
# Description: Central controller for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=./common.sh
source "${PKG_PATH:-.}/common.sh"
# shellcheck source=./settings_functions.sh
source "$PKG_PATH/settings_functions.sh"
# shellcheck source=./manage_files.sh
source "$PKG_PATH/manage_files.sh"
# shellcheck source=./test/src/verify_environment.sh
source "$PKG_PATH/test/src/verify_environment.sh"

PLUGINS_DIR="${PLUGINS_DIR:-"$PKG_PATH/plugins"}"
USER_INTERFACE="${USER_INTERFACE:-cli}"

load_plugins() {
    if [[ -d "$PLUGINS_DIR" ]]; then
        for plugin in "$PLUGINS_DIR"/*.sh; do
            if [[ -f "$plugin" ]]; then
                # shellcheck disable=SC1090
                source "$plugin" || log_warn "Failed to load plugin: $plugin"
                log_info "Loaded plugin: $(basename "$plugin")"
            fi
        done
    fi
}

source_all_services() {
    local services_dir="$PKG_PATH/service"
    if [[ ! -d "$services_dir" ]]; then
        handle_error "$LINENO" "Services directory missing: $services_dir"
    fi
    for script in "$services_dir"/optimize_*.sh; do
        if [[ -f "$script" ]]; then
            # shellcheck disable=SC1090
            source "$script" || log_warn "Failed to source service: $script"
        fi
    done
}

source_views() {
    local view_script="$PKG_PATH/view/${USER_INTERFACE}.sh"
    if [[ -f "$view_script" ]]; then
        # shellcheck disable=SC1090
        source "$view_script" || handle_error "$LINENO" "Failed to source view: $view_script"
        "main_${USER_INTERFACE}"
    else
        handle_error "$LINENO" "View script not found: $view_script"
    fi
}

# Proposed dynamic service execution
run_all_services() {
    log_info "Running all services in sequence..."
    source_all_services

    # Dynamically find all functions matching the optimization pattern
    local -a services
    mapfile -t services < <(declare -F | awk '{print $3}' | grep '^optimize_.*_service$')

    for svc in "${services[@]}"; do
        $svc || log_warn "$svc failed."
    done
    log_success "All services sequence complete."
    touch "${XDG_CACHE_HOME}/.scr_dirty"
    log_success "Path cache marked for re-indexing."
}

run_parallel_services() {
    log_info "Running services in parallel..."
    source_all_services

    # Selecting core services for parallel execution as in stable
    run_parallel_checks \
        "optimize_go_service" \
        "optimize_ruby_service" \
        "optimize_cargo_service"

    log_success "Parallel services completed."
    touch "${XDG_CACHE_HOME}/.scr_dirty"
    log_success "Path cache marked for re-indexing."
}

export_functions() {
    export -f log_info log_warn log_error log_success handle_error
    export -f ensure_dir ensure_xdg_dirs pkg_is_installed install_sys_pkg
    export -f create_config_if_missing load_config modify_settings
    export -f run_all_services run_parallel_services run_verification
}

main_controller() {
    load_plugins
    source_all_services
    export_functions
    source_views
}
