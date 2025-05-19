#!/usr/bin/env bash
# File: common.sh
# Description: Common functions & configuration loader for 4ndr0service Suite.
set -euo pipefail
IFS=$'\n\t'

# =================== // 4ndr0service common.sh //

## Constants

if [[ "${COMMON_SH_INCLUDED:-}" == "true" ]]; then
    return
fi
export COMMON_SH_INCLUDED=true

## Config & Logging Defaults
CONFIG_FILE="${CONFIG_FILE:-$HOME/.local/share/4ndr0service/config.json}"
LOG_FILE_DIR_DEFAULT="$HOME/.local/share/logs/4ndr0service/logs"
LOG_FILE_DEFAULT="$LOG_FILE_DIR_DEFAULT/4ndr0service.log"

## Logging

log_info() {
    local message="$1"
    json_log "INFO" "$message"
}

log_warn() {
    local message="$1"
    json_log "WARN" "$message"
    echo -e "\033[1;33m⚠️ Warning: $message\033[0m"
}

json_log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    \mkdir -p "${LOG_FILE_DIR:-$LOG_FILE_DIR_DEFAULT}"
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
      "$timestamp" "$level" "$msg" >> "${LOG_FILE:-$LOG_FILE_DEFAULT}"
}

## Error Handling

handle_error() {
    local error_message="$1"
    json_log "ERROR" "$error_message"
    echo -e "\033[0;31m❌ Error: $error_message\033[0m" >&2
    exit 1
}

## Directory Helpers

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        if \mkdir -p "$dir"; then
            log_info "Created directory: '$dir'."
        else
            handle_error "Failed to create directory '$dir'."
        fi
    else
        log_info "Directory '$dir' already exists."
    fi
}

## Installation Helpers

attempt_tool_install() {
    local tool="$1"
    local fix_mode="$2"
    if [[ "$fix_mode" == "true" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_warn "No config file found; cannot install tools without package mapping."
            return
        fi

        local pkg_map
        pkg_map="$(jq -r ".tool_package_map.\"$tool\"" "$CONFIG_FILE" 2>/dev/null || true)"
        if [[ "$pkg_map" == "null" || -z "$pkg_map" ]]; then
            log_warn "No package mapping found for $tool. Skipping installation."
            return
        fi

        local PKG_MANAGER
        PKG_MANAGER="$(jq -r '.package_manager' "$CONFIG_FILE" || echo "pacman")"

        case "$PKG_MANAGER" in
            pacman)
                if sudo pacman -Syu --needed --noconfirm "$pkg_map"; then
                    log_info "$tool installed successfully via pacman."
                else
                    log_warn "Failed to install $tool with pacman."
                fi
                ;;
            apt-get)
                if sudo apt-get update && sudo apt-get install -y "$pkg_map"; then
                    log_info "$tool installed successfully via apt-get."
                else
                    log_warn "Failed to install $tool with apt-get."
                fi
                ;;
            dnf)
                if sudo dnf install -y "$pkg_map"; then
                    log_info "$tool installed successfully via dnf."
                else
                    log_warn "Failed to install $tool with dnf."
                fi
                ;;
            brew)
                if brew install "$pkg_map"; then
                    log_info "$tool installed successfully via brew."
                else
                    log_warn "Failed to install $tool with brew."
                fi
                ;;
            *)
                log_warn "Unsupported package manager $PKG_MANAGER. Cannot install $tool."
                ;;
        esac
    else
        log_warn "$tool missing. Use --fix to attempt installation."
    fi
}

## Path Expansion Utility

expand_path() {
    local raw="$1"
    # Expand $XDG_DATA_HOME, $XDG_CONFIG_HOME, $XDG_CACHE_HOME, $HOME, etc.
    local expanded
    expanded="$(echo "$raw" \
        | sed "s|\$XDG_DATA_HOME|$XDG_DATA_HOME|g" \
        | sed "s|\$XDG_CONFIG_HOME|$XDG_CONFIG_HOME|g" \
        | sed "s|\$XDG_CACHE_HOME|$XDG_CACHE_HOME|g" \
        | sed "s|\$HOME|$HOME|g")"
    echo "$expanded"
}

## Config
prompt_config_value() {
    local key="$1"
    local default_val="$2"
    local val
    read -rp "Enter value for $key [$default_val]: " val
    val="${val:-$default_val}"
    echo "$val"
}

create_config_if_missing() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "No config file found at $CONFIG_FILE."
        read -rp "Do you want to create config.json now? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            ensure_dir "$(dirname "$CONFIG_FILE")"

            local default_xdg_data="$HOME/.local/share"
            local default_xdg_config="$HOME/.config"
            local default_xdg_cache="$HOME/.cache"
            local default_xdg_state="$HOME/.local/state"
            local default_pkg_manager="pacman"
            local default_settings_editor="neovim"
            local default_user_interface="cli"

            cat > "$CONFIG_FILE" <<EOF
{
  "env": {
    "XDG_DATA_HOME": "$(prompt_config_value "XDG_DATA_HOME" "$default_xdg_data")",
    "XDG_CONFIG_HOME": "$(prompt_config_value "XDG_CONFIG_HOME" "$default_xdg_config")",
    "XDG_CACHE_HOME": "$(prompt_config_value "XDG_CACHE_HOME" "$default_xdg_cache")",
    "XDG_STATE_HOME": "$(prompt_config_value "XDG_STATE_HOME" "$default_xdg_state")",
    "CARGO_HOME": "\$XDG_DATA_HOME/cargo",
    "RUSTUP_HOME": "\$XDG_DATA_HOME/rustup",
    "NVM_DIR": "\$XDG_CONFIG_HOME/nvm",
    "PSQL_HOME": "\$XDG_DATA_HOME/postgresql",
    "MYSQL_HOME": "\$XDG_DATA_HOME/mysql",
    "SQLITE_HOME": "\$XDG_DATA_HOME/sqlite",
    "MESON_HOME": "\$XDG_DATA_HOME/meson",
    "GOPATH": "\$XDG_DATA_HOME/go",
    "GOMODCACHE": "\$XDG_CACHE_HOME/go/mod",
    "VENV_HOME": "\$XDG_DATA_HOME/python/virtualenvs",
    "PIPX_HOME": "\$XDG_DATA_HOME/python/pipx",
    "ELECTRON_CACHE": "\$XDG_CACHE_HOME/electron",
    "NODE_DATA_HOME": "\$XDG_DATA_HOME/node",
    "NODE_CONFIG_HOME": "\$XDG_CONFIG_HOME/node",
    "SQL_DATA_HOME": "\$XDG_DATA_HOME/sql",
    "SQL_CONFIG_HOME": "\$XDG_CONFIG_HOME/sql",
    "SQL_CACHE_HOME": "\$XDG_CACHE_HOME/sql"
  },
  "tools": [
    "cargo",
    "npm",
    "pipx",
    "rustup",
    "psql",
    "mysql",
    "sqlite3",
    "electron",
    "meson",
    "ninja",
    "python3",
    "go",
    "node"
  ],
  "required_env": [
    "XDG_DATA_HOME",
    "XDG_CONFIG_HOME",
    "XDG_CACHE_HOME",
    "LOG_FILE",
    "CARGO_HOME",
    "RUSTUP_HOME",
    "NVM_DIR",
    "PSQL_HOME",
    "MYSQL_HOME",
    "SQLITE_HOME",
    "MESON_HOME",
    "GOPATH",
    "GOMODCACHE",
    "GOROOT",
    "VENV_HOME",
    "PIPX_HOME",
    "ELECTRON_CACHE",
    "NODE_DATA_HOME",
    "NODE_CONFIG_HOME",
    "SQL_DATA_HOME",
    "SQL_CONFIG_HOME",
    "SQL_CACHE_HOME"
  ],
  "directory_vars": [
    "XDG_DATA_HOME",
    "XDG_CONFIG_HOME",
    "XDG_CACHE_HOME",
    "CARGO_HOME",
    "RUSTUP_HOME",
    "NVM_DIR",
    "PSQL_HOME",
    "MYSQL_HOME",
    "SQLITE_HOME",
    "MESON_HOME",
    "GOPATH",
    "GOMODCACHE",
    "GOROOT",
    "VENV_HOME",
    "PIPX_HOME",
    "ELECTRON_CACHE",
    "NODE_DATA_HOME",
    "NODE_CONFIG_HOME",
    "SQL_DATA_HOME",
    "SQL_CONFIG_HOME",
    "SQL_CACHE_HOME"
  ],
  "backup_dir": "$(prompt_config_value "backup_dir" "$backup_dir")",
  "package_manager": "$(prompt_config_value "package_manager" "$default_pkg_manager")",
  "settings_editor": "$(prompt_config_value "settings_editor" "$default_settings_editor")",
  "user_interface": "$(prompt_config_value "user_interface" "$default_user_interface")",
  "plugins_dir": "$(prompt_config_value "plugins_dir" "$plugins_dir")",
  "logging": {
    "log_file_dir": "$HOME/.local/share/logs/4ndr0service/",
    "log_file": "$HOME/.local/share/logs/4ndr0service/4ndr0service.log"
  },
  "tool_package_map": {
    "mysql": "mysql",
    "electron": "electron"
  }
}
EOF
            echo "Config file created at $CONFIG_FILE."
        else
            handle_error "Cannot proceed without config file."
        fi
    fi
}

## Load Configuration
load_config() {
    create_config_if_missing
    if ! command -v jq &>/dev/null; then
        handle_error "'jq' is required. Please install jq."
    fi

    # Load raw values from config
    local raw_XDG_DATA_HOME raw_XDG_CONFIG_HOME raw_XDG_CACHE_HOME raw_XDG_STATE_HOME
    local raw_CARGO_HOME raw_RUSTUP_HOME raw_NVM_DIR raw_PSQL_HOME raw_MYSQL_HOME
    local raw_SQLITE_HOME raw_MESON_HOME raw_GOPATH raw_GOMODCACHE raw_GOROOT
    local raw_VENV_HOME raw_PIPX_HOME raw_ELECTRON_CACHE raw_NODE_DATA_HOME
    local raw_NODE_CONFIG_HOME raw_SQL_DATA_HOME raw_SQL_CONFIG_HOME raw_SQL_CACHE_HOME

    raw_XDG_DATA_HOME="$(jq -r '.env.XDG_DATA_HOME' "$CONFIG_FILE")"
    raw_XDG_CONFIG_HOME="$(jq -r '.env.XDG_CONFIG_HOME' "$CONFIG_FILE")"
    raw_XDG_CACHE_HOME="$(jq -r '.env.XDG_CACHE_HOME' "$CONFIG_FILE")"
    raw_XDG_STATE_HOME="$(jq -r '.env.XDG_STATE_HOME' "$CONFIG_FILE")"
    LOG_FILE_DIR="$(jq -r '.logging.log_file_dir' "$CONFIG_FILE")"
    LOG_FILE="$(jq -r '.logging.log_file' "$CONFIG_FILE")"

    raw_CARGO_HOME="$(jq -r '.env.CARGO_HOME' "$CONFIG_FILE")"
    raw_RUSTUP_HOME="$(jq -r '.env.RUSTUP_HOME' "$CONFIG_FILE")"
    raw_NVM_DIR="$(jq -r '.env.NVM_DIR' "$CONFIG_FILE")"
    raw_PSQL_HOME="$(jq -r '.env.PSQL_HOME' "$CONFIG_FILE")"
    raw_MYSQL_HOME="$(jq -r '.env.MYSQL_HOME' "$CONFIG_FILE")"
    raw_SQLITE_HOME="$(jq -r '.env.SQLITE_HOME' "$CONFIG_FILE")"
    raw_MESON_HOME="$(jq -r '.env.MESON_HOME' "$CONFIG_FILE")"
    raw_GOPATH="$(jq -r '.env.GOPATH' "$CONFIG_FILE")"
    raw_GOMODCACHE="$(jq -r '.env.GOMODCACHE' "$CONFIG_FILE")"
    raw_GOROOT="$(jq -r '.env.GOROOT' "$CONFIG_FILE")"
    raw_VENV_HOME="$(jq -r '.env.VENV_HOME' "$CONFIG_FILE")"
    raw_PIPX_HOME="$(jq -r '.env.PIPX_HOME' "$CONFIG_FILE")"
    raw_ELECTRON_CACHE="$(jq -r '.env.ELECTRON_CACHE' "$CONFIG_FILE")"
    raw_NODE_DATA_HOME="$(jq -r '.env.NODE_DATA_HOME' "$CONFIG_FILE")"
    raw_NODE_CONFIG_HOME="$(jq -r '.env.NODE_CONFIG_HOME' "$CONFIG_FILE")"
    raw_SQL_DATA_HOME="$(jq -r '.env.SQL_DATA_HOME' "$CONFIG_FILE")"
    raw_SQL_CONFIG_HOME="$(jq -r '.env.SQL_CONFIG_HOME' "$CONFIG_FILE")"
    raw_SQL_CACHE_HOME="$(jq -r '.env.SQL_CACHE_HOME' "$CONFIG_FILE")"

    backup_dir="$(jq -r '.backup_dir' "$CONFIG_FILE")"
    PKG_MANAGER="$(jq -r '.package_manager' "$CONFIG_FILE")"
    SETTINGS_EDITOR="$(jq -r '.settings_editor' "$CONFIG_FILE")"
    USER_INTERFACE="$(jq -r '.user_interface' "$CONFIG_FILE")"
    plugins_dir="$(jq -r '.plugins_dir' "$CONFIG_FILE")"

    # Expand paths to actual values
    XDG_DATA_HOME="$(expand_path "$raw_XDG_DATA_HOME")"
    XDG_CONFIG_HOME="$(expand_path "$raw_XDG_CONFIG_HOME")"
    XDG_CACHE_HOME="$(expand_path "$raw_XDG_CACHE_HOME")"
    XDG_STATE_HOME="$(expand_path "$raw_XDG_STATE_HOME")"
    LOG_FILE_DIR="$(expand_path "$LOG_FILE_DIR")"
    LOG_FILE="$(expand_path "$LOG_FILE")"
    plugins_dir="$(expand_path "$plugins_dir")"

    CARGO_HOME="$(expand_path "$raw_CARGO_HOME")"
    RUSTUP_HOME="$(expand_path "$raw_RUSTUP_HOME")"
    NVM_DIR="$(expand_path "$raw_NVM_DIR")"
    PSQL_HOME="$(expand_path "$raw_PSQL_HOME")"
    MYSQL_HOME="$(expand_path "$raw_MYSQL_HOME")"
    SQLITE_HOME="$(expand_path "$raw_SQLITE_HOME")"
    MESON_HOME="$(expand_path "$raw_MESON_HOME")"
    GOPATH="$(expand_path "$raw_GOPATH")"
    GOMODCACHE="$(expand_path "$raw_GOMODCACHE")"
    GOROOT="$(expand_path "$raw_GOROOT")"
    VENV_HOME="$(expand_path "$raw_VENV_HOME")"
    PIPX_HOME="$(expand_path "$raw_PIPX_HOME")"
    ELECTRON_CACHE="$(expand_path "$raw_ELECTRON_CACHE")"
    NODE_DATA_HOME="$(expand_path "$raw_NODE_DATA_HOME")"
    NODE_CONFIG_HOME="$(expand_path "$raw_NODE_CONFIG_HOME")"
    SQL_DATA_HOME="$(expand_path "$raw_SQL_DATA_HOME")"
    SQL_CONFIG_HOME="$(expand_path "$raw_SQL_CONFIG_HOME")"
    SQL_CACHE_HOME="$(expand_path "$raw_SQL_CACHE_HOME")"
}
load_config

## Ensure Primary Directories Exist
ensure_dir "$LOG_FILE_DIR"
ensure_dir "$backup_dir"
ensure_dir "$plugins_dir"

## Parallel Execution Helper
run_parallel_checks() {
    local checks=("$@")
    local pids=()
    local success=true

    for chk in "${checks[@]}"; do
        (eval "$chk") &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            success=false
        fi
    done

    $success || handle_error "One or more checks failed in parallel."
}
