#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$ROOT_DIR/install.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0pac-installer-gup.XXXXXXXX")"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'GUP INSTALLER FAIL: %s\n' "$1" >&2
    exit 1
}

bash -n "$INSTALLER" || fail "installer syntax check failed"

PAYLOAD="$TEST_ROOT/payload"
cp -a "$ROOT_DIR/." "$PAYLOAD"

if find "$PAYLOAD" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.bak' -o -name '.coverage' \) -print -quit | grep -q .; then
    fail "baseline payload already contains generated artifacts"
fi
if find "$PAYLOAD" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -print -quit | grep -q .; then
    fail "baseline payload already contains generated directories"
fi

printf '%s\n' 'generated' > "$PAYLOAD/__generated_sentinel.pyc"
mkdir -p "$PAYLOAD/__pycache__"
printf '%s\n' 'generated' > "$PAYLOAD/__pycache__/sentinel.pyc"

CONTAMINATED_LOG="$TEST_ROOT/contaminated.log"
set +e
sudo "$PAYLOAD/install.sh" --dry-run --path "$TEST_ROOT/target" 2>&1 |
    tee "$CONTAMINATED_LOG" >/dev/null
CONTAMINATED_RC=$?
set -e

[[ "$CONTAMINATED_RC" -ne 0 ]] || fail "contaminated payload was accepted"
grep -Fq 'Generated or transient artifact present in payload tree:' "$CONTAMINATED_LOG" ||
    fail "contaminated payload rejection was not reported"
[[ ! -e "$TEST_ROOT/target" ]] || fail "failed dry-run created an installation target"

rm -f -- "$PAYLOAD/__generated_sentinel.pyc" "$PAYLOAD/__pycache__/sentinel.pyc"
rm -rf -- "$PAYLOAD/__pycache__"

CLEAN_LOG="$TEST_ROOT/clean.log"
sudo "$PAYLOAD/install.sh" --dry-run --path "$TEST_ROOT/target" 2>&1 |
    tee "$CLEAN_LOG" >/dev/null ||
    fail "clean payload dry-run failed"
[[ ! -e "$TEST_ROOT/target" ]] || fail "clean dry-run created an installation target"

if find "$PAYLOAD" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.bak' -o -name '.coverage' \) -print -quit | grep -q .; then
    fail "generated file remained after validation"
fi
if find "$PAYLOAD" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -print -quit | grep -q .; then
    fail "generated directory remained after validation"
fi


ROLLBACK_TARGET="$TEST_ROOT/rollback-target"
mkdir -p "$ROLLBACK_TARGET"
printf '%s\n' 'preexisting-installation' > "$ROLLBACK_TARGET/sentinel"
SHIM_DIR="$TEST_ROOT/mv-shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/mv" <<'MVSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
FAIL_TARGET="${GUP_FAIL_TARGET:?}"
STATE_FILE="${GUP_FAIL_STATE:?}"
DEST="${@: -1}"
if [[ "$DEST" == "$FAIL_TARGET" && ! -e "$STATE_FILE" ]]; then
    : > "$STATE_FILE"
    printf 'GUP INJECT: refusing stage commit into %s\n' "$DEST" >&2
    exit 73
fi
exec /usr/bin/mv "$@"
MVSHIM
chmod 0755 "$SHIM_DIR/mv"
ROLLBACK_LOG="$TEST_ROOT/rollback.log"
ROLLBACK_STATE="$TEST_ROOT/mv-failed"
set +e
sudo env PATH="$SHIM_DIR:$PATH" GUP_FAIL_TARGET="$ROLLBACK_TARGET" GUP_FAIL_STATE="$ROLLBACK_STATE" \
    "$PAYLOAD/install.sh" --path "$ROLLBACK_TARGET" 2>&1 |
    tee "$ROLLBACK_LOG" >/dev/null
ROLLBACK_RC=$?
set -e
[[ "$ROLLBACK_RC" -eq 73 ]] || fail "controlled stage-commit failure did not propagate as exit 73"
grep -Fq 'Rolling back committed filesystem changes' "$ROLLBACK_LOG" || fail "rollback was not entered"
[[ -d "$ROLLBACK_TARGET" ]] || fail "preexisting target was not restored after stage-commit failure"
grep -Fq 'preexisting-installation' "$ROLLBACK_TARGET/sentinel" || fail "restored target contents do not match the preexisting installation"
[[ ! -e "$ROLLBACK_TARGET/4ndr0pac" ]] || fail "failed deployment payload remained at the target"

FAIL_CLOSED_TARGET="$TEST_ROOT/fail-closed-target"
mkdir -p "$FAIL_CLOSED_TARGET"
printf '%s\n' 'preserve-me' > "$FAIL_CLOSED_TARGET/sentinel"
FAIL_CLOSED_SHIM="$TEST_ROOT/fail-closed-shim"
mkdir -p "$FAIL_CLOSED_SHIM"
cat > "$FAIL_CLOSED_SHIM/mv" <<'MVSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
FAIL_TARGET="${GUP_FAIL_TARGET:?}"
COUNT_FILE="${GUP_FAIL_COUNT:?}"
DEST="${@: -1}"
count=0
[[ -f "$COUNT_FILE" ]] && count="$(<"$COUNT_FILE")"
if [[ "$DEST" == "$FAIL_TARGET" ]]; then
    count=$((count + 1))
    printf '%s\n' "$count" > "$COUNT_FILE"
    if ((count >= 2)); then
        printf 'GUP INJECT: refusing rollback restoration into %s\n' "$DEST" >&2
        exit 74
    fi
fi
exec /usr/bin/mv "$@"
MVSHIM
cat > "$FAIL_CLOSED_SHIM/ln" <<'LNSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'GUP INJECT: refusing invocation-link creation\n' >&2
exit 75
LNSHIM
chmod 0755 "$FAIL_CLOSED_SHIM/mv" "$FAIL_CLOSED_SHIM/ln"
FAIL_CLOSED_LOG="$TEST_ROOT/fail-closed.log"
FAIL_CLOSED_COUNT="$TEST_ROOT/fail-closed-count"
set +e
sudo env PATH="$FAIL_CLOSED_SHIM:$PATH" GUP_FAIL_TARGET="$FAIL_CLOSED_TARGET" GUP_FAIL_COUNT="$FAIL_CLOSED_COUNT" \
    "$PAYLOAD/install.sh" --path "$FAIL_CLOSED_TARGET" 2>&1 |
    tee "$FAIL_CLOSED_LOG" >/dev/null
FAIL_CLOSED_RC=$?
set -e
[[ "$FAIL_CLOSED_RC" -ne 0 ]] || fail "rollback-restoration failure was not propagated"
grep -Fq 'Rollback could not restore the previous installation; backup retained at ' "$FAIL_CLOSED_LOG" || fail "rollback restoration failure was not reported"
BACKUP_PATH="$(sed -n 's/.*backup retained at //p' "$FAIL_CLOSED_LOG" | tail -n 1)"
[[ -n "$BACKUP_PATH" && -e "$BACKUP_PATH/payload/sentinel" ]] || fail "rollback backup was not retained after restoration failure"
[[ ! -e "$FAIL_CLOSED_TARGET" ]] || fail "failed target remained after rollback restoration failure"
printf 'GUP PASS: rollback restoration failure is fail-closed and preserves recovery artifacts.\n'

printf 'GUP PASS: target restoration survives stage-commit failure.\n'

printf 'GUP PASS: installer syntax, fail-closed payload rejection, clean dry-run, and non-mutation gates passed.\n'
