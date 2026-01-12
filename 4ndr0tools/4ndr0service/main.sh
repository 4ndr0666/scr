#!/usr/bin/env bash
# File: main.sh
# Optimized entry point — hardened argument parsing, mode flags, core orchestration

set -euo pipefail
IFS=$'\n\t'

# ──────────────────────────────────────────────────────────────────────────────
# CANONICAL PKG_PATH — EMBEDDED BY INSTALL.SH
# ──────────────────────────────────────────────────────────────────────────────
PKG_PATH="/opt/4ndr0service"
export PKG_PATH

# ──────────────────────────────────────────────────────────────────────────────
# SOURCE COMMON (now the single source of truth)
# ──────────────────────────────────────────────────────────────────────────────
source "$PKG_PATH/common.sh"
source "$PKG_PATH/controller.sh"

# ──────────────────────────────────────────────────────────────────────────────
# HELP & USAGE
# ──────────────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
4ndr0service Suite — Self-Healing Dev Environment Orchestrator

Usage: 4ndr0service [OPTIONS]

Options:
  --help       Show this help message
  --report     Generate verification report only
  --fix        Attempt automatic fixes where possible
  --parallel   Run independent services/checks in parallel
  --test       Run smoke tests + full verification (non-destructive)
  --dry-run    Simulate actions without making changes

Examples:
  4ndr0service --report --fix
  4ndr0service --parallel
  4ndr0service --test

EOF
    exit 0
}

# ──────────────────────────────────────────────────────────────────────────────
# FLAG PARSING
# ──────────────────────────────────────────────────────────────────────────────
report_mode=false
fix_mode=false
parallel_mode=false
test_mode=false
dry_run=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)     show_help ;;
        --report)   report_mode=true ;;
        --fix)      fix_mode=true ;;
        --parallel) parallel_mode=true ;;
        --test)     test_mode=true ;;
        --dry-run)  dry_run=true ;;
        *)          log_warn "Unknown option: $1" && exit 1 ;;
    esac
    shift
done

export FIX_MODE="$fix_mode"
export REPORT_MODE="$report_mode"
export DRY_RUN="$dry_run"

# ──────────────────────────────────────────────────────────────────────────────
# CORE LOGIC
# ──────────────────────────────────────────────────────────────────────────────
run_core_checks() {
    local report="$1" fix="$2" par="$3"

    create_config_if_missing
    load_config

    if [[ "$fix" == "true" || "$report" == "true" ]]; then
        run_verification
    elif [[ "$par" == "true" ]]; then
        run_parallel_services
    else
        run_all_services
    fi
}

if [[ "$test_mode" == "true" ]]; then
    log_info "Running smoke test + full verification..."
    run_core_checks true false false
    log_info "Smoke test complete. Check logs above for details."
    exit 0
elif [[ $# -gt 0 || "$report_mode" == "true" || "$fix_mode" == "true" || "$parallel_mode" == "true" ]]; then
    run_core_checks "$report_mode" "$fix_mode" "$parallel_mode"
else
    main_controller
fi
