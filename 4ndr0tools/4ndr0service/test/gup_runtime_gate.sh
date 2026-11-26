#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
readonly TEST_DIR

ROOT="$(command git -C "$TEST_DIR" rev-parse --show-toplevel 2>/dev/null || dirname -- "$TEST_DIR")"
readonly ROOT

HEAD="$(command git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf 'WORKTREE')"
readonly HEAD

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
    pipx_inventory_runtime.sh
    systemd_installer_runtime.sh
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