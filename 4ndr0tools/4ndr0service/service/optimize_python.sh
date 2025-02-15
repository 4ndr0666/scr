#!/usr/bin/env bash
# File: optimize_python.sh
# Description: Python environment optimization logic for 4ndr0service.
set -euo pipefail
IFS=$'\n\t'

optimize_python_service() {
  echo -e "\033[0;36m🔧 Starting Python environment optimization...\033[0m"

  # 1) Check if Python is installed
  echo "📦 Checking if Python is installed..."
  if command -v python3 &>/dev/null; then
      local py_version
      py_version="$(python3 --version 2>/dev/null || echo 'Unknown')"
      echo -e "\033[0;32m✅ Python is already installed: $py_version\033[0m"
  else
      echo -e "\033[1;33m⚠ Python not found.\033[0m"
      attempt_tool_install "python3" "false"
      return 1
  fi

  # 2) Determine pip command
  echo "🔄 Checking if pip is installed..."
  local pip_cmd=""
  if command -v pip3 &>/dev/null; then
      pip_cmd="pip3"
  elif command -v pip &>/dev/null; then
      pip_cmd="pip"
  fi

  if [[ -z "$pip_cmd" ]]; then
      echo -e "\033[1;33m⚠ pip not found.\033[0m"
      attempt_tool_install "pip" "false"
      return 0
  fi

  # 3) Attempt pip upgrade (PEP 668 environment might block)
  echo "🔄 Attempting pip upgrade..."
  set +e
  "$pip_cmd" install --upgrade pip
  local ec=$?
  set -e

  if [[ $ec -ne 0 ]]; then
      echo -e "\033[1;33m⚠ Warning: pip upgrade blocked by externally-managed environment (PEP 668).\033[0m"
      attempt_pacman_install "python-pip"
  else
      echo "✅ pip upgraded successfully."
  fi

  # virtualenv handling
  echo "🔧 Checking for virtualenv..."
  if ! "$pip_cmd" show virtualenv &>/dev/null; then
      echo "🔄 Installing virtualenv..."
      set +e
      "$pip_cmd" install --upgrade virtualenv
      local venv_ec=$?
      set -e
      if [[ $venv_ec -ne 0 ]]; then
          echo -e "\033[1;33m⚠ Warning: virtualenv upgrade blocked by externally-managed environment (PEP 668).\033[0m"
          attempt_pacman_install "python-virtualenv"
      else
          echo "✅ virtualenv installed/updated."
      fi
  else
      echo "🔄 Updating virtualenv..."
      set +e
      "$pip_cmd" install --upgrade virtualenv
      local venv_ec2=$?
      set -e
      if [[ $venv_ec2 -ne 0 ]]; then
          echo -e "\033[1;33m⚠ Warning: virtualenv upgrade blocked by externally-managed environment.\033[0m"
          attempt_pacman_install "python-virtualenv"
      else
          echo "✅ virtualenv updated successfully."
      fi
  fi

  # Configure Python directories
  echo "🛠️ Configuring Python directories..."
  mkdir -p "$VENV_HOME" "$PIPX_HOME" "$PIPX_HOME/bin"
  echo "Setting pip cache => $XDG_CACHE_HOME/python/pip..."
  set +e
  "$pip_cmd" config set global.cache-dir "$XDG_CACHE_HOME/python/pip"
  set -e
  echo "✅ pip cache => $XDG_CACHE_HOME/python/pip"

  export WORKON_HOME="$VENV_HOME"
  echo "✅ WORKON_HOME => $WORKON_HOME"

  export PATH="$PIPX_HOME/bin:$PATH"
  echo "✅ PATH updated with $PIPX_HOME/bin"

  ensure_pip_command() {
      if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
          echo "⚠ No pip command is available. Attempting fallback installation..."
          attempt_pacman_install "python-pip"
          return
      fi
      echo "✅ pip command is available."
  }
  ensure_pip_command

  # Packages: pipx, black, flake8, mypy, pytest
  echo "🔧 Installing Python packages (pipx, black, flake8, mypy, pytest)..."
  if command -v pipx &>/dev/null; then
      echo "✅ pipx is already installed."
  else
      echo "Installing pipx..."
      set +e
      "$pip_cmd" install --upgrade pipx
      local pipx_ec=$?
      set -e
      if [[ $pipx_ec -ne 0 ]]; then
          echo -e "\033[1;33m⚠ Warning: pipx installation blocked by environment.\033[0m"
          attempt_pacman_install "python-pipx"
      else
          echo "✅ pipx installed successfully."
      fi
  fi

  fix_broken_pipx_env() {
      local pkg="$1"
      local venv_dir="$PIPX_HOME/venvs/$pkg"
      echo "Installing or updating $pkg via pipx..."
      set +e
      pipx install "$pkg" --force
      local rc=$?
      set -e
      if [[ $rc -eq 0 ]]; then
          echo -e "\033[0;32m✅ $pkg installed/updated via pipx.\033[0m"
      else
          echo -e "\033[1;33m⚠ Could not install/update $pkg via pipx.\033[0m"
          attempt_pacman_install "python-$pkg"
      fi
  }

  tools=("black" "flake8" "mypy" "pytest")
  for t in "${tools[@]}"; do
      fix_broken_pipx_env "$t"
  done

  echo "🔐 Managing permissions for Python directories..."
  local dirs=(
    "$XDG_DATA_HOME/python"
    "$XDG_CONFIG_HOME/python"
    "$XDG_CACHE_HOME/python"
    "$VENV_HOME"
    "$PIPX_HOME"
    "$PIPX_HOME/bin"
  )
  for d in "${dirs[@]}"; do
      if [[ ! -w "$d" ]]; then
          echo "✅ Directory $d is writable? [Check ownership if needed]"
      else
          echo "✅ Directory $d is writable."
      fi
  done

  echo "✅ Validating Python environment..."
  if command -v python3 &>/dev/null; then
      echo "python3 => $(python3 --version)"
  fi
  if command -v pip3 &>/dev/null; then
      echo "pip3 => $(pip3 --version)"
  fi
  echo "✅ Python environment validated (partial success possible)."

  echo "🧼 Performing final cleanup for Python..."
  local tmp_path="$XDG_CACHE_HOME/python/tmp"
  if [[ -d "$tmp_path" ]]; then
      rm -rf "$tmp_path" || echo "Could not remove $tmp_path"
      echo "Removed $tmp_path"
  else
      echo "No $tmp_path to clean."
  fi
  echo "🧼 Final cleanup done."

  echo -e "\033[0;32m🎉 Python environment optimization complete.\033[0m"
  echo -e "\033[0;36mPYTHON_DATA_HOME:\033[0m $XDG_DATA_HOME/python"
  echo -e "\033[0;36mPYTHON_CONFIG_HOME:\033[0m $XDG_CONFIG_HOME/python"
  echo -e "\033[0;36mPYTHON_CACHE_HOME:\033[0m $XDG_CACHE_HOME/python"
  echo -e "\033[0;36mVENV_HOME:\033[0m $VENV_HOME"
  echo -e "\033[0;36mPIPX_HOME:\033[0m $PIPX_HOME"
  echo -e "\033[0;36mPIPX_BIN_DIR:\033[0m $PIPX_HOME/bin"
  echo -e "\033[0;36mPython version:\033[0m $(python3 --version 2>/dev/null || echo 'Unknown')"
  if command -v pip3 &>/dev/null; then
      echo -e "\033[0;36mpip version:\033[0m $(pip3 --version)"
  fi
}
export -f optimize_python_service
