#!/usr/bin/env bash
# File: common.sh
# Centralized utilities, hardened PATH, logging, error handling, retry wrappers
# Optimized revision — all repeated patterns moved here

set -euo pipefail
IFS=$'\n\t'

# ──────────────────────────────────────────────────────────────────────────────
# CANONICAL PKG_PATH — EMBEDDED BY INSTALL.SH — DO NOT MODIFY MANUALLY
# ──────────────────────────────────────────────────────────────────────────────
PKG_PATH="/opt/4ndr0service"
export PKG_PATH

# ──────────────────────────────────────────────────────────────────────────────
# XDG DEFAULTS + PATH INJECTION (deduplicated, idempotent)
# ──────────────────────────────────────────────────────────────────────────────
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Pyenv / Pipx / Poetry canonical paths
export PYENV_ROOT="${PYENV_ROOT:-$XDG_DATA_HOME/pyenv}"
export PIPX_HOME="${PIPX_HOME:-$XDG_DATA_HOME/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$PIPX_HOME/bin}"

# Inject into PATH once, deduplicated
typeset -U path
path=(
    "$PYENV_ROOT/bin"
    "$PYENV_ROOT/shims"
    "$PIPX_BIN_DIR"
    "$HOME/.local/bin"
    "$path[@]"
)

export PATH

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────
export CONFIG_FILE="$XDG_CONFIG_HOME/4ndr0service/config.json"

# ──────────────────────────────────────────────────────────────────────────────
# LOGGING & ERROR HANDLING
# ──────────────────────────────────────────────────────────────────────────────
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
handle_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
    exit 1
}

trap 'handle_error "Line $LINENO: $BASH_COMMAND failed"' ERR

# ──────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS (centralized — used by all services)
# ──────────────────────────────────────────────────────────────────────────────
ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir" || handle_error "Failed to create: $dir"
}

check_directory_writable() {
    local dir="$1"
    [[ -w "$dir" ]] && log_info "Directory $dir is writable." ||
        handle_error "Directory $dir is not writable!"
}

safe_jq_array() {
    local key="$1" file="$2" default="[]"
    jq -r --arg k "$key" --argjson def "$default" '.[$k] // $def | .[]' "$file" 2>/dev/null || echo ""
}

retry() {
    local max=3 count=0
    until "$@"; do
        ((count++))
        if ((count >= max)); then
            handle_error "Command failed after $max retries: $*"
        fi
        log_warn "Retry $count/$max failed — waiting $((2**count))s..."
        sleep $((2**count))
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# PARALLEL EXECUTION (enhanced with GNU parallel if available)
# ──────────────────────────────────────────────────────────────────────────────
run_parallel_checks() {
    local funcs=("$@")
    local pids=() status=0

    if command -v parallel >/dev/null 2>&1; then
        # Prefer GNU parallel when installed
        printf '%s\n' "${funcs[@]}" | parallel --halt now,fail=1 --joblog /tmp/4ndr0-parallel.log \
            'bash -c "{}" || exit 1'
        return $?
    else
        # Fallback to background jobs
        for f in "${funcs[@]}"; do
            if declare -f "$f" >/dev/null; then
                "$f" &
                pids+=("$!")
            else
                log_warn "Function $f not found for parallel execution."
            fi
        done

        for pid in "${pids[@]}"; do
            wait "$pid" || status=1
        done
        return $status
    fi
}

# Export all for sourcing
export -f log_info log_warn handle_error ensure_dir check_directory_writable \
    safe_jq_array retry run_parallel_checks
