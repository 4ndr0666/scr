#!/usr/bin/env bash
# File: test/verify_environment.sh
# Description: Alpha Auditor for 4ndr0service environment integrity.
# NOTE: Moved from test/src/verify_environment.sh → test/verify_environment.sh.
#       The test/src/ subdirectory was structurally redundant; this file belongs
#       directly under test/ alongside final_audit.sh.

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

# D-17 FIX (clarification): Do NOT set FIX_MODE / REPORT_MODE inside THIS file
# at source-time. The correct pattern is for callers (final_audit.sh, main.sh)
# to set and export these variables BEFORE sourcing this file. The defaults
# below are applied as local variables inside run_verification() so the caller's
# exported values are always respected and never shadowed by this module.
# final_audit.sh correctly sets FIX_MODE/REPORT_MODE at its top level before
# sourcing — that pattern is intentional and correct.

# ── TOOL REMOVAL ──────────────────────────────────────────────────────────────
# GAP-02 FIX: Decommissions a tool from the suite — removes the hive venv,
# the ~/.local/bin symlink, and prunes it from config.json python_tools.
# Idempotent: safe to call against a tool that is already fully absent.
remove_tool() {
    local tool="${1:-}"
    if [[ -z "$tool" ]]; then
        log_warn "remove_tool: no tool name supplied"
        return 1
    fi

    log_info "Decommissioning tool: $tool"

    # 1. Remove hive venv
    local hive_path="${VENV_HOME}/${tool}"
    if [[ -d "$hive_path" ]]; then
        rm -rf -- "$hive_path"
        log_success "Removed hive venv: $hive_path"
    else
        log_info "Hive venv not present: $hive_path (already clean)"
    fi

    # 2. Remove ~/.local/bin symlink if it points into the removed hive
    local bin_link="${BIN_DIR}/${tool}"
    if [[ -L "$bin_link" ]]; then
        local link_target
        link_target=$(readlink -f "$bin_link" 2>/dev/null || true)
        if [[ "$link_target" == "$hive_path"* || ! -e "$bin_link" ]]; then
            rm -f "$bin_link"
            log_success "Removed symlink: $bin_link"
        else
            log_info "Symlink $bin_link points elsewhere — leaving in place"
        fi
    fi

    # 3. Prune from config.json python_tools list
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        local _tmp
        _tmp=$(mktemp)
        if jq --arg t "$tool" '(.python_tools // []) |= map(select(. != $t))' "$CONFIG_FILE" > "$_tmp"; then
            mv "$_tmp" "$CONFIG_FILE"
            log_success "Removed $tool from config.json python_tools"
        else
            rm -f "$_tmp"
            log_warn "jq failed to update config.json for tool removal: $tool"
        fi
    fi
}

# ── OFFENSIVE HIVE PROVISIONER ────────────────────────────────────────────────
# GAP-06 FIX: FIX_MODE for missing offensive hives now actually provisions them.
# Prefers ascension's install_resilient_tool; falls back to direct venv+pip.
_provision_hive() {
    local hive="$1"

    # Prefer ascension's install_resilient_tool if already loaded
    if declare -f install_resilient_tool >/dev/null 2>&1; then
        install_resilient_tool "$hive"
        return
    fi

    # Source ascension to get install_resilient_tool (argument-gating block
    # is protected by [[ "${BASH_SOURCE[0]}" == "$0" ]] so sourcing is safe)
    local _asc="${PKG_PATH}/ascension.sh"
    if [[ -f "$_asc" ]]; then
        # shellcheck source=/dev/null
        if ! source "$_asc" 2>/dev/null; then
            log_error "_provision_hive: failed to source ascension.sh"
            return 1
        fi
        if declare -f install_resilient_tool >/dev/null 2>&1; then
            install_resilient_tool "$hive"
            return
        fi
        log_error "_provision_hive: ascension.sh loaded but install_resilient_tool is unavailable"
        return 1
    fi

    # Last resort: direct venv + pip
    log_warn "_provision_hive fallback: ascension unavailable — installing $hive via direct venv"
    local target_venv="${VENV_HOME}/${hive}"
    ensure_dir "$VENV_HOME"

    # GUP 4.2: the fallback path carries the same hard timeouts as the
    # ascension inject vector — a hung venv create or pip install must never
    # wedge an audit run.
    run_bounded 300 "fallback venv create ($hive)" python3 -m venv "$target_venv" || {
        local rc=$?
        log_error "_provision_hive: failed to create venv for $hive"
        return "$rc"
    }

    run_bounded 300 "fallback pip upgrade ($hive)" "$target_venv/bin/pip" install --quiet --upgrade pip || {
        local rc=$?
        log_error "_provision_hive: failed to bootstrap pip for $hive"
        return "$rc"
    }

    run_bounded 900 "fallback pip install $hive" "$target_venv/bin/pip" install "$hive" || {
        local rc=$?
        log_error "_provision_hive: failed to install $hive"
        return "$rc"
    }

    log_success "Provisioned hive (fallback): $hive"
}

run_verification() {
    # Apply defaults locally; never overwrite the caller's environment.
    local fix_mode="${FIX_MODE:-false}"
    local report_mode="${REPORT_MODE:-false}"

    load_config

    # ── 0. Offensive Hive Audit ──────────────────────────────────────────────
    # GAP-01/05 FIX: hive list is now config-driven from "offensive_hives" key.
    # Hardcoded ["stig","ImgCodeCheck"] removed — config.json is the authority.
    log_info "Verifying Offensive Tooling Hives..."
    local -a offensive_hives
    mapfile -t offensive_hives < <(jq -r '(.offensive_hives // [])[]' "$CONFIG_FILE" 2>/dev/null || true)

    if [[ ${#offensive_hives[@]} -eq 0 ]]; then
        log_info "No offensive hives defined in config.json (offensive_hives key absent or empty)."
    fi

    for hive in "${offensive_hives[@]}"; do
        [[ -z "$hive" ]] && continue
        if [[ ! -d "$VENV_HOME/$hive" ]]; then
            log_warn "Offensive hive missing: $hive."
            if [[ "$fix_mode" == "true" ]]; then
                log_info "FIX_MODE: provisioning missing hive: $hive"
                _provision_hive "$hive"
            fi
        else
            log_success "Verified hive: $hive"
        fi
    done

    log_info "Verifying Environment Alignment..."

    local -a req_env dir_vars req_tools
    mapfile -t req_env   < <(jq -r '(.required_env   // [])[]' "$CONFIG_FILE")
    mapfile -t dir_vars  < <(jq -r '(.directory_vars // [])[]' "$CONFIG_FILE")
    mapfile -t req_tools < <(jq -r '(.tools          // [])[]' "$CONFIG_FILE")

    # ── 1. Environment Variable Audit ────────────────────────────────────────
    for var in "${req_env[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warn "Missing environment variable: $var"
            if [[ "$fix_mode" == "true" ]]; then
                initialize_suite
                log_info "Restoration attempted for $var"
            fi
        fi
    done

    # ── 2. Directory Integrity & Permissions ─────────────────────────────────
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

    # ── 3. Toolchain Presence ────────────────────────────────────────────────
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
