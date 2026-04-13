#!/usr/bin/env bash
# File: install.sh
# Description: Professional installer for 4ndr0service Suite.
# Features: Dry-run mode, custom install location, dependency check, and idempotency.

set -euo pipefail
IFS=$'\n\t'

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION & GLOBAL VARIABLES
# ──────────────────────────────────────────────────────────────────────────────
SOURCE_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
DEFAULT_INSTALL_LOCATION="/opt/4ndr0service"
BIN_DIR="${HOME}/.local/bin"
SYMLINK_PATH="${BIN_DIR}/4ndr0service"
DRY_RUN=false
UNINSTALL=false

# ──────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────
log_info() { printf "\033[1;32m[INFO]\033[0m  %s\n" "$*"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
log_error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"; }
log_scorch() { printf "\033[1;35m[SCORCH]\033[0m %s\n" "$*"; }

# Wrapper for executing commands with dry-run support
run() {
    local cmd_str="$(IFS=' '; echo "$*")"
    if [[ "${DRY_RUN}" == "true" ]]; then
        printf "\033[1;34m[DRY-RUN]\033[0m Would run: %s\n" "${cmd_str}"
    else
        printf "\033[1;30m[EXEC]\033[0m %s\n" "${cmd_str}"
        "$@"
    fi
}

normalize_path() {
    local path="$1"
    if [[ "$path" == "~"* ]]; then path="${HOME}${path#~}"; fi
    if [[ "$path" != /* ]]; then path="$(cd "$(pwd)" && pwd -P)/$path"; fi
    path="$(readlink -f "$path" 2>/dev/null || echo "$path")"
    echo "${path%/}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run    Show what would be done without making any changes.
  -u, --uninstall  Initiate scorch protocol; completely tear down the framework.
  -h, --help       Show this help message.

EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ──────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
    -n | --dry-run)   DRY_RUN=true; shift ;;
    -u | --uninstall) UNINSTALL=true; shift ;;
    -h | --help)      usage; exit 0 ;;
    *)                log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────────────
# MAIN INSTALL LOGIC
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${UNINSTALL}" == "true" ]]; then
    log_info "Initiating Scorch Protocol. Tearing down 4ndr0service..."
    
    if [[ -L "${SYMLINK_PATH}" || -e "${SYMLINK_PATH}" ]]; then
        run rm -f "${SYMLINK_PATH}"
        log_scorch "Severed Symlink: ${SYMLINK_PATH}"
    fi

    if [[ -d "${DEFAULT_INSTALL_LOCATION}" ]]; then
        # Safety check to ensure we don't accidentally wipe /opt or /usr
        if [[ "${DEFAULT_INSTALL_LOCATION}" == "/opt/4ndr0service" ]]; then
            run sudo rm -rf "${DEFAULT_INSTALL_LOCATION}"
            log_scorch "Annihilated Matrix: ${DEFAULT_INSTALL_LOCATION}"
        else
            log_warn "Custom install location detected. Manual purge required for: ${DEFAULT_INSTALL_LOCATION}"
        fi
    fi

    # Wipe root lockfiles to prevent ghost locks
    run sudo rm -f /tmp/4ndr0service_*.lock
    
    log_info "Teardown complete. Zero traces remain."
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# INSTALLATION PROTOCOL
# ──────────────────────────────────────────────────────────────────────────────
printf "\033[1;36m[PROMPT]\033[0m Install location [default: %s]: " "${DEFAULT_INSTALL_LOCATION}"
read -r USER_INPUT
INSTALL_LOCATION=$(normalize_path "${USER_INPUT:-$DEFAULT_INSTALL_LOCATION}")

log_info "Source directory: ${SOURCE_DIR}"
log_info "Target matrix: ${INSTALL_LOCATION}"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Running in DRY-RUN mode. Simulation only."
fi

# 2. Sync files if source and destination differ
if [[ "${SOURCE_DIR}" != "${INSTALL_LOCATION}" ]]; then
    log_info "Synchronizing architecture. Enforcing perfect mirror..."

    # Ensure parent directory exists (requires sudo if in /opt)
    PARENT_DIR="$(dirname "${INSTALL_LOCATION}")"
    if [[ ! -d "${PARENT_DIR}" ]]; then
        run sudo mkdir -p "${PARENT_DIR}"
    fi

    # Create target directory
    if [[ ! -d "${INSTALL_LOCATION}" ]]; then
        run sudo mkdir -p "${INSTALL_LOCATION}"
    fi

    # [4NDR0666OS OVERRIDE]: Absolute Mirror Enforcement
    if command -v rsync &>/dev/null; then
        # --delete ensures destination exactly matches source (removes sample_check.sh)
        run sudo rsync -av --delete --progress \
            --exclude '.git/' \
            --exclude '__pycache__/' \
            --exclude '*.bak' \
            --exclude '.gemini/' \
            --exclude '.github/' \
            "${SOURCE_DIR}/" "${INSTALL_LOCATION}/"
    else
        log_warn "rsync missing. Falling back to cp. Annihilating destination for perfect mirror..."
        if [[ "${DRY_RUN}" == "false" ]]; then
            # We wipe the inner contents, not the folder itself, to preserve mounts/symlinks if any
            sudo find "${INSTALL_LOCATION}" -mindepth 1 -delete
        fi
        run sudo cp -r "${SOURCE_DIR}/"* "${INSTALL_LOCATION}/"
    fi
fi

# 3. Ensure bin directory exists
if [[ ! -d "${BIN_DIR}" ]]; then
    run mkdir -p "${BIN_DIR}"
fi

log_info "Enforcing execution permissions on all payloads..."
run sudo find "${INSTALL_LOCATION}" -type f -name "*.sh" -exec chmod +x {} +

# 3. Establish Invocation Symlink
log_info "Establishing neural link: ${SYMLINK_PATH} -> ${INSTALL_LOCATION}/main.sh"
if [[ -L "${SYMLINK_PATH}" || -e "${SYMLINK_PATH}" ]]; then
    run rm -rf "${SYMLINK_PATH}"
fi
run ln -s "${INSTALL_LOCATION}/main.sh" "${SYMLINK_PATH}"

# 4. Dependency Gate
if ! command -v jq &>/dev/null; then
    log_warn "jq not found. Framework JSON parsing will fail."
    if command -v pacman &>/dev/null; then
        log_info "Triggering pacman dependency resolution..."
        run sudo pacman -S --noconfirm jq
    else
        log_error "Please install 'jq' manually."
    fi
else
    log_info "Dependency 'jq' verified."
fi

# 5. Initialization Check
log_info "Initializing suite..."
# Run main.sh --report from the install location
run "${INSTALL_LOCATION}/main.sh" --report || log_warn "Initial report returned non-zero exit code."

log_info "Deployment absolute. The 4ndr0service is perfectly synchronized."
if [[ "${DRY_RUN}" == "false" ]]; then
    log_info "You can now run '4ndr0service' from your terminal (ensure ${BIN_DIR} is in your PATH)."
fi
