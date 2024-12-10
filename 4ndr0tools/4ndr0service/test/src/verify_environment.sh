#!/bin/bash
# File: verify_environment.sh
# Author: 4ndr0666
# Date: 2024-12-06
## Desc: Verifies XDG specifications for system paths, environment variables, directories, and required tools.
## Offers report mode and fix mode. If run with --fix, attempts to create missing directories.
## If run with --report, prints a summary report of checks.

set -euo pipefail
IFS=$'\n\t'

# ================================== // VERIFY_ENVIRONMENT.SH //
# --- // Constants:
REQUIRED_ENV_VARS=(
    "XDG_DATA_HOME"
    "XDG_CONFIG_HOME"
    "XDG_CACHE_HOME"
    "LOG_FILE"
    "CARGO_HOME"
    "RUSTUP_HOME"
    "NVM_DIR"
    "PSQL_HOME"
    "MYSQL_HOME"
    "SQLITE_HOME"
    "MESON_HOME"
#    "GOPATH"
    "GOMODCACHE"
    "GOROOT"
    "VENV_HOME"
    "PIPX_HOME"
    "ELECTRON_CACHE"
    "NODE_DATA_HOME"
    "NODE_CONFIG_HOME"
    "SQL_DATA_HOME"
    "SQL_CONFIG_HOME"
    "SQL_CACHE_HOME"
)

# --- // Deps:
REQUIRED_TOOLS=(
    "cargo"
    "npm"
    "pipx"
    "rustup"
    "psql"
    "mysql"
    "sqlite3"
    "electron"
    "meson"
    "ninja"
    "python3"
    "go"
    "node"
)

# --- // Logging:
LOG_FILE="${LOG_FILE:-$HOME/.local/share/logs/4ndr0service/logs/service_optimization.log}"
log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "\033[0;31m❌ Error: $error_message\033[0m" >&2
    log "ERROR: $error_message"
    exit 1
}

# --- // Dirs:
DIRECTORY_VARS=(
    "XDG_DATA_HOME"
    "XDG_CONFIG_HOME"
    "XDG_CACHE_HOME"
    "CARGO_HOME"
    "RUSTUP_HOME"
    "NVM_DIR"
    "PSQL_HOME"
    "MYSQL_HOME"
    "SQLITE_HOME"
    "MESON_HOME"
    "GOPATH"
    "GOMODCACHE"
    "GOROOT"
    "VENV_HOME"
    "PIPX_HOME"
    "ELECTRON_CACHE"
    "NODE_DATA_HOME"
    "NODE_CONFIG_HOME"
    "SQL_DATA_HOME"
    "SQL_CONFIG_HOME"
    "SQL_CACHE_HOME"
)

# --- // CLI:
REPORT_MODE="false"
FIX_MODE="false"

for arg in "$@"; do
    case "$arg" in
        --help)
            echo "Usage: $0 [--help] [--report] [--fix]"
            echo "  --help    Show this help message."
            echo "  --report  Print a summary report of checks."
            echo "  --fix     Attempt to fix issues (e.g., create missing directories)."
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

# --- // Check_env:
check_env_vars() {
    local missing_vars=()
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if (( ${#missing_vars[@]} > 0 )); then
        echo "The following required environment variables are not set:"
        for mv in "${missing_vars[@]}"; do
            echo "  - $mv"
            log "Missing environment variable: $mv"
        done
        # Not necessarily fatal; user might want to fix them or rely on defaults.
    else
        echo "All required environment variables are set."
        log "All required environment variables are set."
    fi
}

# --- // Check_dirs:
check_directories() {
    local issues_found="false"
    for var in "${DIRECTORY_VARS[@]}"; do
        local dir="${!var:-}"
        if [[ -z "$dir" ]]; then
            # If var not set, skip directory check
            continue
        fi
        if [[ ! -d "$dir" ]]; then
            echo "Directory for $var: '$dir' does not exist."
            log "Directory '$dir' for '$var' does not exist."
            if [[ "$FIX_MODE" == "true" ]]; then
                echo "Attempting to create directory '$dir'..."
                if mkdir -p "$dir"; then
                    echo "Created directory: $dir"
                    log "Created directory '$dir'."
                else
                    echo "Warning: Failed to create directory '$dir'."
                    log "Warning: Failed to create directory '$dir'."
                    issues_found="true"
                fi
            else
                issues_found="true"
            fi
        fi

        # Exclude GOROOT from writable checks if it's set to a system directory
        if [[ "$var" == "GOROOT" && "$GOROOT" == "/usr/lib/go" ]]; then
            # Typically, /usr/lib/go should not be writable by regular users
            continue
        fi

        # Check if writable
        if [[ -d "$dir" && ! -w "$dir" ]]; then
            echo "Directory '$dir' is not writable."
            log "Directory '$dir' is not writable."
            issues_found="true"
        fi
    done

    if [[ "$issues_found" == "false" ]]; then
        echo "All required directories exist and are writable (or not applicable)."
        log "All required directories are OK."
    fi
}

# --- // Check_tools:
check_tools() {
    local missing_tools=()
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if (( ${#missing_tools[@]} > 0 )); then
        echo "The following required tools are missing from PATH:"
        for mt in "${missing_tools[@]}"; do
            echo "  - $mt"
            log "Missing tool: $mt"
        done
        # Not necessarily fatal, user might want to install them.
    else
        echo "All required tools are present in PATH."
        log "All required tools are present."
    fi
}

# --- // Report:
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
    echo "========================================"
}

# --- // Main_entry_point:
main() {
    echo "Verifying environment alignment..."
    log "Starting environment verification..."

    check_env_vars
    check_directories
    check_tools

    echo "Verification complete."
    log "Environment verification complete."

    if [[ "$REPORT_MODE" == "true" ]]; then
        print_report
    fi

    echo "Done."
}
main
