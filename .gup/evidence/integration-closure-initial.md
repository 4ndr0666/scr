# 4ndr0service Integration Closure — First Broad-Radius Pass

**Protocol:** GUP 7.0.1  
**Scope source:** `e00d2ca39ca4b5dd7bf9e5c96d0130e042521360` / tree `bcc1e9652ca6a45d1f8e6bbc246e01885125e305`  
**Current repository HEAD at observation:** `5c6ff8734052e633638325b657c3e29cb48105ed`  
**Verdict:** `BLOCKED — INITIAL OBSERVATIONS ONLY`

This ledger records the broad-radius integration pass. “Observed” means a source path or explicit call/reference was inspected; it does not mean all paths are proven complete. No capability removal is proposed. All unresolved items remain blockers.

## Required nine-surface matrix

| Surface | Initial observations | Closure status | Evidence still required |
|---|---|---|---|
| `entry_points` | `main.sh` exposes help/version/report/fix/parallel/test/CLI modes; `install.sh` exposes install/dry-run/uninstall/systemd-skip; `ascension.sh`, `purge_matrix.sh`, `prunesys`, and `systemd/install_env_maintenance.sh` are additional executable entry points. | PARTIAL | Enumerate direct vs sourced entry modes, argument contracts, exit statuses, permissions and source-safe behavior for every executable file. |
| `loaders` | `main.sh` sources `common.sh`, `controller.sh`, and `manage_files.sh`; controller sources settings/files, dynamically loads plugins/services/views and sources `test/verify_environment.sh`; views load audit/ascension/purge and may fall back between CLI/dialog. | PARTIAL | Derive complete loader graph with order, conditional branches, source guards, missing-file handling and recursion/load-order tests. |
| `callers` | Controller dispatches service functions and view actions; main routes modes; views route audit/cleanup/config actions; systemd invokes installed main entry point. | PARTIAL | Map every exported function to actual caller and test; detect uncalled helpers, dead dispatch branches, missing function names and unhandled return values. |
| `providers` | `common.sh` provides shared paths/logging/locking/config helpers; service scripts define `optimize_*_service`; plugin defines `plugin_scr_alias_gen`; audit and UI scripts provide their named functions. | PARTIAL | Verify each provider’s public symbol names against all dynamic dispatches and validate required helper definitions in isolated/sourced modes. |
| `consumers` | Main/controller/views consume shared helpers; service scripts consume XDG paths, config keys, package managers, language runtimes, network release metadata and filesystem state; installer consumes source tree/systemd templates. | PARTIAL | Bidirectional dependency ledger: every consumer requirement declared, every declaration actually consumed, every provider version/capability verified; include error/timeout semantics. |
| `configuration_paths` | Shared config path is `${XDG_CONFIG_HOME}/4ndr0service/config.json`; XDG config/data/state/cache/bin paths and pipx/NVM/Python/Gem/Cargo/Go paths are derived in shared/service scripts. Observed keys include `python_version`, `node_version`, `cargo_tools`, `electron_tools`, `go_tools`, `npm_global_packages`, `ruby_gems`, `venv_pipx_packages`. | PARTIAL | Identify canonical config schema and creation/default/migration path; validate malformed/missing config, key writers/readers, type/range checks and atomic writes. |
| `install_migration_paths` | `install.sh` uses `/opt/4ndr0service`, `/usr/local/bin/4ndr0service`, dry-run/uninstall, old `test/src` layout migration, rollback trap and optional systemd; systemd installer patches installed unit paths. | PARTIAL | Prove clean install, upgrade, migration, failure at each mutation, rollback preservation, uninstall bounds, re-run idempotency and actual copied-file inventory. |
| `tests` | Runtime gate lists 19 tests; prior CI reported 19/19 pass, pipx proof 8/0; CI validates Bash syntax for 44 `.sh` files and ShellCheck. `test/tools/error_mitigations.sh` is inventoried but not in the 19-test list. | PARTIAL | Run tests from exact candidate checkout; map each test to protected capability and production caller; resolve test overlap and standalone tests not invoked by any workflow. |
| `runtime_dependencies` | README declares Bash, coreutils, findutils, util-linux, readlink, jq, pacman, sudo, systemctl and audit tooling; Dialog is optional; optimizer scripts add language runtimes, package managers, curl/network and system state dependencies. | PARTIAL | Bidirectional dependency declaration audit, minimum versions/platform assumptions, optional-vs-required distinction, network denial/failure paths, timeout and missing-binary injection. |

## Initial architecture and deployment observations

### Entry and loading flow (partial)

```text
install.sh
  ├─ copies suite to /opt/4ndr0service
  ├─ creates /usr/local/bin/4ndr0service
  └─ optionally deploys user systemd service + timer

main.sh
  ├─ common.sh
  ├─ controller.sh
  │   ├─ settings_functions.sh
  │   ├─ manage_files.sh
  │   ├─ plugins/*.sh (dynamic)
  │   ├─ service/*.sh (dynamic)
  │   ├─ view/*.sh (dynamic)
  │   └─ test/verify_environment.sh
  └─ manage_files.sh

view/cli.sh and view/dialog.sh
  ├─ final_audit.sh
  ├─ verify_environment.sh
  ├─ ascension.sh
  ├─ purge_matrix.sh
  └─ controller/common entry paths
```

This diagram is a partial graph from observed source statements, not a complete call graph. Dynamic glob order, function dispatch and conditional branches remain unverified.

### Findings / target order

1. **T1 — Capture exact source graph and load order.** Resolve the `controller.sh` ↔ `manage_files.sh` relationship, dynamic glob ordering, source guards and function dispatch.
2. **T2 — Preserve production dependency hidden under test path.** Trace `test/verify_environment.sh` callers and installer inclusion. Do not move or rename it until a migration with equivalence proof exists.
3. **T3 — Canonical configuration contract.** Trace config creation, validation, all readers/writers, key types and missing/malformed cases. No configuration file is present in the 48-file scope inventory; establish whether it is generated at runtime or owned elsewhere.
4. **T4 — Installation and systemd closure.** Trace copied files, path rewrites, service/timer activation, rollback and uninstall. Confirm the documentation URL before any correction.
5. **T5 — Test closure.** Resolve duplicate versioned runtime tests and determine why `test/tools/error_mitigations.sh` is not in the runtime gate. Preserve existing tests until redundancy is proven.
6. **T6 — Runtime dependency matrix.** Reconcile README claims, actual commands, optional tools and network dependencies in both directions.
7. **T7 — Full lineage and semantic superset.** Generate per-path history dispositions and SHA-256/named-unit evidence from a complete Git checkout before baseline approval.

## Evidence boundary

The current runtime gate and syntax/ShellCheck results are useful narrow checks. They do not prove all nine surfaces are closed, configuration is canonical, install/migration paths are complete, or the service is a behavioral superset. No GUP PASS is claimed.
