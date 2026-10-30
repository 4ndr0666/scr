#!/usr/bin/env bash
# G7 (v2.4.3): report_heal_outcome printed "PGP keys that blocked AUR rebuilds
# (import manually ...)" with NO rows when the PGP-blocked packages had since
# healed but unrelated AUR packages were still broken.
# usage: test_pgp_header_v243.sh <lib.sh>     exit 0 = all pass
LIB="${1:?lib path required}"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE="$(mktemp)"; trap 'rm -f "$LOGFILE"' EXIT
fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }
BLUE=""; OK=""; WARN=""; WARNING=""; RESET=""; CAT="[ACTION]"; GREEN=""; YELLOW=""; SKY_BLUE=""; MAGENTA=""
reset_state() {
	HEAL_ATTEMPTED_OFFICIAL_PKGS=(); HEAL_ATTEMPTED_AUR_PKGS=(kirigami2 python-pywal pacaur sortphotos)
	HEAL_STILL_BROKEN_PKGS=(pacaur sortphotos); HEAL_STILL_BROKEN_SOURCES=(aur aur)
	HEAL_VERIFIED_CHECKED_COUNT=4; HEAL_VERIFIED_RESTORED_COUNT=2
	HEAL_STALE_UNRESOLVED_PKGS=()
	HEAL_AUR_FAIL_PKGS=(pacaur sortphotos); HEAL_AUR_FAIL_MODES=(build build); HEAL_AUR_FAIL_GLOBS=("" "")
	HEAL_AUR_PGP_KEYS=(53E6B47B45CEA3E0D5B7457758D0EE648A48B3BB 155DC67DC25496572CDD608FF635E931C2834999)
	HEAL_AUR_PGP_FAILURE_PKGS=(kirigami2 python-pywal)
	HEAL_OFFICIAL_FAIL_CONFLICT_PKGS=(); HEAL_OFFICIAL_FAIL_CONFLICT_GLOBS=()
	HEAL_UNHEALED_OFFICIAL_PKGS=(); HEAL_UNHEALED_AUR_PKGS=(); HEAL_UNHEALED_UNKNOWN_PKGS=(); HEAL_UNHEALED_REASONS=()
}

# 1. keys recorded for packages that have since healed -> no empty header
reset_state
out="$(report_heal_outcome 2>&1)"
[[ "$out" != *"PGP keys that blocked"* ]] && ok "healed PGP packages: no empty header" || bad "empty PGP header printed"
[[ "$out" == *"pacaur"* && "$out" == *"sortphotos"* ]] && ok "unrelated build failures still reported" || bad "build failures lost"

# 2. a key whose package is STILL broken -> header + exact row (unchanged format)
reset_state
HEAL_STILL_BROKEN_PKGS=(kirigami2 pacaur); HEAL_STILL_BROKEN_SOURCES=(aur aur)
HEAL_AUR_FAIL_PKGS=(kirigami2 pacaur); HEAL_AUR_FAIL_MODES=(pgp build); HEAL_AUR_FAIL_GLOBS=("" "")
out="$(report_heal_outcome 2>&1)"
[[ "$out" == *"PGP keys that blocked AUR rebuilds (import manually as the build user):"* ]] && ok "unresolved PGP package: header printed" || bad "header missing"
[[ "$out" == *"  gpg --recv-keys 53E6B47B45CEA3E0D5B7457758D0EE648A48B3BB  (required by: kirigami2)"* ]] && ok "exact row format unchanged" || bad "row missing/changed"
[[ "$out" != *"155DC67DC25496572CDD608FF635E931C2834999"* ]] && ok "healed package's key not listed" || bad "healed package's key listed"

# 3. rc 0
rc=0; report_heal_outcome >/dev/null 2>&1 || rc=$?; [[ $rc -eq 0 ]] && ok "report returns 0" || bad "rc=$rc"
exit $fail
