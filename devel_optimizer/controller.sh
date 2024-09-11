#!/bin/bash

optimize_go() {
    optimize_go_service
}

optimize_ruby() {
    optimize_ruby_service
}

optimize_cargo() {
    optimize_cargo_service
}

optimize_node() {
     optimize_node_service
}

optimize_nvm() {
    optimize_nvm_service
}

optimize_meson() {
    optimize_meson_service
}

optimize_poetry() {
    optimize_poetry_service
}

optimize_rust_tooling() {
    optimize_rust_tooling_service
}

optimize_db_tools() {
    optimize_db_tools_service
}

update_settings() {
    modify_settings
    source_settings
    printf "\n"
}
