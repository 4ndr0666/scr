#!/usr/bin/env bash
# File: test/installer_runtime_v2.sh
# Description: Isolated proof that post-install verification failures abort install.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$(dirname -- "$SCRIPT_DIR")/install.sh"
fail=0
pass=0

pass_case() { printf '[PASS] %s\n' "$1"; ((pass++)) || true; }
fail_case() { printf '[FAIL] %s\n' "$1" >&2; ((fail++)) || true; }

if bash -n "$INSTALLER"; then pass_case 'installer syntax valid'; else fail_case 'installer syntax valid'; fi

# A failed --report is a failed installation: the installer must not log
# deployment success or clear rollback state after verification failure.
if grep -Fq '|| log_warn "--report returned non-zero' "$INSTALLER"; then
    fail_case 'post-install report failure propagates'
else
    pass_case 'post-install report failure propagates'
fi

if grep -Fq '|| { log_error "--report verification failed; installation aborted."; exit 1; }' "$INSTALLER"; then
    pass_case 'post-install report abort contract present'
else
    fail_case 'post-install report abort contract present'
fi

printf '\nGUPv5.3.1 installer v2 failure-propagation proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
