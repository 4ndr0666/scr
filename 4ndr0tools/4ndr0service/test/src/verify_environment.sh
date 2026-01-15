#!/usr/bin/env bash
# File: verify_environment.sh
# Description: Verification and auto-fix logic for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../../common.sh
source "${PKG_PATH:-.}/common.sh"

FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"

run_verification() {
    log_info "Verifying environment alignment..."
    load_config
    
    local -a required_env
    mapfile -t required_env < <(jq -r '(.required_env // [])[]' "$CONFIG_FILE")
    local -a directory_vars
    mapfile -t directory_vars < <(jq -r '(.directory_vars // [])[]' "$CONFIG_FILE")
    local -a required_tools
    mapfile -t required_tools < <(jq -r '(.tools // [])[]' "$CONFIG_FILE")

    # Check Env Vars
    for var in "${required_env[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warn "Missing environment variable: $var"
            if [[ "$FIX_MODE" == "true" ]]; then
                case "$var" in
                    LOG_FILE) export LOG_FILE="$XDG_CACHE_HOME/4ndr0service/service.log"; log_info "Fixed: $var set"; ;;
                    PYENV_ROOT) export PYENV_ROOT="$XDG_DATA_HOME/pyenv"; log_info "Fixed: $var set"; ;;
                    PIPX_HOME) export PIPX_HOME="$XDG_DATA_HOME/pipx"; log_info "Fixed: $var set"; ;;
                    PIPX_BIN_DIR) export PIPX_BIN_DIR="$XDG_BIN_HOME"; log_info "Fixed: $var set"; ;;
                    NVM_DIR) export NVM_DIR="$XDG_CONFIG_HOME/nvm"; log_info "Fixed: $var set"; ;;
                    PSQL_HOME) export PSQL_HOME="$XDG_DATA_HOME/psql"; log_info "Fixed: $var set"; ;;
                    MYSQL_HOME) export MYSQL_HOME="$XDG_DATA_HOME/mysql"; log_info "Fixed: $var set"; ;;
                    *) log_warn "Cannot auto-fix $var" ;;
                esac
            fi
        fi
    done

    # Check Directories
    for var in "${directory_vars[@]}"; do
        local dir_path="${!var:-}"
        if [[ -n "$dir_path" ]]; then
            if [[ ! -d "$dir_path" ]]; then
                log_warn "Directory missing: $dir_path ($var)"
                if [[ "$FIX_MODE" == "true" ]]; then
                    ensure_dir "$dir_path"
                fi
            fi
            if [[ -d "$dir_path" && ! -w "$dir_path" ]]; then
                log_warn "Directory not writable: $dir_path"
                if [[ "$FIX_MODE" == "true" ]]; then
                    chmod u+w "$dir_path" && log_info "Fixed permissions for $dir_path"
                fi
            fi
        fi
    done

    # Check Tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Missing tool: $tool"
            if [[ "$FIX_MODE" == "true" ]]; then
                install_sys_pkg "$tool" || true
            fi
        else
            [[ "$REPORT_MODE" == "true" ]] && log_success "Found: $tool"
        fi
    done

    if [[ "$REPORT_MODE" == "true" ]]; then
        print_report "${required_env[@]}" "${directory_vars[@]}" "${required_tools[@]}"
    fi
    
    log_info "Verification complete."
}

print_report() {
    log_info "===== Environment Verification Report ====="
    # Simplified report logic
    log_info "Check completed. See logs for details."
    log_info "=============================="
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_verification
fi
