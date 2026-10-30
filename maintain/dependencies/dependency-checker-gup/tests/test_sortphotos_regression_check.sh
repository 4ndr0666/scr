#!/usr/bin/env bash
set -uo pipefail
source ./deps_lib.sh > /dev/null 2>&1 || true

# Reproduce the exact field-log scenario, with sortphotos deliberately
# ABSENT from HEAL_AUR_FAIL_PKGS/MODES (testing the hypothesis that
# scan_install_failure_segment returned zero rows for it).
HEAL_ATTEMPTED_OFFICIAL_PKGS=(filesystem)
HEAL_ATTEMPTED_AUR_PKGS=(electron-builder kirigami2 pacaur peerflix python-pywal sortphotos textlint)
HEAL_STILL_BROKEN_PKGS=(filesystem electron-builder kirigami2 pacaur peerflix python-pywal sortphotos textlint)
HEAL_STILL_BROKEN_SOURCES=(official aur aur aur aur aur aur aur)
HEAL_VERIFIED_CHECKED_COUNT=9
HEAL_VERIFIED_RESTORED_COUNT=1
HEAL_STALE_UNRESOLVED_PKGS=(python-thefuzz)
HEAL_AUR_FAIL_PKGS=(electron-builder peerflix textlint kirigami2 python-pywal pacaur)
HEAL_AUR_FAIL_MODES=(conflict conflict conflict pgp pgp build)
HEAL_AUR_FAIL_GLOBS=("/usr/lib/node_modules/electron-builder/node_modules/*" "/usr/lib/node_modules/peerflix/node_modules/*" "/usr/lib/node_modules/textlint/node_modules/*" "" "" "")
HEAL_AUR_PGP_KEYS=(155DC67DC25496572CDD608FF635E931C2834999 53E6B47B45CEA3E0D5B7457758D0EE648A48B3BB)
HEAL_AUR_PGP_FAILURE_PKGS=(python-pywal kirigami2)
HEAL_OFFICIAL_FAIL_CONFLICT_PKGS=()
HEAL_OFFICIAL_FAIL_CONFLICT_GLOBS=()
HEAL_UNHEALED_OFFICIAL_PKGS=()
HEAL_UNHEALED_AUR_PKGS=()
HEAL_UNHEALED_UNKNOWN_PKGS=()
HEAL_UNHEALED_REASONS=()

echo "===== report_heal_outcome output ====="
report_heal_outcome
echo "===== end ====="
