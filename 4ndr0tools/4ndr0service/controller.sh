#!/usr/bin/env bash
# File: controller.sh
# Central controller for the 4ndr0service Suite.

# ================== // 4ndr0service controller.sh //
### Debugging
set -euo pipefail
IFS=$'\n\t'

### Constants
# Determine PKG_PATH dynamically for both direct and sourced use
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    PKG_PATH="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../common.sh" ]; then
    PKG_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
elif [ -f "$SCRIPT_DIR/../../common.sh" ]; then
    PKG_PATH="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
else
    echo "Error: Could not determine package path." >&2
    exit 1
fi
export PKG_PATH

source "$PKG_PATH/common.sh"
source "$PKG_PATH/settings_functions.sh"
source "$PKG_PATH/manage_files.sh"
source "$PKG_PATH/test/src/verify_environment.sh"

load_plugins() {
    if [[ ! -d "$plugins_dir" ]]; then
        log_warn "Plugins directory '$plugins_dir' not found. Skipping."
        return
    fi
    for plugin in "$plugins_dir"/*.sh; do
        if [[ -f "$plugin" ]]; then
            source "$plugin" || log_warn "Failed to load plugin '$plugin'."
            log_info "Loaded plugin: $plugin"
        fi
    done
}

source_all_services() {
    local services_dir="$PKG_PATH/service"
    if [[ ! -d "$services_dir" ]]; then
        handle_error "Services directory '$services_dir' does not exist."
    fi
    for script in "$services_dir"/optimize_*.sh; do
        if [[ -f "$script" ]]; then
            source "$script" || log_warn "Failed to source '$script'."
            log_info "Sourced service script: '$script'."
        fi
    done
}

source_views() {
    case "$USER_INTERFACE" in
        cli)
            local cli_script="$PKG_PATH/view/cli.sh"
            if [[ -f "$cli_script" ]]; then
                source "$cli_script" || handle_error "Failed to source '$cli_script'."
                log_info "Sourced CLI interface script."
                main_cli
            else
                handle_error "CLI script not found at '$cli_script'."
            fi
            ;;
        dialog)
            local dialog_script="$PKG_PATH/view/dialog.sh"
            if [[ -f "$dialog_script" ]]; then
                source "$dialog_script" || handle_error "Failed to source '$dialog_script'."
                log_info "Sourced Dialog interface script."
                main_dialog
            else
                handle_error "Dialog script not found at '$dialog_script'."
            fi
            ;;
        *)
            handle_error "Unknown USER_INTERFACE: '$USER_INTERFACE'."
            ;;
    esac
}

run_all_services() {
    log_info "Running all services in sequence..."
    optimize_go_service       || log_warn "Go setup failed."
    optimize_ruby_service     || log_warn "Ruby setup failed."
    optimize_cargo_service    || log_warn "Cargo setup failed."
    optimize_node_service     || log_warn "Node.js + NVM setup failed."
    optimize_meson_service    || log_warn "Meson setup failed."
    optimize_python_service   || log_warn "Python setup failed."
    optimize_electron_service || log_warn "Electron setup failed."
    optimize_venv_service     || log_warn "Venv setup failed."
    log_info "All services have been attempted in sequence."
}

run_parallel_services() {
    log_info "Running selected services in parallel..."
    run_parallel_checks \
        "optimize_go_service" \
        "optimize_ruby_service" \
        "optimize_cargo_service"
    log_info "Parallel services completed."
}

export_functions() {
    export -f log_info log_warn handle_error attempt_tool_install ensure_dir
    export -f prompt_config_value create_config_if_missing load_config
    export -f modify_settings fallback_editor
    export -f load_plugins source_all_services source_views
    export -f run_all_services run_parallel_services run_verification
}

main_controller() {
    export_functions
    load_plugins
    source_all_services
    source_views
}

# Execute controller main logic when sourced or run
main_controller
