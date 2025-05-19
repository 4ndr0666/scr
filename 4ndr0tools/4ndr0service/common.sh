#!/usr/bin/env bash
# 4ndr0service: common.sh (unified env loader for pyenv/pipx/poetry/XDG)

set -euo pipefail

# ---- XDG Environment ----
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ---- pyenv/pipx/poetry Environment ----
if [[ -z "${PYENV_ROOT:-}" ]]; then
    if [[ -d "$XDG_DATA_HOME/pyenv" ]]; then
        export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
    else
        export PYENV_ROOT="$HOME/.pyenv"
    fi
fi
export PIPX_HOME="${PIPX_HOME:-$XDG_DATA_HOME/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$PIPX_HOME/bin}"

# ---- Idempotent PATH order: pyenv/bin, pyenv/shims, pipx/bin, then rest ----
case ":$PATH:" in
    *:"$PYENV_ROOT/bin:"*) ;;
    *) PATH="$PYENV_ROOT/bin:$PATH" ;;
esac
case ":$PATH:" in
    *:"$PYENV_ROOT/shims:"*) ;;
    *) PATH="$PYENV_ROOT/shims:$PATH" ;;
esac
case ":$PATH:" in
    *:"$PIPX_BIN_DIR:"*) ;;
    *) PATH="$PIPX_BIN_DIR:$PATH" ;;
esac
export PATH

# ---- Utility: Directory ensures for XDG dirs ----
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$PIPX_HOME" "$PIPX_BIN_DIR" "$PYENV_ROOT"

# ---- End of common.sh ----
