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
[[ -f "$ROLLBACK_TARGET" ]] || fail "preexisting target was not restored after stage-commit failure"
grep -Fq 'preexisting-installation' "$ROLLBACK_TARGET" || fail "restored target contents do not match the preexisting installation"
[[ ! -e "$ROLLBACK_TARGET/4ndr0pac" ]] || fail "failed deployment payload remained at the target"
printf 'GUP PASS: target restoration survives stage-commit failure.\n'

printf 'GUP PASS: installer syntax, fail-closed payload rejection, clean dry-run, and non-mutation gates passed.\n'
