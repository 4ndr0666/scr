#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="$ROOT_DIR/4ndr0pac"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0pac-gup.XXXXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT

BACKEND="$TMP_DIR/fake-backend.sh"
LOG="$TMP_DIR/backend.log"
cat >"$BACKEND" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"$BACKEND_LOG"
exit 7
EOF
chmod 700 "$BACKEND"
export BACKEND_LOG="$LOG"

fail() {
    printf 'GUP FAIL: %s\n' "$1" >&2
    exit 1
}

run_expect() {
    local expected="$1"
    shift
    set +e
    "$@"
    local actual=$?
    set -e
    [[ "$actual" -eq "$expected" ]] || fail "expected exit $expected, got $actual: $*"
}

python3 -c 'from pathlib import Path; import ast, sys; ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8"), filename=sys.argv[1])' "$FRONTEND" || fail "frontend does not parse"
bash -n "$FRONTEND.sh" || fail "backend shell syntax check failed"
bash -n "$0" || fail "Golden Unit harness syntax check failed"
bash -n "$ROOT_DIR/gup_gap_scan.sh" || fail "backend gap scanner syntax check failed"
bash -n "$ROOT_DIR/gup_semantic_test.sh" || fail "backend semantic test syntax check failed"

LIST_OUTPUT="$(python3 "$FRONTEND" --backend "$BACKEND" --list)"
[[ "$(grep -c '\[confirm\]' <<<"$LIST_OUTPUT")" -eq 5 ]] || fail "dangerous directive inventory changed"

run_expect 130 bash -c 'printf "n\\n" | python3 "$1" --backend "$2" "Remove Packages"' _ "$FRONTEND" "$BACKEND"
[[ ! -s "$LOG" ]] || fail "backend executed after confirmation denial"

run_expect 7 bash -c 'printf "yes\\n" | python3 "$1" --backend "$2" "Remove Packages" pkg-a' _ "$FRONTEND" "$BACKEND"
[[ "$(tail -n 1 "$LOG")" == "r pkg-a" ]] || fail "confirmed dangerous directive reached backend incorrectly"

run_expect 7 python3 "$FRONTEND" --backend "$BACKEND" "Package Info" pkg-a
[[ "$(tail -n 1 "$LOG")" == "p pkg-a" ]] || fail "safe directive did not propagate backend arguments"

LINES_BEFORE="$(wc -l <"$LOG")"
DRY_OUTPUT="$(python3 "$FRONTEND" --backend "$BACKEND" --dry-run "Remove Packages" pkg-a)"
[[ "$DRY_OUTPUT" == *"[dry-run]"* ]] || fail "dry-run did not report the command"
[[ "$(wc -l <"$LOG")" -eq "$LINES_BEFORE" ]] || fail "dry-run executed backend"

run_expect 130 bash -c 'printf "n\\n" | python3 "$1" --backend "$2" 6' _ "$FRONTEND" "$BACKEND"

CLEANUP_SENTINEL="/tmp/4ndr0pac-gup-cleanup-sentinel"
CLEANUP_SHIM="$TMP_DIR/cleanup-shim"
printf '%s\n' 'cleanup-sentinel' >"$CLEANUP_SENTINEL"
cat >"$CLEANUP_SHIM/rm" <<'RMSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
for arg in "$@"; do
    if [[ "$arg" == /tmp/4ndr0pac* ]]; then
        printf 'GUP INJECT: refusing temporary 4ndr0pac cleanup\n' >&2
        exit 79
    fi
done
exec /usr/bin/rm "$@"
RMSHIM
chmod 700 "$CLEANUP_SHIM/rm"
set +e
PATH="$CLEANUP_SHIM:$PATH" "$FRONTEND.sh" version >/dev/null 2>"$TMP_DIR/cleanup.log"
CLEANUP_RC=$?
set -e
/usr/bin/rm -f -- "$CLEANUP_SENTINEL"
[[ "$CLEANUP_RC" -eq 79 ]] || fail "cleanup failure did not propagate as exit 79"
grep -Fq 'Failed to remove temporary 4ndr0pac artifacts.' "$TMP_DIR/cleanup.log" ||
    fail "cleanup failure was not reported explicitly"
printf 'GUP PASS: temporary-artifact cleanup failure is fail-closed and reported.\n'

printf 'GUP PASS: 4ndr0pac safety boundary, argument propagation, dry-run, syntax, and cleanup gates passed.\n'
