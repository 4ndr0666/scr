#!/usr/bin/env bash
# File: service/optimize_go.sh
# Optimized — retry, dry-run, simplified

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_go_service() {
    log_info "Optimizing Go environment..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    if ! command -v go >/dev/null 2>&1; then
        log_info "Installing Go via pacman..."
        retry sudo pacman -Syu --needed go
    fi

    export GOPATH="${XDG_DATA_HOME:-$HOME/.local/share}/go"
    export GOBIN="$GOPATH/bin"
    export PATH="$GOBIN:$PATH"

    ensure_dir "$GOPATH" "$GOBIN"
    check_directory_writable "$GOPATH" "$GOBIN"

    mapfile -t TOOLS < <(safe_jq_array "go_tools" "$CONFIG_FILE")

    for tool in "${TOOLS[@]}"; do
        [[ -z "$tool" ]] && continue
        log_info "Installing/updating $tool..."
        retry go install "$tool"
    done

    log_info "Go optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_go_service
