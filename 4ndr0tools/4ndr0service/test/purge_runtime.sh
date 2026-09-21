#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="${GUP_REPO_ROOT:?GUP_REPO_ROOT must identify the repository root}"
source_file="$repo_root/4ndr0tools/4ndr0service/purge_matrix.sh"
tmpdir="$(mktemp -d)"
cleanup() { rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT TERM HUP

awk '
    /^run_purge\(\)[[:space:]]*\{/ { capture=1 }
    capture { print }
    capture && /^}$/ { exit }
' "$source_file" >"$tmpdir/unit.sh"
grep -q '^run_purge()' "$tmpdir/unit.sh"

log_info() { :; }
log_warn() { :; }
log_success() { :; }
log_purge() { :; }

VENV_HOME="$tmpdir/venvs"
BIN_DIR="$tmpdir/bin"
XDG_CONFIG_HOME="$tmpdir/config"
XDG_DATA_HOME="$tmpdir/data"
mkdir -p "$VENV_HOME" "$BIN_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

source "$tmpdir/unit.sh"

# The first case injects a failure at the broken-link pruning operation.
find() {
    if [[ "$*" == *"find -L"* ]] || [[ "$*" == *"-L $BIN_DIR"* ]]; then
        if [[ "$*" == *"-maxdepth 1 -type l -delete"* ]]; then
            return 71
        fi
    fi
    return 0
}
actual=0
if run_purge; then actual=0; else actual=$?; fi
if (( actual != 71 )); then
    printf '[FAIL] ghost-link purge failure: expected rc=71, got rc=%s\n' "$actual" >&2
    exit 1
fi
printf '[PASS] ghost-link purge failure propagates: rc=71\n'

# The second case allows the earlier operations to succeed and injects failure
# only at the __pycache__ purge operation.
find() {
    if [[ "$*" == *"-type d -name __pycache__ -exec"* ]]; then
        return 73
    fi
    return 0
}
actual=0
if run_purge; then actual=0; else actual=$?; fi
if (( actual != 73 )); then
    printf '[FAIL] cache purge failure: expected rc=73, got rc=%s\n' "$actual" >&2
    exit 1
fi
printf '[PASS] cache purge failure propagates: rc=73\n'

printf '\nGUPv5.3.1 purge runtime proof: 2 passed, 0 failed\n'
printf '[PASS] Isolated run_purge() failure-propagation proof\n'
