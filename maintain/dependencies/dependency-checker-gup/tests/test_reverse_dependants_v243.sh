#!/usr/bin/env bash
# G4 (v2.4.3): reverse_dependants_of splits PACKAGE_DEPENDS on '|' only, but the
# value is the space-separated 'Depends On' line of `pacman -Qi`, so any owner
# with 2+ dependencies was never matched and the -Rdd confirmation prompt told
# the operator "no installed package depends on it" while something did.
# usage: test_reverse_dependants_v243.sh <lib.sh>     exit 0 = all pass
LIB="${1:?lib path required}"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE="$(mktemp)"; trap 'rm -f "$LOGFILE"' EXIT
fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }

PACKAGE_DEPENDS=()
PACKAGE_DEPENDS[newm]="python-thefuzz  python  glibc"            # real pacman -Qi spacing (2 spaces)
PACKAGE_DEPENDS[solo]="python-thefuzz"                           # single dependency (the only case that worked)
PACKAGE_DEPENDS[versioned]="glibc  python-thefuzz>=0.22  zlib"   # version constraint inside a list
PACKAGE_DEPENDS[altdep]="foo|python-thefuzz"                     # alternative form
PACKAGE_DEPENDS[prefix]="python-thefuzz-extra  glibc"            # substring decoy: must NOT match
PACKAGE_DEPENDS[suffix]="my-python-thefuzz  glibc"               # substring decoy: must NOT match
PACKAGE_DEPENDS[unrelated]="glibc  zlib  bash"
PACKAGE_DEPENDS[tabbed]=$'glibc\tpython-thefuzz'                 # tab separation

got="$(reverse_dependants_of python-thefuzz | sort | tr '\n' ' ')"
want="altdep newm solo tabbed versioned "
[[ "$got" == "$want" ]] && ok "multi-dependency owners are found (got: $got)" || bad "got '$got' want '$want'"

[[ -z "$(reverse_dependants_of nonexistent-pkg)" ]] && ok "unknown package has no dependants" || bad "phantom dependants for unknown package"
rc=0; reverse_dependants_of python-thefuzz >/dev/null || rc=$?
[[ $rc -eq 0 ]] && ok "always returns 0 (safe under set -e / ERR trap)" || bad "rc=$rc"
PACKAGE_DEPENDS=(); rc=0; out="$(reverse_dependants_of anything)" || rc=$?
[[ $rc -eq 0 && -z "$out" ]] && ok "empty metadata -> silent, rc 0" || bad "rc=$rc out=$out"
exit $fail
