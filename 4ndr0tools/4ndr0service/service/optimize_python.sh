#!/usr/bin/env bash
# 4ndr0service: Optimize Python Environment for pyenv, pipx, poetry, etc.

set -euo pipefail

# ---- 1. Ensure Python3 available via pyenv if possible ----
echo "📦 Checking if Python is installed..."

if command -v python3 &>/dev/null; then
    py_version="$(python3 --version 2>/dev/null || echo 'Unknown')"
    echo -e "\033[0;32m✅ Python is already installed: $py_version\033[0m"
else
    echo -e "\033[1;33m⚠ Python not found.\033[0m"
    if command -v pyenv &>/dev/null; then
        echo "👉 Using pyenv to install Python 3.10.14..."
        pyenv install -s 3.10.14 || echo "Warning: pyenv install failed."
        pyenv global 3.10.14 || echo "Warning: could not set pyenv global version."
        pyenv rehash || true
        if command -v python3 &>/dev/null; then
            echo -e "\033[0;32m✅ Installed Python 3.10.14 via pyenv.\033[0m"
        else
            echo -e "\033[1;33m⚠ Python still not available. Please install a Python version via pyenv.\033[0m"
            exit 1
        fi
    else
        echo "⚠ Neither python3 nor pyenv detected. Please install python3 or pyenv."
        exit 1
    fi
fi

# ---- 2. Detect pip3 ----
if command -v pip3 &>/dev/null; then
    pip_cmd="pip3"
elif command -v python3 &>/dev/null; then
    python3 -m ensurepip --upgrade || true
    pip_cmd="python3 -m pip"
else
    echo "❌ Python3 not available for pip bootstrap."
    exit 1
fi

# ---- 3. Upgrade pip ----
echo "🔄 Attempting pip upgrade..."
set +e
"$pip_cmd" install --upgrade pip
ec=$?
set -e
if [[ $ec -ne 0 ]]; then
    echo -e "\033[1;33m⚠ Warning: pip upgrade failed (possibly due to externally-managed environment).\033[0m"
    if command -v pyenv &>/dev/null; then
        echo "👉 Skipping system pip install since pyenv is in use."
    else
        echo "❌ pip unavailable and pyenv not detected. Manual intervention required."
        exit 1
    fi
else
    echo "✅ pip upgraded successfully."
fi

# ---- 4. Ensure virtualenv ----
echo "🔧 Checking for virtualenv..."
set +e
"$pip_cmd" show virtualenv &>/dev/null
ve_show=$?
set -e

if [[ $ve_show -ne 0 ]]; then
    set +e
    "$pip_cmd" install --upgrade virtualenv
    venv_ec=$?
    set -e
    if [[ $venv_ec -ne 0 ]]; then
        echo -e "\033[1;33m⚠ Warning: virtualenv install failed (likely externally-managed environment).\033[0m"
        if command -v pyenv &>/dev/null; then
            echo "👉 Skipping system virtualenv install due to pyenv."
        else
            echo "❌ virtualenv unavailable and pyenv not detected. Manual intervention required."
            exit 1
        fi
    else
        echo "✅ virtualenv installed/updated."
    fi
else
    echo "✅ virtualenv already installed."
fi

# ---- 5. Ensure pipx ----
echo "🔧 Installing Python packages (pipx, poetry, black, flake8, mypy, pytest)..."
if command -v pipx &>/dev/null; then
    echo "✅ pipx is already installed."
else
    set +e
    "$pip_cmd" install --user --upgrade pipx
    pipx_ec=$?
    set -e
    if [[ $pipx_ec -ne 0 ]]; then
        echo -e "\033[1;33m⚠ Warning: pipx installation blocked by environment.\033[0m"
        if command -v pyenv &>/dev/null; then
            echo "👉 Skipping system pipx install due to pyenv."
        else
            echo "❌ pipx unavailable and pyenv not detected. Manual intervention required."
            exit 1
        fi
    else
        echo "✅ pipx installed successfully."
    fi
fi

# ---- 6. Ensure CLI tools via pipx ----
fix_broken_pipx_env() {
    local pkg="$1"
    if pipx list | grep -qw "$pkg"; then
        pipx upgrade "$pkg" >/dev/null 2>&1
    else
        pipx install "$pkg" >/dev/null 2>&1
    fi
    rc=$?
    if [[ $rc -eq 0 ]]; then
        echo -e "\033[0;32m✅ $pkg installed/updated via pipx.\033[0m"
    else
        echo -e "\033[1;33m⚠ Could not install/update $pkg via pipx.\033[0m"
        if command -v pyenv &>/dev/null; then
            echo "👉 Skipping system install for $pkg; please check pipx or network."
        else
            echo "❌ $pkg unavailable and pyenv not detected. Manual intervention required."
        fi
    fi
}

tools=(black flake8 mypy pytest poetry)
for t in "${tools[@]}"; do
    fix_broken_pipx_env "$t"
done

# ---- 7. Final status report ----
echo "python3 => $(python3 --version 2>/dev/null || echo 'Unknown')"
echo "pip3 => $("$pip_cmd" --version 2>/dev/null || echo 'Unknown')"
if command -v pyenv &>/dev/null; then
    pyenv rehash || true
fi

echo "✅ Python environment optimized!"
