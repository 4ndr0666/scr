#!/usr/bin/env bash
# File: test/source_safety_runtime.sh
# Description: Isolated runtime proof that ascension.sh and purge_matrix.sh can
# be sourced (as view/cli.sh, view/dialog.sh and verify_environment.sh
# _provision_hive() do) WITHOUT executing their standalone argument dispatch.
#
# GAP-A/GAP-B regression proof: before the standalone bootstrap guards were
# added, `source ascension.sh` from a no-argument session executed
# `show_usage; exit 0` — terminating the entire CLI menu — and from a
# session carrying inherited parameters (e.g. main.sh --fix --report) hit the
# `*)` branch and exited 1, killing the systemd audit mid-run. The same applied
# to purge_matrix.sh. This proof pins both contracts:
#   1. Sourcing is non-terminal: the shell survives, functions are defined,
#      and no dispatch output is produced.
#   2. Direct execution is unchanged: no args -> usage + rc 0; unknown
#      vector -> usage + rc 1.
#
# GUPv5.3.1: each case runs in a disposable child bash process so the real
# production mutex acquired by common.sh is always released (child exit).

set -euo pipefail
IFS=$'\n\t'

# ── SUITE DIR RESOLUTION ──────────────────────────────────────────────────────
# Prefer GUP_REPO_ROOT when it points at the legacy 4ndr0tools layout; else
# self-resolve: this file lives at <suite>/test/, so the suite root is one
# dirname up. Works for both repository layouts without CI env hints.
_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
if [[ -n "${GUP_REPO_ROOT:-}" && -f "$GUP_REPO_ROOT/4ndr0tools/4ndr0service/common.sh" ]]; then
    SUITE_DIR="$GUP_REPO_ROOT/4ndr0tools/4ndr0service"
else
    SUITE_DIR="$(dirname -- "$_TEST_DIR")"
fi

ASCENSION="$SUITE_DIR/ascension.sh"
PURGE="$SUITE_DIR/purge_matrix.sh"

[[ -f "$ASCENSION" ]] || { printf '[FATAL] ascension.sh not found: %s\n' "$ASCENSION" >&2; exit 2; }
[[ -f "$PURGE" ]] || { printf '[FATAL] purge_matrix.sh not found: %s\n' "$PURGE" >&2; exit 2; }

pass=0
fail=0
pass_case() { printf '[PASS] %s\n' "$1"; ((pass++)) || true; }
fail_case() { printf '[FAIL] %s\n' "$1" >&2; ((fail++)) || true; }

# ── CASE 1: source ascension.sh with NO positional parameters ─────────────────
# The sourcing shell must survive, define the payload functions, and emit no
# usage text (dispatch not entered).
rc1_out="$(bash -c '
    set -euo pipefail
    source "$1"
    [[ $(declare -F | command grep -c "^declare -f \(run_sync\|install_resilient_tool\|remove_hive_tool\|list_hive_tools\|clean_pip_ghosts\)$") -eq 5 ]] || exit 10
    printf "SURVIVED"
' _ "$ASCENSION" 2>&1)" || rc1=$? || rc1=0
if [[ "${rc1_out}" == "SURVIVED" && "${rc1:-0}" -eq 0 ]]; then
    pass_case 'source ascension.sh (no args) is non-terminal and defines payload'
else
    fail_case "source ascension.sh (no args) survived incorrectly (rc=${rc1:-?}, out=${rc1_out:0:80})"
fi
unset rc1 rc1_out 2>/dev/null || true

# ── CASE 2: source ascension.sh WITH inherited parameters (systemd shape) ─────
# main.sh --fix --report sources-adjacent flows must not hit the `*)` branch.
rc2_out="$(bash -c '
    set -euo pipefail
    p="$1"
    set -- --fix --report
    source "$p"
    printf "SURVIVED"
' _ "$ASCENSION" 2>&1)" || rc2=$? || rc2=0
if [[ "${rc2_out}" == "SURVIVED" && "${rc2:-0}" -eq 0 ]]; then
    pass_case 'source ascension.sh (inherited --fix --report) is non-terminal'
else
    fail_case "source ascension.sh (inherited args) survived incorrectly (rc=${rc2:-?}, out=${rc2_out:0:80})"
fi
unset rc2 rc2_out 2>/dev/null || true

# ── CASE 3: source purge_matrix.sh with NO positional parameters ──────────────
rc3_out="$(bash -c '
    set -euo pipefail
    source "$1"
    declare -F run_purge >/dev/null || exit 10
    printf "SURVIVED"
' _ "$PURGE" 2>&1)" || rc3=$? || rc3=0
if [[ "${rc3_out}" == "SURVIVED" && "${rc3:-0}" -eq 0 ]]; then
    pass_case 'source purge_matrix.sh (no args) is non-terminal and defines run_purge'
else
    fail_case "source purge_matrix.sh (no args) survived incorrectly (rc=${rc3:-?}, out=${rc3_out:0:80})"
fi
unset rc3 rc3_out 2>/dev/null || true

# ── CASE 4: source purge_matrix.sh with an inherited unknown option ───────────
rc4_out="$(bash -c '
    set -euo pipefail
    p="$1"
    set -- --bogus
    source "$p"
    printf "SURVIVED"
' _ "$PURGE" 2>&1)" || rc4=$? || rc4=0
if [[ "${rc4_out}" == "SURVIVED" && "${rc4:-0}" -eq 0 ]]; then
    pass_case 'source purge_matrix.sh (inherited unknown option) is non-terminal'
else
    fail_case "source purge_matrix.sh (inherited args) survived incorrectly (rc=${rc4:-?}, out=${rc4_out:0:80})"
fi
unset rc4 rc4_out 2>/dev/null || true

# ── CASE 5: direct execution contracts are preserved ──────────────────────────
set +e
out5="$(bash "$ASCENSION" 2>&1)"; rc5=$?
set -e
if [[ $rc5 -eq 0 && "$out5" == *"Usage:"* ]]; then
    pass_case 'direct ascension.sh (no args) still shows usage and exits 0'
else
    fail_case "direct ascension.sh (no args) contract changed (rc=$rc5)"
fi

set +e
bash "$ASCENSION" --definitely-not-a-vector >/dev/null 2>&1; rc6=$?
set -e
if [[ $rc6 -eq 1 ]]; then
    pass_case 'direct ascension.sh (unknown vector) still exits 1'
else
    fail_case "direct ascension.sh (unknown vector) contract changed (rc=$rc6)"
fi

set +e
out7="$(bash "$PURGE" 2>&1)"; rc7=$?
set -e
if [[ $rc7 -eq 0 && "$out7" == *"Usage:"* ]]; then
    pass_case 'direct purge_matrix.sh (no args) still shows usage and exits 0'
else
    fail_case "direct purge_matrix.sh (no args) contract changed (rc=$rc7)"
fi

set +e
bash "$PURGE" --bogus >/dev/null 2>&1; rc8=$?
set -e
if [[ $rc8 -eq 1 ]]; then
    pass_case 'direct purge_matrix.sh (unknown option) still exits 1'
else
    fail_case "direct purge_matrix.sh (unknown option) contract changed (rc=$rc8)"
fi

printf '\nGUPv5.3.1 source-safety runtime proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
