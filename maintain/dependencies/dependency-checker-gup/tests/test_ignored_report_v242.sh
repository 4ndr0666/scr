#!/usr/bin/env bash
source ./deps242_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_ign.log; : > "$LOGFILE"
NOTE=""; RESET=""
ok=0; bad=0
chk() { if [[ "$2" == "$3" ]]; then echo "PASS: $1"; ok=$((ok+1)); else echo "FAIL: $1 (got: $2 | want: $3)"; bad=$((bad+1)); fi; }

echo "== A. the ignore-skip site records the package (was: recorded nowhere) =="
run_command() { CMD_OUTPUT=""; return 1; }     # no base/base-devel group members
is_ignored() { [[ "$1" == "filesystem" ]]; }
HEAL_IGNORED_BROKEN_PKGS=(); HEAL_IGNORED_BROKEN_LABELS=()
HEAL_UNHEALED_OFFICIAL_PKGS=(); HEAL_UNHEALED_AUR_PKGS=(); HEAL_UNHEALED_UNKNOWN_PKGS=()
_heal_package_batch verified-missing-files filesystem >/dev/null 2>&1; rc=$?
chk "batch still returns 0 when nothing is actionable" "$rc" "0"
chk "package recorded" "${HEAL_IGNORED_BROKEN_PKGS[*]:-<none>}" "filesystem"
chk "audit class recorded" "${HEAL_IGNORED_BROKEN_LABELS[*]:-<none>}" "verified-missing-files"
chk "NOT counted as outstanding debt (verdict wording unchanged)" "$(( ${#HEAL_UNHEALED_OFFICIAL_PKGS[@]} + ${#HEAL_UNHEALED_AUR_PKGS[@]} + ${#HEAL_UNHEALED_UNKNOWN_PKGS[@]} ))" "0"

echo "== B. report: dedupe, per-class diagnosis, 5-package bound =="
diag_calls=()
diagnose_persistent_breakage() { diag_calls+=("$1|$2"); }
HEAL_IGNORED_BROKEN_PKGS=(filesystem filesystem python-thefuzz a b c d e f)
HEAL_IGNORED_BROKEN_LABELS=(verified-missing-files verified-missing-files stale-python-dir verified-missing-files verified-missing-files verified-missing-files verified-missing-files verified-missing-files verified-missing-files)
report_ignored_broken_findings > /tmp/ign_out.txt 2>&1
out="$(cat /tmp/ign_out.txt)"
chk "duplicate listed once" "$({ grep -c '^  filesystem ' <<<"$out" || true; })" "1"
chk "stale-python package listed" "$({ grep -c 'python-thefuzz (stale-python-dir)' <<<"$out" || true; })" "1"
chk "stale-python class never diagnosed" "$({ printf '%s\n' "${diag_calls[@]}" | { grep -c 'python-thefuzz' || true; }; })" "0"
chk "diagnosis bounded to 5" "${#diag_calls[@]}" "5"
chk "diagnosis told no heal was attempted" "$({ printf '%s\n' "${diag_calls[@]}" | { grep -c 'ignored — no heal attempted' || true; }; })" "5"

echo "== C. empty -> silent (superset: runs with no ignored-broken packages are unchanged) =="
HEAL_IGNORED_BROKEN_PKGS=(); HEAL_IGNORED_BROKEN_LABELS=()
chk "no output when empty" "$(report_ignored_broken_findings 2>&1 | wc -c)" "0"

echo "== D. wiring at BOTH main() exits =="
body="$(sed -n '/^main()/,/^}/p' deps242.sh)"
chk "call sites in main()" "$({ grep -c '^\s*report_ignored_broken_findings$' <<<"$body" || true; })" "2"
chk "each directly follows report_recovery_outcome" "$({ grep -A1 '^\s*report_recovery_outcome$' <<<"$body" | { grep -c 'report_ignored_broken_findings' || true; }; })" "2"
echo "passed=$ok failed=$bad"
