#!/usr/bin/env bash
# File: service/optimize_ruby.sh
# Optimized — retry, dry-run

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_ruby_service() {
    log_info "Optimizing Ruby environment..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    command -v ruby >/dev/null 2>&1 || retry sudo pacman -Syu --needed ruby

    export GEM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/gem"
    export PATH="$GEM_HOME/bin:$PATH"

    ensure_dir "$GEM_HOME"
    check_directory_writable "$GEM_HOME"

    mapfile -t GEMS < <(safe_jq_array "ruby_gems" "$CONFIG_FILE")

    for gem in "${GEMS[@]}"; do
        [[ -z "$gem" ]] && continue
        if gem list -i "$gem" >/dev/null 2>&1; then
            log_info "Updating $gem..."
            retry gem update "$gem"
        else
            log_info "Installing $gem..."
            retry gem install --user-install "$gem"
        fi
    done

    log_info "Ruby optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_ruby_service
