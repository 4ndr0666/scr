#!/bin/sh
# Author: 4ndr0666
set -eu

# ===================== // Mem-police Installer //
## Description:
#    Compiles and installs mem-police (v3.2.4), its systemd unit and a default config
# -----------------------------------

# Auto-escalate
[ "$(id -u)" -eq 0 ] || exec sudo sh "$0" "$@"

# Colors
if command -v tput >/dev/null && [ -t 1 ]; then
    GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
    BUG()  { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
    INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
    HAVE_TPUT=1
else
    GLOW() { printf '[OK] %s\n' "$*"; }
    BUG()  { printf '[ERR] %s\n' "$*"; }
    INFO() { printf '[..] %s\n' "$*"; }
    HAVE_TPUT=0
fi

INFO "Compiling mem-police..."
# timeout: bound the external compiler invocation (a hung toolchain must not hang the installer)
if timeout 300 cc -O2 -std=c11 -Wall -Wextra -pedantic \
     -D_POSIX_C_SOURCE=200809L -D_GNU_SOURCE \
     -o mem-police mem-police.c -lpcre2-8
then
    GLOW "Compilation succeeded"
else
    BUG  "Compilation failed (or exceeded 300 s). Ensure libpcre2-dev or pcre2-devel is installed."
    exit 1
fi

INFO "Installing to /usr/local/bin..."
if install -m755 mem-police /usr/local/bin/; then
    GLOW "mem-police installed successfully."

    # --- systemd unit + config (idempotent) ---
    # The unit carries no user data, so it is refreshed on every run.  The config is
    # installed only when absent, so a re-run never overwrites the operator's edits;
    # owner and mode are enforced every run because the daemon refuses any config
    # that is not root:root 0600.  Nothing is enabled or started here.
    if install -m 0644 mem-police.service /etc/systemd/system/mem-police.service; then
        GLOW "Installed /etc/systemd/system/mem-police.service"
    else
        BUG  "Installing mem-police.service failed (is it next to this script?)."
        exit 1
    fi
    if [ -e /etc/mem_police.conf ]; then
        INFO "Keeping existing /etc/mem_police.conf"
    elif install -m 0600 -o root -g root mem-police.conf /etc/mem_police.conf; then
        GLOW "Installed default /etc/mem_police.conf"
    else
        BUG  "Installing /etc/mem_police.conf failed (is mem-police.conf next to this script?)."
        exit 1
    fi
    chown root:root /etc/mem_police.conf
    chmod 0600 /etc/mem_police.conf
    if command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload 2>/dev/null; then
        GLOW "systemd reloaded"
    else
        INFO "systemd not running here; run 'systemctl daemon-reload' on the target host"
    fi
    echo ""
    # Colour only when the colour helpers were enabled above (tty + tput present);
    # otherwise the unconditional tput calls emitted "tput: No value for $TERM" noise.
    if [ "$HAVE_TPUT" -eq 1 ]; then
        printf '%s\n' "Start mem-police as root with:
$(tput setaf 4)  systemctl start mem-police$(tput sgr0)
or for interactive logging:
$(tput setaf 4)  sudo /usr/local/bin/mem-police --foreground$(tput sgr0)"
    else
        printf '%s\n' "Start mem-police as root with:
  systemctl start mem-police
or for interactive logging:
  sudo /usr/local/bin/mem-police --foreground"
    fi
else
    BUG  "Installation failed."
    exit 1
fi

exit 0
