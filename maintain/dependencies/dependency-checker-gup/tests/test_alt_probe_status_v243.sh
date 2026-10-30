#!/usr/bin/env bash
# G2 (v2.4.3): compute_missing_dependencies must hard-error on an unrecognized
# `pacman -T` exit code during ALTERNATIVE ('a|b') probing — v2.0.0 semantics,
# silently lost since v2.3.2 (`dep_status=$?` read after an `if ... fi`, always 0).
# usage: test_alt_probe_status_v243.sh <lib.sh>     exit 0 = all pass
LIB="${1:?lib path required}"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE="$(mktemp)"; ERRF="$(mktemp)"; trap 'rm -f "$LOGFILE" "$ERRF"' EXIT
fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }

parse_target_dependencies() { printf '%s\n' 'alpha|beta'; }
is_ignored() { return 1; }
ALL_SYSTEM=false

# 1. unrecognized rc (99) on an alternative probe -> hard error (return 1), nothing queued
run_command() { CMD_OUTPUT=""; return 99; }
MISSING_DEPS_RESULT=(); rc=0
compute_missing_dependencies target >/dev/null 2>"$ERRF" || rc=$?
[[ $rc -eq 1 ]] && ok "rc 99 on alternative probe aborts the audit (return 1)" || bad "rc 99 swallowed (rc=$rc)"
[[ ${#MISSING_DEPS_RESULT[@]} -eq 0 ]] && ok "no phantom missing dependency queued after hard error" || bad "queued: ${MISSING_DEPS_RESULT[*]}"
grep -q 'alternative check failed with unrecognized exit code: 99\.' "$ERRF" && ok "error names the REAL exit code (99), not a clobbered 0" || bad "logged: $(grep 'alternative check' "$ERRF" | tail -1 || true)"

# 2. superset: rc 1 (not installed) on every alternative -> reported missing, return 0
run_command() { CMD_OUTPUT=""; return 1; }
MISSING_DEPS_RESULT=(); rc=0
compute_missing_dependencies target >/dev/null 2>&1 || rc=$?
[[ $rc -eq 0 && "${MISSING_DEPS_RESULT[*]}" == "alpha|beta" ]] && ok "rc 1 on all alternatives -> missing, return 0 (unchanged)" || bad "rc=$rc result=${MISSING_DEPS_RESULT[*]:-}"

# 3. superset: rc 127 (pacman -T 'not satisfied' code on some builds) behaves like rc 1
run_command() { CMD_OUTPUT=""; return 127; }
MISSING_DEPS_RESULT=(); rc=0
compute_missing_dependencies target >/dev/null 2>&1 || rc=$?
[[ $rc -eq 0 && "${MISSING_DEPS_RESULT[*]}" == "alpha|beta" ]] && ok "rc 127 treated as not-installed (unchanged)" || bad "rc=$rc result=${MISSING_DEPS_RESULT[*]:-}"

# 4. superset: first alternative satisfied (rc 0) -> not missing
run_command() { CMD_OUTPUT=""; return 0; }
MISSING_DEPS_RESULT=(); rc=0
compute_missing_dependencies target >/dev/null 2>&1 || rc=$?
[[ $rc -eq 0 && ${#MISSING_DEPS_RESULT[@]} -eq 0 ]] && ok "satisfied alternative -> nothing missing (unchanged)" || bad "rc=$rc result=${MISSING_DEPS_RESULT[*]:-}"

exit $fail
