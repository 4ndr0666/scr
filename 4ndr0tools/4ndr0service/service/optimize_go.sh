#!/usr/bin/env bash
# File: service/optimize_go.sh
# Description: Go environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

optimize_go_service() {
    log_info "Optimizing Go environment..."
    
    # 1. Install Go
    if ! command -v go &>/dev/null; then
        install_sys_pkg "go" || handle_error "$LINENO" "Failed to install Go."
    fi

    # 2. Setup XDG Paths
    export GOPATH="${XDG_DATA_HOME}/go"
    export GOMODCACHE="${XDG_CACHE_HOME}/go/pkg/mod"
    path_prepend "${GOPATH}/bin"

    ensure_dir "${GOPATH}/bin"
    ensure_dir "${GOMODCACHE}"

    # 3. Install Tools from Config
    local -a tools
    mapfile -t tools < <(jq -r '(.go_tools // [])[]' "$CONFIG_FILE")
    
    if [[ ${#tools[@]} -gt 0 ]]; then
        log_info "Installing/Updating Go tools..."
        for tool in "${tools[@]}"; do
            log_info "Processing $tool..."
            go install "$tool" || log_warn "Failed to install $tool"
        done
    fi

    # 4. Cleanup
    log_info "Cleaning Go build cache..."
    go clean -cache || true

    log_success "Go optimization complete. Version: $(go version | awk '{print $3}')"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_go_service
fi