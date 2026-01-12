#!/usr/bin/env bash
# File: install.sh
# God-tier installer for 4ndr0service Suite
# Embeds PKG_PATH, creates canonical symlink, hardens paths
# Run as: bash install.sh
# Location: place in repo root or run from anywhere with git clone first

set -euo pipefail
IFS=$'\n\t'

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION - DO NOT CHANGE UNLESS FORKING
# ──────────────────────────────────────────────────────────────────────────────
readonly DEST="/opt/4ndr0service"
readonly BIN_SYMLINK="/usr/local/bin/4ndr0service"
readonly REPO_URL="https://github.com/4ndr0666/4ndr0service.git"  # CHANGE TO YOUR FORK IF NEEDED
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/4ndr0service"

# ──────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
handle_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
    exit 1
}

ensure_dir() {
    local dir="$1"
    mkdir -p "$dir" || handle_error "Failed to create directory: $dir"
}

ensure_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Do NOT run this installer as root. Use sudo only when prompted."
        exit 1
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN INSTALL LOGIC
# ──────────────────────────────────────────────────────────────────────────────
ensure_root

log_info "4ndr0service God-Installer v1.0.0 — Void-Gaze Protocol"

# 1. Clone or update repo to canonical location
if [[ -d "$DEST" ]]; then
    log_info "Existing installation found at $DEST → pulling latest..."
    cd "$DEST" || handle_error "Cannot cd into $DEST"
    git fetch --all || log_warn "git fetch failed, continuing anyway..."
    git reset --hard origin/main || log_warn "git reset failed, manual conflict resolution may be needed"
else
    log_info "Cloning fresh install to $DEST..."
    ensure_dir "$(dirname "$DEST")"
    git clone "$REPO_URL" "$DEST" || handle_error "git clone failed"
    cd "$DEST" || handle_error "Cannot cd into newly cloned $DEST"
fi

# 2. Embed absolute PKG_PATH into EVERY .sh file that uses it
log_info "Embedding canonical PKG_PATH=\"$DEST\" into all scripts..."
find . -type f -name '*.sh' -exec sed -i \
    "s|^PKG_PATH=.*|PKG_PATH=\"$DEST\"|g; \
     s|\${PKG_PATH:-.*}|\"$DEST\"|g" {} \;

# Special handling for common.sh if it has fallback logic
sed -i "s|ensure_pkg_path|PKG_PATH=\"$DEST\"; export PKG_PATH|" common.sh

# 3. Create symlink in /usr/local/bin (requires sudo)
log_info "Creating canonical symlink $BIN_SYMLINK → $DEST/main.sh"
sudo ln -sf "$DEST/main.sh" "$BIN_SYMLINK" || handle_error "Failed to create symlink (sudo required)"

# 4. Ensure executable
chmod +x "$DEST/main.sh" "$BIN_SYMLINK"

# 5. Create config skeleton if missing
ensure_dir "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    log_info "Creating default config skeleton..."
    cat > "$CONFIG_DIR/config.json" <<'EOF'
{
  "settings_editor": "vim",
  "required_env": ["PYENV_ROOT", "PIPX_HOME", "PIPX_BIN_DIR"],
  "directory_vars": ["PYENV_ROOT", "PIPX_HOME", "PIPX_BIN_DIR"],
  "tools": ["python3", "pipx", "pyenv", "poetry"],
  "python_version": "3.10.14",
  "python_tools": ["black", "flake8", "mypy", "pytest", "poetry"],
  "cargo_tools": ["cargo-update", "cargo-audit"],
  "electron_tools": ["electron-builder"],
  "go_tools": ["golang.org/x/tools/gopls@latest", "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"],
  "node_version": "lts/*",
  "npm_global_packages": ["npm", "yarn", "pnpm", "typescript", "eslint", "prettier"],
  "ruby_gems": ["bundler", "rake", "rubocop"],
  "venv_pipx_packages": ["black", "flake8", "mypy", "pytest"],
  "venv_name": ".venv"
}
EOF
fi

# 6. Smoke test
log_info "Running smoke test..."
if "$BIN_SYMLINK" --test; then
    log_info "Smoke test passed."
else
    log_warn "Smoke test failed — check logs and run manually with --test"
fi

# 7. Final sigil
log_info "Installation complete."
log_info "You may now invoke the suite with: 4ndr0service"
log_info "PKG_PATH is permanently set to $DEST"
log_info "Daily environment healing timer should be enabled via install_env_maintenance.sh"

exit 0
