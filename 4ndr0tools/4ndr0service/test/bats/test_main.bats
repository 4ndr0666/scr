#!/usr/bin/env bats

setup() {
    # Get the directory of the bats script
    BATS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # Project root relative to this file
    PROJECT_ROOT="$(cd "$BATS_DIR/../.." >/dev/null 2>&1 && pwd)"
    export PKG_PATH="$PROJECT_ROOT"
}

@test "CLI menu exits cleanly when 'Exit' is selected" {
    # Run main.sh and provide '12' (Exit option) as input
    run bash -c "printf '12\n' | $PROJECT_ROOT/main.sh --cli"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Goodbye!"* ]]
}

@test "Verification function runs with --fix" {
    # Unset environment variables to ensure fix logic is triggered
    # NVM_DIR is in required_env but not auto-set in common.sh top-level
    unset NVM_DIR

    run "$PROJECT_ROOT/main.sh" --fix --report

    [ "$status" -eq 0 ]
    [[ "$output" == *"Verifying environment alignment"* ]]
    [[ "$output" == *"Fixed: NVM_DIR set"* ]]
}

@test "Help message displays correctly" {
    run "$PROJECT_ROOT/main.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
