#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_python.sh
# Production-grade Python toolchain bootstrapper for 4ndr0service

set -euo pipefail
IFS=$'\n\t'

# Determine PKG_PATH and source common environment
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
if [ -f "$SCRIPT_DIR/../common.sh" ]; then
    PKG_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
elif [ -f "$SCRIPT_DIR/../../common.sh" ]; then
    PKG_PATH="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
else
    echo "Error: Could not determine package path for optimize_python.sh" >&2
    exit 1
fi
export PKG_PATH
source "$PKG_PATH/common.sh"

optimize_python_service() {
    # Configuration
    local PY_VERSION="3.10.14"
    local -a TOOLS=(black flake8 mypy pytest poetry)

    echo "📦 Checking if Python is installed..."
    if command -v python3 &>/dev/null; then
        local py_version
        py_version="$(python3 --version 2>/dev/null || echo 'Unknown')"
        echo -e "\033[0;32m✅ Python is already installed: $py_version\033[0m"
    else
        echo -e "\033[1;33m⚠ Python not found.\033[0m"
        if command -v pyenv &>/dev/null; then
            echo "👉 Using pyenv to install Python $PY_VERSION..."
            pyenv install -s "$PY_VERSION" || echo "Warning: pyenv install failed."
            pyenv global "$PY_VERSION" || echo "Warning: could not set pyenv global version."
            pyenv rehash || true
            if command -v python3 &>/dev/null; then
                echo -e "\033[0;32m✅ Installed Python $PY_VERSION via pyenv.\033[0m"
            else
                echo -e "\033[1;33m⚠ Python still not available. Please install a Python version via pyenv.\033[0m"
                return 1
            fi
        else
            echo "ERROR: Python not found and pyenv not installed. Please install pyenv or python3 manually."
            return 1
        fi
    fi

    # Use python3 -m pip as canonical pip command.
    local pip_cmd="python3 -m pip"
    if ! $pip_cmd --version &>/dev/null; then
        echo "pip not found. Attempting ensurepip..."
        python3 -m ensurepip --upgrade || echo "Warning: ensurepip failed. Try manually installing pip."
    fi

    echo "🔄 Attempting pip upgrade..."
    set +e
    $pip_cmd install --upgrade pip
    local pip_ec=$?
    set -e
    if [[ $pip_ec -ne 0 ]]; then
        echo -e "\033[1;33m⚠ Warning: pip upgrade failed (possibly due to externally-managed environment).\033[0m"
        if command -v pyenv &>/dev/null; then
            echo "👉 Skipping system pip install since pyenv is in use."
        else
            echo "Manual pip install required."
        fi
    else
        echo "✅ pip upgraded successfully."
    fi

    echo "🔧 Checking for virtualenv..."
    if ! $pip_cmd show virtualenv &>/dev/null; then
        set +e
        $pip_cmd install --upgrade virtualenv
        local venv_ec=$?
        set -e
        if [[ $venv_ec -ne 0 ]]; then
            echo -e "\033[1;33m⚠ Warning: virtualenv install failed.\033[0m"
            if command -v pyenv &>/dev/null; then
                echo "👉 Skipping system virtualenv install due to pyenv."
            else
                echo "Manual virtualenv install required."
            fi
        else
            echo "✅ virtualenv installed/updated."
        fi
    else
        echo "✅ virtualenv is already installed."
    fi

    echo "🔧 Ensuring pipx is installed..."
    if command -v pipx &>/dev/null; then
        echo "✅ pipx is already installed."
    else
        $pip_cmd install --user pipx || echo -e "\033[1;33m⚠ Warning: pipx installation failed.\033[0m"
        if command -v pipx &>/dev/null; then
            echo "✅ pipx installed successfully."
        fi
    fi

    echo "🔧 Installing/updating base Python tools via pipx..."
    for tool in "${TOOLS[@]}"; do
        if ! pipx list | grep -q "${tool}"; then
            echo "📦 Installing $tool with pipx..."
            pipx install "$tool" || echo -e "\033[1;33m⚠ Warning: Failed to install $tool via pipx.\033[0m"
        else
            echo "🔄 $tool found; upgrading with pipx..."
            pipx upgrade "$tool" || echo -e "\033[1;33m⚠ Warning: Failed to upgrade $tool via pipx.\033[0m"
        fi
    done

    echo "✅ Python environment setup complete."
}

# If run as a script, execute the optimization
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_python_service
fi
