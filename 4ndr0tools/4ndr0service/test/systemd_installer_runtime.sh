#!/usr/bin/env bash
# Exercise systemd unit discovery, path rewriting, activation, and reruns in an
# isolated suite tree. All writes and mocked systemctl calls stay under TMPDIR.
set -euo pipefail
IFS=$'\n\t'

ROOT="$(command git rev-parse --show-toplevel)"
SOURCE="$ROOT/4ndr0tools/4ndr0service"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "expected file: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "missing '$2' in $1"; }

make_fixture() {
    local suite="$1"
    mkdir -p "$suite/systemd" "$suite/test" "$TMP/bin"
    cp "$SOURCE/common.sh" "$suite/common.sh"
    cp "$SOURCE/systemd/install_env_maintenance.sh" "$suite/systemd/"
    cp "$SOURCE/systemd/env_maintenance.timer" "$suite/systemd/"
    cp "$SOURCE/systemd/env_maintenance.service" "$suite/systemd/"
    cat > "$TMP/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
if [[ "${*: -2}" == "list-unit-files env_maintenance.timer" ]]; then
    exit 0
fi
exit 0
MOCK
    chmod +x "$TMP/bin/systemctl"
}

run_fixture() {
    local suite="$1"
    local home="$2"
    SYSTEMCTL_LOG="$home/systemctl.log" \
    HOME="$home" \
    XDG_CONFIG_HOME="$home/config" \
    XDG_DATA_HOME="$home/data" \
    XDG_STATE_HOME="$home/state" \
    XDG_CACHE_HOME="$home/cache" \
    XDG_BIN_HOME="$home/bin" \
    PATH="$TMP/bin:$PATH" \
        bash "$suite/systemd/install_env_maintenance.sh"
}

# Standard deployment: the flat systemd/ templates must be found and patched
# for the physical suite root, not a stale /opt default or systemd/user path.
SUITE="$TMP/suite with spaces"
HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"
make_fixture "$SUITE"
service_before="$(sha256sum "$SUITE/systemd/env_maintenance.service" | cut -d ' ' -f1)"
timer_before="$(sha256sum "$SUITE/systemd/env_maintenance.timer" | cut -d ' ' -f1)"
run_fixture "$SUITE" "$HOME_DIR"
DEPLOY="$HOME_DIR/config/systemd/user"
assert_file "$DEPLOY/env_maintenance.service"
assert_file "$DEPLOY/env_maintenance.timer"
assert_contains "$DEPLOY/env_maintenance.service" "Environment=PKG_PATH=$SUITE"
assert_contains "$DEPLOY/env_maintenance.service" "ExecStart=$SUITE/main.sh --fix --report"
assert_contains "$DEPLOY/env_maintenance.timer" "OnCalendar=daily"
assert_contains "$HOME_DIR/systemctl.log" "--user daemon-reload"
assert_contains "$HOME_DIR/systemctl.log" "--user enable --now env_maintenance.timer"
[[ "$(sha256sum "$SUITE/systemd/env_maintenance.service" | cut -d ' ' -f1)" == "$service_before" ]] || fail "source service template mutated"
[[ "$(sha256sum "$SUITE/systemd/env_maintenance.timer" | cut -d ' ' -f1)" == "$timer_before" ]] || fail "source timer template mutated"

# Idempotent deployment: rerunning must leave deployed unit bytes unchanged.
service_deployed_before="$(sha256sum "$DEPLOY/env_maintenance.service" | cut -d ' ' -f1)"
timer_deployed_before="$(sha256sum "$DEPLOY/env_maintenance.timer" | cut -d ' ' -f1)"
run_fixture "$SUITE" "$HOME_DIR"
[[ "$(sha256sum "$DEPLOY/env_maintenance.service" | cut -d ' ' -f1)" == "$service_deployed_before" ]] || fail "service output changed on rerun"
[[ "$(sha256sum "$DEPLOY/env_maintenance.timer" | cut -d ' ' -f1)" == "$timer_deployed_before" ]] || fail "timer output changed on rerun"

# Missing companion service: generation is confined to this disposable fixture
# and the generated unit is patched and deployed before timer activation.
MISSING_SUITE="$TMP/missing-service-suite"
MISSING_HOME="$TMP/missing-service-home"
mkdir -p "$MISSING_HOME"
make_fixture "$MISSING_SUITE"
rm "$MISSING_SUITE/systemd/env_maintenance.service"
run_fixture "$MISSING_SUITE" "$MISSING_HOME"
assert_file "$MISSING_SUITE/systemd/env_maintenance.service"
assert_file "$MISSING_HOME/config/systemd/user/env_maintenance.service"
assert_contains "$MISSING_HOME/config/systemd/user/env_maintenance.service" "Environment=PKG_PATH=$MISSING_SUITE"
assert_contains "$MISSING_HOME/config/systemd/user/env_maintenance.service" "ExecStart=$MISSING_SUITE/main.sh --fix --report"

printf '[PASS] systemd installer runtime: flat template discovery, custom-root patching, activation, source preservation, rerun idempotency, and missing-service generation\n'
