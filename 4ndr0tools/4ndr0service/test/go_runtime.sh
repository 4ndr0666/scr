#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
ROOT="${GUP_REPO_ROOT:?GUP_REPO_ROOT is required}"
SVC="$ROOT/4ndr0tools/4ndr0service"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
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
handle_error() { return "${1:-1}"; }
install_sys_pkg() { return 73; }
EOF
cat >"$TMP/bin/jq" <<'EOF'
#!/usr/bin/env bash
printf '\n'
EOF
chmod +x "$TMP/bin/jq"
: >"$TMP/config.json"
export TEST_DATA="$TMP/data" TEST_CACHE="$TMP/cache" TEST_CONFIG="$TMP/config.json"
export PKG_PATH="$TMP/service"
export PATH="$TMP/bin:/usr/bin:/bin"
sed '/^if \[\[ "\${BASH_SOURCE\[0\]}" == "\$0" \]\]; then/,$d' "$SVC/service/optimize_go.sh" > "$TMP/service/optimize_go.sh"
source "$TMP/service/optimize_go.sh"
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
