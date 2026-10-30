#!/usr/bin/env bash
set -uo pipefail
source ./deps_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_dc3.log
: > "$LOGFILE"

# Simulate: pacman -Syu always fails with the field log's exact conflict,
# and detect_pending_upgrades always reports the identical 55-package set
# (pending set is genuinely unchanged between the two heal-batch calls).
call_count=0
run_pacman_install() { call_count=$((call_count+1)); return 1; }
detect_pending_upgrades() { :; }  # PENDING_UPGRADE_PKGS left untouched -> identical set

PENDING_UPGRADES_COUNT=55
PENDING_UPGRADE_PKGS=(asar-4.3.1-1 gspell-1.14.5-1 haskell-aeson-2.2.3.0-2)  # abbreviated stand-in set
PENDING_PYTHON_UPGRADE=""
INTERACTIVE_MODE=false
FORCE_HEAL_ALL=true
PREFLIGHT_SYNC_DONE=false
PREFLIGHT_SYNC_FAILED=false
PREFLIGHT_SYNC_FAILED_PKGS=()

echo "=== Call 1 (verified-missing-files batch): expect real attempt, failure recorded ==="
if sync_system_preflight; then echo "FAIL: expected failure"; else echo "OK: returned failure"; fi
echo "run_pacman_install call_count after call 1: $call_count (expect 1)"
echo "PREFLIGHT_SYNC_FAILED=${PREFLIGHT_SYNC_FAILED} (expect true)"

echo
echo "=== Call 2 (stale-python-dir batch, same run, identical pending set): expect fast-decline, NO second pacman -Syu attempt ==="
if sync_system_preflight; then echo "FAIL: expected failure"; else echo "OK: returned failure"; fi
echo "run_pacman_install call_count after call 2: $call_count (expect STILL 1 — this is the fix)"

echo
echo "=== Call 3: pending set CHANGES (simulating partial resolution) -> must retry for real, not stay declined ==="
PENDING_UPGRADE_PKGS=(only-one-left-1.0-1)
if sync_system_preflight; then echo "FAIL: expected failure"; else echo "OK: returned failure"; fi
echo "run_pacman_install call_count after call 3: $call_count (expect 2 — the changed set must retry)"
