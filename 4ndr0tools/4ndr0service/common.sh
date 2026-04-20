#!/usr/bin/env bash
# File: common.sh
# Description: Core library for 4ndr0service Suite.
#   - Centralizes logging, error handling, and path management.
#   - Provides unified package management and configuration logic.
#   - Source of truth for XDG compliance.

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# [4NDR0666OS] AUTONOMIC MUTEX LOCK (USER-SCOPED)
# Prevents systemd daemon race conditions while allowing multi-user isolation.
# ──────────────────────────────────────────────────────────────────────────────
if [[ -z "${_4NDR0_MUTEX_LOCKED:-}" ]]; then
    _LOCK_FILE="/tmp/4ndr0service_${EUID:-$(id -u)}.lock"

    if [[ -e "$_LOCK_FILE" && ! -w "$_LOCK_FILE" ]]; then
        echo -e "\033[38;5;196m[FATAL] Lockfile $_LOCK_FILE is owned by another user (likely root). Execute 'sudo rm $_LOCK_FILE' to clear the blockage.\033[0m" >&2
        exit 1
    fi

    exec 200>"$_LOCK_FILE"
    if ! flock -n 200; then
        echo -e "\033[38;5;208m[WARN] Matrix is currently locked by an active process for UID ${EUID}. Aborting collision cycle.\033[0m" >&2
        exit 1
    fi
    export _4NDR0_MUTEX_LOCKED=1
fi

IFS=$'\n\t'

if [[ -n "${COMMON_SOURCED:-}" ]]; then
    return 0
fi
COMMON_SOURCED=1

# =============================================================================
# 1. ANSI COLORS
# FIX: The original file exported these variables then immediately re-declared
#      them with `declare -r`.  Under `set -euo pipefail`, re-declaring an
#      already-exported variable as readonly raises a fatal error.  Single
#      authoritative `export` block; no `declare -r` anywhere in this file.
# =============================================================================

export C_RED='\033[0;31m'
export C_GREEN='\033[0;32m'
export C_YELLOW='\033[1;33m'
export C_BLUE='\033[0;34m'
export C_RESET='\033[0m'

# =============================================================================
# 2. XDG BASE DIRECTORY SPECIFICATION  (single authoritative block)
# FIX: Original had two separate export blocks for XDG vars (Sections 2 & 4)
#      which created redundancy and a maintenance hazard.  Unified here.
# =============================================================================

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

# Offensive Suite Paths (Derived from XDG)
export PYENV_ROOT="${XDG_DATA_HOME}/pyenv"
export VENV_HOME="${XDG_DATA_HOME}/virtualenv"
export BIN_DIR="${HOME}/.local/bin"

# Cohesion Variables (Aligning with config.json constraints)
export PIPX_HOME="${PIPX_HOME:-$XDG_DATA_HOME/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$HOME/.local/bin}"
export NVM_DIR="${NVM_DIR:-$XDG_DATA_HOME/nvm}"
export PSQL_HOME="${PSQL_HOME:-$XDG_DATA_HOME/psql}"
export MYSQL_HOME="${MYSQL_HOME:-$XDG_DATA_HOME/mysql}"

# Application Config & Log Paths
export CONFIG_FILE="${XDG_CONFIG_HOME}/4ndr0service/config.json"
export LOG_FILE="${XDG_CACHE_HOME}/4ndr0service/service.log"

# =============================================================================
# 3. PKG_PATH DISCOVERY
# =============================================================================

ensure_pkg_path() {
    if [[ -z "${PKG_PATH:-}" || ! -f "${PKG_PATH:-}/common.sh" ]]; then
        local caller="${BASH_SOURCE[0]:-$0}"
        local script_dir
        script_dir="$(cd -- "$(dirname -- "$(readlink -f "$caller")")" && pwd -P)"

        local count=0
        while [[ "$script_dir" != "/" && $count -lt 3 ]]; do
            if [[ -f "$script_dir/common.sh" ]]; then
                PKG_PATH="$script_dir"
                break
            fi
            script_dir="$(dirname "$script_dir")"
            ((count++))
        done

        if [[ -z "${PKG_PATH:-}" ]]; then
            printf "CRITICAL ERROR: Could not determine package base path.\n" >&2
            exit 1
        fi
    fi
    export PKG_PATH
}

ensure_pkg_path

# =============================================================================
# 4. LOGGING & ERROR HANDLING
# =============================================================================

log_info() {
    printf "${C_BLUE}[INFO]${C_RESET} %s %s\n" "$(date +'%H:%M:%S')" "$*"
}

log_success() {
    printf "${C_GREEN}[OK]${C_RESET}   %s %s\n" "$(date +'%H:%M:%S')" "$*"
}

log_warn() {
    printf "${C_YELLOW}[WARN]${C_RESET} %s %s\n" "$(date +'%H:%M:%S')" "$*" >&2
}

log_error() {
    printf "${C_RED}[FAIL]${C_RESET} %s %s\n" "$(date +'%H:%M:%S')" "$*" >&2
}

handle_error() {
    local line_no="$1"
    local command="$2"
    local exit_code="${3:-$?}"
    log_error "Command '$command' failed at line $line_no with exit code $exit_code."
    exit "$exit_code"
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# =============================================================================
# 5. FILESYSTEM UTILITIES
# =============================================================================

ensure_dir() {
    local dir="${1:-}"
    [[ -z "$dir" ]] && return 0
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

ensure_xdg_dirs() {
    ensure_dir "$XDG_CONFIG_HOME"
    ensure_dir "$XDG_DATA_HOME"
    ensure_dir "$XDG_STATE_HOME"
    ensure_dir "$XDG_CACHE_HOME"
    ensure_dir "$XDG_BIN_HOME"
    ensure_dir "$(dirname "$LOG_FILE")"
}

# =============================================================================
# 6. PACKAGE MANAGEMENT
# FIX: pkg_is_installed() logic was inverted. Original:
#        `[[ -z "$pkg" ]] && pacman -Qi "$pkg" &>/dev/null`
#      This called pacman when $pkg was EMPTY (guaranteed failure) and silently
#      returned exit-0 ("installed") for every non-empty value without querying
#      pacman at all, meaning install_sys_pkg() never installed anything.
#      Corrected: guard returns 1 on empty input, then pacman is queried.
# =============================================================================

detect_pkg_manager() { echo "pacman"; }

pkg_is_installed() {
    local pkg="${1:-}"
    [[ -z "$pkg" ]] && return 1
    pacman -Qi "$pkg" &>/dev/null
}

install_sys_pkg() {
    local pkg="$1"
    if pkg_is_installed "$pkg"; then
        log_info "$pkg is already installed."
        return 0
    fi
    log_info "Deploying $pkg via Pacman..."
    sudo pacman -S --noconfirm --needed "$pkg"
}

# =============================================================================
# 7. CONFIGURATION MANAGEMENT
# =============================================================================

create_config_if_missing() {
    ensure_dir "$(dirname "$CONFIG_FILE")"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat >"$CONFIG_FILE" <<'ENDOFCONFIG'
{
  "settings_editor": "vim",
  "required_env": ["PYENV_ROOT", "PIPX_HOME", "PIPX_BIN_DIR", "NVM_DIR", "PSQL_HOME", "MYSQL_HOME"],
  "directory_vars": ["PYENV_ROOT", "PIPX_HOME", "PIPX_BIN_DIR", "NVM_DIR", "PSQL_HOME", "MYSQL_HOME"],
  "tools": ["python3", "pipx", "pyenv", "poetry"],
  "python_version": "3.10.14",
  "python_tools": ["black", "flake8", "mypy", "pytest", "poetry"],
  "cargo_tools": ["cargo-update", "cargo-audit"],
  "electron_tools": ["electron-builder"],
  "go_tools": ["golang.org/x/tools/gopls@latest", "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"],
  "node_version": "lts/*",
  "npm_global_packages": ["npm", "yarn", "pnpm", "typescript", "eslint", "prettier"],
  "ruby_gems": ["bundler", "rake", "rubocop"],
  "venv_pipx_packages": ["black", "flake8", "mypy", "pytest"],
  "audit_keywords": ["config_watch", "data_watch", "cache_watch"]
}
ENDOFCONFIG
        log_success "Created default config at $CONFIG_FILE"
    fi
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_config_if_missing
    fi
    if ! command -v jq &>/dev/null; then
        install_sys_pkg "jq"
    fi
    if ! jq -e . >/dev/null 2>&1 <"$CONFIG_FILE"; then
        log_error "Config file corrupt: $CONFIG_FILE"
        exit 1
    fi
}

# =============================================================================
# 8. SHELL CONFIG UTILS
# =============================================================================

ensure_config_line() {
    local file="$1"
    local line="$2"
    [[ ! -f "$file" ]] && touch "$file"
    if ! grep -Fxq "$line" "$file"; then
        printf "%s\n" "$line" >>"$file"
        log_success "Added config to $file"
    fi
}

path_prepend() {
    local dir="$1"
    if [[ -d "${dir}" ]] && [[ ":$PATH:" != *":${dir}:"* ]]; then
        export PATH="${dir}${PATH:+:$PATH}"
        log_info "Prepended to PATH: ${dir}"
    fi
}

# Execute multiple functions in parallel and wait for all to complete.
# Returns 1 if any worker failed; 0 if all succeeded.
run_parallel_checks() {
    local funcs=("$@")
    local pids=()

    for f in "${funcs[@]}"; do
        if declare -f "$f" >/dev/null; then
            "$f" &
            pids+=($!)
        else
            log_warn "Function $f not found for parallel run."
        fi
    done

    local status=0
    for pid in "${pids[@]}"; do
        wait "$pid" || status=1
    done

    return "$status"
}

# =============================================================================
# 9. SUITE INITIALIZATION
# =============================================================================

initialize_suite() {
    ensure_xdg_dirs
    path_prepend "${XDG_BIN_HOME}"
    load_config
    log_success "4ndr0service initialized."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    initialize_suite
fi
