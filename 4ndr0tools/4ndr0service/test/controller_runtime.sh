#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo="${GUP_REPO_ROOT:?GUP_REPO_ROOT must point to the repository root}"
controller="$repo/4ndr0tools/4ndr0service/controller.sh"
tmp="$(mktemp -d)"
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT INT TERM HUP

mkdir -p "$tmp/service" "$tmp/plugins" "$tmp/cache"

cat >"$tmp/common.sh" <<'STUB'
set -euo pipefail
log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_success() { printf '[OK] %s\n' "$*"; }
handle_error() { return "${3:-1}"; }
ensure_dir() { mkdir -p -- "$1"; }
path_prepend() { :; }
install_sys_pkg() { :; }
run_parallel_checks() { return 0; }
export XDG_CACHE_HOME="$PWD"
STUB
: >"$tmp/settings_functions.sh"
: >"$tmp/manage_files.sh"

cat >"$tmp/service/optimize_good.sh" <<'STUB'
optimize_good_service() { return 0; }
STUB

cat >"$tmp/service/optimize_bad_source.sh" <<'STUB'
return 23
STUB

cat >"$tmp/service/optimize_fail.sh" <<'STUB'
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
        printf '[FAIL] %s: expected rc=%s got rc=%s\n' "$name" "$expected" "$actual" >&2
        return 1
    fi
    printf '[PASS] %s: rc=%s\n' "$name" "$actual"
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
printf '\nGUPv5.3.1 controller runtime proof: PASS\n'
