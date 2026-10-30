#!/usr/bin/env bash
source ./deps241_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_pipeline_fix.log
YAY_AVAILABLE=true
wait_for_pacman_lock() { :; }

echo "=== CASE 1: conflict-only failure (no 'required by:' lines) -> no spurious FATAL, zero keys ==="
cat > "$LOGFILE" << 'LOGEOF'
error: failed to commit transaction (conflicting files)
peerflix: /usr/lib/node_modules/peerflix/node_modules/x/index.js exists in filesystem
LOGEOF
import_pgp_keys_for_build_user() { echo "UNEXPECTED: import called with: $*" >&2; return 1; }
run_yay() { return 1; }
scan_install_failure_segment() { :; }
INTERACTIVE_MODE=false; FORCE_HEAL_ALL=false
HEAL_AUR_PGP_KEYS=(); HEAL_AUR_PGP_FAILURE_PKGS=(); HEAL_AUR_FAIL_PKGS=(); HEAL_AUR_FAIL_MODES=(); HEAL_AUR_FAIL_GLOBS=()
out="$( { if rebuild_aur_packages peerflix; then :; fi; } 2>&1 )"
if grep -q "FATAL" <<<"$out"; then echo "FAIL: spurious FATAL still emitted"; echo "$out"; else echo "PASS: no FATAL emitted"; fi
echo "keys recorded: ${#HEAL_AUR_PGP_KEYS[@]} (expect 0)"

echo
echo "=== CASE 2 (regression): log WITH 'required by:' lines -> keys still parsed and passed to import ==="
: > "$LOGFILE"
run_yay() {
	# first (batch) call appends the yay PGP block to the log, then fails
	cat >> "$LOGFILE" << 'LOGEOF'
 :: PGP keys need importing:
 -> 53E6B47B45CEA3E0D5B7457758D0EE648A48B3BB, required by: kirigami2
LOGEOF
	return 1
}
imported=""
import_pgp_keys_for_build_user() { imported="$*"; return 1; }
HEAL_AUR_PGP_KEYS=(); HEAL_AUR_PGP_FAILURE_PKGS=()
if rebuild_aur_packages kirigami2 >/dev/null 2>&1; then :; fi
echo "import called with: ${imported:-<never>}"
[[ "$imported" == "53E6B47B45CEA3E0D5B7457758D0EE648A48B3BB" ]] && echo "PASS: key parsed and forwarded" || echo "FAIL: key not forwarded"
echo "HEAL_AUR_PGP_FAILURE_PKGS: ${HEAL_AUR_PGP_FAILURE_PKGS[*]:-<none>}"
