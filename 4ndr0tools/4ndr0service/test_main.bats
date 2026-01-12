#!/usr/bin/env bats
# File: test/bats/test_main.bats
# Enhanced test suite — more coverage, mocks

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "main.sh exits cleanly on --help" {
  run bash "$PKG_PATH/main.sh" --help
  assert_success
  assert_output --partial "4ndr0service Suite"
}

@test "CLI menu exits cleanly on Exit" {
  run bash -c "printf '13\n' | $PKG_PATH/view/cli.sh"
  assert_success
  assert_output --partial "Session terminated."
}

@test "Verification detects and fixes missing env vars in --fix mode" {
  unset PYENV_ROOT PIPX_HOME

  run bash "$PKG_PATH/test/src/verify_environment.sh" --fix
  assert_success
  assert_output --partial "Fixed: PYENV_ROOT"
  assert_output --partial "Fixed: PIPX_HOME"
}

@test "Parallel checks execute without error" {
  run bash -c "FIX_MODE=false $PKG_PATH/main.sh --parallel"
  assert_success
  assert_output --partial "Parallel + sequential pass complete"
}

@test "Dry-run mode skips destructive actions" {
  run bash "$PKG_PATH/service/optimize_python.sh" --dry-run
  assert_success
  assert_output --partial "[DRY-RUN] Skipping actual changes"
}

@test "Config is valid JSON after creation" {
  rm -f "$CONFIG_FILE"
  run bash -c "source $PKG_PATH/common.sh; create_config_if_missing; jq . $CONFIG_FILE"
  assert_success
}
