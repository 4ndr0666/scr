#!/usr/bin/env bash
# File: common.sh
# Description: Core library for 4ndr0service Suite.
#   - Centralizes logging, error handling, and path management.
#   - Provides unified package management and configuration logic.
#   - Source of truth for XDG compliance.

set -euo pipefail
IFS=$'\n\t'

if [[ -n "${COMMON_SOURCED:-}" ]]; then
    return 0
fi
export COMMON_SOURCED=1

# =============================================================================
# 1. PATH DISCOVERY & INITIALIZATION
# =============================================================================

# Ensure PKG_PATH is set relative to this script location
ensure_pkg_path() {
    if [[ -z "${PKG_PATH:-}" || ! -f "${PKG_PATH:-}/common.sh" ]]; then
        local caller="${BASH_SOURCE[0]:-$0}"
        local script_dir
        # Resolve symlinks to find the actual physical location
        script_dir="$(cd -- "$(dirname -- "$(readlink -f "$caller")")" && pwd -P)"
        
        # Traverse up to find the root containing common.sh (max 3 levels)
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
# 2. LOGGING & ERROR HANDLING
# =============================================================================

# ANSI Colors
declare -r C_RED='\033[0;31m'
declare -r C_GREEN='\033[0;32m'
declare -r C_YELLOW='\033[1;33m'
declare -r C_BLUE='\033[0;34m'
declare -r C_RESET='\033[0m'

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

# Robust error handler
handle_error() {
    local line_no="$1"
    local command="$2"
    local exit_code="${3:-$?}"
    log_error "Command '$command' failed at line $line_no with exit code $exit_code."
    exit "$exit_code"
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# =============================================================================
# 3. XDG & ENVIRONMENT CONFIGURATION
# =============================================================================

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

# Application Config File
export CONFIG_FILE="$XDG_CONFIG_HOME/4ndr0service/config.json"
export LOG_FILE="$XDG_CACHE_HOME/4ndr0service/service.log"

ensure_dir() {
    local dir="$1"
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
# 4. PACKAGE MANAGEMENT
# =============================================================================

detect_pkg_manager() {
    if command -v pacman &>/dev/null; then echo "pacman"
    elif command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v brew &>/dev/null; then echo "brew"
    else echo "unknown"
    fi
}

pkg_is_installed() {
    local pkg="$1"
    local mgr
    mgr=$(detect_pkg_manager)
    case "$mgr" in
        pacman) pacman -Qi "$pkg" &>/dev/null ;;
        apt) dpkg -l "$pkg" &>/dev/null ;;
        dnf) rpm -q "$pkg" &>/dev/null ;;
        brew) brew list "$pkg" &>/dev/null ;;
        *) command -v "$pkg" &>/dev/null ;;
    esac
}

install_sys_pkg() {
    local pkg="$1"
    if pkg_is_installed "$pkg"; then
        log_info "$pkg is already installed."
        return 0
    fi

    local mgr
    mgr=$(detect_pkg_manager)
    log_info "Installing $pkg using $mgr..."
    case "$mgr" in
        pacman) sudo pacman -S --noconfirm --needed "$pkg" ;;
        apt) sudo apt-get update && sudo apt-get install -y "$pkg" ;;
        dnf) sudo dnf install -y "$pkg" ;;
        brew) brew install "$pkg" ;;
        *) log_warn "Manual installation required: $pkg"; return 1 ;;
    esac
}

# =============================================================================
# 5. CONFIGURATION MANAGEMENT
# =============================================================================

create_config_if_missing() {
    ensure_dir "$(dirname "$CONFIG_FILE")"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat >"$CONFIG_FILE" <<EOF
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
EOF
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
# 6. SHELL CONFIG UTILS
# =============================================================================

ensure_config_line() {
    local file="$1"
    local line="$2"
    [[ ! -f "$file" ]] && touch "$file"
    if ! grep -Fxq "$line" "$file"; then
        printf "%s\n" "$line" >> "$file"
        log_success "Added config to $file"
    fi
}

path_prepend() {
    local dir="$1"
    if [[ -d "${dir}" ]] && [[ ":$PATH:" != *":${dir}:"* ]]; then
        export PATH="${dir}${PATH:+":$PATH"}"
        log_info "Prepended to PATH: ${dir}"
    fi
}

# Execute multiple functions in parallel and wait for completion
run_parallel_checks() {
    local funcs=("$@")
    local pids=()

    for f in "${funcs[@]}"; do
        if declare -f "$f" >/dev/null; then
            "$f" &
            pids+=("$!")
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

initialize_suite() {
    ensure_xdg_dirs
    path_prepend "${XDG_BIN_HOME}"
    load_config
    log_success "4ndr0service initialized."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    initialize_suite
fi
