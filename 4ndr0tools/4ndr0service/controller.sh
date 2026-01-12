#!/usr/bin/env bash
# File: controller.sh
# Optimized central controller — plugin loading, service sourcing, UI dispatch

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"
source "$PKG_PATH/settings_functions.sh"
source "$PKG_PATH/manage_files.sh"
source "$PKG_PATH/test/src/verify_environment.sh"

# ──────────────────────────────────────────────────────────────────────────────
# CONFIG & PATHS
# ──────────────────────────────────────────────────────────────────────────────
plugins_dir="${PLUGINS_DIR:-$PKG_PATH/plugins}"
services_dir="$PKG_PATH/service"

# ──────────────────────────────────────────────────────────────────────────────
# PLUGIN LOADING (auto-discover & source)
# ──────────────────────────────────────────────────────────────────────────────
load_plugins() {
    [[ -d "$plugins_dir" ]] || { log_warn "No plugins dir found."; return; }

    for plugin in "$plugins_dir"/*.sh; do
        [[ -f "$plugin" ]] || continue
        source "$plugin" && log_info "Loaded plugin: $(basename "$plugin")" ||
            log_warn "Failed to load plugin: $plugin"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# SERVICE SOURCING (all optimize_*)
# ──────────────────────────────────────────────────────────────────────────────
source_all_services() {
    [[ -d "$services_dir" ]] || handle_error "Services directory missing: $services_dir"

    for script in "$services_dir"/optimize_*.sh; do
        [[ -f "$script" ]] || continue
        source "$script" && log_info "Sourced service: $(basename "$script")" ||
            log_warn "Failed to source service: $script"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# PARALLEL & SEQUENTIAL RUNNERS (using centralized run_parallel_checks)
# ──────────────────────────────────────────────────────────────────────────────
run_all_services() {
    log_info "Running all services sequentially..."
    optimize_go_service      || log_warn "Go optimization failed"
    optimize_ruby_service    || log_warn "Ruby optimization failed"
    optimize_cargo_service   || log_warn "Cargo optimization failed"
    optimize_node_service    || log_warn "Node optimization failed"
    optimize_meson_service   || log_warn "Meson optimization failed"
    optimize_python_service  || log_warn "Python optimization failed"
    optimize_electron_service|| log_warn "Electron optimization failed"
    optimize_venv_service    || log_warn "Venv optimization failed"
    log_info "Sequential services complete."
}

run_parallel_services() {
    log_info "Running independent services in parallel..."
    run_parallel_checks \
        optimize_go_service \
        optimize_ruby_service \
        optimize_cargo_service \
        optimize_meson_service
    # Node/Python/Electron/Venv left sequential due to potential shared deps
    optimize_node_service
    optimize_python_service
    optimize_electron_service
    optimize_venv_service
    log_info "Parallel + sequential pass complete."
}

# ──────────────────────────────────────────────────────────────────────────────
# EXPORT ALL CORE FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────
export_functions() {
    export -f log_info log_warn handle_error ensure_dir check_directory_writable \
        safe_jq_array retry run_parallel_checks \
        create_config_if_missing load_config modify_settings \
        run_all_services run_parallel_services run_verification
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN DISPATCH (CLI/Dialog/fzf fallback)
# ──────────────────────────────────────────────────────────────────────────────
main_controller() {
    load_plugins
    source_all_services
    export_functions

    if command -v dialog >/dev/null 2>&1; then
        source "$PKG_PATH/view/dialog.sh"
        main_dialog
    elif command -v fzf >/dev/null 2>&1; then
        local choice
        choice=$(printf "Go\nRuby\nCargo\nNode.js\nMeson\nPython\nElectron\nVenv\nAudit\nManage\nSettings\nExit" | \
            fzf --prompt="4ndr0service: " --height=20)
        case "$choice" in
            Go)      optimize_go_service ;;
            Ruby)    optimize_ruby_service ;;
            Cargo)   optimize_cargo_service ;;
            "Node.js") optimize_node_service ;;
            Meson)   optimize_meson_service ;;
            Python)  optimize_python_service ;;
            Electron)optimize_electron_service ;;
            Venv)    optimize_venv_service ;;
            Audit)   run_verification ;;
            Manage)  manage_files_main ;;
            Settings)modify_settings ;;
            Exit|*)  log_info "Session terminated." && exit 0 ;;
        esac
    else
        source "$PKG_PATH/view/cli.sh"
        main_cli
    fi
}
