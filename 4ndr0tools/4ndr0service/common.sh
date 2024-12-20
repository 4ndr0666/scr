#!/usr/bin/env bash
# File: common.sh
# Description: Common functions and configuration loader for 4ndr0service Suite

set -euo pipefail
IFS=$'\n\t'

# Prevent multiple sourcing
if [[ "${COMMON_SH_INCLUDED:-}" == "true" ]]; then
    return
fi
export COMMON_SH_INCLUDED=true

# Default paths
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/4ndr0service/config.json}"
LOG_FILE_DIR_DEFAULT="$HOME/.local/share/logs/4ndr0service/logs"
LOG_FILE_DEFAULT="$LOG_FILE_DIR_DEFAULT/4ndr0service.log"

json_log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')
    mkdir -p "${LOG_FILE_DIR:-$LOG_FILE_DIR_DEFAULT}"
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' "$timestamp" "$level" "$msg" >> "${LOG_FILE:-$LOG_FILE_DEFAULT}"
}

handle_error() {
    local error_message="$1"
    json_log "ERROR" "$error_message"
    echo -e "\033[0;31m❌ Error: $error_message\033[0m" >&2
    exit 1
}

log_info() {
    local message="$1"
    json_log "INFO" "$message"
}

log_warn() {
    local message="$1"
    json_log "WARN" "$message"
    echo -e "\033[1;33m⚠️ Warning: $message\033[0m"
}

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        if mkdir -p "$dir"; then
            log_info "Created directory: '$dir'."
        else
            handle_error "Failed to create directory '$dir'."
        fi
    else
        log_info "Directory '$dir' already exists."
    fi
}

attempt_tool_install() {
    local tool="$1"
    local fix_mode="$2"
    if [[ "$fix_mode" == "true" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_warn "No config file found. Cannot install tools without package mapping."
            return
        fi
        local pkg_map
        pkg_map=$(jq -r ".tool_package_map.\"$tool\"" "$CONFIG_FILE" 2>/dev/null || true)
        if [[ "$pkg_map" == "null" || -z "$pkg_map" ]]; then
            log_warn "No package mapping found for $tool. Skipping installation."
            return
        fi
        local PKG_MANAGER
        PKG_MANAGER=$(jq -r '.package_manager' "$CONFIG_FILE" || echo "pacman")
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
                    log_info "$tool installed successfully via Homebrew."
                else
                    log_warn "Failed to install $tool with Homebrew."
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
            default_xdg_data="$HOME/.local/share"
            default_xdg_config="$HOME/.config"
            default_xdg_cache="$HOME/.cache"
            default_xdg_state="$HOME/.local/state"
            default_pkg_manager="pacman"
            default_settings_editor="nano"
            default_user_interface="cli"
            cat > "$CONFIG_FILE" <<EOF
{
  "env": {
    "XDG_DATA_HOME": "$(prompt_config_value "XDG_DATA_HOME" "$default_xdg_data")",
    "XDG_CONFIG_HOME": "$(prompt_config_value "XDG_CONFIG_HOME" "$default_xdg_config")",
    "XDG_CACHE_HOME": "$(prompt_config_value "XDG_CACHE_HOME" "$default_xdg_cache")",
    "XDG_STATE_HOME": "$(prompt_config_value "XDG_STATE_HOME" "$default_xdg_state")",
    "CARGO_HOME": "$(prompt_config_value "CARGO_HOME" "\$XDG_DATA_HOME/cargo")",
    "RUSTUP_HOME": "$(prompt_config_value "RUSTUP_HOME" "\$XDG_DATA_HOME/rustup")",
    "NVM_DIR": "$(prompt_config_value "NVM_DIR" "\$XDG_CONFIG_HOME/nvm")",
    "PSQL_HOME": "$(prompt_config_value "PSQL_HOME" "\$XDG_DATA_HOME/postgresql")",
    "MYSQL_HOME": "$(prompt_config_value "MYSQL_HOME" "\$XDG_DATA_HOME/mysql")",
    "SQLITE_HOME": "$(prompt_config_value "SQLITE_HOME" "\$XDG_DATA_HOME/sqlite")",
    "MESON_HOME": "$(prompt_config_value "MESON_HOME" "\$XDG_DATA_HOME/meson")",
    "GOPATH": "$(prompt_config_value "GOPATH" "\$XDG_DATA_HOME/go")",
    "GOMODCACHE": "$(prompt_config_value "GOMODCACHE" "\$XDG_CACHE_HOME/go/mod")",
    "GOROOT": "$(prompt_config_value "GOROOT" "/usr/lib/go")",
    "VENV_HOME": "$(prompt_config_value "VENV_HOME" "\$XDG_DATA_HOME/python/virtualenvs")",
    "PIPX_HOME": "$(prompt_config_value "PIPX_HOME" "\$XDG_DATA_HOME/python/pipx")",
    "ELECTRON_CACHE": "$(prompt_config_value "ELECTRON_CACHE" "\$XDG_CACHE_HOME/electron")",
    "NODE_DATA_HOME": "$(prompt_config_value "NODE_DATA_HOME" "\$XDG_DATA_HOME/node")",
    "NODE_CONFIG_HOME": "$(prompt_config_value "NODE_CONFIG_HOME" "\$XDG_CONFIG_HOME/node")",
    "SQL_DATA_HOME": "$(prompt_config_value "SQL_DATA_HOME" "\$XDG_DATA_HOME/sql")",
    "SQL_CONFIG_HOME": "$(prompt_config_value "SQL_CONFIG_HOME" "\$XDG_CONFIG_HOME/sql")",
    "SQL_CACHE_HOME": "$(prompt_config_value "SQL_CACHE_HOME" "\$XDG_CACHE_HOME/sql")"
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
  "backup_dir": "$(prompt_config_value "backup_dir" "\$XDG_STATE_HOME/backups")",
  "package_manager": "$(prompt_config_value "package_manager" "$default_pkg_manager")",
  "settings_editor": "$(prompt_config_value "settings_editor" "$default_settings_editor")",
  "user_interface": "$(prompt_config_value "user_interface" "$default_user_interface")",
  "plugins_dir": "$(prompt_config_value "plugins_dir" "\$XDG_CONFIG_HOME/4ndr0service/plugins")",
  "logging": {
    "log_file_dir": "$(prompt_config_value "log_file_dir" "\$XDG_DATA_HOME/logs/4ndr0service/logs")",
    "log_file": "$(prompt_config_value "log_file" "\$XDG_DATA_HOME/logs/4ndr0service/logs/4ndr0service.log")"
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

load_config() {
    create_config_if_missing
    # Ensure jq is installed
    if ! command -v jq &>/dev/null; then
        handle_error "'jq' is required. Please install jq."
    fi
    # Load variables from config.json
    XDG_DATA_HOME=$(jq -r '.env.XDG_DATA_HOME' "$CONFIG_FILE")
    XDG_CONFIG_HOME=$(jq -r '.env.XDG_CONFIG_HOME' "$CONFIG_FILE")
    XDG_CACHE_HOME=$(jq -r '.env.XDG_CACHE_HOME' "$CONFIG_FILE")
    XDG_STATE_HOME=$(jq -r '.env.XDG_STATE_HOME' "$CONFIG_FILE")
    LOG_FILE_DIR=$(jq -r '.logging.log_file_dir' "$CONFIG_FILE")
    LOG_FILE=$(jq -r '.logging.log_file' "$CONFIG_FILE" | sed "s|\$XDG_DATA_HOME|$XDG_DATA_HOME|g")
    CARGO_HOME=$(jq -r '.env.CARGO_HOME' "$CONFIG_FILE")
    RUSTUP_HOME=$(jq -r '.env.RUSTUP_HOME' "$CONFIG_FILE")
    NVM_DIR=$(jq -r '.env.NVM_DIR' "$CONFIG_FILE")
    PSQL_HOME=$(jq -r '.env.PSQL_HOME' "$CONFIG_FILE")
    MYSQL_HOME=$(jq -r '.env.MYSQL_HOME' "$CONFIG_FILE")
    SQLITE_HOME=$(jq -r '.env.SQLITE_HOME' "$CONFIG_FILE")
    MESON_HOME=$(jq -r '.env.MESON_HOME' "$CONFIG_FILE")
    GOPATH=$(jq -r '.env.GOPATH' "$CONFIG_FILE")
    GOMODCACHE=$(jq -r '.env.GOMODCACHE' "$CONFIG_FILE")
    GOROOT=$(jq -r '.env.GOROOT' "$CONFIG_FILE")
    VENV_HOME=$(jq -r '.env.VENV_HOME' "$CONFIG_FILE")
    PIPX_HOME=$(jq -r '.env.PIPX_HOME' "$CONFIG_FILE")
    ELECTRON_CACHE=$(jq -r '.env.ELECTRON_CACHE' "$CONFIG_FILE")
    NODE_DATA_HOME=$(jq -r '.env.NODE_DATA_HOME' "$CONFIG_FILE")
    NODE_CONFIG_HOME=$(jq -r '.env.NODE_CONFIG_HOME' "$CONFIG_FILE")
    SQL_DATA_HOME=$(jq -r '.env.SQL_DATA_HOME' "$CONFIG_FILE")
    SQL_CONFIG_HOME=$(jq -r '.env.SQL_CONFIG_HOME' "$CONFIG_FILE")
    SQL_CACHE_HOME=$(jq -r '.env.SQL_CACHE_HOME' "$CONFIG_FILE")
    backup_dir=$(jq -r '.backup_dir' "$CONFIG_FILE")
    PKG_MANAGER=$(jq -r '.package_manager' "$CONFIG_FILE")
    SETTINGS_EDITOR=$(jq -r '.settings_editor' "$CONFIG_FILE")
    USER_INTERFACE=$(jq -r '.user_interface' "$CONFIG_FILE")
    PLUGINS_DIR=$(jq -r '.plugins_dir' "$CONFIG_FILE")
}

load_config

# Ensure log directory exists
ensure_dir "$LOG_FILE_DIR"
# Ensure backup directory exists
ensure_dir "$backup_dir"
ensure_dir "$PLUGINS_DIR"

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

print_report() {
    echo "========== ENVIRONMENT REPORT =========="
    echo "Environment Variables:"
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "  - $var: NOT SET"
        else
            echo "  - $var: ${!var}"
        fi
    done

    echo
    echo "Directories:"
    for var in "${DIRECTORY_VARS[@]}"; do
        local dir="${!var:-}"
        if [[ -z "$dir" ]]; then
            echo "  - $var: NOT SET, cannot check directory."
        else
            if [[ -d "$dir" ]]; then
                if [[ "$var" == "GOROOT" && "$GOROOT" == "/usr/lib/go" ]]; then
                    echo "  - $var: $dir [EXISTS, NOT WRITABLE - Expected]"
                elif [[ -w "$dir" ]]; then
                    echo "  - $var: $dir [OK]"
                else
                    echo "  - $var: $dir [NOT WRITABLE]"
                fi
            else
                echo "  - $var: $dir [MISSING]"
            fi
        fi
    done

    echo
    echo "Tools:"
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo "  - $tool: FOUND ($(command -v "$tool"))"
        else
            echo "  - $tool: NOT FOUND"
        fi
    done
    echo "========================================"
}

run_core_checks() {
    local report_mode="$1"
    local fix_mode="$2"
    local parallel="$3"
    local checks=(
        "check_env_vars \"$fix_mode\""
        "check_directories \"$fix_mode\""
        "check_tools \"$fix_mode\""
    )
    if [[ "$parallel" == "true" ]]; then
        run_parallel_checks "${checks[@]}"
    else
        for chk in "${checks[@]}"; do
            eval "$chk"
        done
    fi
    if [[ "$report_mode" == "true" ]]; then
        print_report
    fi
}

check_env_vars() {
    local fix_mode="$1"
    local missing_vars=()
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    if (( ${#missing_vars[@]} > 0 )); then
        for mv in "${missing_vars[@]}"; do
            log_warn "Missing environment variable: $mv"
            echo "Missing environment variable: $mv"
        done
    else
        log_info "All required environment variables are set."
    fi
}

check_directories() {
    local fix_mode="$1"
    local any_issue=false
    for var in "${DIRECTORY_VARS[@]}"; do
        local dir="${!var:-}"
        if [[ -z "$dir" ]]; then
            continue
        fi
        if [[ ! -d "$dir" ]]; then
            log_warn "Directory '$dir' for '$var' does not exist."
            echo "Directory for $var: '$dir' does not exist."
            if [[ "$fix_mode" == "true" ]]; then
                if mkdir -p "$dir"; then
                    log_info "Created directory: $dir"
                    echo "Created directory: $dir"
                else
                    log_warn "Failed to create directory: $dir"
                    any_issue=true
                fi
            else
                any_issue=true
            fi
        fi
        if [[ "$var" == "GOROOT" && "$GOROOT" == "/usr/lib/go" ]]; then
            continue
        fi
        if [[ -d "$dir" && ! -w "$dir" ]]; then
            if [[ "$fix_mode" == "true" ]]; then
                if chmod u+w "$dir"; then
                    log_info "Set write permission for $dir"
                    echo "Set write permission for $dir"
                else
                    log_warn "Could not set write permission for $dir"
                    any_issue=true
                fi
            else
                log_warn "Directory '$dir' is not writable."
                any_issue=true
            fi
        fi
    done
    if ! $any_issue; then
        log_info "All required directories are OK."
    fi
}

check_tools() {
    local fix_mode="$1"
    local missing_tools=()
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    if (( ${#missing_tools[@]} > 0 )); then
        for mt in "${missing_tools[@]}"; do
            log_warn "Missing tool: $mt"
            echo "Missing tool: $mt"
            attempt_tool_install "$mt" "$fix_mode"
        done
    else
        log_info "All required tools are present."
    fi
}
