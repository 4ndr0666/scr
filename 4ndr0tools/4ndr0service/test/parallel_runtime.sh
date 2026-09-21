#!/usr/bin/env bash
set -euo pipefail

repo_root="${GUP_REPO_ROOT:-$(command git rev-parse --show-toplevel)}"
common="$repo_root/4ndr0tools/4ndr0service/common.sh"

tmpdir="$(command mktemp -d)"
cleanup() {
    command rm -rf -- "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

command awk '
    /^run_parallel_checks\(\)[[:space:]]*\{/ { capture=1 }
    capture { print }
    capture && /^}$/ { exit }
' "$common" >"$tmpdir/run_parallel_checks.sh"

grep -q '^run_parallel_checks()' "$tmpdir/run_parallel_checks.sh"

cat >>"$tmpdir/run_parallel_checks.sh" <<'EOF'

log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN] %s\n' "$*" >&2; }

worker_ok() { return 0; }
worker_fail() { return 7; }
EOF

cat >"$tmpdir/proof.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$1"

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

    if [[ "$actual" -eq "$expected" ]]; then
        printf '[PASS] %s: rc=%s\n' "$name" "$actual"
        ((pass+=1))
    else
        printf '[FAIL] %s: expected rc=%s, got rc=%s\n' "$name" "$expected" "$actual" >&2
        ((fail+=1))
    fi
}

check_rc 'all workers succeed' 0 run_parallel_checks worker_ok worker_ok
check_rc 'worker failure propagates' 1 run_parallel_checks worker_ok worker_fail
check_rc 'missing worker propagates' 1 run_parallel_checks worker_ok missing_worker
check_rc 'all workers missing fails' 1 run_parallel_checks missing_a missing_b

printf '\nGUPv5.3.1 parallel runtime proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
EOF

command chmod 700 "$tmpdir/proof.sh"
command bash "$tmpdir/proof.sh" "$tmpdir/run_parallel_checks.sh"
printf '[PASS] Isolated run_parallel_checks() runtime proof\n'
