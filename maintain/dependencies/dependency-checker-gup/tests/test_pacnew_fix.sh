#!/usr/bin/env bash
set -uo pipefail
source ./deps_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_dc.log
mkdir -p "$(dirname "$LOGFILE")"
: > "$LOGFILE"

echo "=== TEST 1: scan_install_side_effects_segment against the real field-log text ==="
cat >> "$LOGFILE" << 'LOGEOF'
warning: filesystem-2025.10.12-1 is up to date -- reinstalling
resolving dependencies...
:: Processing package changes...
reinstalling filesystem...
warning: /etc/fstab installed as /etc/fstab.pacnew
warning: /etc/passwd installed as /etc/passwd.pacnew
warning: /etc/shadow installed as /etc/shadow.pacnew
warning: directory permissions differ on /root/
filesystem: 700  package: 750
:: Running post-transaction hooks...
LOGEOF
HEAL_PACNEW_FILES=()
HEAL_PERM_DIFF_DIRS=()
scan_install_side_effects_segment 0
echo "HEAL_PACNEW_FILES: ${HEAL_PACNEW_FILES[*]}"
echo "HEAL_PERM_DIFF_DIRS: ${HEAL_PERM_DIFF_DIRS[*]}"

echo
echo "=== TEST 2: report_pacnew_findings renders it ==="
report_pacnew_findings

echo "=== TEST 3: report_pacnew_findings no-ops cleanly when empty ==="
HEAL_PACNEW_FILES=()
HEAL_PERM_DIFF_DIRS=()
out="$(report_pacnew_findings)"
if [[ -z "$out" ]]; then echo "PASS: no output when nothing found"; else echo "FAIL: unexpected output: $out"; fi

echo
echo "=== TEST 4: scanner only fires on start_line onward (does not pick up earlier unrelated content) ==="
: > "$LOGFILE"
printf 'warning: /should/not/be/seen installed as /should/not/be/seen.pacnew\n' >> "$LOGFILE"
start_marker="$(wc -l < "$LOGFILE")"
printf 'warning: /etc/real.conf installed as /etc/real.conf.pacnew\n' >> "$LOGFILE"
HEAL_PACNEW_FILES=()
scan_install_side_effects_segment "$start_marker"
echo "HEAL_PACNEW_FILES (should be only /etc/real.conf.pacnew): ${HEAL_PACNEW_FILES[*]}"
