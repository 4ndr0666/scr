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
cp "$SUITE_DIR/controller.sh" "$case_dir/controller.sh"
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
