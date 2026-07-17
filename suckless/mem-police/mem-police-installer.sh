#!/bin/sh
# Author: 4ndr0666
# shellcheck disable=SC2059
set -eu

# ===================== // Mem-police Installer //
## Description:
#    Compiles and installs mem-police (v3.2.0)
#
# CHANGELOG (vs prior version):
#   - Removed blanket `# shellcheck disable=all`; replaced with targeted
#     SC2059 (printf format-string variable) which is the only suppression
#     legitimately needed in this file.
#   - Added terminal-capability guard around the final "next steps" printf
#     block so tput escape codes are not emitted to non-interactive output
#     (pipes, logs). Falls back to plain text if tput is unavailable.
#   - Updated compile flags to exactly match Makefile CFLAGS and mem-police.c
#     header comment: added -D_GNU_SOURCE for explicit coherence across all
#     three build-definition sources.
# -----------------------------------

# Auto-escalate
[ "$(id -u)" -eq 0 ] || exec sudo sh "$0" "$@"

# Colors — guarded by terminal capability check
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    # shellcheck disable=SC2039,SC2059
    GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
    # shellcheck disable=SC2039,SC2059
    BUG()  { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
    # shellcheck disable=SC2039,SC2059
    INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
    HAVE_TPUT=1
else
    GLOW() { printf '[OK] %s\n' "$*"; }
    BUG()  { printf '[ERR] %s\n' "$*"; }
    INFO() { printf '[..] %s\n' "$*"; }
    HAVE_TPUT=0
fi

INFO "Compiling mem-police..."
if cc -O2 -std=c11 -Wall -Wextra -pedantic \
     -D_POSIX_C_SOURCE=200809L -D_GNU_SOURCE \
     -o mem-police mem-police.c -lpcre2-8
then
    GLOW "Compilation succeeded"
else
    BUG  "Compilation failed. Ensure libpcre2-dev or pcre2-devel is installed."
    exit 1
fi

INFO "Installing to /usr/local/bin..."
if install -m755 mem-police /usr/local/bin/; then
    GLOW "mem-police installed successfully."
    echo ""
    # Use terminal-aware output for the "next steps" block.
    # Previously this block used inline $(tput ...) calls unconditionally,
    # embedding raw ESC sequences into non-interactive output (logs, pipes).
    if [ "$HAVE_TPUT" -eq 1 ]; then
        printf 'Start mem-police as root with:\n'
        # shellcheck disable=SC2039
        printf '  %s\n' "$(tput setaf 4)systemctl start mem-police$(tput sgr0)"
        printf 'or for interactive logging:\n'
        # shellcheck disable=SC2039
        printf '  %s\n' "$(tput setaf 4)sudo /usr/local/bin/mem-police --foreground$(tput sgr0)"
    else
        printf 'Start mem-police as root with:\n'
        printf '  systemctl start mem-police\n'
        printf 'or for interactive logging:\n'
        printf '  sudo /usr/local/bin/mem-police --foreground\n'
    fi
else
    BUG  "Installation failed."
    exit 1
fi

exit 0
