# 4ndr0service

`4ndr0service` is a Linux environment-maintenance and optimization suite for managing development toolchains, Python environments, caches, system maintenance, auditing, and optional scheduled maintenance.

This document is written for **operating the suite**. It focuses on installation, everyday use, configuration, maintenance, troubleshooting, and recovery.

> **Scope:** This documentation covers `4ndr0tools/4ndr0service/`. Repository dependency-management files and workflows are outside the scope of this suite documentation.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [What 4ndr0service Does](#2-what-4ndr0service-does)
3. [Requirements](#3-requirements)
4. [Installation](#4-installation)
5. [First Run](#5-first-run)
6. [Command-Line Options](#6-command-line-options)
7. [Interactive Menu](#7-interactive-menu)
8. [Optimization Services](#8-optimization-services)
9. [Python Hive Management](#9-python-hive-management)
10. [Deep Cleanup](#10-deep-cleanup)
11. [Audit and Verification](#11-audit-and-verification)
12. [Systemd Maintenance Timer](#12-systemd-maintenance-timer)
13. [Configuration](#13-configuration)
14. [Files, State, and Logs](#14-files-state-and-logs)
15. [Troubleshooting](#15-troubleshooting)
16. [Recovery and Contingencies](#16-recovery-and-contingencies)
17. [Testing the Installation](#17-testing-the-installation)
18. [Uninstallation](#18-uninstallation)
19. [Operational Reference](#19-operational-reference)

---

# 1. Quick Start

## 1.1 Install

From the `4ndr0service` directory:

```bash
sudo ./install.sh
```

The standard installation is:

```text
/opt/4ndr0service
```

The command installed for normal use is:

```text
/usr/local/bin/4ndr0service
```

## 1.2 Verify

Run:

```bash
4ndr0service --version
4ndr0service --report
```

If both commands complete normally, the installed copy is available and the audit/report path can be reached.

## 1.3 Start the normal interface

```bash
4ndr0service
```

This opens the interactive interface.

If you want the shell-based interface explicitly:

```bash
4ndr0service --cli
```

## 1.4 Repair mode

To run the audit path with automatic remediation:

```bash
4ndr0service --fix
```

## 1.5 If the installed command is unavailable

Run the repository copy directly:

```bash
cd /path/to/scr/4ndr0tools/4ndr0service
bash ./main.sh --help
```

If this works, the suite itself is available and the installed copy or `/usr/local/bin/4ndr0service` link should be investigated.

---

# 2. What 4ndr0service Does

The suite provides several maintenance areas.

### Development environments

Optimization services are provided for:

- Go
- Ruby
- Cargo/Rust
- Node.js
- NVM
- Meson
- Python
- Electron
- Python virtual environments

### Python tools

The Python Hive layer manages isolated Python command-line tools in dedicated virtual environments.

It can:

- synchronize the Python environment;
- install an isolated Python tool;
- remove an isolated Python tool;
- list configured and live isolated tools;
- clean known Python/pip ghost artifacts.

### System maintenance

The suite can perform maintenance involving:

- stale files;
- broken symbolic links;
- Python caches;
- stale virtual environments;
- selected package/cache cleanup;
- the Python Ghost Link bridge;
- suite configuration.

### Auditing

The audit path checks the environment and maintenance state represented by the current suite, including areas such as:

- systemd;
- the maintenance timer;
- auditd rules;
- package-state checks;
- environment verification.

### Scheduled maintenance

The suite can install a user-scoped systemd service and timer for automated maintenance.

---

# 3. Requirements

The suite targets Arch Linux.

Common requirements are:

- Bash
- coreutils
- findutils
- util-linux
- `readlink`
- `jq`
- `pacman`
- `sudo` for privileged operations
- `systemctl` for systemd integration
- `auditctl`/`augenrules` where audit checks apply

The optional Dialog interface requires:

```text
dialog
```

Individual optimization services may require their corresponding language runtime, compiler, package manager, or toolchain.

The installer checks required components where appropriate instead of assuming every optional tool is installed.

---

# 4. Installation

## 4.1 Standard installation

From the suite directory:

```bash
sudo ./install.sh
```

The installer:

1. resolves the source and destination;
2. supports migration from the legacy `test/src/` layout;
3. synchronizes the suite files;
4. applies executable permissions to shell payloads;
5. creates or replaces the `4ndr0service` command link;
6. verifies `jq`;
7. can deploy the systemd maintenance units;
8. performs post-install verification;
9. rolls back supported partial installations when a safe rollback is possible.

## 4.2 Dry run

To inspect the installation without making filesystem changes:

```bash
sudo ./install.sh --dry-run
```

A successful dry run returns exit status `0`.

## 4.3 Install without systemd

If scheduled maintenance is not wanted:

```bash
sudo ./install.sh --skip-systemd
```

The suite can still be used manually.

Systemd can be configured later.

## 4.4 Check the installed command

```bash
command -v 4ndr0service
readlink -f "$(command -v 4ndr0service)"
```

The standard target should resolve to:

```text
/opt/4ndr0service/main.sh
```

---

# 5. First Run

A practical first-run sequence is:

```bash
4ndr0service --version
4ndr0service --report
4ndr0service
```

Use the interactive menu to select the maintenance operation you need.

For a repair-oriented pass:

```bash
4ndr0service --fix
```

For the shell interface without relying on the default interface selection:

```bash
4ndr0service --cli
```

---

# 6. Command-Line Options

| Command | Purpose |
|---|---|
| `4ndr0service` | Open the normal interactive interface |
| `4ndr0service --help` | Display command help |
| `4ndr0service --version` | Display the suite version |
| `4ndr0service --report` | Run the audit/report path |
| `4ndr0service --fix` | Run the audit path with automatic remediation |
| `4ndr0service --parallel` | Run the supported parallel service set |
| `4ndr0service --test` | Run core checks and emit structured output |
| `4ndr0service --cli` | Force the shell CLI |

`--report` and `--fix` use the audit path rather than the ordinary interactive service batch.

---

# 7. Interactive Menu

The interactive interface provides access to the suite's major operations.

The current menu contains:

1. Go Optimization
2. Ruby Optimization
3. Cargo Optimization
4. Node.js Optimization
5. NVM Optimization
6. Meson Optimization
7. Python Optimization
8. Electron Optimization
9. Venv Optimization
10. Audit/Verification
11. Sync Python Hive & Ghost Links
12. Install Isolated Python Tool
13. Remove Isolated Python Tool
14. List Injected Hive Tools
15. Deep Clean
16. File Management
17. Settings
18. Exit

A failed interactive operation returns control to the menu so another operation can be attempted. The failure is still recorded in the result/log.

## 7.1 Dialog interface

The Dialog interface is available through:

```text
view/dialog.sh
```

The controller can select it with:

```bash
USER_INTERFACE=dialog
```

If `dialog` is unavailable, the suite falls back to the CLI.

You can always force the CLI with:

```bash
4ndr0service --cli
```

---

# 8. Optimization Services

The service layer contains independent optimizers for:

- Go
- Ruby
- Cargo
- Node.js
- NVM
- Meson
- Python
- Electron
- virtual environments

Normal service execution runs the applicable services sequentially.

The supported parallel path currently runs:

```text
Go
Ruby
Cargo
```

using the corresponding optimizer functions.

## 8.1 If one service fails

A failure in one service does not necessarily prevent later services from running.

The final operation still reports failure when one or more services failed.

This means:

- later maintenance may continue;
- the failed operation is still visible;
- the overall result is not falsely reported as successful.

Check:

```bash
cat ~/.cache/4ndr0service/service.log
```

Then rerun the affected operation individually when practical.

---

# 9. Python Hive Management

`ascension.sh` manages isolated Python tools.

Run:

```bash
./ascension.sh --help
```

Supported operations include:

```text
--sync
--inject
--eject
--list
--clean-ghosts
```

## 9.1 Synchronize

```bash
./ascension.sh --sync
```

This synchronizes the Python environment and related Hive state.

## 9.2 Install an isolated Python tool

```bash
./ascension.sh --inject tool-name
```

The tool receives its own virtual environment under the configured virtual-environment area.

When installation succeeds, the suite creates the corresponding user-local executable link.

## 9.3 Remove an isolated Python tool

```bash
./ascension.sh --eject tool-name
```

Removal covers the isolated environment, suite-owned executable link, and corresponding configuration entry.

## 9.4 List tools

```bash
./ascension.sh --list
```

The listing distinguishes:

- configured tools with an existing virtual environment;
- configured tools whose virtual environment is missing;
- live virtual environments not represented in configuration.

## 9.5 Clean Python ghost artifacts

```bash
./ascension.sh --clean-ghosts
```

This targets known broken Python/pip metadata and ghost-artifact patterns rather than deleting arbitrary packages.

---

# 10. Deep Cleanup

The deep-clean functionality is provided by:

```text
purge_matrix.sh
```

It is also available from the interactive menu as **Deep Clean**.

It is intended for maintenance such as:

- broken symbolic links;
- stale virtual environments;
- Python cache trees;
- selected package/orphan cleanup paths.

Deep cleanup can remove data. Use it deliberately.

Before using the script directly:

```bash
./purge_matrix.sh --help
```

---

# 11. Audit and Verification

The full audit path is:

```text
test/final_audit.sh
```

Run it directly with:

```bash
bash test/final_audit.sh
```

The audit covers the current environment and maintenance checks represented by the suite, including:

- systemd bus availability;
- maintenance timer state;
- auditd rules;
- package duplicate checks;
- environment verification.

The main command uses this audit path for:

```bash
4ndr0service --report
```

and:

```bash
4ndr0service --fix
```

The interactive **Audit/Verification** menu uses the same audit surface.

---

# 12. Systemd Maintenance Timer

The suite provides:

```text
systemd/env_maintenance.service
systemd/env_maintenance.timer
systemd/install_env_maintenance.sh
```

The installer can deploy a user-scoped maintenance service and timer.

## 12.1 Check the service

```bash
systemctl --user status env_maintenance.service
```

## 12.2 Check the timer

```bash
systemctl --user status env_maintenance.timer
```

## 12.3 Check the schedule

```bash
systemctl --user list-timers env_maintenance.timer
```

## 12.4 Start maintenance manually

```bash
systemctl --user start env_maintenance.service
```

## 12.5 Read service logs

```bash
journalctl --user -u env_maintenance.service
```

## 12.6 Install or repair the systemd units

```bash
bash systemd/install_env_maintenance.sh
```

A usable user systemd session may be required. If user-systemd is unavailable, use direct commands such as:

```bash
4ndr0service --report
```

or:

```bash
4ndr0service --fix
```

---

# 13. Configuration

The default configuration file is:

```text
~/.config/4ndr0service/config.json
```

If it does not exist, the suite creates a default configuration.

The configuration contains settings covering areas such as:

- editor selection;
- Python version;
- required environment variables;
- directory locations;
- base tools;
- Python tools;
- Cargo tools;
- Electron tools;
- Go tools;
- Node version;
- global npm packages;
- Ruby gems;
- virtual-environment packages;
- audit keywords;
- Hive entries.

## 13.1 Validate configuration

```bash
jq -e . ~/.config/4ndr0service/config.json
```

A non-zero result means the JSON should be treated as invalid and repaired before relying on downstream operations.

Preserve a copy of a damaged configuration before replacing it.

---

# 14. Files, State, and Logs

The suite follows the normal XDG user-directory layout.

Default locations:

| Purpose | Location |
|---|---|
| Configuration | `~/.config/4ndr0service/` |
| Main configuration | `~/.config/4ndr0service/config.json` |
| Cache | `~/.cache/4ndr0service/` |
| Service log | `~/.cache/4ndr0service/service.log` |
| Data | `~/.local/share/` |
| State | `~/.local/state/` |
| User executables | `~/.local/bin/` |

Suite-related tool locations include:

```text
~/.local/share/pyenv
~/.local/share/virtualenv
~/.local/share/pipx
~/.local/share/nvm
~/.local/share/psql
~/.local/share/mysql
```

The actual configuration determines which of these are used.

## 14.1 Read the service log

```bash
cat ~/.cache/4ndr0service/service.log
```

The terminal output is human-readable. The log file is written without terminal color/control sequences.

---

# 15. Troubleshooting

## 15.1 `4ndr0service` command not found

Check:

```bash
command -v 4ndr0service
ls -l /usr/local/bin/4ndr0service
```

If the command is missing, reinstall:

```bash
sudo ./install.sh
```

You can also run the repository copy directly:

```bash
bash ./main.sh --help
```

---

## 15.2 Suite root cannot be located

Check the entry point:

```bash
readlink -f ./main.sh
```

Check the shared runtime file:

```bash
ls -l ./common.sh
grep -n '4ndr0service' ./common.sh
```

The executable should be part of a complete `4ndr0service` tree.

Do not solve a suite-root problem by pointing `PKG_PATH` at an unrelated shell library.

---

## 15.3 `PKG_PATH` appears stale

Check:

```bash
printf 'PKG_PATH=%s\n' "${PKG_PATH:-<unset>}"
readlink -f "$(command -v 4ndr0service)"
```

Executed entry points resolve their own suite location. If the installed command resolves to the wrong tree, repair the installation or symlink rather than forcing an unrelated `PKG_PATH`.

---

## 15.4 `jq` is missing

On Arch Linux:

```bash
sudo pacman -S jq
```

Verify:

```bash
jq --version
```

Then rerun the failed operation.

---

## 15.5 Configuration is corrupt

Validate:

```bash
jq -e . ~/.config/4ndr0service/config.json
```

If invalid:

1. preserve the existing file for diagnosis;
2. restore valid JSON;
3. rerun the affected operation.

Do not replace JSON with shell syntax or an incomplete fragment.

---

## 15.6 Pacman reports a lock

Inspect:

```bash
ls -l /var/lib/pacman/db.lck
ps aux | grep '[p]acman'
```

If a real package transaction is running, let it finish.

Only remove a lock after establishing that no package-manager process owns the transaction and that the lock is stale.

---

## 15.7 Systemd timer did not activate

Check:

```bash
systemctl --user status env_maintenance.timer
systemctl --user status env_maintenance.service
systemctl --user list-timers env_maintenance.timer
```

Check the journal:

```bash
journalctl --user -u env_maintenance.service
```

If user-systemd is unavailable, install from a normal logged-in user session or use:

```bash
bash systemd/install_env_maintenance.sh
```

Manual execution remains available:

```bash
4ndr0service --report
```

---

## 15.8 Auditd rule installation failed

Inspect the rule:

```bash
sudo test -f /etc/audit/rules.d/4ndr0service.rules
```

Inspect loaded rules:

```bash
sudo auditctl -l
```

A missing rule or failed rule write is an actual remediation failure and should be resolved before treating the audit as clean.

---

## 15.9 A service failed but later services ran

This is normal for the batch execution path.

Read the log:

```bash
cat ~/.cache/4ndr0service/service.log
```

Find the failed operation and rerun it independently when possible.

The fact that later operations completed does not make the failed batch successful.

---

## 15.10 A command returned `124`

`124` is the suite's timeout result.

Check the log for the operation and its timeout.

For a network-dependent operation:

1. verify network connectivity;
2. verify DNS;
3. verify the package or tool source;
4. retry the specific operation;
5. increase a timeout only when the operation genuinely requires more time.

Do not convert a timeout into success.

---

## 15.11 A command returned `137`

`137` indicates that a timed-out process survived the initial termination signal and was forcibly terminated.

Investigate the command itself and why it did not terminate normally.

---

## 15.12 Dialog is unavailable

The suite can fall back to the CLI.

Use:

```bash
4ndr0service --cli
```

If the Dialog interface is required, install `dialog`:

```bash
sudo pacman -S dialog
```

---

## 15.13 Python Hive tool has a missing virtual environment

Inspect the inventory:

```bash
./ascension.sh --list
```

If a configured tool has no corresponding virtual environment, remove and reinstall the affected tool using the Hive operations.

Avoid deleting arbitrary virtual environments before checking whether the suite configuration references them.

---

## 15.14 Python ghost artifacts remain

Run:

```bash
./ascension.sh --clean-ghosts
```

Then inspect the relevant Python environment if the problem persists.

The cleanup targets known ghost-artifact patterns rather than indiscriminately deleting installed packages.

---

## 15.15 Installation failed part-way through

Inspect:

```bash
ls -ld /opt/4ndr0service
ls -l /usr/local/bin/4ndr0service
```

Resolve the reported cause, then rerun:

```bash
sudo ./install.sh
```

The installer has rollback handling for supported installation targets.

For a custom installation location outside the installer's safe rollback prefixes, inspect the target manually before removing anything.

---

# 16. Recovery and Contingencies

## 16.1 The installed suite will not start

Run the repository copy:

```bash
cd /path/to/scr/4ndr0tools/4ndr0service
bash ./main.sh --help
```

If that succeeds, inspect the installed command:

```bash
readlink -f "$(command -v 4ndr0service)"
```

Then reinstall if necessary:

```bash
sudo ./install.sh
```

---

## 16.2 The installed copy is suspect

Verify the command target:

```bash
readlink -f "$(command -v 4ndr0service)"
```

Compare it with:

```text
/opt/4ndr0service/main.sh
```

Then reinstall from the known-good checkout:

```bash
sudo ./install.sh
```

---

## 16.3 Systemd is unavailable

The timer is optional for manual operation.

Use:

```bash
4ndr0service --report
```

or:

```bash
4ndr0service --fix
```

---

## 16.4 One optimizer is broken

Use the corresponding interactive menu operation or isolate the service directly after loading the suite environment.

Review:

```bash
cat ~/.cache/4ndr0service/service.log
```

Do not suppress the failure merely to make the rest of the maintenance run appear successful.

---

## 16.5 The runtime test gate fails

From the repository root:

```bash
ROOT="$(git rev-parse --show-toplevel)"
GUP_REPO_ROOT="$ROOT" \
bash "$ROOT/4ndr0tools/4ndr0service/test/gup_runtime_gate.sh"
```

Identify the first failing proof.

Run that proof independently:

```bash
bash test/the-failing-proof.sh
```

Use the failure output to locate the specific problem, correct the problem, then rerun the individual proof followed by the complete gate.

---

# 17. Testing the Installation

The suite contains 18 runtime proof scripts.

## 17.1 Run the complete gate

From the repository root:

```bash
ROOT="$(git rev-parse --show-toplevel)"

GUP_REPO_ROOT="$ROOT" \
bash "$ROOT/4ndr0tools/4ndr0service/test/gup_runtime_gate.sh"
```

A clean run ends with:

```text
GUP current-iteration runtime gate: 18/18 passed
[PASS] Current repository iteration is runtime-gate clean
```

## 17.2 Run individual runtime tests

The available proofs are:

```bash
bash test/ascension_runtime.sh
bash test/controller_plugin_runtime.sh
bash test/controller_runtime.sh
bash test/final_audit_runtime.sh
bash test/final_audit_runtime_v2.sh
bash test/ghost_removal_runtime.sh
bash test/go_runtime.sh
bash test/installer_runtime.sh
bash test/installer_runtime_v2.sh
bash test/node_nvm_runtime.sh
bash test/parallel_runtime.sh
bash test/path_resolution_runtime.sh
bash test/prunesys_runtime.sh
bash test/purge_runtime.sh
bash test/run_bounded_runtime.sh
bash test/settings_runtime.sh
bash test/source_safety_runtime.sh
bash test/verify_environment_runtime.sh
```

## 17.3 Shell syntax checks

Check individual files:

```bash
bash -n main.sh
bash -n common.sh
bash -n controller.sh
bash -n install.sh
```

Check every shell script:

```bash
find . -type f -name '*.sh' -print0 |
while IFS= read -r -d '' file; do
    bash -n "$file" || exit 1
done
```

## 17.4 Check Git whitespace errors

```bash
git diff --check
```

---

# 18. Uninstallation

The standard uninstall path is:

```bash
sudo ./install.sh --uninstall
```

The uninstall operation removes the standard installation components, including the normal command link and suite-managed user systemd/audit components where applicable.

Before uninstalling, preserve any configuration or data that you intentionally want to keep.

The uninstall operation should not be treated as a generic cleanup command for unrelated files stored in user XDG directories.

---

# 19. Operational Reference

## Common commands

### Start

```bash
4ndr0service
```

### Help

```bash
4ndr0service --help
```

### Version

```bash
4ndr0service --version
```

### Report

```bash
4ndr0service --report
```

### Repair

```bash
4ndr0service --fix
```

### CLI

```bash
4ndr0service --cli
```

### Parallel checks

```bash
4ndr0service --parallel
```

### Test mode

```bash
4ndr0service --test
```

### Python Hive help

```bash
./ascension.sh --help
```

### Python Hive synchronization

```bash
./ascension.sh --sync
```

### List isolated Python tools

```bash
./ascension.sh --list
```

### Clean Python ghost artifacts

```bash
./ascension.sh --clean-ghosts
```

### Run deep-clean help

```bash
./purge_matrix.sh --help
```

### Read the service log

```bash
cat ~/.cache/4ndr0service/service.log
```

### Validate configuration

```bash
jq -e . ~/.config/4ndr0service/config.json
```

### Check systemd timer

```bash
systemctl --user status env_maintenance.timer
```

### Check systemd service

```bash
systemctl --user status env_maintenance.service
```

### Read systemd logs

```bash
journalctl --user -u env_maintenance.service
```

### Run the complete runtime gate

```bash
ROOT="$(git rev-parse --show-toplevel)"
GUP_REPO_ROOT="$ROOT" \
bash "$ROOT/4ndr0tools/4ndr0service/test/gup_runtime_gate.sh"
```

---

## Exit-status quick reference

The suite preserves meaningful command results rather than turning failures into success.

Important bounded-execution results include:

| Status | Meaning |
|---:|---|
| `0` | Successful operation |
| `2` | Invalid timeout or missing command in bounded execution |
| `124` | Operation timed out |
| `137` | Timed-out process required forced termination |
| Other non-zero | Operation-specific failure |

For a batch operation, one failed service can be followed by additional services, but the aggregate operation still returns non-zero.

---

## Installation locations

Standard installed tree:

```text
/opt/4ndr0service
```

Standard command:

```text
/usr/local/bin/4ndr0service
```

Main installed entry point:

```text
/opt/4ndr0service/main.sh
```

---

## Suite layout

The main operational components are:

```text
4ndr0service/
├── main.sh
├── common.sh
├── controller.sh
├── settings_functions.sh
├── manage_files.sh
├── ascension.sh
├── purge_matrix.sh
├── prunesys
├── plugins/
├── service/
├── view/
├── systemd/
└── test/
```

The important user-facing areas are:

- `main.sh` — primary entry point
- `view/` — interactive interfaces
- `service/` — optimization services
- `ascension.sh` — Python Hive management
- `purge_matrix.sh` — deep cleanup
- `systemd/` — scheduled maintenance
- `test/` — verification and runtime tests

---

## Recommended operating sequence

For routine maintenance:

```text
1. 4ndr0service --report
2. Review any reported issues
3. 4ndr0service --fix when remediation is appropriate
4. Re-run 4ndr0service --report
5. Use the interactive menu for targeted optimization or cleanup
6. Review ~/.cache/4ndr0service/service.log when an operation fails
```

For a newly installed or repaired checkout:

```text
1. sudo ./install.sh
2. 4ndr0service --version
3. 4ndr0service --report
4. 4ndr0service
5. Verify systemd separately if scheduled maintenance was enabled
```

For a problem:

```text
1. Read the reported error
2. Check ~/.cache/4ndr0service/service.log
3. Re-run the affected operation directly
4. Check configuration, package-manager, systemd, or network state as applicable
5. Use the repository copy if the installed command itself is suspect
```

This keeps normal operation, targeted maintenance, and recovery paths separate and makes the source of a failure easier to identify.
