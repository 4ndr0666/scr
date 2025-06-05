#!/usr/bin/env bash
set -euo pipefail

# Universal Codex Project Setup Script
# ------------------------------------

# -- Detect Package Manager
if command -v apt-get &>/dev/null; then
    PM="apt-get"
    SUDO="sudo"
elif command -v dnf &>/dev/null; then
    PM="dnf"
    SUDO="sudo"
elif command -v brew &>/dev/null; then
    PM="brew"
    SUDO=""
else
    echo "No supported package manager found. Please install required tools manually."
    exit 1
fi

# -- Python Environment
PYTHON_VERSION="3.11.12"
VENV_DIR=".codex-venv"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# Ensure desired Python version
if ! pyenv versions --bare | grep -q "^${PYTHON_VERSION}$"; then
    echo "Installing Python ${PYTHON_VERSION}..."
    pyenv install "${PYTHON_VERSION}"
fi
pyenv global "${PYTHON_VERSION}"
pyenv rehash

echo "Creating Python virtual environment..."
python -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"

echo "Upgrading pip..."
pip install --upgrade pip

# -- Python Development Tools
echo "Installing Python dev tools..."
pip install \
    black \
    pyright \
    flake8 \
    isort \
    mypy \
    pytest

# -- Shell Scripting Tools
echo "Installing shell development tools..."
$SUDO $PM update -y || true
$SUDO $PM install -y shellcheck shfmt || true

# -- Node.js/JS/TS Tools (global, uses Node 20)
if command -v npm &>/dev/null; then
    echo "Installing Node.js/TS dev tools..."
    npm install -g \
        prettier \
        eslint \
        typescript \
        ts-node
fi

# -- Go Tools
if command -v go &>/dev/null; then
    echo "Installing Go tools..."
    go install golang.org/x/lint/golint@latest
    go install github.com/fzipp/gocyclo/cmd/gocyclo@latest
fi

# -- Rust Tools
if command -v cargo &>/dev/null; then
    echo "Installing Rust tools..."
    cargo install --locked --root "$HOME/.cargo" cargo-audit || true
    cargo install --locked --root "$HOME/.cargo" cargo-edit || true
fi

# -- Docker Tools (if present)
if command -v docker &>/dev/null; then
    echo "Installing Docker linter..."
    if ! command -v hadolint &>/dev/null; then
        $SUDO $PM install -y hadolint || true
    fi
fi

# -- YAML, Markdown, and Misc Linters
if command -v npm &>/dev/null; then
    npm install -g markdownlint-cli yaml-lint
fi

# -- EditorConfig (universal style)
if command -v npm &>/dev/null; then
    npm install -g editorconfig-checker
fi

# -- Print Summary
cat <<EOF

Setup complete!

Activated Python venv: $VENV_DIR
Installed Python: black, pyright, flake8, isort, mypy, pytest
Installed Shell: shellcheck, shfmt
Installed Node/TS: prettier, eslint, typescript, ts-node
Installed Go: golint, gocyclo (if Go present)
Installed Rust: cargo-audit, cargo-edit (if Rust present)
Installed Docker: hadolint (if Docker present)
Installed Misc: markdownlint-cli, yaml-lint, editorconfig-checker

To activate Python venv:
    source $VENV_DIR/bin/activate

You can comment/uncomment tools above to match your needs. 
EOF
