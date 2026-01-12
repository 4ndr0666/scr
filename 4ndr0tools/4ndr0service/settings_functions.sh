#!/usr/bin/env bash
# File: settings_functions.sh
# Optimized: safer jq, installed-editor filtering, reload support

set -euo pipefail
IFS=$'\n\t'

# ──────────────────────────────────────────────────────────────────────────────
# SOURCE COMMON
# ──────────────────────────────────────────────────────────────────────────────
source "$PKG_PATH/common.sh"

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION MANAGEMENT
# ──────────────────────────────────────────────────────────────────────────────
create_config_if_missing() {
    ensure_dir "$(dirname "$CONFIG_FILE")"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat >"$CONFIG_FILE" <<'EOF'
{
  "settings_editor": "vim",
  "required_env": ["PYENV_ROOT", "PIPX_HOME", "PIPX_BIN_DIR"],
  "directory_vars": ["PYENV_ROOT", "PIPX_HOME", "PIPX_BIN_DIR"],
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
  "venv_name": ".venv"
}
EOF
        log_info "Created default config → $CONFIG_FILE"
    fi
}

load_config() {
    [[ -f "$CONFIG_FILE" && -s "$CONFIG_FILE" ]] || handle_error "Config missing or empty: $CONFIG_FILE"
    jq -e . >/dev/null 2>&1 <"$CONFIG_FILE" || handle_error "Invalid JSON in config: $CONFIG_FILE"
}

modify_settings() {
    local editor
    editor=$(jq -r '.settings_editor // "vim"' "$CONFIG_FILE")

    # Filter to only installed editors
    local available=()
    for e in vim nano emacs micro lite-xl code; do
        command -v "$e" >/dev/null && available+=("$e")
    done

    if [[ ${#available[@]} -eq 0 ]]; then
        editor="vi"  # absolute fallback
    elif ! command -v "$editor" >/dev/null; then
        editor="${available[0]}"
        log_warn "Preferred editor '$editor' not found → using ${available[0]}"
    fi

    "$editor" "$CONFIG_FILE" && log_info "Config edited with $editor"
}

# Export
export -f create_config_if_missing load_config modify_settings
