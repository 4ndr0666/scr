#!/bin/bash

source "$(pkg_path)/service/settings.sh"

pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink "$0")"
    else
        dirname "$0"
    fi
}

optimize_go() {
    echo "Starting Go optimization..."
    optimize_go_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Go optimization failed!"
    fi
}

optimize_ruby() {
    echo "Starting Ruby optimization..."
    optimize_ruby_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Ruby optimization failed!"
    fi
}

optimize_cargo() {
    echo "Starting Cargo optimization..."
    optimize_cargo_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Cargo optimization failed!"
    fi
}

optimize_node() {
    echo "Starting Node.js optimization..."
    optimize_node_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Node.js optimization failed!"
    fi
}

optimize_nvm() {
    echo "Starting NVM optimization..."
    optimize_nvm_service
    if [[ $? -ne 0 ]]; then
        echo "Error: NVM optimization failed!"
    fi
}

optimize_meson() {
    echo "Starting Meson optimization..."
    optimize_meson_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Meson optimization failed!"
    fi
}

optimize_venv() {
    echo "Starting Python optimization..."
    optimize_poetry_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Python optimization failed!"
    fi
}

optimize_rust_tooling() {
    echo "Starting Rust tooling optimization..."
    optimize_rust_tooling_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Rust tooling optimization failed!"
    fi
}

optimize_db_tools() {
    echo "Starting Database tools optimization..."
    optimize_db_tools_service
    if [[ $? -ne 0 ]]; then
        echo "Error: Database tools optimization failed!"
    fi
}

update_settings() {
    modify_settings
    source_settings
    printf "\n"
}
