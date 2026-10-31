# permctl v8.0.0: Vectorized Arch Linux Permissions, Zstd Snapshot & Mtree Policy Engine

`permctl` is a strictly POSIX-compliant (`#!/bin/sh`, validated under `/usr/bin/dash` and `bash --posix`), Suckless, vectorized permissions, ACL, snapshot, policy, and disaster-recovery engine for Arch Linux.

Rather than gluing legacy scripts together with slow per-file shell loops, `permctl` v8.0.0 replaces $O(N)$ subprocess fork-storms with **vectorized `find ... -exec stat {} +` streams, in-memory `awk` hash-joins, `xargs -0` batch-grouped mutators, single-process `awk FNR==1 ... nextfile` magic-byte inspection, and multi-threaded Zstandard (`zstd -T0`) index compression**.

## Architectural & Algorithmic Design

* **Zero Per-File Shell Loops ($O(1)$ Process Spawns per Batch):**
  * Legacy shell scripts that iterate over `find` output with `while read -r f; do stat "$f"; chmod ... "$f"; done` spawn 2–4 external processes *per file* (600,000+ forks across 200,000 files, taking 10–15 minutes).
  * `permctl` v8.0.0 uses `apply_vectorized_stream()`: it batches `stat` calls via `xargs -0 -r stat -c '%a|%U:%G|%n'` (~4,000 paths per `execve` invocation), performs an **in-memory `awk` hash-join** against the target policy or snapshot, filters out the 99%+ of paths that already match on disk, and groups the remaining delta by target `(mode)` and `(owner:group)` so `chmod` and `chown` execute once per distinct mode/owner batch rather than once per file.
* **4-Tier Authoritative Init Record (`permctl.idx.zst` & `permissions_policy.tsv`):**
  * **Tier 1 (Pacman Mtree Stream):** Streams `/var/lib/pacman/local/*/mtree` through a single `/set`-aware `awk` state machine to extract the package maintainer's exact factory `mode`, `uid`, and `gid`—ignoring broken live disk modes.
  * **Tier 2 (Canonical Arch Security Overrides):** Enforces hardened defaults on `/etc/shadow` (`0600`), `/etc/gshadow` (`0600`), `/etc/sudoers` (`0440`), `/etc/sudoers.d` (`0750`/`0440`), `/etc/polkit-1/rules.d` (`0750` `root:polkitd`), `/root` (`0700`), `/tmp` (`1777`), `/dev/shm` (`1777`), `utempter` (`2711`), and `sudo`/`su` (`4755`).
  * **Tier 3 (Vectorized Home Synthesis with Magic-Byte Detection):** Focuses on security-critical trees (`~/.ssh`, `~/.gnupg`, `~/.config`, `~/bin`, `~/.local/bin`, `~/.zsh`, dotfiles) while pruning multi-gigabyte browser/build/media caches (`Cache`, `Code Cache`, `GPUCache`, `node_modules`, `.rustup`, `gallery-dl`). Inspects executable candidates in a **single `awk` process** (`FNR==1 { if ($0 ~ /^#!/ || substr($0,1,4) == "\177ELF") print FILENAME; nextfile }`) without spawning `head` or `file` per path.
  * **Tier 4 (Custom Paths & Multi-Threaded `zstd -T0` Compression):** Normalizes paths in `/etc/custom_paths.txt` and compresses the deduplicated index with `zstd -T0 -3` (`permctl.idx.zst`). Benchmarks over **39,960 real snapshot records** complete in **< 1 second**.
* **Live Visual Telemetry:**
  * **Determinate Progress Bars (`ui_progress`):** Real-time `[██████████░░░░░]  66% (2/3)` progress bars with step counters on `stderr`.
  * **Indeterminate Background Spinners (`run_with_spinner`):** Non-blocking TTY spinner during `pacman -Qkk` package verification.
  * **Completion Scorecards (`ui_scorecard`):** Box-drawn summary tables reporting total records, batch `chmod`/`chown` counts, artifact paths, and elapsed wall-clock seconds.
* **Persistent Rollback Journal (`permctl_rollback.tsv`):** Records pre-mutation metadata so changes can be undone both interactively (`z`) and from the CLI (`sudo permctl rollback`).

## Consolidation Matrix (All 23 Legacy Scripts Superseded)

| Legacy Script / Directory | `permctl` v8.0.0 Subcommands | Algorithmic & Engineering Upgrade |
| :--- | :--- | :--- |
| `permissionsctl` (v1–v5) & `README.md` | `setup`, `policy-gen`, `policy-audit`, `policy-fix` (`fix`), `setup-cron` | Replaced live-`stat` loop (which recorded broken permissions as policy and took 10+ minutes) with a 1-second streaming `/var/lib/pacman/local/*/mtree` + vectorized `awk` hash-join engine and `zstd -T0` index (`permctl.idx.zst`). |
| `PermMaster/permmaster` & `perm_snapper/*` | `snapshot` (`backup`), `restore`, `report` | Added `getfacl --skip-base` (skipping files without extended ACLs), `zstd -T0` snapshot compression (`.perms.zst`), right-anchored `awk` parsing for legacy `andro_*-snapshot.txt` files (39,960 lines parsed in `< 1s`), and delta-only batch restoration. |
| `perms/perms.sh`, `perms2.sh`, `perms3.sh`, `groupacc.sh`, `standardperms.sh`, `interactive_perm_changer.sh` | `menu`, `status`, `own-it`, `compaudit`, `standard` (`-a`, `-d`, `-f`, `--chmod`, `--pattern`), `rollback`, `cheatsheet` | Removed `eval` and `source`, added persistent rollback journaling, Zsh `compaudit` verification, and interactive `fzf` path/pattern switching. |
| `devnull_fix/permissions_rollback.sh` (v4) | `devnull-fix` (`emergency-rollback`) | Guarded `/dev/null` (`c 1 3`, `0666`) verification/recreation + Phases 1–7 (`utempter` `2711`, `sudo`/`su` `4755`, `shadow` `0600`, `sudoers.d` `0750`/`0440`, `polkit-1/rules.d` `0750`) with `--root` and `--dry-run` support. |
| `factoryreset.sh`, `reset_permissions.sh`, `default_permissions.py`, `set_advanced_permissions.sh` | `reset-dirs`, `reset-etc`, `reset-home`, `reset-factory` (`--reset`), `set-special` | Vectorized `reset-home` using `awk FNR==1 ... nextfile` magic-byte inspection so genuine `#!` scripts and `\177ELF` binaries keep `0755` while accidentally `0777`'d data files reset to `0644`. |
| `acl_manager.sh`, `acl_manager-v4`, `rsync.md`, `rsync2.md` | `acl-get`, `acl-set`, `lock`, `unlock`, `user-group`, `rename-user`, `uid-align`, `rsync-meta`, `templates` | Added UID/GID parity auditing (`uid-align`), metadata-only `rsync -aAXv --no-W --omit-dir-times`, and automated auth-file backups before `rename-user`. |

## Installation

```sh
sudo install -Dm755 permctl.sh /usr/local/bin/permctl
```

## Quick-Start Workflows

### 1. Repair a Drifted System & Generate the Authoritative Init Index
If your system currently has broken permissions, run this sequence to repair core nodes, restore package files from `pacman` mtree metadata, generate the authoritative policy, and enforce it in seconds:

```sh
# 1. Verify /dev/null (c 1 3, 0666) and lock down core auth/sudo/polkit paths
sudo permctl devnull-fix

# 2. Repair drifted package files directly from /var/lib/pacman/local/*/mtree
sudo permctl fix-pacman --strategy=direct

# 3. Generate the authoritative Init Index (/etc/permctl/permctl.idx.zst & permissions_policy.tsv)
sudo permctl setup andro

# 4. Run vectorized policy audit and batch-fix any remaining discrepancies
sudo permctl policy-audit
sudo permctl policy-fix
```

### 2. Daily-Driver Operations & Instant Rollback

```sh
# Inspect ownership, octal/symbolic mode, special bits, chattr flags, and ACLs
permctl status /etc/sudoers

# Claim ownership and grant ug+rwx recursively
sudo permctl own-it -R --user=andro --group=wheel ./project

# Lock down directory (chown + strip group/world write + check Zsh compaudit)
sudo permctl compaudit -R --user=andro --group=andro ~/.zsh

# Apply private permissions (dirs 0700, files 0600) or custom pattern chmod
sudo permctl standard -a ./secrets
sudo permctl --chmod=0755 --pattern='*.sh' ~/bin

# Undo the last CLI operation from the persistent rollback journal
sudo permctl rollback
```

### 3. Vectorized Zstd Snapshots & Multi-Format Delta Restore

```sh
# Capture a Zstandard-compressed snapshot (.perms.zst, .acl, .attrs, .sha256)
sudo permctl snapshot --prefix=/var/backups/permctl/etc_snap /etc

# Preview or apply a vectorized delta restore (only touches files that differ!)
sudo permctl restore --dry-run --from=/var/backups/permctl/etc_snap /
sudo permctl restore --from=/var/backups/permctl/etc_snap /

# Restore directly from a legacy perm_snapper file (e.g. andro_etc-snapshot.txt)
sudo permctl restore --from=/path/to/andro_etc-snapshot.txt /
```

## CLI Subcommands & Options Reference

| Subcommand | Description |
| :--- | :--- |
| `menu` | Launch the interactive TUI dashboard (default when run with no arguments). |
| `status [path]` | Inspect ownership, UID/GID, octal/symbolic mode, special bits, `lsattr`, and ACLs. |
| `own-it [path]` | Set ownership to `USER:GROUP` and mode `ug+rwx` (supports `-R`, `--pattern`). |
| `compaudit [path]` | Set ownership to `USER:GROUP`, strip `og-w`, and run Zsh `compaudit` check. |
| `standard [path]` | Apply private modes (dirs `0700`, files `0600`; or `-d`, `-f`, `--chmod=MODE`). |
| `set-special [path]` | Apply special bits (`--bits=suid\|sgid\|sticky\|all`). |
| `acl-get` / `acl-set` | View or modify POSIX ACLs (`--acl=SPEC`, supports `-R`). |
| `lock` / `unlock` | Set (`chattr +i`) or clear (`chattr -i`) the immutable file attribute. |
| `snapshot [path]` | Create vectorized snapshot bundle (`.perms`, `.perms.zst`, `.acl`, `.attrs`, `.sha256`). |
| `restore [path]` | Vectorized delta restore (`--from=PATH`, `--remap-user=OLD:NEW`). |
| `audit [path]` | Unified audit: `audit-pacman` + `audit-security` + `policy-audit`. |
| `audit-pacman` | Verify installed package files via `pacman -Qkk`. |
| `audit-security [p]` | Single-pass scan for world-writable files/dirs, unowned files, and SUID/SGID binaries. |
| `fix-pacman` | Repair package files (`--strategy=direct\|cache\|reinstall\|all-packages`). |
| `setup [user]` | Save config, configure daily cron job, and build authoritative policy index. |
| `policy-gen [user]` | Build authoritative policy (`--policy-source=authoritative\|snapshot\|live`). |
| `policy-audit` | Vectorized hash-join audit against `$POLICY_FILE`. |
| `policy-fix` | Vectorized batch enforcement of `$POLICY_FILE` (alias: `fix`). |
| `reset-dirs` | Reset canonical top-level system directories (`/bin`, `/etc`, `/tmp`, `/var`, etc.). |
| `reset-etc` | Normalize `/etc` and lock down `shadow`, `gshadow`, `sudoers.d`, `polkit`, and SSH keys. |
| `reset-home` | Vectorized `/home/*` reset preserving verified `#!` & `ELF` executables. |
| `reset-factory` | Full factory reset (`devnull-fix` + `reset-dirs` + `reset-etc` + `reset-home`). |
| `devnull-fix` | Emergency rollback v4: recreate `/dev/null` (`c 1 3`, `0666`) and repair critical paths. |
| `user-group` | Add/remove user from group (`--user=U --group=G --action=add\|remove`). |
| `rename-user` | Safely migrate username, group, `/home`, and filesystem UIDs (`--remap-user=OLD:NEW`). |
| `uid-align [target]` | Audit `/etc/passwd` & `/etc/group` UID/GID parity between `/` and mounted target root. |
| `rsync-meta [target]`| Synchronize metadata only (`rsync -aAXv --no-W --omit-dir-times`) without touching file data. |
| `rollback` | Undo changes recorded in `~/.local/share/logs/permctl_rollback.tsv`. |
| `report [outfile]` | Export structured JSON audit report from log file. |
| `cheatsheet` | Display `CHMOD_INDEX` and canonical Arch Linux permissions table. |
| `templates` | Display Live-ISO, `rsync --no-W`, and emergency recovery command templates. |