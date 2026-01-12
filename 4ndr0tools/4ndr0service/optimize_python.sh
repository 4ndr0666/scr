#!/usr/bin/env bash
# File: service/optimize_python.sh
# Optimized — retry, dry-run, safe jq

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_python_service() {
    log_info "Optimizing Python environment..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    if command -v pyenv >/dev/null 2>&1; then
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"

        if [[ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]]; then
            retry git clone https://github.com/pyenv/pyenv-virtualenv.git \
                "$PYENV_ROOT/plugins/pyenv-virtualenv"
        fi
    fi

    local py_version
    py_version=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")

    if ! command -v python3 >/dev/null 2>&1; then
        log_info "Installing Python $py_version via pyenv..."
        retry pyenv install -s "$py_version"
        retry pyenv global "$py_version"
        retry pyenv rehash
    fi

    mapfile -t TOOLS < <(safe_jq_array "python_tools" "$CONFIG_FILE")

    for tool in "${TOOLS[@]}"; do
        [[ -z "$tool" ]] && continue
        if pipx list | grep -q "$tool"; then
            log_info "Upgrading $tool..."
            retry pipx upgrade "$tool"
        else
            log_info "Installing $tool..."
            retry pipx install "$tool"
        fi
    done

    log_info "Python optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_python_service
