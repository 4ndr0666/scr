# permctl: Unified Arch Linux Permissions, ACL, Policy & Recovery Suite

`permctl` is a comprehensive, production-grade, and strictly POSIX-compliant (`#!/bin/sh`) system administration suite for Arch Linux and systemd-based Linux distributions. It consolidates, modernizes, and supersedes 23 disparate legacy scripts, prototypes, and operational guides into a single, cohesive command-line utility and interactive terminal console.

The suite provides daily-driver conveniences (rapid ownership changes, restrictive lockdown, private directory enforcement, and undo/rollback), deep sysadmin operations (POSIX ACLs, extended attribute locking, multi-format permission snapshots, and user account migration), declarative policy management, package database audits (`pacman -Qkk` / mtree repair), and emergency disaster recovery (guarded `/dev/null` recreation and authentication-path restoration).

---

## Architecture & Engineering Principles

* **Strict POSIX Compliance (`#!/bin/sh`):** Engineered with zero Bashisms (no `[[ ... ]]`, no arrays, no `local`, no `declare`, no `source`, no process substitution, and no non-POSIX `read`/`echo` flags). Validated against `/usr/bin/dash` and `/usr/bin/bash --posix`.
* **Fail-Closed & EAFP Error Handling:** Mutating operations attempt changes directly at the filesystem layer, log exact status codes, and halt or warn on failure without masked subshell errors.
* **Persistent Session Rollback Journal:** Every file mutation records previous ownership, octal mode, and path into a persistent journal (`permctl_rollback.tsv`), enabling multi-step rollbacks both from the interactive console (`z`) and from the CLI (`permctl rollback`).
* **Subshell-Safe Metrics & Declarative Policies:** Eliminates legacy subshell counter bugs (where counters piped into `while` loops silently reported zero). Policy generation, auditing, and enforcement use clean tab/pipe-separated streams (`permissions_policy.tsv`) and export standard YAML companion policies (`permissions_policy.yaml`).
* **Smart Binary & Script Detection:** When resetting `/home` permissions, `permctl` inspects file headers (`#!` shebangs, `\x7fELF` magic bytes) and canonical script paths rather than trusting existing execute bits, ensuring genuine binaries keep `0755` while accidentally `0777`'d regular files normalize to `0644`.
* **Universal Snapshot Compatibility:** Auto-detects and restores across four generations of legacy backup formats, including unified multi-file bundles (`.perms`, `.acl`, `.attrs`), legacy `perm_snapper` tables, CSV logs, and `acl_manager` directories with user remapping (`--remap-user=OLD:NEW`).

---

## Consolidation Map (Superseded Legacy Utilities)

`permctl` replaces all scripts, fragments, and templates previously maintained across the `legacy_code` tree:

| Legacy Utility / Directory | Replaced By `permctl` Subcommands | Key Flaws Resolved |
| :--- | :--- | :--- |
| `perms/perms.sh`, `perms2.sh`, `perms3.sh` | `status`, `own-it`, `compaudit`, `standard`, `rollback`, `cheatsheet` | Eliminated unsafe `eval` execution, unquoted variable expansions, and insecure `/etc/perms_config.cfg` `source` calls. |
| `groupacc.sh` | `own-it`, `compaudit`, `acl-get` | Added non-interactive CLI flags, recursion safeguards, and proper error propagation. |
| `interactive_perm_changer.sh` | `own-it`, `compaudit`, `standard` (`--pattern=GLOB`) | Replaced hardcoded prompts with flexible CLI arguments and glob filters. |
| `devnull_fix/permissions_rollback.sh` (v4) & `README.md` | `devnull-fix` (`emergency-rollback`) | Preserved guarded character device recreation (`c 1 3`, `0666`) and Phases 1–7 path repairs with full `--root=PATH` and `--dry-run` support. |
| `PermMaster/permmaster` & `README.md` | `menu`, `snapshot`, `restore`, `audit-pacman`, `fix-pacman`, `report` | Fixed unquoted `find` arguments, removed `find` pipe subshell races, and made snapshot parsing resilient to spaces in filenames. |
| `perm_snapper/perm_snapshot.sh` & `perm_snapshot_restore.sh` | `snapshot`, `restore` (`--from=PATH`) | Fixed broken `awk` field parsing (`awk '{print $1}'` failed on paths with spaces; `awk '{print $6}'` parsed `"file"` instead of `%A` symbolic bits). Tested against **39,960 legacy snapshot lines** with zero failures. |
| `permissionsctl` (v1, v2, v3, v4, v5) & `README.md` | `policy-gen`, `policy-audit`, `policy-fix`, `setup-cron` | Fixed subshell counter bug where discrepancies were lost across pipes; removed mandatory external `yq` and `parallel` runtime dependencies. |
| `acl_manager/acl_manager.sh` & `acl_manager-v4` | `acl-get`, `acl-set`, `lock`, `unlock`, `rename-user`, `restore` | Hardened user migration with automated authentication file backups (`passwd`, `group`, `shadow`, `gshadow`) before account renaming. |
| `factoryreset.sh`, `reset_permissions.sh`, `default_permissions.py` | `reset-dirs`, `reset-etc`, `reset-home`, `reset-factory` | Corrected inverted directory ownership assignments and added smart executable inspection during `/home` reset. |
| `standardperms.sh` (v1 & v2) | `standard` (`-a`, `-d`, `-f`, `--chmod=MODE`) | Replaced malformed `chmod root:root` typos with proper `chown` calls and added strict octal/symbolic mode validation. |
| `advanced/rsync.md` & `rsync2.md` | `uid-align`, `rsync-meta`, `templates` | Automated UID/GID pre-flight alignment checks and codified metadata-only synchronization (`rsync -aAXv --no-W --omit-dir-times`). |

---

## Dependencies & Installation

### Requirements Matrix

| Category | Binaries / Packages | Notes |
| :--- | :--- | :--- |
| **Core (POSIX)** | `sh`, `find`, `stat`, `chmod`, `chown`, `awk`, `sed`, `grep`, `sort`, `comm`, `tr`, `cut`, `head`, `tail`, `wc`, `date`, `mktemp` | Present by default on all Linux installations (via `coreutils` / `busybox`). |
| **ACL & Attributes** | `getfacl`, `setfacl` (`acl`), `getfattr`, `setfattr` (`attr`), `lsattr`, `chattr` (`e2fsprogs`) | Required for extended attribute locking and ACL inspection/restoration. |
| **Arch Package Manager** | `pacman` (`pacman`), `pacsift` / `paccheck` (`pacutils`), `bsdtar` (`libarchive`) | Required for `audit-pacman` and `fix-pacman` mtree repairs. |
| **Optional Enhancements** | `fzf` (interactive fuzzy picker), `rsync` (metadata sync), `go-yq` (YAML export), `zsh` (Zsh compaudit) | `permctl` functions fully without these, degrading gracefully to standard POSIX prompts. |

### Installation

Copy `permctl.sh` into your system path (e.g., `/usr/local/bin/permctl`) and ensure executable permissions:

```sh
sudo install -Dm755 permctl.sh /usr/local/bin/permctl
```

To enable shell autocompletion or run initial environment setup:

```sh
sudo permctl setup
```

---

## Command-Line Interface Reference

```
Usage: permctl [subcommand] [options] [path]
```

If invoked without a subcommand, `permctl` automatically launches the interactive TUI console.

### Subcommands

| Subcommand | Description |
| :--- | :--- |
| `menu` | Launch the interactive TUI console dashboard. |
| `status [path]` | Inspect ownership, UID/GID, octal/symbolic mode, special bits, file attributes, and ACLs. |
| `own-it [path]` | Claim target: set ownership to `USER:GROUP` and apply mode `ug+rwx`. Supports `-R` and `--pattern`. |
| `compaudit [path]` | Lock down target: set ownership to `USER:GROUP`, strip world/group write (`og-w`), and check Zsh directories. |
| `standard [path]` | Apply standard private permissions (dirs `0700`, files `0600`). Supports `-d`, `-f`, or custom `--chmod=MODE`. |
| `set-special [path]` | Set special bits on target: `--bits=suid`, `sgid`, `sticky`, or `all`. |
| `acl-get [path]` | Display POSIX Access Control Lists (supports `-R`). |
| `acl-set [path]` | Modify Access Control Lists with `--acl=SPEC` (e.g., `u:andro:rwx`). Supports `-R`. |
| `lock [path]` | Set immutable file attribute via `chattr +i`. |
| `unlock [path]` | Clear immutable file attribute via `chattr -i`. |
| `snapshot [path]` | Create permissions, ACL, and xattr snapshot bundle (`.perms`, `.acl`, `.attrs`, `.sha256`). |
| `restore [path]` | Restore permissions from snapshot (`--from=PATH`). Auto-detects all four legacy snapshot formats. |
| `audit [path]` | Run unified audit: package database (`pacman -Qkk`), security anomalies, and policy verification. |
| `audit-pacman` | Audit installed package files against the pacman database (`pacman -Qkk`). |
| `audit-security [p]` | Scan target for security anomalies: world-writable files, unstickied dirs, unowned files, and SUID/SGID. |
| `fix-pacman` | Repair package permissions: `--strategy=direct` (mtree), `cache` (bsdtar), `reinstall`, or `all-packages`. |
| `setup [user]` | Initialize configuration, create backup directories, install daily cron audit, and generate policy. |
| `policy-gen [user]` | Scan system and personal directories to generate `$POLICY_FILE` and `$YAML_POLICY_FILE`. |
| `policy-audit` | Check current filesystem state against declarative policy file. |
| `policy-fix` | Enforce and correct filesystem permissions to match declarative policy file. |
| `setup-cron` | Install daily automated cron audit job (`@daily root /usr/local/bin/permctl policy-audit`). |
| `reset-dirs` | Reset permissions and ownership on canonical top-level system directories (`/bin`, `/etc`, `/tmp`, etc.). |
| `reset-etc` | Normalize `/etc` permissions while locking down `/etc/shadow`, `/etc/sudoers.d`, and SSH keys. |
| `reset-home` | Reset `/home/*` permissions, preserving executable scripts/binaries and locking `~/.ssh` and `~/.gnupg`. |
| `reset-factory` | Full factory reset: executes `devnull-fix` + `reset-dirs` + `reset-etc` + `reset-home`. |
| `devnull-fix` | Emergency rollback v4: recreates `/dev/null` (`c 1 3`, `0666`), repairs authentication, sudoers, and binaries. |
| `user-group` | Modify group memberships: `--user=USER --group=GROUP --action=add|remove`. |
| `rename-user` | Safely migrate username, group, `/home`, and filesystem UIDs: `--remap-user=OLD:NEW`. |
| `uid-align [target]`| Audit UID/GID parity between `/etc/passwd` on `/` and a mounted target root (e.g., Live ISO environment). |
| `rsync-meta [target]`| Synchronize metadata only (`rsync -aAXv --no-W --omit-dir-times`) without modifying file contents. |
| `rollback` | Roll back single-path mutations recorded in the session journal (`permctl_rollback.tsv`). |
| `report [outfile]` | Generate a structured JSON audit report from log entries. |
| `cheatsheet` | Display permissions reference table, octal modes, special bits, and canonical system permissions. |
| `templates` | Display Live-ISO synchronization, metadata-only rsync, and disaster recovery command templates. |

### Command Options

```
  -r, -R, --recursive          Operate recursively on directories
  -n, --dry-run                Simulate operations without making changes
  -y, --yes                    Skip interactive confirmation prompts
  -s, --silent                 Suppress console output (log file only)
  -d, --dirs-only              Apply 'standard' mode to directories only (0700)
  -f, --files-only             Apply 'standard' mode to files only (0600)
  --chmod=MODE                 Custom octal or symbolic mode (e.g. 0755, ug+rwx)
  --dir-mode=MODE              Override standard directory mode (default: 0700)
  --file-mode=MODE             Override standard file mode (default: 0600)
  --pattern=GLOB               Filter files by glob pattern (e.g. '*.so*', '*.conf')
  --user=USER                  Target owner username (default: current invoking user)
  --group=GROUP                Target group name (default: root)
  --acl=SPEC                   ACL specification for acl-set (e.g. 'u:andro:rwx')
  --bits=SPEC                  Special bit specification (suid, sgid, sticky, all)
  --prefix=PATH                Output prefix for snapshot creation
  --from=PATH                  Source path/prefix/file for snapshot restoration
  --remap-user=OLD:NEW         Remap ownership & ACLs from OLD to NEW user during restore
  --strategy=NAME              Pacman repair strategy: direct (default), cache, reinstall, all-packages
  --action=add|remove          Action for user-group modification
  --root=PATH                  Alternate system root prefix for mounted recovery (default: /)
  --policy=PATH                Override default policy file path
  --include-cache              Include ~/.cache and Trash during reset-home
  --no-fzf                     Disable fzf interactive selection prompts
  --no-escalate                Do not auto-escalate via sudo (for testing or container use)
  -h, --help                   Display help information and exit
```

---

## Operational Workflows

### 1. Daily-Driver File & Directory Management

Take ownership of a project directory, lock down permissions, or apply custom chmod modes to specific file types, with full undo capability:

```sh
# Claim ownership and grant user/group read-write-execute recursively
sudo permctl own-it -R --user=andro --group=wheel ~/src/my_project

# Lock down an exported repository (remove group/world write)
sudo permctl compaudit -R ~/src/my_project

# Set standard private permissions (0700 for dirs, 0600 for files)
sudo permctl standard -R ~/.gnupg

# Apply custom chmod mode to specific files matching a pattern
sudo permctl standard -R --chmod=0755 --pattern='*.sh' ~/bin

# Undo changes from the previous operation
sudo permctl rollback
```

### 2. Snapshot Creation & Multi-Format Restoration

Capture complete filesystem permission states (including ACLs and extended attributes) and restore them on demand or across system reinstallations:

```sh
# Create a timestamped snapshot of /etc and /usr/local
sudo permctl snapshot --prefix=/var/backups/permctl/pre_upgrade_etc /etc

# Preview changes before applying a snapshot (Dry Run)
sudo permctl restore --dry-run --from=/var/backups/permctl/pre_upgrade_etc /

# Restore a snapshot, remapping old username 'andro' to new username 'alex'
sudo permctl restore --from=/var/backups/permctl/pre_upgrade_etc --remap-user=andro:alex /

# Restore directly from a legacy perm_snapper text snapshot
sudo permctl restore --from=/path/to/andro_etc-snapshot.txt /
```

### 3. Pacman Database Audit & Direct Mtree Repair

Identify and fix files whose permissions or ownerships have drifted from the official Arch package database:

```sh
# Audit package files and scan for security anomalies (world-writable / unowned files)
sudo permctl audit /etc

# Repair drifted package permissions directly using /var/lib/pacman/local mtree files
sudo permctl fix-pacman --strategy=direct

# Alternatively, extract missing metadata from cached package archives
sudo permctl fix-pacman --strategy=cache
```

### 4. Emergency System Recovery (`/dev/null` & Authentication Fix)

If a broken permission script, corrupted package installation, or rogue `chmod -R` breaks `/dev/null`, sudo, shadow files, or login binaries:

```sh
# Run Phase 0 (/dev/null verification & mknod recreation) + Phases 1–7 path recovery
sudo permctl devnull-fix

# Or run full factory reset across system directories, /etc, and /home
sudo permctl reset-factory
```

### 5. Live-ISO Factory Extraction & Target Drive Sync

When booted into an Arch Linux Live ISO to repair or replicate permissions onto an installed target drive:

```sh
# Mount the installed root partition
sudo mount /dev/nvme0n1p2 /mnt/target_root

# Step 1: Verify UID and GID alignment between Live ISO and target system
sudo permctl uid-align /mnt/target_root

# Step 2: Synchronize metadata only (--no-W) without replacing or overwriting file contents
sudo permctl rsync-meta /mnt/target_root

# Step 3: Normalize /etc and system directory permissions under the target root prefix
sudo permctl reset-dirs --root=/mnt/target_root
sudo permctl reset-etc --root=/mnt/target_root
```

### 6. Declarative Policy Management & Daily Auditing

Define an exact baseline policy for system directories and personal paths, audit for unauthorized modifications, and enforce compliance:

```sh
# Generate declarative TSV policy and YAML companion from current system and custom paths
sudo permctl policy-gen andro

# Audit filesystem against policy (returns code 0 if clean, code 1 on discrepancies)
sudo permctl policy-audit

# Enforce and correct any detected discrepancies
sudo permctl policy-fix

# Install automated daily audit cron job
sudo permctl setup-cron
```

---

## Interactive TUI Console

Running `permctl` with no arguments (or running `permctl menu`) opens an interactive terminal dashboard:

```
==============================================================
  PERMCTL v7.1.0 — Unified Arch Permissions & Sysadmin Suite
==============================================================
# --- // PATH STATUS // ----------------------------------------
  Path:        /etc/sudoers (regular file)
  Owner:Group: root:root (UID=0, GID=0)
  Permissions: 440 (-r--r-----) [Special: none]
  Attributes:  --------------e-------
  ACLs:
    user::r--
    group::r--
    other::---
# --------------------------------------------------------------
  Active Flags: Recursive=0 | Dry-Run=0 | Target=andro:root | Pattern=*

[Daily Driver Operations]
  1) Own-It (chown andro:root + chmod ug+rwx)
  2) CompAudit Lockdown (chown + chmod og-w + Zsh compaudit)
  3) Standard Private Perms (dirs=0700, files=0600)
  4) Custom Chmod / Ownership / Pattern Transform
  5) ACL Inspector & Modifier (getfacl / setfacl)
  6) Lock / Unlock File Immutable Attribute (chattr +i/-i)

[Sysadmin, Snapshot, Policy & Recovery Operations]
  7) Create Permissions Snapshot (.perms + .acl + .attrs)
  8) Restore Snapshot (Auto-detects PermMaster / perm_snapper / CSV / ACL)
  9) Audit Installed Packages (pacman -Qkk) & Security Anomalies
 10) Fix Package Permissions (direct mtree / cache / reinstall)
 11) Policy Engine: Generate / Audit / Enforce Policy
 12) Reset System Presets (System Dirs / /etc / /home / Full Factory)
 13) Emergency Rollback (/dev/null + sudoers + shadow + utempter v4)
 14) User & Group Admin (Add/Remove Group or Migrate Username)
 15) Generate JSON Audit Report
 16) Reference Cheatsheet & Rsync Templates

[Session Controls]
  d) Switch Target Path      r) Toggle Recursive      n) Toggle Dry-Run
  u) Set Target User:Group   p) Set File Glob Pattern z) Undo/Rollback Session
  0) Exit
```

---

## Configuration & Log Management

* **Configuration File:** `/etc/permctl/permctl.conf` (persists defaults for `DEFAULT_USER`, `DEFAULT_GROUP`, `BACKUP_BASE_DIR`, and `POLICY_FILE`).
* **Declarative Policies:** Stored at `/etc/permctl/permissions_policy.tsv` and exported to `/etc/permctl/permissions_policy.yaml`.
* **Activity Logs:** Written to `~/.local/share/logs/permctl.log` (or `/var/log/permctl.log`). Automatically rotates when file size exceeds 10 MiB.
* **Rollback Journal:** Recorded to `~/.local/share/logs/permctl_rollback.tsv`.
* **Custom Paths:** Add custom paths (one per line) to `/etc/custom_paths.txt` to include them in automated policy generation.

---

## Uninstallation

To remove `permctl` and its associated runtime files:

```sh
# 1. Remove binary
sudo rm -f /usr/local/bin/permctl

# 2. Remove configuration and policies
sudo rm -rf /etc/permctl

# 3. Remove cron audit job if installed
sudo crontab -l | grep -v "permctl policy-audit" | sudo crontab -

# 4. Remove logs and journals
rm -f ~/.local/share/logs/permctl*
```