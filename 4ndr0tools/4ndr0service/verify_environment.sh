#!/usr/bin/env bash
# File: test/src/verify_environment.sh
# Fully hardened verification + auto-fix engine

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"
source "$PKG_PATH/settings_functions.sh"

create_config_if_missing
load_config

FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"
DRY_RUN="${DRY_RUN:-false}"

export FIX_MODE REPORT_MODE DRY_RUN

# ──────────────────────────────────────────────────────────────────────────────
# CORE CHECKS
# ──────────────────────────────────────────────────────────────────────────────
check_env_vars() {
    local missing=0
    mapfile -t REQUIRED < <(safe_jq_array "required_env" "$CONFIG_FILE")
    for var in "${REQUIRED[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warn "Missing env var: $var"
            ((missing++))
            [[ "$FIX_MODE" == "true" ]] || continue
            case "$var" in
                PYENV_ROOT)     export PYENV_ROOT="$XDG_DATA_HOME/pyenv" ;;
                PIPX_HOME)      export PIPX_HOME="$XDG_DATA_HOME/pipx" ;;
                PIPX_BIN_DIR)   export PIPX_BIN_DIR="$PIPX_HOME/bin" ;;
                *)              log_warn "No auto-fix for $var" ;;
            esac
            log_info "Fixed: $var set to ${!var}"
        fi
    done
    (( missing == 0 )) && log_info "All required environment variables present."
}

check_directories() {
    mapfile -t DIR_VARS < <(safe_jq_array "directory_vars" "$CONFIG_FILE")
    for var in "${DIR_VARS[@]}"; do
        local dir="${!var:-}"
        [[ -z "$dir" ]] && { log_warn "$var not set"; continue; }
        ensure_dir "$dir"
        check_directory_writable "$dir"
    done
}

check_tools() {
    mapfile -t TOOLS < <(safe_jq_array "tools" "$CONFIG_FILE")
    for tool in "${TOOLS[@]}" pyenv pipx poetry; do
        if command -v "$tool" &>/dev/null; then
            log_info "Tool $tool → FOUND ($(command -v "$tool"))"
        else
            log_warn "Tool $tool → MISSING"
        fi
    done
}

print_report() {
    cat <<EOF

==============================
         4NDR0666 VERIFICATION REPORT
==============================

Environment Variables:
$(env | grep -E "$(safe_jq_array "required_env" "$CONFIG_FILE" | tr '\n' '|' | sed 's/|$//')")

Directories:
$(for v in $(safe_jq_array "directory_vars" "$CONFIG_FILE"); do printf "  %s=%s\n" "$v" "${!v:-<unset>}"; done)

Tools:
$(for t in $(safe_jq_array "tools" "$CONFIG_FILE") pyenv pipx poetry; do printf "  %s: %s\n" "$t" "$(command -v "$t" || echo 'MISSING')"; done)

EOF
}

run_verification() {
    log_info "Starting environment verification..."
    check_env_vars
    check_directories
    check_tools
    [[ "$REPORT_MODE" == "true" ]] && print_report
    log_info "Verification complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_verification "$@"
fi
