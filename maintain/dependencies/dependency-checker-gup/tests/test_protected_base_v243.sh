#!/usr/bin/env bash
# G6 (v2.4.3): is_protected_base_pkg must protect the members of `base` /
# `base-devel` on CURRENT Arch, where both are META-PACKAGES (no groups:
# `base` since Oct 2019, `base-devel` since Feb 2023). The v2.4.0-v2.4.2 source of
# truth was `pacman -Qgq base base-devel`, which is empty there, so the
# "never -Rdd a base member" guard protected nothing. This test does NOT stub
# is_protected_base_pkg — it feeds the real function pacman-shaped output.
# usage: test_protected_base_v243.sh <lib.sh>     exit 0 = all pass
LIB="${1:?lib path required}"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE="$(mktemp)"; trap 'rm -f "$LOGFILE"' EXIT
fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }

# current-Arch shape: no groups; base / base-devel are packages with Depends On
run_command() {
	CMD_OUTPUT=""
	case "$*" in
		"pacman -Qgq base"|"pacman -Qgq base-devel") return 1 ;;   # empty group / non-zero on unknown group
		"pacman -Qi -- base")
			CMD_OUTPUT=$'Name            : base\nVersion         : 3-3\nDepends On      : filesystem  gcc-libs  glibc  bash  coreutils  pacman>=7  systemd\nRequired By     : None'; return 0 ;;
		"pacman -Qi -- base-devel")
			CMD_OUTPUT=$'Name            : base-devel\nVersion         : 1-2\nDepends On      : autoconf  automake  binutils  gcc  make  sudo\nRequired By     : None'; return 0 ;;
	esac
	return 1
}
BASE_GROUP_PROTECTED=(); BASE_GROUP_PROTECTED_LOADED=false
for p in bash glibc filesystem coreutils pacman systemd gcc-libs; do
	is_protected_base_pkg "$p" && ok "$p protected via base's Depends On" || bad "$p NOT protected"
done
for p in gcc make sudo binutils; do
	is_protected_base_pkg "$p" && ok "$p protected via base-devel's Depends On" || bad "$p NOT protected"
done
for p in base base-devel; do
	is_protected_base_pkg "$p" && ok "meta-package $p itself protected" || bad "meta-package $p NOT protected"
done
is_protected_base_pkg python-thefuzz && bad "unrelated package wrongly protected" || ok "unrelated package (python-thefuzz) not protected"
is_protected_base_pkg 'pacman>=7' && bad "constraint text leaked into the set" || ok "version constraints stripped (no 'pacman>=7' key)"

# superset: legacy group data (long-lived install with stale group tags) still honoured
run_command() {
	CMD_OUTPUT=""
	case "$*" in
		"pacman -Qgq base") CMD_OUTPUT=$'oldmember'; return 0 ;;
		"pacman -Qgq base-devel") return 1 ;;
	esac
	return 1
}
BASE_GROUP_PROTECTED=(); BASE_GROUP_PROTECTED_LOADED=false
is_protected_base_pkg oldmember && ok "legacy group member still protected (unchanged behaviour)" || bad "legacy group member lost"

# fail-closed shape: both queries fail entirely -> function still returns cleanly (rc 1 = not protected), no ERR-trap FATAL
run_command() { CMD_OUTPUT=""; return 1; }
BASE_GROUP_PROTECTED=(); BASE_GROUP_PROTECTED_LOADED=false
rc=0; is_protected_base_pkg something 2>/dev/null || rc=$?
[[ $rc -eq 1 ]] && ok "no metadata at all -> returns 1 cleanly" || bad "rc=$rc"
exit $fail
