# 4ndr0service Capability Ledger — Initial Semantic Pass

**Protocol:** GUP 7.0.1  
**Scope:** `4ndr0tools/4ndr0service`  
**Observed service source candidate:** `e00d2ca39ca4b5dd7bf9e5c96d0130e042521360`  
**Status:** `PRELIMINARY — BASELINE NOT APPROVED`

This is a semantic classification pass over the 48-file scope inventory and selected entry-point, loader, installer, service, view, systemd, and test sources. It is not a completed baseline capability ledger: function-level behavior review, per-path history continuity, complete dependency binding, and the nine-surface closure gate remain open. Inferred roles are marked as such and must not be treated as proof that a path is live.

## Capability-to-file map

| Capability / component | Files | Observed role and evidence | State |
|---|---|---|---|
| Main CLI and mode dispatch | `main.sh` | Parses `--help`, `--version`, `--report`, `--fix`, `--parallel`, `--test`, and `--cli`; initializes the suite and chooses report/fix/interactive paths. | Observed; branch-level behavior review pending |
| Shared runtime substrate | `common.sh` | Exports suite version and XDG-derived paths, logging/error helpers, mutex lock, config/log locations, and shared runtime utilities. | Critical provider; history review pending |
| Controller and orchestration | `controller.sh` | Loads plugins, service scripts and views; invokes serial/parallel service paths and environment verification. | Loader/caller graph partially observed |
| File/service orchestration | `manage_files.sh` | Batch execution and dependency bridge; also sources controller for standalone use. | Potential cyclic/load-order edge requires isolated verification |
| Settings mutation | `settings_functions.sh` | Reads editor/config options from `CONFIG_FILE` and provides settings modification/prompt functions. | Config consumer observed; schema/round-trip review pending |
| Primary interactive view | `view/cli.sh` | CLI menu actions route to audit, ascension, purge, controller and verification functions. | Call paths partially observed |
| Optional dialog view | `view/dialog.sh` | Dialog TUI with corresponding audit/ascension/purge actions and CLI fallback. | Optional dependency/fallback closure pending |
| Python hive and isolated tool lifecycle | `ascension.sh` | Provides sync/install/remove/list operations for isolated Python tools and ghost cleanup. | Core capability; dependency and negative-path review pending |
| Deep cleanup / purge | `purge_matrix.sh` | Destructive purge entry point with force gate and shared XDG/Python-hive paths. | Destructive boundary needs target review |
| Cache pruning | `prunesys` | Cache maintenance entry point; sources common runtime substrate. | Cleanup semantics and idempotency review pending |
| Repository alias generation | `plugins/scr_alias_gen.sh` | Scans configured/repository tools and generates Zsh aliases under the XDG cache path. | Plugin loader linkage observed; generated output lifecycle pending |
| Cargo optimization | `service/optimize_cargo.sh` | Cargo cache/tool optimization; reads `cargo_tools` configuration. | Provider present; controller discovery and config contract pending |
| Electron optimization | `service/optimize_electron.sh` | Electron cache/tool optimization and NVM context loading; reads `electron_tools`. | Provider present; caller/config contract pending |
| Go optimization | `service/optimize_go.sh` | Go workspace/module-cache optimization; reads `go_tools`. | Provider present; caller/config contract pending |
| Meson optimization | `service/optimize_meson.sh` | Meson/Ninja cache maintenance. | Provider present; caller and destructive-scope review pending |
| Node optimization | `service/optimize_node.sh` | Node/Corepack/global-package maintenance; interacts with NVM and npm globals. | Cross-provider dependency on NVM observed; order/failure review pending |
| NVM optimization | `service/optimize_nvm.sh` | NVM install/version and Node version selection; reads `node_version` and contacts upstream release metadata. | Network/runtime dependency and failure paths pending |
| Python optimization | `service/optimize_python.sh` | pyenv/Python lifecycle, Python version config, and Python-hive integration. | Recent pipx fail-closed fix and regression test present |
| Ruby optimization | `service/optimize_ruby.sh` | Ruby/Gem path and configured gem optimization via `ruby_gems`. | Provider present; caller/config contract pending |
| Virtualenv/pipx optimization | `service/optimize_venv.sh` | Venv/pipx environment, configured package sync, and cache cleanup; reads `venv_pipx_packages`. | Recent pipx fail-closed fix and regression test present |
| Systemd unit deployment | `systemd/install_env_maintenance.sh` | Isolated runtime proof exercises flat template discovery, custom suite-root rewrites, systemctl activation, source-template preservation, repeat-run byte stability, and missing-service generation. | Targeted installer path PASS in PR #167 CI; real host/systemd activation and full installer rollback remain unverified |
| Scheduled maintenance unit | `systemd/env_maintenance.service` | Isolated runtime test confirms `Environment=PKG_PATH` and `ExecStart` are rewritten to a suite root containing spaces, and source template remains unchanged. | Template-to-installer contract PASS in mocked runtime; host systemd behavior remains unverified |
| Scheduled maintenance timer | `systemd/env_maintenance.timer` | Isolated runtime test confirms flat `systemd/*.timer` discovery, deployed daily schedule, activation commands, and byte-stable repeated deployment. | Historical `systemd/user/env_maintenance.timer` is `translated` to this target at the source-tree/installer-discovery boundary; actual host scheduling, permissions, full install transaction, rollback and uninstall remain unverified |
| Operator documentation | `README.md` | Documents install, modes, service capabilities, configuration, systemd, troubleshooting, recovery and tests. | Documentation-to-implementation parity pending |
| Scope/integration runtime gate | `test/gup_runtime_gate.sh` | Runs 20 named shell runtime proofs and stops at first failing test, including systemd installer lifecycle. | 20/20 passed in post-merge GUP run 39522409058 at merge commit 407924afb16cd97803f88198de8e6e2217618854; other integration surfaces remain PARTIAL |
| Ascension runtime proof | `test/ascension_runtime.sh` | Regression coverage for Python hive/ascension behavior. | In runtime gate |
| Plugin runtime proof | `test/controller_plugin_runtime.sh` | Controller/plugin loading contract. | In runtime gate |
| Controller runtime proof | `test/controller_runtime.sh` | Controller orchestration contract. | In runtime gate |
| Audit runtime proof (legacy/current) | `test/final_audit_runtime.sh`, `test/final_audit_runtime_v2.sh` | Runtime coverage for audit behavior. | Both in runtime gate; overlap rationale pending |
| Audit behavior proof | `test/final_audit.sh` | Implements environment/systemd/auditd/package checks and optional repair path. | Runtime caller observed; not a test-only file despite its directory |
| Ghost removal proof | `test/ghost_removal_runtime.sh` | Regression coverage for ghost artifacts/links. | In runtime gate |
| Go runtime proof | `test/go_runtime.sh` | Go optimization behavior. | In runtime gate |
| Installer runtime proof (legacy/current) | `test/installer_runtime.sh`, `test/installer_runtime_v2.sh` | Installer failure propagation and post-install verification contracts. | Both in runtime gate; overlap rationale pending |
| Node/NVM runtime proof | `test/node_nvm_runtime.sh` | Cross-service Node/NVM behavior. | In runtime gate |
| Parallel execution proof | `test/parallel_runtime.sh` | Parallel worker behavior and failure propagation. | In runtime gate |
| Canonical path resolver proof | `test/path_resolution_runtime.sh` | Regression tests for cwd-independent suite root, sentinel check and installed systemd paths. | In runtime gate; preserves a previously fixed critical defect class |
| Pipx inventory proof | `test/pipx_inventory_runtime.sh` | Distinguishes absent packages from operational inventory failures and checks both consumers abort on query failure. | In runtime gate; 8 assertions passed in PR #161 CI |
| Prunesys runtime proof | `test/prunesys_runtime.sh` | Cache-prune behavior. | In runtime gate |
| Purge runtime proof | `test/purge_runtime.sh` | Purge safety and force-gate behavior. | In runtime gate |
| Bounded execution proof | `test/run_bounded_runtime.sh` | Bounded subprocess/status propagation. | In runtime gate; preserve prior EAFP/status fixes |
| Settings runtime proof | `test/settings_runtime.sh` | Settings behavior. | In runtime gate |
| Source safety proof | `test/source_safety_runtime.sh` | Sourcing/side-effect safety. | In runtime gate |
| Environment verifier runtime proof | `test/verify_environment_runtime.sh` | Environment verifier behavior. | In runtime gate |
| Systemd installer runtime proof | `test/systemd_installer_runtime.sh` | Mocks systemctl in a disposable suite tree; verifies flat template discovery, custom-root patching, source preservation, idempotent rerun, and missing companion-service generation. | In runtime gate; passed in PR #167 run 39518240154 |
| Environment verifier implementation | `test/verify_environment.sh` | Environment audit and provisioning helpers; runs only when executed directly but is also sourced by production orchestration. | Production dependency hidden under `test/`; must remain until callers/migration are proven |
| Historical migration-path rename candidate | `test/tools/error_mitigations.sh` | Exact Git blob match for deleted `test/tools/4ndr0service_env_migrate.sh` at commit `0ed45470d981c426a08730b66b7abeacb4a30391`; GitHub commit metadata marks it renamed with zero content changes. Current file content is an installer implementation (header says `install.sh`), not an error-mitigation helper suite. | `UNRESOLVED_ROLE_MISMATCH`: trace callers, determine intended ownership, and prove whether this older installer snapshot is independently invoked before classifying or moving it |
| Installer | `install.sh` | Installs suite under `/opt/4ndr0service`, links `/usr/local/bin/4ndr0service`, supports dry-run/uninstall, migration and optional systemd. | Critical deployment path; full rollback/upgrade behavior review pending |

## Preserved historical defect classes

These are established by repository history and existing test source; do not remove or weaken their coverage during later rounds.

1. **Bounded execution/status propagation:** commits `36b4fbb8ed93385f67dfd76ac468532e5bc01601`, `d05f370989f570cc2b7e8768a33991e8d3a0bc0b`, `8dbb2541bfa41b4e4f0cf65f6627ca0a94302f62`, and adjacent repairs. Guard `run_bounded_runtime.sh` and `parallel_runtime.sh`.
2. **Missing parallel worker failure:** commit `97c8d9caeeed61ecb92cd4d81963071ae147c9de`. Preserve the negative-path contract in `parallel_runtime.sh`.
3. **Suite-root/path resolution:** commit history includes centralized `PKG_PATH` detection and path fixes; `path_resolution_runtime.sh` records concrete previously broken cwd fallback, malformed source path, foreign `common.sh` adoption, and stale systemd environment cases. Preserve all these tests.
4. **Pipx inventory operational failure:** PRs #159 and #160; `pipx_inventory_runtime.sh` must continue to distinguish “not installed” from failed inventory and abort both consumers on operational errors.
5. **Installation failure propagation:** `installer_runtime.sh` and `installer_runtime_v2.sh` assert failures are not reported as successful installs.
6. **Source-time side effects:** `source_safety_runtime.sh` is a guard against changes that execute operations merely by sourcing a component.

## Initial findings requiring targeted review

- `controller.sh` sources `test/verify_environment.sh` as part of normal runtime loading. This is an actual runtime dependency in a test-named directory, not grounds to move/delete it. Trace all callers and install-copy behavior before any relocation.
- `manage_files.sh` may source `controller.sh` while `controller.sh` sources `manage_files.sh`; verify the guards and standalone entry paths for recursion and partial initialization.
- `controller.sh` dynamically discovers service scripts/plugins/views. Confirm every discovered file exports the expected function and every intended function is called; file presence alone is insufficient.
- `main.sh`, `controller.sh`, views, `ascension.sh`, `purge_matrix.sh`, and service scripts have separate direct/sourced entry paths. Source-safe/idempotent initialization must be proven per path.
- `env_maintenance.service` contains a documentation URL under `github.com/4ndr0666/4ndr0service`, while the observed repository is `4ndr0666/scr`. Confirm canonical project URL before changing it.
- Duplicate `final_audit_runtime.sh` / `final_audit_runtime_v2.sh` and `installer_runtime.sh` / `installer_runtime_v2.sh` remain in the gate. Determine whether they protect distinct regressions; do not consolidate based on names.
- `test/tools/error_mitigations.sh` is in the inventory but not in the 19-test runtime gate. Establish whether it has a separate supported invocation and add it to the gate only after checking runtime, duration and side effects.
- Configuration keys observed include `python_version`, `node_version`, `cargo_tools`, `electron_tools`, `go_tools`, `npm_global_packages`, `ruby_gems`, and `venv_pipx_packages`. Establish one authoritative schema/default path and map every key to its writer, reader and validation before certifying config closure.

## Required next evidence

1. Per-path history and rename/deletion continuity for all 48 files.
2. Exact entry-point → loader → caller → provider/consumer graph, including dynamically loaded scripts and all config keys.
3. Install, migration, systemd deployment, rollback and uninstall path proof.
4. Nine-surface closure dispositions, including explicit `NOT_APPLICABLE` with rationale where warranted.
5. Baseline/candidate tracked-file SHA-256 inventories and named-unit comparison from a real full Git checkout.
6. The reconciled GUP v7.0.1 tooling artifact was validated separately and is not vendored here; complete local-checkout inventory, tool integration, and candidate comparison remain outstanding.
