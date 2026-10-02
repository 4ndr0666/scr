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
sudo "$PAYLOAD/install.sh" --dry-run --path "$TEST_ROOT/target" >"$CONTAMINATED_LOG" 2>&1
CONTAMINATED_RC=$?
set -e

[[ "$CONTAMINATED_RC" -ne 0 ]] || fail "contaminated payload was accepted"
grep -Fq 'Generated or transient artifact present in payload tree:' "$CONTAMINATED_LOG" ||
    fail "contaminated payload rejection was not reported"
[[ ! -e "$TEST_ROOT/target" ]] || fail "failed dry-run created an installation target"

rm -f -- "$PAYLOAD/__generated_sentinel.pyc" "$PAYLOAD/__pycache__/sentinel.pyc"
rm -rf -- "$PAYLOAD/__pycache__"

CLEAN_LOG="$TEST_ROOT/clean.log"
sudo "$PAYLOAD/install.sh" --dry-run --path "$TEST_ROOT/target" >"$CLEAN_LOG" 2>&1 ||
    fail "clean payload dry-run failed"
[[ ! -e "$TEST_ROOT/target" ]] || fail "clean dry-run created an installation target"

if find "$PAYLOAD" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.bak' -o -name '.coverage' \) -print -quit | grep -q .; then
    fail "generated file remained after validation"
fi
if find "$PAYLOAD" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -print -quit | grep -q .; then
    fail "generated directory remained after validation"
fi

printf 'GUP PASS: installer syntax, fail-closed payload rejection, clean dry-run, and non-mutation gates passed.\n'
