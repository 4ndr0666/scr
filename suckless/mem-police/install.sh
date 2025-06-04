#!/bin/sh
# shellcheck disable=all
# Author: 4ndr0666
set -eu

# ===================== // Mem-police Installer //
## Description:
#    Compiles and installs mem-police
# -----------------------------------

## Auto-escalate

[ "$(id -u)" -eq 0 ] || exec sudo sh "$0" "$@"

## Colors

case "${COLORTERM:-}" in
  truecolor|24bit) ;; 
  *) export COLORTERM="24bit" ;;
esac

if command -v tput >/dev/null && [ -t 1 ]; then
    GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
    BUG()  { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
    INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
else
    GLOW() { printf '[OK] %s\n' "$*"; }
    BUG()  { printf '[ERR] %s\n' "$*"; }
    INFO() { printf '[..] %s\n' "$*"; }
fi

## Compile

INFO "Compiling mem-police..."
if cc -O2 -std=c11 -Wall -Wextra -pedantic \
     -D_POSIX_C_SOURCE=200809L \
     -o mem-police mem-police.c
then
    GLOW "Compilation succeeded"
    echo ""
else
    BUG  "Compilation failed"
    exit 1
fi

## Install (requires root)

INFO "Installing to /usr/local/bin..."
if install -m755 mem-police /usr/local/bin/; then
    GLOW "mem-police installed successfully."
    echo ""
    printf '%s\n' "Start mem-police with [→]$(tput setaf 4)  sudo sh -c 'mem-police 2>&1 | tee /var/log/mem-police.log' &$(tput sgr0)"
else
    BUG  "Installation failed."
    exit 1
fi

exit 0
