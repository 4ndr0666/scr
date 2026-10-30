#!/usr/bin/env bash
set -uo pipefail
source ./deps_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_dc4.log
: > "$LOGFILE"

call_count=0
run_pacman_install() { call_count=$((call_count+1)); return 0; }
refresh_pacman_databases() { :; }
cache_package_lists() { :; }
cache_package_groups() { :; }
detect_pending_upgrades() { PENDING_UPGRADE_PKGS=(linux-wifi-hotspot); }  # residual, held back

PENDING_UPGRADES_COUNT=1
PENDING_UPGRADE_PKGS=(linux-wifi-hotspot)
PENDING_PYTHON_UPGRADE=""
INTERACTIVE_MODE=false
FORCE_HEAL_ALL=true
PREFLIGHT_SYNC_DONE=false
PREFLIGHT_SYNC_FAILED=false
PREFLIGHT_SYNC_FAILED_PKGS=()
PREFLIGHT_RESIDUAL_PKGS=()

echo "=== Call 1: succeeds, leaves a held-back residual ==="
sync_system_preflight
echo "call_count=$call_count PREFLIGHT_SYNC_DONE=$PREFLIGHT_SYNC_DONE PREFLIGHT_RESIDUAL_PKGS=${PREFLIGHT_RESIDUAL_PKGS[*]}"

echo
echo "=== Call 2: same residual pending set -> must still skip (v2.3.2 behavior unchanged) ==="
sync_system_preflight
echo "call_count=$call_count (expect STILL 1 -- v2.3.2 success-path dedup unaffected by the v2.3.4 addition)"
