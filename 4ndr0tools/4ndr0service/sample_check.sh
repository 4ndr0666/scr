#!/usr/bin/env bash
# File: plugins/sample_check.sh
# Optimized sample plugin — now with config-driven checks

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

plugin_sample_check() {
    log_info "Executing sample_check plugin..."

    # Example: check for dangerous aliases (configurable via future key)
    if alias | grep -qE 'alias (ls|rm|cp|mv)='; then
        log_warn "Dangerous alias detected (ls/rm/cp/mv). Consider removing for safety."
    fi

    # Example: ensure critical env vars from config are present
    mapfile -t CRITICAL < <(safe_jq_array "required_env" "$CONFIG_FILE")
    for v in "${CRITICAL[@]}"; do
        [[ -z "${!v:-}" ]] && log_warn "Critical env var missing: $v"
    done

    log_info "sample_check plugin completed."
}

# Auto-register / call from controller if desired
# plugin_sample_check
