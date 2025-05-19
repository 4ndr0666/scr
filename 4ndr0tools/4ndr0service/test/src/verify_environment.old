#!/usr/bin/env bash
# File: verify_environment.sh
# Verifies/fixes environment for 4ndr0service Suite.
# Usage: verify_environment.sh [--report] [--fix]
set -euo pipefail
IFS=$'\n\t'

# Set PKG_PATH to three levels up from this script's directory.
: "${PKG_PATH:=$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")}"

# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.local/share/4ndr0service/config.json}"

# Set defaults for mode flags and export them.
FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"
export FIX_MODE REPORT_MODE

# Safely load arrays from the JSON config.
mapfile -t REQUIRED_ENV_VARS < <(jq -r '.required_env[]' "$CONFIG_FILE")
mapfile -t DIRECTORY_VARS   < <(jq -r '.directory_vars[]' "$CONFIG_FILE")
mapfile -t REQUIRED_TOOLS   < <(jq -r '.tools[]' "$CONFIG_FILE")

# --- Override: Skip checking GOROOT ---
# In our automation, we are not using GOROOT; skip it.
check_env_vars() {
    local fix_mode="$1"
    local missing_vars=()
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [[ "$var" == "GOROOT" ]]; then
            continue
        fi
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
        if [[ "$var" == "GOROOT" ]]; then
            continue
        fi
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
    done
    if ! $any_issue; then
        log_info "All required directories are OK."
    fi
}

# --- Override attempt_tool_install for specific tools ---
# We override this function to automatically install missing tools via pacman.
attempt_tool_install() {
    local tool="$1"
    local fix_mode="$2"
    case "$tool" in
        psql)
            echo "Attempting to install psql via pacman..."
            if sudo pacman -S --needed --noconfirm postgresql; then
                log_info "psql installed successfully via pacman."
            else
                log_warn "Failed to install psql via pacman."
            fi
            ;;
        go)
            echo "Attempting to install go via pacman..."
            if sudo pacman -S --needed --noconfirm go; then
                log_info "go installed successfully via pacman."
            else
                log_warn "Failed to install go via pacman."
            fi
            ;;
        *)
            # Fallback: use the original attempt_tool_install from common.sh, if available.
            if declare -f original_attempt_tool_install &>/dev/null; then
                original_attempt_tool_install "$tool" "$fix_mode"
            else
                log_warn "No installation procedure defined for $tool."
            fi
            ;;
    esac
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
        if [[ "$var" == "GOROOT" ]]; then
            continue
        fi
        if [[ -z "${!var:-}" ]]; then
            echo "  - $var: NOT SET"
        else
            echo "  - $var: ${!var}"
        fi
    done

    echo
    echo "Directories:"
    for var in "${DIRECTORY_VARS[@]}"; do
        if [[ "$var" == "GOROOT" ]]; then
            continue
        fi
        local dir="${!var:-}"
        if [[ -z "$dir" ]]; then
            echo "  - $var: NOT SET, cannot check directory."
        else
            if [[ -d "$dir" ]]; then
                if [[ -w "$dir" ]]; then
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
    echo "- For missing tools, ensure your config file contains a valid package mapping."
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
