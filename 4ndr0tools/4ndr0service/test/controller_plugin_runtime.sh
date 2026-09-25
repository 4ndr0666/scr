#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="${GUP_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
case_dir="$tmp_root/case"
command mkdir -p "$case_dir/plugins"
cat >"$case_dir/common.sh" <<'EOF'
log_info() { :; }
log_warn() { :; }
log_error() { :; }
log_success() { :; }
handle_error() { return 1; }
EOF
cat >"$case_dir/settings_functions.sh" <<'EOF'
EOF
cat >"$case_dir/manage_files.sh" <<'EOF'
EOF
cat >"$case_dir/plugins/failing.sh" <<'EOF'
PLUGIN_REGISTER="failing_plugin"
failing_plugin() { return 73; }
EOF
cp "$repo_root/4ndr0tools/4ndr0service/controller.sh" "$case_dir/controller.sh"
export PKG_PATH="$case_dir"
export PLUGINS_DIR="$case_dir/plugins"
source "$case_dir/controller.sh"
set +e
load_plugins
rc=$?
set -e
if [[ "$rc" -eq 1 ]]; then
    printf '[PASS] plugin entrypoint failure propagates: rc=%s\n' "$rc"
    printf 'GUPv5.3.1 controller plugin runtime proof: 1 passed, 0 failed\n'
    exit 0
fi
printf '[FAIL] plugin entrypoint failure propagates: expected rc=1, got rc=%s\n' "$rc"
printf 'GUPv5.3.1 controller plugin runtime proof: 0 passed, 1 failed\n'
exit 1
