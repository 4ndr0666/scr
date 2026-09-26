#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ── SUITE DIR RESOLUTION (GAP-F FIX) ──────────────────────────────────────────
# Dual-layout: honor GUP_REPO_ROOT when it targets the legacy 4ndr0tools/
# layout (the original dotfiles repo), else self-resolve — this file lives at
# <suite>/test/, so the suite root is one dirname up. The proofs now run from
# both repository layouts with no CI env hints and no git dependency.
_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
if [[ -n "${GUP_REPO_ROOT:-}" && -f "$GUP_REPO_ROOT/4ndr0tools/4ndr0service/common.sh" ]]; then
    SUITE_DIR="$GUP_REPO_ROOT/4ndr0tools/4ndr0service"
else
    SUITE_DIR="$(dirname -- "$_TEST_DIR")"
fi
controller="$SUITE_DIR/controller.sh"
tmp="$(command mktemp -d)"
cleanup() { command rm -rf -- "$tmp"; }
trap cleanup EXIT INT TERM HUP

command mkdir -p "$tmp/service" "$tmp/plugins" "$tmp/cache"

command cat >"$tmp/common.sh" <<'STUB'
set -euo pipefail
log_info() { command printf '[INFO] %s\n' "$*"; }
log_warn() { command printf '[WARN] %s\n' "$*" >&2; }
log_error() { command printf '[ERROR] %s\n' "$*" >&2; }
log_success() { command printf '[OK] %s\n' "$*"; }
handle_error() { return "${3:-1}"; }
ensure_dir() { command mkdir -p -- "$1"; }
path_prepend() { :; }
install_sys_pkg() { :; }
run_parallel_checks() { return 0; }
export XDG_CACHE_HOME="$PWD"
STUB
: >"$tmp/settings_functions.sh"
: >"$tmp/manage_files.sh"

command cat >"$tmp/service/optimize_good.sh" <<'STUB'
optimize_good_service() { return 0; }
STUB

command cat >"$tmp/service/optimize_bad_source.sh" <<'STUB'
return 23
STUB

command cat >"$tmp/service/optimize_fail.sh" <<'STUB'
optimize_fail_service() { return 17; }
STUB

run_case() {
    local name="$1"
    local expected="$2"
    shift 2
    local actual=0
    if "$@"; then
        actual=0
    else
        actual=$?
    fi
    if [[ "$actual" -ne "$expected" ]]; then
        command printf '[FAIL] %s: expected rc=%s got rc=%s\n' "$name" "$expected" "$actual" >&2
        return 1
    fi
    command printf '[PASS] %s: rc=%s\n' "$name" "$actual"
}

run_controller_test() {
    export PKG_PATH="$tmp"
    export PLUGINS_DIR="$tmp/plugins"
    export USER_INTERFACE=cli

    # Source production controller; every dependency resolves to disposable stubs.
    source "$controller"

    run_case 'source_all_services aggregates source failure' 1 source_all_services
    command rm -f -- "$tmp/service/optimize_bad_source.sh"

    run_case 'run_all_services propagates service failure' 1 run_all_services
}

run_controller_test
command printf '\nGUPv5.3.1 controller runtime proof: PASS\n'
