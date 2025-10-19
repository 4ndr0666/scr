#!/usr/bin/env bash
# File: optimize_python.sh
# Production-grade Python toolchain bootstrapper for 4ndr0service

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh

optimize_python_service() {
	# Initialize pyenv for the current shell session
			if command -v pyenv &>/dev/null; then
				local PYENV_ROOT_VAL
				PYENV_ROOT_VAL="$(pyenv root)"
	
				if [[ ! -d "$PYENV_ROOT_VAL/plugins/pyenv-virtualenv" ]]; then
					log_info "pyenv-virtualenv plugin not found. Installing..."
					git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT_VAL/plugins/pyenv-virtualenv" || log_warn "Failed to install pyenv-virtualenv plugin."
				fi
	
				eval "$(pyenv init -)"
				eval "$(pyenv virtualenv-init -)"
			fi
	create_config_if_missing
	local PY_VERSION
	PY_VERSION=$(jq -r '.python_version' "$CONFIG_FILE")
	local -a TOOLS
	mapfile -t TOOLS < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE")

	log_info "Checking if Python is installed..."
	if command -v python3 &>/dev/null; then
		local py_version
		py_version="$(python3 --version 2>/dev/null || echo 'Unknown')"
		log_info "Python is already installed: $py_version"
	else
		log_warn "Python not found."
		if command -v pyenv &>/dev/null; then
			log_info "Using pyenv to install Python $PY_VERSION..."
			pyenv install -s "$PY_VERSION" || log_warn "pyenv install failed."
			pyenv global "$PY_VERSION" || log_warn "could not set pyenv global version."
			pyenv rehash || true
			if command -v python3 &>/dev/null; then
				log_info "Installed Python $PY_VERSION via pyenv."
			else
																log_warn "Python still not available. Please install a Python version via pyenv."
																return 1
															fi
														else
															handle_error "Python not found and pyenv not installed. Please install pyenv or python3 manually."
														fi
													fi
												
													# Use pyenv exec pip as canonical pip command.
													local pip_cmd="pyenv exec pip"
												
													log_info "Ensuring pipx is installed..."
													if command -v pipx &>/dev/null; then
														log_info "pipx is already installed."
													else
														$pip_cmd install --user pipx || log_warn "Warning: pipx installation failed."
														if command -v pipx &>/dev/null; then
															log_info "pipx installed successfully."
														fi
													fi
	log_info "Installing/updating base Python tools via pipx..."
	for tool in "${TOOLS[@]}"; do
		if ! pipx list | grep -q "${tool}"; then
			log_info "Installing $tool with pipx..."
			pipx install "$tool" || log_warn "Warning: Failed to install $tool via pipx."
		else
			log_info "$tool found; upgrading with pipx..."
			pipx upgrade "$tool" || log_warn "Warning: Failed to upgrade $tool via pipx."
		fi
	done

	log_info "Python environment setup complete."
}

# If run as a script, execute the optimization
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	optimize_python_service
fi
