#!/usr/bin/env bash
# File: test/src/verify_environment.sh
# Description: Alpha Auditor for 4ndr0service environment integrity.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../../common.sh
source "${PKG_PATH:-.}/common.sh"

# FIX: Do NOT set FIX_MODE / REPORT_MODE at module scope (source-time).
#      Doing so shadows the caller's exported value because Bash evaluates
#      `VAR="${VAR:-default}"` at the point the line executes — i.e., the
#      moment this file is sourced — before run_verification() is called.
#      The defaults are now applied inside the function where they are used,
#      so the caller's environment is always respected.

run_verification() {
    # Apply defaults locally; never overwrite the caller's environment.
    local fix_mode="${FIX_MODE:-false}"
    local report_mode="${REPORT_MODE:-false}"

    log_info "Verifying Offensive Tooling Hives..."
    for hive in "stig" "ImgCodeCheck"; do
        if [[ ! -d "$VENV_HOME/$hive" ]]; then
            log_warn "Offensive hive missing: $hive. Potential logical dissolution."
        else
            log_success "Verified hive: $hive"
        fi
    done

    log_info "Verifying Environment Alignment..."
    load_config

    local -a req_env dir_vars req_tools
    mapfile -t req_env  < <(jq -r '(.required_env  // [])[]' "$CONFIG_FILE")
    mapfile -t dir_vars < <(jq -r '(.directory_vars // [])[]' "$CONFIG_FILE")
    mapfile -t req_tools < <(jq -r '(.tools         // [])[]' "$CONFIG_FILE")

    # 1. Environment Variable Audit
    for var in "${req_env[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warn "Missing environment variable: $var"
            if [[ "$fix_mode" == "true" ]]; then
                initialize_suite
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
                [[ "$fix_mode" == "true" ]] && ensure_dir "$dir_path"
            fi
            if [[ -d "$dir_path" && ! -w "$dir_path" ]]; then
                log_warn "Directory not writable: $dir_path"
                [[ "$fix_mode" == "true" ]] && chmod u+w "$dir_path"
            fi
        fi
    done

    # 3. Toolchain Presence
    for tool in "${req_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Missing toolchain vector: $tool"
            [[ "$fix_mode" == "true" ]] && install_sys_pkg "$tool"
        fi
    done

    log_success "Environment Audit Complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_verification
fi
