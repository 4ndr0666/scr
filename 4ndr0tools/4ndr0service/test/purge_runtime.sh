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

# Provide harmless stand-ins for the filesystem and runtime operations. Each
# case injects one failure and asserts that run_purge propagates it.
VENV_HOME="$tmpdir/venvs"
BIN_DIR="$tmpdir/bin"
XDG_CONFIG_HOME="$tmpdir/config"
XDG_DATA_HOME="$tmpdir/data"
mkdir -p "$VENV_HOME" "$BIN_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

/usr/bin/mkdir -p "$XDG_CONFIG_HOME/failure"

run_case() {
    local name="$1"
    local expected="$2"
    local mode="$3"

    case "$mode" in
        ghost-link)
            find() { return 71; }
            /usr/bin/python3() { return 0; }
            ;;
        cache)
            find() { 
                if [[ "$*" == *"-exec"* ]]; then return 73; fi
                return 0
            }
            ;;
    esac

    local actual=0
    if run_purge; then
        actual=0
    else
        actual=$?
    fi

    if (( actual == expected )); then
        printf '[PASS] %s: rc=%s\n' "$name" "$actual"
    else
        printf '[FAIL] %s: expected rc=%s, got rc=%s\n' "$name" "$expected" "$actual" >&2
        return 1
    fi
}

# The production function invokes /usr/bin/python3 directly, so the first case
# uses a PATH-independent failure at the ghost-link find operation.
find() {
    if [[ "$*" == *"-maxdepth 1 -type l -delete"* ]]; then
        return 71
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

# Re-extract is unnecessary; replace find with a cache-specific failure.
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
