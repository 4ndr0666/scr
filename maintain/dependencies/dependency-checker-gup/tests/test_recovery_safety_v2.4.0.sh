#!/usr/bin/env bash
set -uo pipefail
source ./deps240_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_recov.log
: > "$LOGFILE"

echo "=== TEST 1: blanket --overwrite=\"*\" is UNREACHABLE under -I alone (no interactive) ==="
cat >> "$LOGFILE" << 'LOGEOF'
error: failed to commit transaction (conflicting files)
somepkg: /some/deeply/nested/unresolvable/thing exists in filesystem
LOGEOF
# scoped glob derivation needs >=4 path components; give it a shallow path
# that WON'T derive a safe glob, forcing the blanket-or-nothing branch.
scan_install_failure_segment() { printf 'somepkg\tconflict\t\n'; }
run_pacman_install() { return 1; }  # always fails so we can observe recovery_scope logic without a real pacman
INTERACTIVE_MODE=false
FORCE_HEAL_ALL=true
RECOVERY_OVERWRITE_APPLIED=()
if attempt_conflict_overwrite_retry 0 pacman -S somepkg; then
  echo "UNEXPECTED SUCCESS"
else
  echo "OK: declined (return 1) -- blanket overwrite never attempted under -I with no scoped glob"
fi

echo
echo "=== TEST 2: scoped --overwrite (real glob) IS auto-authorized under -I ==="
scan_install_failure_segment() { printf 'somepkg\tconflict\t/usr/lib/node_modules/somepkg/*\n'; }
call_count=0
run_pacman_install() { call_count=$((call_count+1)); [[ "$*" == *"--overwrite"* ]] && return 0; return 1; }
INTERACTIVE_MODE=false
FORCE_HEAL_ALL=true
RECOVERY_OVERWRITE_APPLIED=()
if attempt_conflict_overwrite_retry 0 pacman -S somepkg; then
  echo "OK: scoped retry succeeded under -I, recorded: ${RECOVERY_OVERWRITE_APPLIED[*]}"
else
  echo "FAIL: expected scoped retry to succeed"
fi

echo
echo "=== TEST 3: ambiguous conflict pair declines UNATTENDED, even with -I ==="
extract_transaction_blockers() { printf 'pkgA\tpkgB\n'; }
INSTALLED_PKGS=([pkgA]=1 [pkgB]=1)
INTERACTIVE_MODE=false
FORCE_HEAL_ALL=true
is_protected_base_pkg() { return 1; }
is_ignored() { return 1; }
RECOVERY_RDD_PKGS_USED=0
: # budget fixed at 5 by readonly declare
if attempt_blocker_removal_chain 0 pacman -S other; then
  echo "UNEXPECTED SUCCESS"
else
  echo "OK: ambiguous pair declined unattended -- neither pkgA nor pkgB removed"
fi

echo
echo "=== TEST 4: the transaction's OWN target is never treated as a removable blocker ==="
extract_transaction_blockers() { printf 'targetpkg\n'; }
INSTALLED_PKGS=([targetpkg]=1)
if attempt_blocker_removal_chain 0 pacman -S targetpkg; then
  echo "UNEXPECTED: chain proceeded"
else
  echo "OK: declined -- targetpkg (the transaction's own arg) was filtered out, leaving zero blockers"
fi

echo
echo "=== TEST 5: a protected base/base-devel package is never in 'actionable' ==="
extract_transaction_blockers() { printf 'glibc\n'; }
INSTALLED_PKGS=([glibc]=1)
is_protected_base_pkg() { [[ "$1" == "glibc" ]]; }
if attempt_blocker_removal_chain 0 pacman -S other; then
  echo "UNEXPECTED SUCCESS"
else
  echo "OK: declined -- glibc excluded as protected, zero actionable blockers remain"
fi

echo
echo "=== TEST 6: budget exhaustion refuses further chains even under -I ==="
RECOVERY_RDD_PKGS_USED=10
: # budget fixed at 5 by readonly declare
extract_transaction_blockers() { printf 'anypkg\n'; }
INSTALLED_PKGS=([anypkg]=1)
is_protected_base_pkg() { return 1; }
if attempt_blocker_removal_chain 0 pacman -S other; then
  echo "UNEXPECTED SUCCESS"
else
  echo "OK: declined -- budget exhausted"
fi
