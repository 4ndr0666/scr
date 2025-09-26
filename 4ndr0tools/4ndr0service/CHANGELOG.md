# CHANGELOG

## Version 1.1.0 (2025-09-26)

This release focuses on significant refactoring and standardization across the entire `4ndr0service` suite. The primary goals were to improve maintainability, enhance consistency in logging and configuration, and streamline the overall architecture.

### Core Logic Refinements

*   **Centralized `PKG_PATH` and `CONFIG_FILE` Management:**
    *   Removed redundant `PKG_PATH` determination logic from `controller.sh`, `manage_files.sh`, `settings_functions.sh`, and all service scripts (`optimize_*.sh`). `PKG_PATH` is now exclusively determined and exported by `common.sh` when sourced by `main.sh`.
    *   `CONFIG_FILE` is now globally defined in `common.sh` based on `XDG_CONFIG_HOME`, ensuring a single source of truth for the configuration file path.
    *   **Benefit:** Reduces redundancy, simplifies path management, and improves consistency across the suite.
*   **Consolidated Service Execution:**
    *   Removed duplicate `batch_execute_all` and `batch_execute_all_parallel` functions from `manage_files.sh`.
    *   `manage_files.sh` now calls the centralized `run_all_services` and `run_parallel_services` functions defined in `controller.sh`.
    *   **Benefit:** Eliminates code duplication, centralizes service orchestration logic, and makes future modifications easier.
*   **Default Execution for `main.sh`:**
    *   Modified `main.sh` to automatically execute `run_core_checks` if no command-line arguments are provided.
    *   **Benefit:** Provides a sensible default behavior for the main entry point, making it more user-friendly for routine checks.

### Configuration Management

*   **Externalized Hardcoded Values to `config.json`:**
    *   **Python:** `python_version` (`3.10.14`) and `python_tools` (`black`, `flake8`, `mypy`, `pytest`, `poetry`) are now configurable via `config.json`.
    *   **Cargo:** `cargo_tools` (`cargo-update`, `cargo-audit`) are now configurable via `config.json`.
    *   **Electron:** `electron_tools` (`electron-builder`) is now configurable via `config.json`.
    *   **Go:** `go_tools` (`golang.org/x/tools/gopls@latest`, `github.com/golangci/golangci-lint/cmd/golangci-lint@latest`) are now configurable via `config.json`.
    *   **Node.js:** `node_version` (`lts/*`) and `npm_global_packages` (`npm`, `yarn`, `pnpm`, `typescript`, `eslint`, `prettier`) are now configurable via `config.json`.
    *   **Ruby:** `ruby_gems` (`bundler`, `rake`, `rubocop`) are now configurable via `config.json`.
    *   **Venv:** `venv_pipx_packages` (`black`, `flake8`, `mypy`, `pytest`) are now configurable via `config.json`.
    *   **Audit:** `audit_keywords` (`config_watch`, `data_watch`, `cache_watch`) are now configurable via `config.json`.
    *   **Tool Installation Commands:** `tool_install_commands` for `psql` (with `yay` and `pacman` options) are now configurable via `config.json`, allowing for dynamic installation based on detected package managers.
    *   **Benefit:** Enhances flexibility, simplifies updates to versions and toolsets, and reduces the need to modify core script logic for configuration changes.

### Logging Standardization

*   **Unified Logging Functions:**
    *   Replaced all direct `echo` statements (especially those with color codes) and custom `log`/`handle_error` functions with `log_info`, `log_warn`, and `handle_error` from `common.sh` across all service, plugin, and test scripts.
    *   **Benefit:** Provides a consistent logging experience, improves readability of output, and centralizes error handling for easier debugging and maintenance.

### Systemd Integration

*   **Streamlined Systemd Service Invocation:**
    *   Modified `install_env_maintenance.sh` to install `main.sh` (the primary entry point) into `~/.local/bin/4ndr0service/main.sh`.
    *   Updated `env_maintenance.service` to call `ExecStart=%h/.local/bin/4ndr0service/main.sh --fix`.
    *   **Benefit:** Ensures the systemd service leverages the main orchestration script, making the automated daily checks more robust and aligned with the suite's architecture.
    *   **Note:** The update to `env_maintenance.service` required manual intervention due to initial permission issues, but the file has now been successfully created with the correct content.

### Script-Specific Refinements

*   **`optimize_cargo.sh`:**
    *   Re-added `check_directory_writable` function.
    *   Updated `install_rustup`, `update_rustup_and_cargo`, `cargo_install_or_update` to use consistent logging.
*   **`optimize_electron.sh`:**
    *   Updated `npm_global_install_or_update` and `optimize_electron_service` to use consistent logging and read tools from `config.json`.
*   **`optimize_go.sh`:**
    *   Updated `check_directory_writable`, `install_go`, `update_go`, `setup_go_paths`, `install_go_tools`, `manage_permissions`, `manage_go_versions`, `perform_go_cleanup`, and `optimize_go_service` to use consistent logging and read tools from `config.json`.
*   **`optimize_meson.sh`:**
    *   Updated `install_meson`, `install_ninja`, and `optimize_meson_service` to use consistent logging.
*   **`optimize_node.sh`:**
    *   Updated `install_nvm`, `install_node`, `install_global_npm_tools`, and `optimize_node_service` to use consistent logging and read versions/packages from `config.json`.
*   **`optimize_nvm.sh`:**
    *   Updated `remove_npmrc_prefix_conflict`, `install_nvm_for_nvm_service`, and `optimize_nvm_service` to use consistent logging and read Node.js version from `config.json`.
*   **`optimize_ruby.sh`:**
    *   Updated `check_directory_writable`, `install_ruby`, `gem_install_or_update`, and `optimize_ruby_service` to use consistent logging and read gems from `config.json`.
*   **`optimize_venv.sh`:**
    *   Updated `check_directory_writable`, `pipx_install_or_update`, and `optimize_venv_service` to use consistent logging and read packages from `config.json`.
*   **`sample_check.sh` (plugin):**
    *   Updated `plugin_sample_check` to use consistent logging.
*   **`final_audit.sh`:**
    *   Updated `check_systemd_timer`, `check_auditd_rules`, `check_pacman_dupes`, `check_systemctl_aliases`, `provide_recommendations`, `check_verify_script`, `run_audit`, and the main execution block to use consistent logging and read audit keywords from `config.json`.
*   **`cli.sh` and `dialog.sh` (view scripts):**
    *   Updated `main_cli` and `main_dialog` to use consistent logging.

This concludes the monthly update and refinement process.
