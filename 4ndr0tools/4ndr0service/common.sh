#!/usr/bin/env bash
# File: common.sh
set -euo pipefail
IFS=$'\n\t'

# Dynamically determine the package base path (PKG_PATH) if not already set
if [ -z "${PKG_PATH:-}" ]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
    if [ -f "$SCRIPT_DIR/common.sh" ]; then
        PKG_PATH="$SCRIPT_DIR"
    elif [ -f "$SCRIPT_DIR/../common.sh" ]; then
        PKG_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
    elif [ -f "$SCRIPT_DIR/../../common.sh" ]; then
        PKG_PATH="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
    else
        echo "Error: Could not determine package base path." >&2
        exit 1
    fi
    export PKG_PATH
fi

expand_path() {
    local raw="$1"
    echo "${raw/#\~/$HOME}"
}

# XDG Directory Defaults
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Pyenv/Pipx Defaults
if [[ -z "${PYENV_ROOT:-}" ]]; then
    if [[ -d "$XDG_DATA_HOME/pyenv" ]]; then
        export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
    else
        export PYENV_ROOT="$HOME/.pyenv"
    fi
fi

export PIPX_HOME="${PIPX_HOME:-$XDG_DATA_HOME/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$PIPX_HOME/bin}"

# Export pyenv, pipx, poetry, and local bin paths, avoiding duplicates.
for dir in "$PYENV_ROOT/bin" "$PYENV_ROOT/shims" "$PIPX_BIN_DIR" "$HOME/.local/bin"; do
    case ":$PATH:" in
        *:"$dir:"*) ;;
        *) PATH="$dir:$PATH" ;;
    esac
done
export PATH

# Utility functions for idempotent directory creation
ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Logging
log_info() { echo -e "\033[1;32mINFO:\033[0m $*"; }
log_warn() { echo -e "\033[1;33mWARN:\033[0m $*"; }
handle_error() { log_warn "Error: $*"; exit 1; }
trap 'handle_error "Line $LINENO: $BASH_COMMAND"' ERR
