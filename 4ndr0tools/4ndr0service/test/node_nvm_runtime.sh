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
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/service/service" "$TMP/home/.local/share/nvm"
cat >"$TMP/service/common.sh" <<'EOF'
log_info() { :; }
log_success() { :; }
log_warn() { :; }
handle_error() { return "${1:-1}"; }
ensure_dir() { mkdir -p "$1"; }
CONFIG_FILE=/dev/null
EOF
cat >"$TMP/service/service/optimize_nvm.sh" <<'EOF'
optimize_nvm_service() { return 73; }
EOF
cat >"$TMP/service/service/optimize_node.sh" <<EOF
$(sed '/^if \[\[ "\${BASH_SOURCE\[0\]}" == "\$0" \]\]; then/,$d' "$SVC/service/optimize_node.sh")
EOF
export PKG_PATH="$TMP/service"
source "$TMP/service/service/optimize_node.sh"
set +e
optimize_node_service >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
    printf '[FAIL] NVM prerequisite failure was suppressed: rc=%s\n' "$rc"
    exit 1
fi
printf '[PASS] NVM prerequisite failure propagates: rc=%s\n' "$rc"
printf 'GUPv5.3.1 Node/NVM runtime proof: 1 passed, 0 failed\n'
