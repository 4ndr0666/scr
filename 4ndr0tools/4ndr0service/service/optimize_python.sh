#!/usr/bin/env bash
# File: optimize_python.sh
# Production-grade Python toolchain bootstrapper for 4ndr0service
set -euo pipefail

PKG_PATH="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
source "$PKG_PATH/common.sh"

PY_VERSION="3.10.14"
TOOLS=(black flake8 mypy pytest poetry)

echo "📦 Checking if Python is installed..."
if command -v python3 &>/dev/null; then
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
            exit 1
        fi
    else
        echo "ERROR: Python not found and pyenv not installed. Please install pyenv or python3 manually."
        exit 1
    fi
fi

# Use python3 -m pip as canonical pip command.
pip_cmd="python3 -m pip"
if ! $pip_cmd --version &>/dev/null; then
    echo "pip not found. Attempting ensurepip..."
    python3 -m ensurepip --upgrade || echo "Warning: ensurepip failed. Try manually installing pip."
fi

echo "🔄 Attempting pip upgrade..."
set +e
$pip_cmd install --upgrade pip
pip_ec=$?
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
    venv_ec=$?
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
    $pip_cmd install --user pipx
    export PATH="$PIPX_HOME/bin:$PATH"
    echo "✅ pipx installed to $PIPX_HOME/bin."
fi

# Rehash for pyenv
if command -v pyenv &>/dev/null; then
    pyenv rehash || true
fi

echo "🔧 Installing/updating Python dev tools via pipx..."
for t in "${TOOLS[@]}"; do
    if pipx list | grep -qw "$t"; then
        pipx upgrade "$t" && echo "✅ $t upgraded via pipx."
    else
        pipx install "$t" && echo "✅ $t installed via pipx."
    fi
done

if command -v pyenv &>/dev/null; then
    pyenv rehash || true
fi

echo "🧼 Final Python env audit:"
echo -e "\033[0;36mPython version:\033[0m $(python3 --version 2>/dev/null || echo 'Unknown')"
echo -e "\033[0;36mpip version:\033[0m $(pip3 --version 2>/dev/null || echo 'Unknown')"
echo -e "\033[0;36mpipx version:\033[0m $(pipx --version 2>/dev/null || echo 'Unknown')"
echo -e "\033[0;36mpoetry version:\033[0m $(poetry --version 2>/dev/null || echo 'Unknown')"
echo "Done."
