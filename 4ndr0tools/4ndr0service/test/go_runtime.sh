#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# ── SUITE DIR RESOLUTION (GAP-F FIX) ──────────────────────────────────────────
# Dual-layout: honor GUP_REPO_ROOT when it targets the legacy 4ndr0tools/
# layout (the original dotfiles repo), else self-resolve — this file lives at
# <suite>/test/, so the suite root is one dirname up. The proofs now run from
# both repository layouts with no CI env hints and no git dependency.
_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
if [[ -n "${GUP_REPO_ROOT:-}" && -f "$GUP_REPO_ROOT/4ndr0tools/4ndr0service/common.sh" ]]; then
    SUITE_DIR="$GUP_REPO_ROOT/4ndr0tools/4ndr0service"
else
    SUITE_DIR="$(dirname -- "$_TEST_DIR")"
fi
SVC="$SUITE_DIR"
TMP="$(mktemp -d)"
trap '/usr/bin/rm -rf "$TMP"' EXIT
mkdir -p "$TMP/service" "$TMP/bin" "$TMP/data" "$TMP/cache"
cat >"$TMP/service/common.sh" <<'EOF'
XDG_DATA_HOME="$TEST_DATA"
XDG_CACHE_HOME="$TEST_CACHE"
CONFIG_FILE="$TEST_CONFIG"
log_info() { :; }
log_success() { :; }
log_warn() { :; }
path_prepend() { PATH="$1:$PATH"; export PATH; }
ensure_dir() { mkdir -p "$1"; }
handle_error() { return 73; }
install_sys_pkg() { return 73; }
EOF
: >"$TMP/config.json"
export TEST_DATA="$TMP/data" TEST_CACHE="$TMP/cache" TEST_CONFIG="$TMP/config.json"
export PKG_PATH="$TMP/service"
# Isolate the prerequisite check from the host toolchain.
export PATH="$TMP/bin"
# Source only the function definitions; the production script's standalone
# bootstrap is intentionally not entered because BASH_SOURCE[0] != $0.
source "$SVC/service/optimize_go.sh"
set +e
optimize_go_service >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -ne 73 ]]; then
    printf '[FAIL] Go prerequisite failure propagation: expected rc=73, got rc=%s\n' "$rc"
    exit 1
fi
printf '[PASS] Go prerequisite failure propagates: rc=%s\n' "$rc"
printf 'GUPv5.3.1 Go runtime proof: 1 passed, 0 failed\n'
