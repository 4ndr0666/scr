#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
ROOT="${GUP_REPO_ROOT:?GUP_REPO_ROOT is required}"
SVC="$ROOT/4ndr0tools/4ndr0service"
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
