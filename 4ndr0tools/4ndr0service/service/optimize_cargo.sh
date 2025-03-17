#!/usr/bin/env bash
# File: optimize_cargo.sh
# Optimizes Cargo environment in alignment with XDG Base Directory Specs.

# ==================== // 4ndr0service optimize_cargo.sh //
### Debugging
set -euo pipefail
IFS=$'\n\t'

### Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

### Logging
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory." >&2; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

# --- // Check if directory is writable
check_directory_writable() {
    local dir_path="$1"
    if [[ ! -w "$dir_path" ]]; then
        handle_error "Directory $dir_path is not writable."
    else
        echo -e "${CYAN}✅ Directory $dir_path is writable.${NC}"
        log "Directory '$dir_path' is writable."
    fi
}

export CARGO_HOME="${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/rustup}"

install_rustup() {
    echo -e "${CYAN}📦 Installing rustup...${NC}"
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
        echo -e "${CYAN}✅ rustup installed successfully.${NC}"
        log "rustup installed successfully."
    else
        handle_error "Failed to install rustup."
    fi
    [ -s "$CARGO_HOME/env" ] && source "$CARGO_HOME/env" || handle_error "Failed to source Rustup environment."
}

update_rustup_and_cargo() {
    echo -e "${CYAN}🔄 Updating rustup and Cargo toolchain...${NC}"
    if rustup self update > /dev/null 2>&1; then
        if rustup update stable > /dev/null 2>&1; then
            echo -e "${CYAN}✅ rustup and Cargo updated successfully.${NC}"
            log "rustup and Cargo updated successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to update Cargo.${NC}"
            log "Warning: Failed to update Cargo."
        fi
    else
        echo -e "${YELLOW}⚠️ rustup self-update disabled for this system. Use your system package manager to update rustup.${NC}"
        log "rustup self-update not available."
    fi
    # Ensure default toolchain is set (required on Arch)
    if ! rustup default | grep -q "stable"; then
        echo -e "${CYAN}🔄 Setting default toolchain to stable...${NC}"
        rustup default stable > /dev/null 2>&1 || handle_error "Failed to set default toolchain."
        log "Default toolchain set to stable."
    fi
}

cargo_install_or_update() {
    local package_name="$1"
    if cargo install --list | grep -q "^$package_name "; then
        echo -e "${CYAN}🔄 Updating Cargo package: $package_name...${NC}"
        if cargo install "$package_name" --force; then
            echo -e "${CYAN}✅ $package_name updated successfully.${NC}"
            log "$package_name updated successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to update $package_name.${NC}"
            log "Warning: Failed to update $package_name."
        fi
    else
        echo -e "${CYAN}📦 Installing Cargo package: $package_name...${NC}"
        if cargo install "$package_name"; then
            echo -e "${CYAN}✅ $package_name installed successfully.${NC}"
            log "$package_name installed successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to install $package_name.${NC}"
            log "Warning: Failed to install $package_name."
        fi
    fi
}

consolidate_cargo_directories() {
    echo -e "${CYAN}🧹 Ensuring Cargo directories exist...${NC}"
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME" || handle_error "Failed creating Cargo dirs."

    # Merge .cargo into $CARGO_HOME if they differ
    if [[ -d "$HOME/.cargo" && "$HOME/.cargo" != "$CARGO_HOME" ]]; then
        echo -e "${CYAN}🧹 Merging existing .cargo => $CARGO_HOME...${NC}"
        if command -v rsync > /dev/null 2>&1; then
            rsync -a --remove-source-files --progress "$HOME/.cargo/" "$CARGO_HOME/" \
                || handle_error "Failed to merge .cargo => $CARGO_HOME."
            rmdir "$HOME/.cargo" 2>/dev/null || true
        else
            mv "$HOME/.cargo"/* "$CARGO_HOME" || handle_error "Failed to move .cargo => $CARGO_HOME."
            rmdir "$HOME/.cargo" 2>/dev/null || true
        fi
    fi

    # Merge .rustup into $RUSTUP_HOME if they differ
    if [[ -d "$HOME/.rustup" && "$HOME/.rustup" != "$RUSTUP_HOME" ]]; then
        echo -e "${CYAN}🧹 Merging existing .rustup => $RUSTUP_HOME...${NC}"
        # Attempt to remove immutable attributes if possible
        if command -v chattr > /dev/null 2>&1; then
            chattr -R -i "$HOME/.rustup" > /dev/null 2>&1 || log "Warning: Unable to remove immutable attributes from ~/.rustup."
        fi
        # Check and exclude settings.toml if permission cannot be changed
        RSYNC_EXCLUDES=""
        if [ -f "$HOME/.rustup/settings.toml" ]; then
            if ! chmod u+w "$HOME/.rustup/settings.toml" 2>/dev/null; then
                echo -e "${CYAN}🔄 Unable to modify permissions on ~/.rustup/settings.toml; excluding it from migration...${NC}"
                RSYNC_EXCLUDES="--exclude=settings.toml"
            else
                rm -f "$HOME/.rustup/settings.toml" || log "Warning: Failed to remove ~/.rustup/settings.toml."
            fi
        fi
        if command -v rsync > /dev/null 2>&1; then
            rsync -a $RSYNC_EXCLUDES --remove-source-files --progress "$HOME/.rustup/" "$RUSTUP_HOME/" \
                || handle_error "Failed to merge .rustup => $RUSTUP_HOME."
            rmdir "$HOME/.rustup" 2>/dev/null || true
        else
            mv "$HOME/.rustup"/* "$RUSTUP_HOME" || handle_error "Failed to move .rustup => $RUSTUP_HOME."
            rmdir "$HOME/.rustup" 2>/dev/null || true
        fi
    fi

    log "Cargo directories consolidated."
}

install_cargo_tools() {
    echo -e "${CYAN}🔧 Installing essential Cargo tools (cargo-update, cargo-audit)...${NC}"
    cargo_install_or_update "cargo-update"
    cargo_install_or_update "cargo-audit"
}

manage_permissions() {
    echo -e "${CYAN}🔐 Verifying permissions for Cargo directories...${NC}"
    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"
    log "Permissions verified for Cargo directories."
}

validate_cargo_installation() {
    echo -e "${CYAN}✅ Validating Cargo installation...${NC}"
    if ! cargo --version > /dev/null 2>&1; then
        handle_error "Cargo missing. Use --fix to attempt installation."
    fi
    if ! rustup --version > /dev/null 2>&1; then
        handle_error "rustup not installed correctly."
    fi
    echo -e "${CYAN}✅ Cargo and rustup are installed + configured.${NC}"
    log "Cargo validated."
}

perform_final_cleanup() {
    echo -e "${CYAN}🧼 Performing final cleanup tasks...${NC}"
    if [[ -d "$CARGO_HOME/tmp" ]]; then
        echo -e "${CYAN}🗑️ Cleaning $CARGO_HOME/tmp...${NC}"
        rm -rf "${CARGO_HOME:?}/tmp" > /dev/null 2>&1 || log "Warning: Failed removing $CARGO_HOME/tmp."
        log "Removed $CARGO_HOME/tmp."
    fi
    if [[ -d "$RUSTUP_HOME/tmp" ]]; then
        echo -e "${CYAN}🗑️ Cleaning $RUSTUP_HOME/tmp...${NC}"
        rm -rf "${RUSTUP_HOME:?}/tmp" > /dev/null 2>&1 || log "Warning: Failed removing $RUSTUP_HOME/tmp."
        log "Removed $RUSTUP_HOME/tmp."
    fi
    echo -e "${CYAN}🧼 Final cleanup completed.${NC}"
    log "Cargo final cleanup done."
}

optimize_cargo_service() {
    echo -e "${CYAN}🔧 Starting Cargo environment optimization...${NC}"

    if ! command -v rustup > /dev/null 2>&1; then
        echo -e "${CYAN}📦 rustup not installed. Installing...${NC}"
        install_rustup
    else
        echo -e "${CYAN}✅ rustup already installed.${NC}"
        log "rustup installed."
    fi

    echo -e "${CYAN}🔄 Updating rustup + Cargo...${NC}"
    update_rustup_and_cargo

    echo -e "${CYAN}🛠️ Setting PATH for Cargo...${NC}"
    export PATH="$CARGO_HOME/bin:$PATH"

    echo -e "${CYAN}🧹 Consolidating Cargo directories...${NC}"
    consolidate_cargo_directories

    echo -e "${CYAN}🔧 Installing essential Cargo tools...${NC}"
    install_cargo_tools

    echo -e "${CYAN}🔐 Managing permissions...${NC}"
    manage_permissions

    echo -e "${CYAN}✅ Validating Cargo installation...${NC}"
    validate_cargo_installation

    echo -e "${CYAN}🧼 Final cleanup...${NC}"
    perform_final_cleanup

    echo -e "${CYAN}🎉 Cargo environment optimization complete.${NC}"
    echo -e "${CYAN}CARGO_HOME:${NC} $CARGO_HOME"
    echo -e "${CYAN}RUSTUP_HOME:${NC} $RUSTUP_HOME"
    echo -e "${CYAN}Cargo version:${NC} $(cargo --version)"
    echo -e "${CYAN}rustup version:${NC} $(rustup --version)"
    log "Cargo environment optimization completed."
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_cargo_service
fi
