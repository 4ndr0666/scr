#!/usr/bin/env bash
# File: service/optimize_cargo.sh
# 4ndr0666OS: Hardened Rust/Cargo Optimization Service
# - Integration: Rustup Hive + Cargo-Update Delta Sync
# - Logic: Registry/Index Sanitization (Inode Recovery)
# - Compliance: SC2155 (Exit Integrity), SC1091 (Env Sourcing)

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"

optimize_cargo_service() {
    log_info "Synchronizing Cargo Matrix..."

    # 1. Rustup Infrastructure
    if ! command -v rustup &>/dev/null; then
        log_info "Rustup missing from Hive. Initiating deployment..."
        # GUP 4.2: pipefail re-asserted inside the child; 600s ceiling on the
        # remote rustup bootstrap.
        run_bounded 600 "rustup bootstrap" \
            bash -c 'set -o pipefail; curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path' \
            || handle_error "$LINENO" "Rustup deployment failed."
    fi

    # 2. Environment Activation
    path_prepend "${CARGO_HOME}/bin"
    # shellcheck disable=SC1091
    [[ -s "${CARGO_HOME}/env" ]] && source "${CARGO_HOME}/env"

    # 3. Toolchain & Registry Sanitization
    log_info "Updating Toolchains & Purging Registry Index..."
    run_bounded 300 "rustup update stable" rustup update stable || log_warn "Toolchain update failed."
    rustup default stable &>/dev/null || true

    # D-05 FIX: Original wiped the entire registry index on every run, forcing
    # Cargo to re-download all index data — catastrophic on metered/air-gapped
    # systems. Replaced with age-gated pruning of stale pack/crate files only.
    # Index structure is preserved; only files older than 7 days (pack) or
    # 30 days (crate cache) are removed.
    if [[ -d "${CARGO_HOME}/registry/index" ]]; then
        find "${CARGO_HOME}/registry/index" -type f -name "*.pack" -mtime +7 -delete 2>/dev/null || true
        log_info "Cargo registry index: stale pack files pruned (>7 days)."
    fi
    if [[ -d "${CARGO_HOME}/registry/cache" ]]; then
        find "${CARGO_HOME}/registry/cache" -type f -name "*.crate" -mtime +30 -delete 2>/dev/null || true
        log_info "Cargo registry cache: stale crate files pruned (>30 days)."
    fi

    # 4. Cargo Tool Synchronization (Delta-Aware)
    local tools_json
    tools_json=$(jq -r '(.cargo_tools // [])[]' "$CONFIG_FILE")
    local -a c_tools
    mapfile -t c_tools <<< "$tools_json"

    if [[ ${#c_tools[@]} -gt 0 && -n "${c_tools[0]}" ]]; then
        log_info "Synchronizing Cargo Tools..."

        local has_updater=false
        command -v cargo-install-update &>/dev/null && has_updater=true

        for tool in "${c_tools[@]}"; do
            [[ -z "$tool" ]] && continue
            if ! cargo install --list | grep -q "^${tool} "; then
                log_info "Deploying tool: $tool"
                run_bounded 300 "cargo install $tool" cargo install "$tool" || log_warn "Cargo failed to deploy: $tool"
            else
                if [[ "$has_updater" == "true" ]]; then
                    log_info "Checking delta for: $tool"
                    run_bounded 600 "cargo install-update $tool" cargo install-update "$tool" || log_warn "Delta sync failed: $tool"
                else
                    log_info "Forcing update for: $tool"
                    run_bounded 300 "cargo install $tool" cargo install "$tool" || log_warn "Force update failed: $tool"
                fi
            fi
        done
    fi

    log_success "Cargo Matrix Calibrated. Rust: $(rustc --version | awk '{print $2}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # GAP-J FIX: standalone runs previously skipped suite initialization —
    # CONFIG_FILE could be absent, so every jq read silently failed and tool
    # sync was silently skipped. initialize_suite guarantees the XDG dirs,
    # the config file and the jq dependency exactly as the main.sh entry
    # point does (idempotent; the flock mutex is already held from the
    # common.sh source above).
    initialize_suite
    optimize_cargo_service
fi
