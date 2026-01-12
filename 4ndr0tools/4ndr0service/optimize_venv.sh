#!/usr/bin/env bash
# File: service/optimize_venv.sh
# Optimized — retry, dry-run, configurable venv name

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_venv_service() {
    log_info "Optimizing Python venv + pipx..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    command -v python3 >/dev/null 2>&1 || handle_error "python3 not found"

    local venv_name
    venv_name=$(jq -r '.venv_name // ".venv"' "$CONFIG_FILE")

    export VENV_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv"
    local venv_path="$VENV_HOME/$venv_name"

    ensure_dir "$VENV_HOME"
    if [[ ! -d "$venv_path" ]]; then
        log_info "Creating venv at $venv_path..."
        retry python3 -m venv "$venv_path"
    fi

    # shellcheck disable=SC1091
    source "$venv_path/bin/activate" || handle_error "Failed activating venv"

    retry pip install --upgrade pip

    mapfile -t PKGS < <(safe_jq_array "venv_pipx_packages" "$CONFIG_FILE")

    for pkg in "${PKGS[@]}"; do
        [[ -z "$pkg" ]] && continue
        if pipx list | grep -q "$pkg"; then
            log_info "Upgrading $pkg..."
            retry pipx upgrade "$pkg"
        else
            log_info "Installing $pkg..."
            retry pipx install "$pkg"
        fi
    done

    check_directory_writable "$venv_path"
    log_info "venv optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_venv_service
