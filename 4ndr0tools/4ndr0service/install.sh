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

# ──────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────
log_info()  { printf "\033[1;32m[INFO]\033[0m  %s\n" "$*"; }
log_warn()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
log_error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"; }

# Wrapper for executing commands with dry-run support
run() {
    local cmd_str
    cmd_str="$(IFS=' '; echo "$*")"
    if [[ "${DRY_RUN}" == "true" ]]; then
        printf "\033[1;34m[DRY-RUN]\033[0m Would run: %s\n" "${cmd_str}"
    else
        printf "\033[1;30m[EXEC]\033[0m %s\n" "${cmd_str}"
        "$@"
    fi
}

normalize_path() {
    local path="$1"
    # Handle home directory tilde expansion manually if shell didn't
    if [[ "$path" == "~"* ]]; then
        path="${HOME}${path#~}"
    fi
    # Resolve to absolute path
    if [[ "$path" != /* ]]; then
        path="$(cd "$(pwd)" && pwd -P)/$path"
    fi
    # Remove trailing slashes and ensure it's absolute
    path="$(readlink -f "$path" 2>/dev/null || echo "$path")"
    echo "${path%/}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run  Show what would be done without making any changes.
  -h, --help     Show this help message.

EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ──────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────────────
# MAIN INSTALL LOGIC
# ──────────────────────────────────────────────────────────────────────────────

# 1. Prompt for installation location
printf "\033[1;36m[PROMPT]\033[0m Install location [default: %s]: " "${DEFAULT_INSTALL_LOCATION}"
read -r USER_INPUT
INSTALL_LOCATION=$(normalize_path "${USER_INPUT:-$DEFAULT_INSTALL_LOCATION}")

log_info "Source directory: ${SOURCE_DIR}"
log_info "Install location: ${INSTALL_LOCATION}"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Running in DRY-RUN mode. No changes will be persisted."
fi

# 2. Sync files if source and destination differ
if [[ "${SOURCE_DIR}" != "${INSTALL_LOCATION}" ]]; then
    log_info "Synchronizing files to ${INSTALL_LOCATION}..."
    
    # Ensure parent directory exists (requires sudo if in /opt)
    PARENT_DIR="$(dirname "${INSTALL_LOCATION}")"
    if [[ ! -d "${PARENT_DIR}" ]]; then
        run sudo mkdir -p "${PARENT_DIR}"
    fi

    # Create target directory
    if [[ ! -d "${INSTALL_LOCATION}" ]]; then
        run sudo mkdir -p "${INSTALL_LOCATION}"
    fi

    # Ownership if we just created it with sudo
    # run sudo chown "${USER}:${USER}" "${INSTALL_LOCATION}"

    # Use rsync if available for better exclusion, otherwise cp
    if command -v rsync &>/dev/null; then
        run sudo rsync -av --progress \
            --exclude '.git/' \
            --exclude '__pycache__/' \
            --exclude '*.bak' \
            --exclude '.gemini/' \
            --exclude '.github/' \
            "${SOURCE_DIR}/" "${INSTALL_LOCATION}/"
    else
        log_warn "rsync not found, falling back to cp (less efficient)..."
        run sudo cp -rv "${SOURCE_DIR}/"* "${INSTALL_LOCATION}/"
        # Note: manual exclusion with cp is harder, we'll stick to basic copy if rsync is missing
    fi
fi

# 3. Ensure bin directory exists
if [[ ! -d "${BIN_DIR}" ]]; then
    run mkdir -p "${BIN_DIR}"
fi

# 4. Make scripts executable in INSTALL_LOCATION
log_info "Setting executable permissions on scripts..."
# Use find to locate .sh files and chmod them
# Note: we use sudo because INSTALL_LOCATION might be root-owned
run sudo find "${INSTALL_LOCATION}" -type f -name "*.sh" -exec chmod +x {} +

# 5. Create symlink
log_info "Creating symlink: ${SYMLINK_PATH} -> ${INSTALL_LOCATION}/main.sh"
if [[ -L "${SYMLINK_PATH}" || -e "${SYMLINK_PATH}" ]]; then
    run rm -rf "${SYMLINK_PATH}"
fi
run ln -s "${INSTALL_LOCATION}/main.sh" "${SYMLINK_PATH}"

# 6. Check for jq (critical dependency)
if ! command -v jq &>/dev/null; then
    log_warn "jq not found. It is required for configuration management."
    if command -v pacman &>/dev/null; then
        log_info "Detected pacman. Installing jq..."
        run sudo pacman -S --noconfirm jq
    else
        log_error "Please install 'jq' manually."
    fi
else
    log_info "Dependency 'jq' is already installed."
fi

# 7. Initialize Suite
log_info "Initializing suite..."
# Run main.sh --report from the install location
run "${INSTALL_LOCATION}/main.sh" --report || log_warn "Initial report returned non-zero exit code."

log_info "Installation complete!"
if [[ "${DRY_RUN}" == "false" ]]; then
    log_info "You can now run '4ndr0service' from your terminal (ensure ${BIN_DIR} is in your PATH)."
fi