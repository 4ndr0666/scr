#!/usr/bin/env bash
# File: settings_functions.sh
# Description: Functions to modify/manage settings for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh

modify_settings() {
	local editor
	editor=$(jq -r '.settings_editor' "$CONFIG_FILE" || echo "vim")
	if [[ -z "$editor" || ! $(command -v "$editor") ]]; then
		editor="vim"
	fi
	"$editor" "$CONFIG_FILE"
	log_info "Settings modified with $editor."
}

fallback_editor() {
	select editor in "vim" "nano" "emacs" "micro" "lite-xl" "Exit"; do
		case $REPLY in
		1) vim "$CONFIG_FILE" && break ;;
		2) nano "$CONFIG_FILE" && break ;;
		3) emacs "$CONFIG_FILE" && break ;;
		4) micro "$CONFIG_FILE" && break ;;
		5) lite-xl "$CONFIG_FILE" && break ;;
		6) break ;;
		*) echo "Invalid selection." ;;
		esac
	done
}

# Create default configuration file if missing
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
  "audit_keywords": ["config_watch", "data_watch", "cache_watch"],
  "tool_install_commands": {
    "psql": {
      "yay": "yay -S --noconfirm postgresql",
      "pacman": "sudo pacman -S --needed --noconfirm postgresql"
    }
  }
}
EOF
		log_info "Created default config at $CONFIG_FILE"
	fi
}

# Ensure configuration file is present
load_config() {
	if [[ ! -f "$CONFIG_FILE" ]]; then
		handle_error "Config file not found at $CONFIG_FILE"
	fi
}

# Prompt user for a configuration value and persist it
prompt_config_value() {
	local key="$1"
	local default="$2"
	local val
	read -rp "Enter value for $key [$default]: " val
	val="${val:-$default}"
	local tmp
	tmp="$(mktemp)"
	jq --arg key "$key" --arg val "$val" '.[$key]=$val' "$CONFIG_FILE" >"$tmp" && mv "$tmp" "$CONFIG_FILE"
	log_info "Set $key to $val in $CONFIG_FILE"
}
