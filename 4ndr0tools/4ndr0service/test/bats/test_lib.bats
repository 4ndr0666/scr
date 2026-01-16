#!/usr/bin/env bats

setup() {
    BATS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    PROJECT_ROOT="$(cd "$BATS_DIR/../.." >/dev/null 2>&1 && pwd)"
    export PKG_PATH="$PROJECT_ROOT"
    source "$PROJECT_ROOT/common.sh"
}

@test "ensure_dir creates a directory" {
    local test_dir="/tmp/4ndr0test_$(date +%s)"
    run ensure_dir "$test_dir"
    [ "$status" -eq 0 ]
    [ -d "$test_dir" ]
    rm -rf "$test_dir"
}

@test "pkg_is_installed returns 0 for bash" {
    run pkg_is_installed "bash"
    [ "$status" -eq 0 ]
}

@test "detect_pkg_manager finds pacman on arch-based systems" {
    if command -v pacman &>/dev/null; then
        run detect_pkg_manager
        [ "$output" == "pacman" ]
    fi
}

@test "path_prepend correctly adds to PATH" {
    local test_path="/tmp/fake_bin_$(date +%s)"
    mkdir -p "$test_path"
    path_prepend "$test_path"
    [[ ":$PATH:" == *":$test_path:"* ]]
    rm -rf "$test_path"
}
