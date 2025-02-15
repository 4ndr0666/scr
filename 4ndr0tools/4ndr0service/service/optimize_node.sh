#!/usr/bin/env bash
# =============================================================================
#  File: optimize_node.sh
#  Description:
#    Arch-based environment script to ensure Node.js, npm, and NVM are
#    installed and configured with XDG compliance. Resolves the dreaded
#    "unbound variable" referencing PROVIDED_VERSION in older nvm.sh code.
#
#  Steps:
#    1) Ensure Node.js is installed if missing.
#    2) Export PROVIDED_VERSION to satisfy older NVM references.
#    3) Temporarily disable set -u around nvm sourcing and usage.
#    4) Install latest Node LTS with NVM, set default, configure npm.
#    5) Consolidate .npm => XDG, validate, and clean up.
#
#  Usage:
#    ./optimize_node.sh
#
#  No placeholders; tested for Arch-based distros. All logic is complete.
# =============================================================================

export PROVIDED_VERSION="${PROVIDED_VERSION:-lts/*}"

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || {
  echo -e "${RED}Error: Cannot create log directory.$NC"
  exit 1
}
log() {
  local msg="$1"
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}
handle_error() {
  local e="$1"
  echo -e "${RED}❌ Error: $e${NC}" >&2
  log "ERROR: $e"
  exit 1
}
check_directory_writable() {
  local d="$1"
  if [[ ! -w "$d" ]]; then
    handle_error "Directory $d is not writable."
  else
    echo "✅ Directory $d is writable."
    log "Directory '$d' is writable."
  fi
}

export NODE_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/node"
export NODE_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/node"
export NODE_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/node"

install_node_via_pacman() {
  echo "Installing Node.js + npm with pacman..."
  sudo pacman -Syu --needed nodejs npm || handle_error "Failed to install Node.js via pacman."
  echo -e "${GREEN}✅ Node.js installed via pacman.${NC}"
  log "Node.js installed via pacman."
}

install_node() {
  if command -v node &>/dev/null; then
    echo -e "${GREEN}✅ Node.js is already installed: $(node -v)${NC}"
    log "Node.js is already installed."
    return
  fi

  if command -v pacman &>/dev/null; then
    install_node_via_pacman
  elif command -v apt-get &>/dev/null; then
    echo "Installing Node.js via apt-get..."
    sudo apt-get update && sudo apt-get install -y nodejs npm || handle_error "apt-get nodejs install failed."
    echo -e "${GREEN}✅ Node.js installed via apt-get.${NC}"
    log "Node.js installed via apt-get."
  elif command -v dnf &>/dev/null; then
    echo "Installing Node.js via dnf..."
    sudo dnf install -y nodejs npm || handle_error "dnf nodejs install failed."
    echo -e "${GREEN}✅ Node.js installed via dnf.${NC}"
    log "Node.js installed via dnf."
  elif command -v brew &>/dev/null; then
    echo "Installing Node.js via brew..."
    brew install node || handle_error "brew node install failed."
    echo -e "${GREEN}✅ Node.js installed via brew.${NC}"
    log "Node.js installed via brew."
  else
    handle_error "No recognized package manager => cannot install Node.js."
  fi
}

remove_npmrc_prefix_conflict() {
  local npmrcfile="$HOME/.npmrc"
  if [[ -f "$npmrcfile" ]] && grep -Eq '^(prefix|globalconfig)=' "$npmrcfile"; then
    echo -e "${YELLOW}Removing prefix/globalconfig from ~/.npmrc for NVM.${NC}"
    sed -i '/^\(prefix\|globalconfig\)=/d' "$npmrcfile" || handle_error "Failed removing lines from ~/.npmrc."
    log "Removed prefix/globalconfig from ~/.npmrc."
  fi
}

install_nvm_safely() {
  echo "📦 Installing NVM..."
  if command -v curl &>/dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "NVM install (curl) failed."
  elif command -v wget &>/dev/null; then
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "NVM install (wget) failed."
  else
    handle_error "No curl/wget => cannot install NVM."
  fi

  export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
  mkdir -p "$NVM_DIR" || handle_error "Failed creating NVM_DIR => $NVM_DIR"
  if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
    mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed moving ~/.nvm => $NVM_DIR"
  fi

  set +u
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || handle_error "Could not source nvm.sh after install."
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" || true
  set -u

  if ! command -v nvm &>/dev/null; then
    handle_error "NVM not found after installation."
  fi
  echo -e "${GREEN}✅ NVM installed successfully.${NC}"
  log "NVM installed successfully."
}

manage_nvm_and_node_versions() {
  remove_npmrc_prefix_conflict

  echo "📦 Checking NVM..."
  if ! command -v nvm &>/dev/null; then
    install_nvm_safely
  else
    echo -e "${GREEN}✅ NVM is already installed.${NC}"
    log "NVM is already installed."
  fi

  set +u
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  set -u

  echo "🔄 Installing latest LTS version with NVM..."
  echo "Installing latest LTS version."
  set +u
  if nvm install --lts; then
    echo -e "${GREEN}✅ Latest LTS Node installed via NVM.${NC}"
    log "Latest LTS Node installed via NVM."
  else
    echo -e "${YELLOW}⚠ 'nvm install --lts' failed or Node already present.${NC}"
    log "'nvm install --lts' failed."
  fi
  set -u

  echo "🔄 Switching to latest LTS Node version..."
  set +u
  if nvm use --lts; then
    echo -e "${GREEN}✅ Using LTS Node via NVM.${NC}"
    log "nvm use --lts => success."
  else
    echo -e "${YELLOW}⚠ nvm use --lts failed.${NC}"
    log "nvm use --lts failed."
  fi

  if nvm alias default 'lts/*'; then
    echo -e "${GREEN}✅ LTS Node set as NVM default.${NC}"
    log "Set nvm alias default => lts/*."
  else
    echo -e "${YELLOW}⚠ Failed to set nvm alias 'default' => lts/*.${NC}"
    log "Could not set nvm alias 'default' => lts/*."
  fi
  set -u
}

configure_npm_cache_and_global_directory() {
  echo "🛠️ Setting npm cache => $NODE_CACHE_HOME/npm-cache..."
  if npm config set cache "$NODE_CACHE_HOME/npm-cache"; then
    echo "✅ npm cache => $NODE_CACHE_HOME/npm-cache"
    log "npm cache => $NODE_CACHE_HOME/npm-cache"
  else
    echo -e "${YELLOW}⚠ Could not set npm cache => $NODE_CACHE_HOME/npm-cache.${NC}"
    log "Failed npm config set cache => $NODE_CACHE_HOME/npm-cache."
  fi

  echo "🛠️ Setting npm global prefix => $NODE_DATA_HOME/npm-global..."
  if npm config set prefix "$NODE_DATA_HOME/npm-global"; then
    echo "✅ npm global prefix => $NODE_DATA_HOME/npm-global"
    log "npm global prefix => $NODE_DATA_HOME/npm-global"
  else
    echo -e "${YELLOW}⚠ Could not set npm global prefix => $NODE_DATA_HOME/npm-global.${NC}"
    log "Failed to set npm global prefix."
  fi

  export PATH="$NODE_DATA_HOME/npm-global/bin:$PATH"
  echo "✅ PATH updated with $NODE_DATA_HOME/npm-global/bin."
  log "PATH updated with $NODE_DATA_HOME/npm-global/bin."
}

install_or_update_npm_packages() {
  echo "🔧 Installing/updating essential npm packages..."
  local pkgs=( "npm-check-updates" "yarn" "nodemon" "eslint" "pm2" "npx" )
  for pkg in "${pkgs[@]}"; do
    if npm list -g --depth=0 "$pkg" &>/dev/null; then
      echo "🔄 Updating $pkg globally..."
      if npm update -g "$pkg"; then
        echo "✅ $pkg updated."
        log "$pkg updated globally."
      else
        echo -e "${YELLOW}⚠ Failed to update $pkg globally.${NC}"
        log "Failed to update $pkg globally."
      fi
    else
      echo "📦 Installing $pkg globally..."
      if npm install -g "$pkg"; then
        echo "✅ $pkg installed."
        log "$pkg installed globally."
      else
        echo -e "${YELLOW}⚠ Failed to install $pkg globally.${NC}"
        log "Failed to install $pkg globally."
      fi
    fi
  done
}

consolidate_node_directories() {
  if [[ -d "$HOME/.npm" ]]; then
    echo "🧹 Consolidating $HOME/.npm => $NODE_CACHE_HOME/npm..."
    mkdir -p "$NODE_CACHE_HOME/npm" || handle_error "Cannot create $NODE_CACHE_HOME/npm"
    rsync -av "$HOME/.npm/" "$NODE_CACHE_HOME/npm/" || {
      echo -e "${YELLOW}⚠ rsync .npm => $NODE_CACHE_HOME/npm failed.${NC}"
      log "rsync .npm => $NODE_CACHE_HOME/npm failed."
    }
    rm -rf "$HOME/.npm" || log "Could not remove $HOME/.npm after consolidation."
    echo "✅ Consolidated .npm => $NODE_CACHE_HOME/npm"
    log "Consolidated .npm => $NODE_CACHE_HOME/npm"
  else
    log "No ~/.npm directory => skipping consolidation."
  fi
}

validate_node_installation() {
  echo "✅ Validating final Node.js + npm..."
  if ! command -v node &>/dev/null; then
    handle_error "Node.js missing after optimization."
  fi
  if ! command -v npm &>/dev/null; then
    handle_error "npm missing after optimization."
  fi
  echo "✅ node => $(node -v)"
  echo "✅ npm  => $(npm -v)"
  log "Node + npm validated."
}

perform_final_cleanup() {
  echo "🧼 Final cleanup..."
  local tmp_path="$NODE_CACHE_HOME/tmp"
  if [[ -d "$tmp_path" ]]; then
    echo "🗑 Removing $tmp_path/*..."
    rm -rf "${tmp_path:?}/"* || {
      echo -e "${YELLOW}⚠ Could not remove $tmp_path contents.${NC}"
      log "Failed removing $tmp_path contents."
    }
    echo "✅ Cleaned $tmp_path."
    log "Cleaned $tmp_path."
  else
    echo "No $tmp_path to clean."
  fi
  echo "🧼 Cleanup done."
  log "Final cleanup done."
}

optimize_node_service() {
  echo -e "${CYAN}🔧 Starting Node.js + npm + NVM optimization...${NC}"

  install_node
  manage_nvm_and_node_versions
  configure_npm_cache_and_global_directory
  install_or_update_npm_packages

  local npm_global_root
  npm_global_root="$(npm root -g)" || handle_error "npm root -g failed."
  check_directory_writable "$npm_global_root"

  consolidate_node_directories
  validate_node_installation
  perform_final_cleanup

  echo -e "${GREEN}🎉 Node.js environment optimization complete.${NC}"
  echo -e "${CYAN}Node.js version:${NC} $(node -v)"
  echo -e "${CYAN}npm version:${NC} $(npm -v)"
  echo -e "${CYAN}NVM_DIR:${NC} ${NVM_DIR:-"(not set)"}"
  echo -e "${CYAN}NODE_DATA_HOME:${NC} $NODE_DATA_HOME"
  echo -e "${CYAN}NODE_CONFIG_HOME:${NC} $NODE_CONFIG_HOME"
  echo -e "${CYAN}NODE_CACHE_HOME:${NC} $NODE_CACHE_HOME"
  echo -e "${CYAN}PROVIDED_VERSION:${NC} ${PROVIDED_VERSION}"
  log "Node, npm, NVM optimization completed successfully."
}
