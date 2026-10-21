# Systemd Installer Integration Evidence

**Protocol:** GUP 7.0.1  
**Scope:** `4ndr0tools/4ndr0service`  
**Implementation under test:** `systemd/install_env_maintenance.sh`  
**Test:** `test/systemd_installer_runtime.sh`  
**Validation run:** [39518240154](https://github.com/4ndr0666/scr/actions/runs/39518240154)  
**Validated code head:** `6ffa9a92ec7647279640554691151116ddaab605`  
**Result:** `PASS — ISOLATED MOCKED RUNTIME ONLY`

## Proofs exercised

The test copies the current `common.sh`, systemd installer, service unit and timer into a disposable fixture. It redirects XDG paths to a temporary home and prepends a mocked `systemctl`; it does not activate systemd on the runner or mutate the repository's source templates.

1. **Flat template discovery:** the installer finds `systemd/env_maintenance.service` and `systemd/env_maintenance.timer` in the current flat directory layout.
2. **Custom root path rewrite:** the fixture suite path includes spaces. The deployed service unit contains matching `Environment=PKG_PATH=<suite-root>` and `ExecStart=<suite-root>/main.sh --fix --report`.
3. **Timer content preservation:** deployed timer retains `OnCalendar=daily`.
4. **Activation sequence:** the mocked command log records `systemctl --user daemon-reload`, `list-unit-files env_maintenance.timer`, and `enable --now env_maintenance.timer`.
5. **Source preservation:** SHA-256 of both source unit templates is unchanged after deployment.
6. **Rerun idempotency:** the deployed service and timer hashes remain byte-identical after a second run.
7. **Missing service generation:** when the fixture omits the service template, the installer generates a service in the disposable source tree, patches it to the fixture root, and deploys it.

The GUP runtime workflow passed run `39518240154`; Bash syntax, source-scope inventory, subtree parity, historical path audit, exact-blob audit and the runtime gate all completed successfully. The runtime gate now contains 20 named tests.

## Boundaries and unresolved work

- This proves installer behavior only under the controlled mocked environment. It does **not** prove real user-session systemd behavior, unit parser acceptance, timer scheduling, auditd provisioning, systemd daemon failure recovery, or host-level permission interactions.
- The existing installer rewrites unit files and activates the timer; this test does not prove the top-level `install.sh` transaction's complete copy/rollback/uninstall lifecycle.
- Historical `systemd/user/env_maintenance.timer` → `systemd/env_maintenance.timer` is strongly supported as `TRANSLATED` by exact blob identity, explicit Git rename metadata, and this path-discovery test. Final historical disposition remains `UNRESOLVED` until a reviewed disposition record reconciles the source path and the full install/migration context.
- `test/tools/error_mitigations.sh` is an executable installer snapshot (its header says `install.sh`), not an error mitigation helper. Repository code search found no explicit invocation beyond self-contained installer references and evidence/ledger mentions. Search-index absence does not prove it is unreachable: glob-based discovery, user invocation, installed copies and external callers remain possible. Its disposition remains `UNRESOLVED_ROLE_MISMATCH`; do not execute it on a real host, move it, or remove it as part of this pass.
- Historical deletion counts remain 52 rename-aware unresolved paths and 55 no-renames raw candidates (2 exact-blob leads, 53 without exact matches). Canonical baseline remains unset. All nine integration surfaces remain `PARTIAL`; no GUP/SUK certification is claimed.
