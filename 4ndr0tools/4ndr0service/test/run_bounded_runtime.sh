#!/usr/bin/env bash
# File: test/run_bounded_runtime.sh
# Description: Isolated runtime proof for common.sh::run_bounded().
# GUPv5.3.1: This harness extracts only the target unit from common.sh and
# executes it in a disposable Bash process. It does not source common.sh,
# acquire the production mutex, initialize XDG state, invoke pacman/sudo,
# start/stop services, or execute the installer.

set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd -- "$(command dirname -- "${BASH_SOURCE[0]}")/../../.." && command pwd -P)"
common="$repo_root/4ndr0tools/4ndr0service/common.sh"

[[ -r "$common" ]] || {
    command printf '[FAIL] common.sh not readable: %s\n' "$common" >&2
    exit 1
}

# Extract by stable source-section boundaries rather than brace counting. This
# deliberately avoids executing or parsing unrelated production initialization.
unit_file="$(command mktemp)"
child_pid=""

cleanup() {
    if [[ -n "$child_pid" ]]; then
        kill -KILL "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi
    command rm -f -- "$unit_file"
}
trap cleanup EXIT HUP INT TERM

command awk '
    /^run_bounded\(\)[[:space:]]*\{$/ { capture=1 }
    /^# Execute multiple functions in parallel and wait for all to complete\./ {
        if (capture) exit
    }
    capture { print }
' "$common" >"$unit_file"

[[ -s "$unit_file" ]] || {
    command printf '[FAIL] Could not extract run_bounded() from %s\n' "$common" >&2
    exit 1
}

command grep -q '^run_bounded()' "$unit_file"
command grep -q '^}$' "$unit_file"

# Execute the extracted unit in a clean Bash process. Only the minimum logging
# interface consumed by run_bounded() is supplied.
child_status=0
command bash --noprofile --norc -s "$unit_file" <<'CHILD' &
set -euo pipefail
IFS=$'\n\t'

unit_file="$1"
source "$unit_file"

log_info() {
    command printf '[INFO] %s\n' "$*"
}

log_error() {
    command printf '[ERROR] %s\n' "$*" >&2
}

run_case() {
    local name="$1"
    local expected="$2"
    shift 2

    local actual
    if "$@"; then
        actual=0
    else
        actual=$?
    fi

    if [[ "$actual" -eq "$expected" ]]; then
        command printf '[PASS] %s: rc=%s\n' "$name" "$actual"
        return 0
    fi

    command printf '[FAIL] %s: expected rc=%s, got rc=%s\n' \
        "$name" "$expected" "$actual" >&2
    return 1
}

pass=0
fail=0

if run_case 'successful command' 0 run_bounded 5 'true' true; then ((pass+=1)); else ((fail+=1)); fi
if run_case 'ordinary failure preserves rc' 7 run_bounded 5 'exit-7' command bash -c 'exit 7'; then ((pass+=1)); else ((fail+=1)); fi
if run_case 'timeout returns 124' 124 run_bounded 1 'sleep-timeout' command sleep 5; then ((pass+=1)); else ((fail+=1)); fi
if run_case 'invalid timeout rejected' 2 run_bounded 0 'invalid-timeout' true; then ((pass+=1)); else ((fail+=1)); fi
if run_case 'missing command rejected' 2 run_bounded 5 'missing-command'; then ((pass+=1)); else ((fail+=1)); fi
if run_case 'TERM-resistant process reaches KILL' 137 run_bounded 1 'term-resistant' command bash -c 'trap "" TERM; command sleep 30'; then ((pass+=1)); else ((fail+=1)); fi

command printf '\nGUPv5.3.1 runtime proof: %d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
CHILD
child_pid=$!

wait "$child_pid" || child_status=$?
child_pid=""

(( child_status == 0 )) || exit "$child_status"

command printf '[PASS] Isolated run_bounded() runtime proof\n'
