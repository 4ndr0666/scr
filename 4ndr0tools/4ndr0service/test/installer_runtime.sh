#!/usr/bin/env bash
# File: test/installer_runtime.sh
# Description: Isolated installer failure-propagation contract proof.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PKG_DIR="$(dirname -- "$SCRIPT_DIR")"
INSTALLER="$PKG_DIR/install.sh"

fail=0
pass=0

pass_case() {
    printf '[PASS] %s\n' "$1"
    ((pass++)) || true
}

fail_case() {
    printf '[FAIL] %s\n' "$1" >&2
    ((fail++)) || true
}

[[ -f "$INSTALLER" ]] || { printf '[FATAL] installer missing: %s\n' "$INSTALLER" >&2; exit 2; }

if bash -n "$INSTALLER"; then
    pass_case 'installer syntax valid'
else
    fail_case 'installer syntax valid'
fi

# A failed invocation symlink is a failed installation: continuing would leave
# the documented /usr/local/bin/4ndr0service entry point absent.
if grep -Fq 'run sudo ln -s "$INSTALL_LOCATION/main.sh" "$SYMLINK_PATH" \\' "$INSTALLER" \
   && grep -Fq '|| log_warn "Failed to create symlink' "$INSTALLER"; then
    fail_case 'invocation symlink failure propagates'
else
    pass_case 'invocation symlink failure propagates'
fi

# jq is required by the suite; a failed automatic installation cannot be
# represented as a successful installer completion.
if grep -Fq 'pacman -S --noconfirm --needed jq' "$INSTALLER" \
   && grep -Fq '|| log_warn "Automatic jq install failed' "$INSTALLER"; then
    fail_case 'required jq installation failure propagates'
else
    pass_case 'required jq installation failure propagates'
fi

# systemd deployment is part of the default installer contract; if the unit
# installer is invoked and fails, the parent installer must not silently turn
# that failure into success.
if grep -Fq 'bash "$_systemd_installer" \\' "$INSTALLER" \
   && grep -Fq '|| log_warn "systemd maintenance timer activation failed' "$INSTALLER"; then
    fail_case 'systemd deployment failure propagates'
else
    pass_case 'systemd deployment failure propagates'
fi

printf '\nGUPv5.3.1 installer failure-propagation proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
