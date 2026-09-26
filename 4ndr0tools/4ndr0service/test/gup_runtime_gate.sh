#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT="$(command git rev-parse --show-toplevel)"
readonly ROOT

HEAD="$(command git -C "$ROOT" rev-parse HEAD)"
readonly HEAD

TEST_DIR="$ROOT/4ndr0tools/4ndr0service/test"
readonly TEST_DIR

runtime_tests=(
    ascension_runtime.sh
    controller_plugin_runtime.sh
    controller_runtime.sh
    final_audit_runtime.sh
    final_audit_runtime_v2.sh
    ghost_removal_runtime.sh
    go_runtime.sh
    installer_runtime.sh
    installer_runtime_v2.sh
    node_nvm_runtime.sh
    parallel_runtime.sh
    path_resolution_runtime.sh
    prunesys_runtime.sh
    purge_runtime.sh
    run_bounded_runtime.sh
    settings_runtime.sh
    source_safety_runtime.sh
    verify_environment_runtime.sh
)

printf 'GUP current-iteration runtime gate\n'
printf 'HEAD: %s\n' "$HEAD"
printf 'TESTS: %d\n\n' "${#runtime_tests[@]}"

passes=0
for test_name in "${runtime_tests[@]}"; do
    test_path="$TEST_DIR/$test_name"
    printf '[GUP] %s\n' "$test_name"
    if command bash "$test_path"; then
        passes=$((passes + 1))
        printf '[GUP-PASS] %s\n\n' "$test_name"
    else
        rc=$?
        printf '[GUP-FAIL] %s: rc=%s\n' "$test_name" "$rc" >&2
        printf 'GUP current-iteration runtime gate: %d/%d passed\n' "$passes" "${#runtime_tests[@]}" >&2
        exit "$rc"
    fi
done

printf 'GUP current-iteration runtime gate: %d/%d passed\n' "$passes" "${#runtime_tests[@]}"
printf '[PASS] Current repository iteration is runtime-gate clean\n'