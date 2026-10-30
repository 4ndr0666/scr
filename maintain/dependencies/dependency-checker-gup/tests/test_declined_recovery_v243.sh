#!/usr/bin/env bash
# G5 (v2.4.3): a recovery rung that is NOT applied (unattended without -I,
# operator decline, protected/ignored blocker, removal failure) used to log
# "remains for the final report" but recorded nothing, so the final report
# showed only the missing dependency plus a generic `pacman -S --needed X`
# that provably fails. Now declined recoveries are recorded and reported with
# exact, scoped remediation.  SAFETY: the report never suggests a blanket
# --overwrite='*'.
# usage: test_declined_recovery_v243.sh <lib.sh>     exit 0 = all pass
LIB="${1:?lib path required}"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE="$(mktemp)"; trap 'rm -f "$LOGFILE"' EXIT
fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }
BLUE=""; OK=""; WARN=""; WARNING=""; RESET=""; CAT="[ACTION]"; GREEN=""; YELLOW=""; SKY_BLUE=""; MAGENTA=""
has() { [[ "$1" == *"$2"* ]]; }

# ---- A. conflict, unattended, no -I, scoped glob derived ----
scan_install_failure_segment() { printf 'asar\tconflict\t/usr/lib/node_modules/asar/node_modules/*\n'; }
run_pacman_install() { return 1; }
INTERACTIVE_MODE=false; FORCE_HEAL_ALL=false
RECOVERY_OVERWRITE_APPLIED=(); RECOVERY_RDD_REMOVED_PKGS=()
RECOVERY_DECLINED_CONFLICTS=(); RECOVERY_DECLINED_BLOCKERS=()
attempt_conflict_overwrite_retry 0 pacman -S --needed --noconfirm asar >/dev/null 2>&1 && bad "A: retry unexpectedly ran" || true
out="$(report_recovery_outcome 2>&1)"
has "$out" "sudo pacman -S --noconfirm --overwrite '/usr/lib/node_modules/asar/node_modules/*' asar" && ok "A: exact scoped remediation printed" || bad "A: no scoped remediation: $out"
has "$out" "-I" && ok "A: names -I as the authorization path" || bad "A: -I not named"
has "$out" 'overwrite "*"' || has "$out" "overwrite '*'" || has "$out" 'overwrite="*"' && bad "A: blanket overwrite suggested" || ok "A: no blanket overwrite suggested"

# ---- B. conflict, -I, NO derivable scope (shallow path) ----
scan_install_failure_segment() { printf 'shallow\tconflict\t\n'; }
INTERACTIVE_MODE=false; FORCE_HEAL_ALL=true
RECOVERY_DECLINED_CONFLICTS=()
attempt_conflict_overwrite_retry 0 pacman -S shallow >/dev/null 2>&1 && bad "B: retry unexpectedly ran" || true
out="$(report_recovery_outcome 2>&1)"
has "$out" "shallow" && has "$out" "no safe overwrite scope" && ok "B: no-scope case explained" || bad "B: $out"
has "$out" "$LOGFILE" && ok "B: points at the log holding the conflicting paths" || bad "B: log path missing"
has "$out" "overwrite='*'" || has "$out" 'overwrite "*"' || has "$out" "overwrite '*'" && bad "B: blanket overwrite suggested" || ok "B: no blanket overwrite suggested"

# ---- C/D/E. blockers: unattended, protected, ignored ----
extract_transaction_blockers() { printf 'python-thefuzz\nglibc\nignoredpkg\n'; }
INSTALLED_PKGS=([python-thefuzz]=1 [glibc]=1 [ignoredpkg]=1 [newm]=1)
PACKAGE_DEPENDS=([newm]="python-thefuzz  python  glibc")
is_protected_base_pkg() { [[ "$1" == "glibc" ]]; }
is_ignored() { [[ "$1" == "ignoredpkg" ]]; }
RECOVERY_RDD_PKGS_USED=0; RECOVERY_DECLINED_BLOCKERS=(); RECOVERY_DECLINED_CONFLICTS=()
INTERACTIVE_MODE=false; FORCE_HEAL_ALL=false
attempt_blocker_removal_chain 0 pacman -S python-newdep >/dev/null 2>&1 && bad "C: chain unexpectedly ran" || true
out="$(report_recovery_outcome 2>&1)"
has "$out" "python-thefuzz [unattended]" && has "$out" "required by: newm" && ok "C: unattended blocker listed with its dependants" || bad "C: $out"
has "$out" "glibc [protected]" && ok "D: protected base member listed as never auto-removed" || bad "D: $out"
has "$out" "ignoredpkg [ignored]" && ok "E: ignore-listed blocker listed" || bad "E: $out"
has "$out" "pacman -Rdd python-thefuzz" && ok "C: chain command shown for the actionable blocker" || bad "C: chain command missing"
[[ "$out" != *"pacman -Rdd glibc"* && "$out" != *"pacman -Rdd ignoredpkg"* ]] && ok "D/E: protected/ignored never offered for -Rdd" || bad "D/E: offered -Rdd for protected/ignored"

# ---- H. dedupe + I. rc 0 ----
RECOVERY_DECLINED_BLOCKERS+=("python-thefuzz"$'\t'"unattended")
out="$(report_recovery_outcome 2>&1)"; n="$(grep -c 'python-thefuzz \[unattended\]' <<<"$out" || true)"
[[ "$n" -eq 1 ]] && ok "H: duplicate rows listed once" || bad "H: listed $n times"
rc=0; report_recovery_outcome >/dev/null 2>&1 || rc=$?; [[ $rc -eq 0 ]] && ok "I: report returns 0" || bad "I: rc=$rc"

# ---- F. nothing recorded -> silent (superset) ----
RECOVERY_OVERWRITE_APPLIED=(); RECOVERY_RDD_REMOVED_PKGS=(); RECOVERY_DECLINED_CONFLICTS=(); RECOVERY_DECLINED_BLOCKERS=()
out="$(report_recovery_outcome 2>&1)"; [[ -z "$out" ]] && ok "F: empty state -> no output (unchanged)" || bad "F: output: $out"

# ---- G. applied-only output is byte-identical to the v2.4.2 format ----
RECOVERY_OVERWRITE_APPLIED=("asar: scoped (/usr/lib/node_modules/asar/node_modules/*)")
out="$(report_recovery_outcome 2>&1)"
want=$'Transaction recovery actions this run:\n--overwrite retry applied (1):\n  asar: scoped (/usr/lib/node_modules/asar/node_modules/*)\n'
[[ "$out" == "${want%$'\n'}" ]] && ok "G: applied-only output unchanged, no declined block" || bad "G: $(printf %q "$out")"
exit $fail
