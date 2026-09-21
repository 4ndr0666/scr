#!/usr/bin/env bash
# File: test/verify_environment_runtime.sh
# Description: Isolated runtime proof for _provision_hive() failure propagation.

set -euo pipefail
IFS=$'\n\t'

repo_root="${GUP_REPO_ROOT:?GUP_REPO_ROOT must identify the repository root}"
source_file="$repo_root/4ndr0tools/4ndr0service/test/verify_environment.sh"

tmpdir="$(mktemp -d)"
cleanup() {
    rm -rf -- "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

# Extract ONLY the production _provision_hive() function. Do not source the
# production module: it would initialize the real suite mutex/environment.
awk '
    /^_provision_hive\(\)[[:space:]]*\{/ { capture=1 }
    capture { print }
    capture && /^}$/ { exit }
' "$source_file" >"$tmpdir/unit.sh"

grep -q '^_provision_hive()' "$tmpdir/unit.sh"

log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_success() { printf '[PASS-LOG] %s\n' "$*"; }
ensure_dir() { mkdir -p -- "$1"; }

source "$tmpdir/unit.sh"

pass=0
fail=0

check_rc() {
    local name="$1"
    local expected="$2"
    shift 2

    local actual
    if "$@"; then
        actual=0
    else
        actual=$?
    fi

    if (( actual == expected )); then
        printf '[PASS] %s: rc=%s\n' "$name" "$actual"
        ((pass+=1))
    else
        printf '[FAIL] %s: expected rc=%s, got rc=%s\n' "$name" "$expected" "$actual" >&2
        ((fail+=1))
    fi
}

# Case 1: an available ascension file that fails while being sourced must not
# be converted into a successful fallback path.
case1="$tmpdir/case1"
mkdir -p -- "$case1"
printf '%s\n' 'false' >"$case1/ascension.sh"
PKG_PATH="$case1"
check_rc 'ascension source failure propagates' 1 _provision_hive source_failure

# Case 2: fallback venv creation failure must propagate instead of being
# converted into a warning/success result.
case2="$tmpdir/case2"
mkdir -p -- "$case2/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 77' >"$case2/bin/python3"
chmod 700 -- "$case2/bin/python3"
PATH="$case2/bin:$PATH"
PKG_PATH="$tmpdir/nonexistent"
VENV_HOME="$case2/venvs"
check_rc 'fallback provisioning failure propagates' 77 _provision_hive fallback_failure

printf '\nGUPv5.3.1 verify_environment runtime proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
printf '[PASS] Isolated _provision_hive() runtime proof\n'
