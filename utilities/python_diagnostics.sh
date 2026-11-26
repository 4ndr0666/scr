#!/bin/bash
#                    === PYTHON DIAGNOSTICS === #
# This aggregates all of the paths and dirs used by python on the machine.
#

(
  data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
  hive_root="${VENV_HOME:-$data_root/virtualenv}"
  pipx_root="${PIPX_HOME:-$data_root/pipx}"
  pipx_bin="${PIPX_BIN_DIR:-$HOME/.local/bin}"
  print -r -- "VIRTUAL_ENV=${VIRTUAL_ENV:-<unset>}" \
    "PYENV_ROOT=${PYENV_ROOT:-$data_root/pyenv}" \
    "Hive=$hive_root" "PIPX_HOME=$pipx_root" "PIPX_BIN_DIR=$pipx_bin" \
    "PIPX_DEFAULT_PYTHON=${PIPX_DEFAULT_PYTHON:-<unset>}"
  whence -va python3 pip3 pipx pyenv 4ndr0service
  for interpreter in python3 /usr/bin/python3; do
    command "$interpreter" -I -c 'import sys; print(sys.executable, sys.version.split()[0], "prefix="+sys.prefix, "base="+sys.base_prefix)'
  done
  if (( $+commands[pyenv] )); then
    command pyenv version
    print -r -- "pyenv global=$(command pyenv global)"
    command pyenv which python3
  fi
  typeset -aU bin_roots=("$HOME/.local/bin" "$pipx_bin")
  for bin_root in "${bin_roots[@]}"; do
    for link in "$bin_root"/*(@N); do
      target=$(readlink -m -- "$link") || continue
      case "$target" in
        "$hive_root"/*|"$pipx_root"/*)
          if [[ -e "$link" ]]; then state=ok; else state=dangling; fi
          print -r -- "$link -> $target ($state)"
          ;;
      esac
    done
  done
)
