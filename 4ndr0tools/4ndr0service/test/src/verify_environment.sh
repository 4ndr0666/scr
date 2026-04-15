#!/usr/bin/env bash
# File: test/src/verify_environment.sh
# Description: Alpha Auditor for 4ndr0service environment integrity.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../../common.sh
source "${PKG_PATH:-.}/common.sh"

FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"

run_verification() {
    log_info "Verifying Offensive Tooling Hives..."
    # Core offensive hives identified in Phase 4 of Ascension Protocol
    for hive in "stig" "ImgCodeCheck"; do
        if [[ ! -d "$VENV_HOME/$hive" ]]; then
            log_warn "Offensive hive missing: $hive. Potential logical dissolution."
        else
            log_success "Verified hive: $hive"
        fi
    done

    log_info "Verifying Environment Alignment..."
    load_config
    
    local -a req_env req_tools dir_vars
    mapfile -t req_env < <(jq -r '(.required_env // [])[]' "$CONFIG_FILE")
    mapfile -t dir_vars < <(jq -r '(.directory_vars // [])[]' "$CONFIG_FILE")
    mapfile -t req_tools < <(jq -r '(.tools // [])[]' "$CONFIG_FILE")

    # 1. Environment Variable Audit
    for var in "${req_env[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warn "Missing environment variable: $var"
            if [[ "$FIX_MODE" == "true" ]]; then
                # Attempt auto-repair via standard XDG fallbacks
                initialize_suite # Re-trigger initialization to restore vars
                log_info "Restoration attempted for $var"
            fi
        fi
    done

    # 2. Directory Integrity & Permissions
    for var in "${dir_vars[@]}"; do
        local dir_path="${!var:-}"
        if [[ -n "$dir_path" ]]; then
            if [[ ! -d "$dir_path" ]]; then
                log_warn "Directory missing: $dir_path ($var)"
                [[ "$FIX_MODE" == "true" ]] && ensure_dir "$dir_path"
            fi
            if [[ -d "$dir_path" && ! -w "$dir_path" ]]; then
                log_warn "Directory not writable: $dir_path"
                [[ "$FIX_MODE" == "true" ]] && chmod u+w "$dir_path"
            fi
        fi
    done

    # 3. Toolchain Presence
    for tool in "${req_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Missing toolchain vector: $tool"
            [[ "$FIX_MODE" == "true" ]] && install_sys_pkg "$tool"
        fi
    done

    log_success "Environment Audit Complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_verification
fi
