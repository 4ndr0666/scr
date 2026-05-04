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
# FIX: Path updated from test/src/verify_environment.sh to test/verify_environment.sh
#      The test/src/ subdirectory was structurally redundant; verify_environment.sh
#      now lives directly under test/ in the production tree.
# shellcheck source=./test/verify_environment.sh
source "$PKG_PATH/test/verify_environment.sh"

PLUGINS_DIR="${PLUGINS_DIR:-"$PKG_PATH/plugins"}"
USER_INTERFACE="${USER_INTERFACE:-cli}"

load_plugins() {
    if [[ ! -d "$PLUGINS_DIR" ]]; then
        return 0
    fi

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
                "${PLUGIN_REGISTER}" || log_warn "Plugin ${PLUGIN_REGISTER} returned non-zero."
            fi
        else
            log_warn "Failed to load plugin: $plugin"
        fi
    done
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

run_all_services() {
    log_info "Running all services in sequence..."
    # D-09 FIX: Guard against double-sourcing. main_controller() already calls
    # source_all_services(). Re-sourcing redefines functions harmlessly under
    # normal conditions but would be fatal if any future service file acquires
    # a readonly variable. The presence of optimize_go_service is a reliable
    # sentinel that all services have been loaded.
    if ! declare -f optimize_go_service >/dev/null 2>&1; then
        source_all_services
    fi

    local -a services
    mapfile -t services < <(declare -F | awk '{print $3}' | grep '^optimize_.*_service$')

    for svc in "${services[@]}"; do
        "$svc" || log_warn "$svc failed."
    done

    log_success "All services sequence complete."
    touch "${XDG_CACHE_HOME}/.scr_dirty"
    log_success "Path cache marked for re-indexing."
}

run_parallel_services() {
    log_info "Running services in parallel (Go, Ruby, Cargo)..."
    # CONSTRAINT: Only these three services are safe to parallelize.
    # They write to disjoint directories: $GOPATH, $GEM_HOME, $CARGO_HOME.
    # REQUIREMENT: D-02 patch (pacman lock wait) must be applied — all three
    # can trigger install_sys_pkg() and will deadlock without the lock guard.
    # NOTE: path_prepend() mutations inside subshells (&) do NOT propagate
    # back to the parent shell. PATH changes from parallel workers are lost.
    # Rely on persistent profile exports (~/.zprofile) for PATH permanence.
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
