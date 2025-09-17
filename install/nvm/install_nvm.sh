#!/bin/bash
# Author: 4ndr0666
# =================== // INSTALL_NVM.SH //
# NVM exposes the following environment variables:
# - NVM_DIR - nvm's installation directory.
# - NVM_BIN - where node, npm, and global packages for the active version of node are installed.
# - NVM_INC - node's include file directory (useful for building C/C++ addons for node).
# - NVM_CD_FLAGS - used to maintain compatibility with zsh.
# - NVM_RC_VERSION - version from .nvmrc file if being used.
# - PATH, MANPATH & NODE_PATH when changing versions.
# Regular install with either:
#wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
#curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# The script clones the nvm repo to $XDG_CONFIG_HOME or ~/.nvm, and adds the following to shell rc:
#export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# To get latest LTS version and migrate existing packages:
#$nvm install --reinstall-packages-from=current 'lts/*
# Install newest Node.js and migrate npm packages from a previous version:
#$nvm install --reinstall-packages-from=node node
# Update npm at the same time add the '--latest-npm flag':
#$nvm install --reinstall-packages-from=default --latest-npm 'lts/*'
# Install a newest io.js and migrate npm packages from a previous version:
#$nvm install --reinstall-packages-from=iojs iojs
# To run tests first do a:
#$npm install
# Then choose fast, slow or all:
#$npm run test/fast
#$npm run test/slow
#$npm test
# ---------------------------------------------------------------------------------

# Ensures RC file is not edited (use regular install for shell snippet):
PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash' && nvm install --reinstall-packages-from=default --latest-npm 'lts/*'

# Set colors
sleep 2
export NVM_COLORS='cmgRY'
#NVM_COLORS='rgBcm'
