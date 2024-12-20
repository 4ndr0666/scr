#!/usr/bin/env bash
# File: plugins/sample_check.sh
# Description: Sample plugin for additional environment checks.

set -euo pipefail
IFS=$'\n\t'

sample_check() {
    if [[ -d "$HOME/.sample_dir" ]]; then
        echo "Sample directory exists."
        log_info "Sample directory exists."
    else
        echo "Sample directory does not exist."
        log_warn "Sample directory does not exist."
    fi
}

sample_check
