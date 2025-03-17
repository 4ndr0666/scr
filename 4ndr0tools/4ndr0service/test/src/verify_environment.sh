#!/usr/bin/env bash
# File: verify_environment.sh
# Verifies/fixes environment for 4ndr0service Suite.
# Usage: verify_environment.sh [--report] [--fix]
set -euo pipefail
IFS=$'\n\t'

# Ensure PKG_PATH is defined (fallback: directory of this script)
: "${PKG_PATH:=$(dirname "$(realpath "$0")")}"

# Use environment variables if already set; otherwise, parse command-line arguments.
FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"

if [[ "$#" -gt 0 ]]; then
    for arg in "$@"; do
        case "$arg" in
            --help)
                echo "Usage: $0 [--help] [--report] [--fix]"
                exit 0
                ;;
            --report)
                REPORT_MODE="true"
                ;;
            --fix)
                FIX_MODE="true"
                ;;
            *)
                echo "Unknown argument: $arg"
                exit 1
                ;;
        esac
    done
fi

source "$PKG_PATH/common.sh"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.local/share/4ndr0service/config.json}"

REQUIRED_ENV_VARS=($(jq -r '.required_env[]' "$CONFIG_FILE"))
DIRECTORY_VARS=($(jq -r '.directory_vars[]' "$CONFIG_FILE"))
REQUIRED_TOOLS=($(jq -r '.tools[]' "$CONFIG_FILE"))

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
        if [[ "$var" != "GOROOT" ]]; then
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
    echo
    echo "----- Recommendations -----"
    echo "- For any missing tools, ensure your config file contains a valid package mapping."
    echo "- If directories or environment variables are missing, run with the --fix flag."
    echo "- Review the report above for any items marked as NOT SET or NOT WRITABLE."
    echo "=============================="
}

main() {
    echo "Verifying environment alignment..."
    log_info "Starting environment verification..."

    check_env_vars "$FIX_MODE"
    check_directories "$FIX_MODE"
    check_tools "$FIX_MODE"

    echo "Verification complete."
    log_info "Verification complete."

    if [[ "$REPORT_MODE" == "true" ]]; then
        print_report
    fi
    echo "Done."
}

main
