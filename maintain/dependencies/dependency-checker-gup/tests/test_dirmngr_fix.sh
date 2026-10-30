#!/usr/bin/env bash
set -uo pipefail
source ./deps_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_dc2.log
: > "$LOGFILE"

# Stub out the parts that would otherwise hit real system state.
unprivileged_user() { echo "andro"; return 0; }
sudo() {
  # simulate: gpgconf --launch dirmngr fails (no dirmngr reachable)
  if [[ "$2" == "gpgconf" ]]; then return 1; fi
  return 0
}

echo "=== TEST 1: GPGCONF_AVAILABLE=true, dirmngr launch fails -> fast-fail, no keyserver attempts ==="
GPGCONF_AVAILABLE=true
GPG_AVAILABLE=true
HEAL_PGP_DIRMNGR_UNAVAILABLE=false
start=$(date +%s)
if import_pgp_keys_for_build_user "DEADBEEF00000000000000000000000000000000"; then
  echo "FAIL: expected failure"
else
  echo "OK: returned failure as expected"
fi
end=$(date +%s)
echo "elapsed: $((end-start))s (should be near-instant, not ~2x SHORT_EXTERNAL_TIMEOUT_SECONDS for a real keyserver loop)"
echo "HEAL_PGP_DIRMNGR_UNAVAILABLE=${HEAL_PGP_DIRMNGR_UNAVAILABLE} (expect true)"

echo
echo "=== TEST 2: GPGCONF_AVAILABLE=false -> old v2.2.0 behavior preserved (falls through to keyserver loop) ==="
GPGCONF_AVAILABLE=false
HEAL_PGP_DIRMNGR_UNAVAILABLE=false
sudo() {
  # now simulate gpg --recv-keys itself failing (the old code path)
  return 1
}
if import_pgp_keys_for_build_user "DEADBEEF00000000000000000000000000000000"; then
  echo "FAIL: expected failure"
else
  echo "OK: returned failure via old keyserver-loop path"
fi
echo "HEAL_PGP_DIRMNGR_UNAVAILABLE=${HEAL_PGP_DIRMNGR_UNAVAILABLE} (expect false — dirmngr check was skipped entirely)"
