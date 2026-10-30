#!/usr/bin/env bash
set -uo pipefail
source ./deps240_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_unresolv.log
: > "$LOGFILE"

# Simulate: pacman -T deterministically keeps reporting the same
# unresolvable dep as missing every iteration (matches real pacman -T
# behavior against unchanged installed state).
compute_missing_dependencies() { MISSING_DEPS_RESULT=("stuck-dep=1.0"); return 0; }
install_dependencies() { UNRESOLVABLE_DEPS+=("stuck-dep=1.0"); UNRESOLVABLE_DEP_SET["stuck-dep=1.0"]=1; return 1; }
cache_package_lists() { :; }
cache_package_groups() { :; }
auto_rebuild_broken_reverse_deps() { return 1; }

ALL_SYSTEM=true
INSTALLED_PKGS=([stuck-dep]=1)
UNRESOLVABLE_DEPS=()
UNRESOLVABLE_DEP_SET=()
AUTO_HEAL_ATTEMPTS_USED=0

process_dependency_closure
echo "last_missing after closure: ${last_missing[*]:-<EMPTY>}"
if [[ ${#last_missing[@]} -gt 0 ]]; then
  echo "OK: last_missing is non-empty -- main() will take the 'missing deps' exit path, which DOES call report_unresolvable_findings"
else
  echo "BUG CONFIRMED: last_missing is empty despite an unresolved UNRESOLVABLE_DEPS entry -- report_unresolvable_findings would be silently skipped"
fi
echo "UNRESOLVABLE_DEPS: ${UNRESOLVABLE_DEPS[*]:-<EMPTY>}"
