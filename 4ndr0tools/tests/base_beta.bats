#!/usr/bin/env bats

load '/usr/lib/bats/bats-support/load'
load '/usr/lib/bats/bats-assert/load'

@test "4ndr0base-beta.sh --help prints usage" {
  run "$BATS_TEST_DIRNAME/../4ndr0base-beta.sh" --help
  assert_success
  assert_output --partial "Usage:"
}

@test "4ndr0base-beta.sh --dry-run outputs dry run" {
  run "$BATS_TEST_DIRNAME/../4ndr0base-beta.sh" --dry-run
  assert_success
  assert_output --partial "[DRY-RUN]"
}
