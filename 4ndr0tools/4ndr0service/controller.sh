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
# verify_environment.sh is sourced lazily inside main_controller() only
# when the audit path is actually needed — not on every service-only run.

PLUGINS_DIR="${PLUGINS_DIR:-"$PKG_PATH/plugins"}"
USER_INTERFACE="${USER_INTERFACE:-cli}"

load_plugins() {
    if [[ ! -d "$PLUGINS_DIR" ]]; then
        return 0
    fi

    local status=0
    for plugin in "$PLUGINS_DIR"/*.sh; do
        [[ -f "$plugin" ]] || continue

        # Unset PLUGIN_REGISTER before sourcing so a plugin that omits it
        # does not accidentally inherit a previous plugin's value.
        unset PLUGIN_REGISTER

        # shellcheck disable=SC1090
        if source "$plugin"; then
            log_info "Loaded plugin: $(basename "$plugin")"
            if [[ -n "${PLUGIN_REGISTER:-}" ]] && declare -f "${PLUGIN_REGISTER}" >/dev/null 2>&1; then
                log_info "Executing plugin entry point: ${PLUGIN_REGISTER}"
                if ! "${PLUGIN_REGISTER}"; then
                    log_error "Plugin ${PLUGIN_REGISTER} returned non-zero."
                    status=1
                fi
            fi
        else
            log_error "Failed to load plugin: $plugin"
            status=1
        fi
    done

    return "$status"
}

source_all_services() {
    local services_dir="$PKG_PATH/service"
    if [[ ! -d "$services_dir" ]]; then
        handle_error "$LINENO" "Services directory missing: $services_dir"
    fi

    local status=0
    for script in "$services_dir"/optimize_*.sh; do
        if [[ -f "$script" ]]; then
            # shellcheck disable=SC1090
            if source "$script"; then
                continue
            fi
            log_error "Failed to source service: $script"
            status=1
        fi
    done

    return "$status"
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

run_all_services() {
    log_info "Running all services in sequence..."
    if ! declare -f optimize_go_service >/dev/null 2>&1; then
        source_all_services
    fi

    local -a services
    mapfile -t services < <(declare -F | awk '{print $3}' | grep '^optimize_.*_service$' | grep -v '^optimize_nvm_service$')

    local status=0
    for svc in "${services[@]}"; do
        if "$svc"; then
            continue
        fi
        log_error "$svc failed."
        status=1
    done

    if (( status != 0 )); then
        log_error "One or more services failed."
        return "$status"
    fi

    log_success "All services sequence complete."
    touch "${XDG_CACHE_HOME}/.scr_dirty"
    log_success "Path cache marked for re-indexing."
}

run_parallel_services() {
    log_info "Running services in parallel (Go, Ruby, Cargo)..."
    if ! declare -f optimize_go_service >/dev/null 2>&1; then
        source_all_services
    fi

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
    export -f ensure_dir path_prepend install_sys_pkg
    export -f optimize_go_service optimize_ruby_service optimize_cargo_service
}

main_controller() {
    load_plugins
    source_all_services
    export_functions
    if ! declare -f run_verification >/dev/null 2>&1; then
        source "$PKG_PATH/test/verify_environment.sh"
    fi
    source_views
}
