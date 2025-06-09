# bkup.sh — Minimal, Safe, Flexible Archive Backup Script

A robust Bash script for making timestamped, compressed archive backups of any directory or file, with automatic log-keeping, old-backup pruning, and safe first-run configuration.  
Ideal for personal systems, home servers, or cron-based unattended jobs.

---

## Features

- **Simple CLI**: Archive any path(s) with one command.
- **Secure Config**: Auto-generates config on first run (`~/.config/bkup.conf`), or use environment variables for overrides.
- **Atomic Backups**: Each path is tarred/compressed to its own timestamped archive.
- **Supported Compression**: `zstd` (default), `gzip`, `bzip2`, `xz`, or uncompressed.
- **Pruning**: Old archives are automatically deleted based on a retention period (default: 2 days, configurable).
- **Idempotent Locking**: Single-run via lock file; safe for cron and unattended use.
- **Logging**: Detailed, timestamped logs for all operations.
- **Dry-Run Mode**: Preview all actions without changing files.
- **Portable**: Requires only `bash`, `tar`, `find`, `flock`, and standard coreutils.

---

## Installation

```sh
sudo install -m755 bkup.sh /usr/local/bin/bkup.sh
````

---

## Usage

```sh
bkup.sh [OPTIONS] PATH [PATH ...]
```

* Archives each PATH to the backup directory as `<name>-<UTCstamp>.<compression>`.
* Prunes (deletes) old archives according to the retention period.

### Options

* `-h`, `--help`       Show help message and current settings.
* `-n`, `--dry-run`    Print all actions, but do not write or delete files.
* `--`                 Treat all following arguments as paths, even if they start with `-`.

---

## Configuration

By default, `bkup.sh` creates and uses `~/.config/bkup.conf`.
You may override any setting by editing that file **or** by setting an environment variable.

### Configurable Variables

| Variable      | Description                              | Default                |
| ------------- | ---------------------------------------- | ---------------------- |
| BACKUP\_DIR   | Where to store archive files             | `/Nas/Backups/backups` |
| LOG\_FILE     | Log file path                            | `$BACKUP_DIR/bkup.log` |
| LOCK\_FILE    | Lock file for safe concurrency           | `/var/lock/bkup.lock`  |
| KEEP\_DAYS    | Days to keep archives before pruning     | `2`                    |
| TAR\_COMPRESS | Compression: zstd, gzip, bzip2, xz, none | `zstd`                 |
| TAR\_OPTS     | Extra options for `tar`                  | *(none)*               |

Example config (`~/.config/bkup.conf`):

```bash
# bkup.conf — generated 2025-06-08 UTC

BACKUP_DIR="$HOME/Backups"
LOG_FILE="$BACKUP_DIR/bkup.log"
LOCK_FILE="/tmp/bkup.lock"
KEEP_DAYS=7
TAR_COMPRESS="zstd"
TAR_OPTS="--verbose"
```

---

## Examples

### **Archive the Brave browser config (manual run)**

```sh
bkup.sh ~/.config/BraveSoftware
```

### **Dry-run to see what would happen:**

```sh
bkup.sh -n ~/.config/BraveSoftware
```

---

## Setting Up as a Cron Job (Brave Browser Example)

To automatically back up your Brave browser config **every day at 3:15am**:

1. **Open your user’s crontab:**

   ```sh
   crontab -e
   ```

2. **Add this line:**

   ```
   15 3 * * * /usr/local/bin/bkup.sh $HOME/.config/BraveSoftware
   ```

   This will:

   * Archive `~/.config/BraveSoftware` daily.
   * Log all actions in your backup directory’s log.
   * Prune old Brave backups after the retention period.

*You can back up multiple directories by listing more paths:*

```sh
bkup.sh $HOME/.config/BraveSoftware $HOME/Documents $HOME/Pictures
```

---

## Logging and Errors

* All operations (successes, warnings, errors) are logged in `$LOG_FILE`.
* On error, the script returns a non-zero exit code and logs the problem.
* Use `-n` (dry-run) to preview actions before running unattended jobs.

---

## First-Run Notes

* On first run, the script creates `~/.config/bkup.conf` with default settings.
* **Edit this file** to customize backup location, retention, compression, etc.

---

## Security

* Config file is created with owner-only permissions (chmod 600).
* If you run as root (for system-wide backups), ensure only trusted users can edit your config file and backup directory.

---

## Requirements

* bash (v4+ recommended)
* tar (GNU tar preferred for zstd support)
* find, flock, coreutils
* Optionally: zstd, xz, gzip, or bzip2 (as needed for compression)

---

## Troubleshooting

* **Permission denied?**
  Make sure you (or your cronjob) have write access to the backup/log/lock locations.
* **Compression errors?**
  Check that the requested compression program is installed and available in `PATH`.

---

## License

MIT (c) 4ndr0666
Feel free to modify and share.

