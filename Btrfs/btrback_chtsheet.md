# btrbk Conflict Resolution Cheat-Sheet

This cheat-sheet is tailored to resolving the specific conflict you are facing with your Btrfs filesystem, specifically with the UUID and FSID issues on `/dev/sdd3` and `/dev/sdd4`. It includes practical examples and organized markdown styling for easy reference.

## General Usage

```bash
btrbk [<options>] <command> [[--] <filter>...]
```

### Options

- `-h, --help`: Display help message.
- `--version`: Display version information.
- `-c, --config=FILE`: Specify configuration file.
- `-n, --dry-run`: Perform a trial run with no changes made.
- `--exclude=FILTER`: Exclude configured sections.
- `-p, --preserve`: Preserve all (do not delete anything).
- `--preserve-snapshots`: Preserve snapshots (do not delete snapshots).
- `--preserve-backups`: Preserve backups (do not delete backups).
- `--wipe`: Delete all but latest snapshots.
- `-v, --verbose`: Increase logging level.
- `-q, --quiet`: Do not print backup summary.
- `-l, --loglevel=LEVEL`: Set logging level (`error`, `warn`, `info`, `debug`, `trace`).
- `-t, --table`: Change output to table format.
- `-L, --long`: Change output to long format.
- `--format=FORMAT`: Change output format (`table`, `long`, `raw`).
- `-S, --print-schedule`: Print scheduler details (for the `run` command).
- `--progress`: Show progress bar on send-receive operation.
- `--lockfile=FILE`: Create and check lockfile.
- `--override=KEY=VALUE`: Globally override a configuration option.

### Commands

- `run`: Run snapshot and backup operations.
- `dryrun`: Don't run Btrfs commands; show what would be executed.
- `snapshot`: Run snapshot operations only.
- `resume`: Run backup operations, and delete snapshots.
- `prune`: Only delete snapshots and backups.
- `archive <src> <dst>`: Recursively copy all subvolumes.
- `clean`: Delete incomplete (garbled) backups.
- `stats`: Print snapshot/backup statistics.
- `list <subcommand>`: Available subcommands are:
  - `all`: Snapshots and backups.
  - `snapshots`: Snapshots only.
  - `backups`: Backups and correlated snapshots.
  - `latest`: Most recent snapshots and backups.
  - `config`: Configured source/snapshot/target relations.
  - `source`: Configured source/snapshot relations.
  - `volume`: Configured volume sections.
  - `target`: Configured targets.
- `usage`: Print filesystem usage.
- `ls <path>`: List all Btrfs subvolumes below path.
- `origin <subvol>`: Print origin information for subvolume.
- `diff <from> <to>`: List file changes between related subvolumes.
- `extents [diff] <path>`: Calculate accurate disk space usage.

## Practical Examples for Conflict Resolution

### 1. Ensure `/dev/sdd3` is Hidden and Unmounted

```bash
sudo umount /dev/sdd3
mount | grep /dev/sdd3
sudo btrfstune -S 1 /dev/sdd3
```

### 2. Update Fstab

```bash
sudo cp /etc/fstab /etc/fstab.bak
sudo sed -i '/\/dev\/sdd3/d' /etc/fstab
```

### 3. Attempt to Repair or Recover `/dev/sdd4`

1. **Unmount `/dev/sdd4`**:

   ```bash
   sudo umount /dev/sdd4
   ```

2. **Run Btrfs Check with Repair**:

   ```bash
   sudo btrfs check --repair /dev/sdd4
   ```

3. **Use Btrfs Rescue Commands**:

   ```bash
   sudo btrfs rescue super-recover /dev/sdd4
   sudo btrfs rescue chunk-recover /dev/sdd4
   ```

4. **Zero Log**:

   ```bash
   sudo btrfs rescue zero-log /dev/sdd4
   ```

5. **Mount with Recovery Options**:

   ```bash
   sudo mkdir -p /mnt/recovery
   sudo mount -o usebackuproot,ro /dev/sdd4 /mnt/recovery
   ```

6. **Attempt Data Restoration**:

   ```bash
   sudo mkdir -p /path/to/recovery
   sudo btrfs restore -v /dev/sdd4 /path/to/recovery
   ```

### 4. If Recovery Fails, Recreate and Restore `/dev/sdd4`

1. **Recreate the Filesystem on `/dev/sdd4`**:

   ```bash
   sudo mkfs.btrfs /dev/sdd4
   ```

2. **Restore the Image to `/dev/sdd4`**:
   - Use Clonezilla to restore the image to the newly created Btrfs filesystem.

### btrbk Usage for Regular Backups

1. **Create Snapshots and Backups**:

   ```bash
   btrbk run
   ```

2. **Perform a Trial Run**:

   ```bash
   btrbk --dry-run run
   ```

3. **Create Snapshots Only**:

   ```bash
   btrbk snapshot
   ```

4. **Run Backup Operations and Delete Snapshots**:

   ```bash
   btrbk resume
   ```

5. **Deleting Snapshots and Backups**:

   ```bash
   btrbk prune
   ```

6. **Copy Subvolumes Recursively**:

   ```bash
   btrbk archive /mnt/source /mnt/backup
   ```

7. **Clean Incomplete Backups**:

   ```bash
   btrbk clean
   ```

8. **Print Snapshot/Backup Statistics**:

   ```bash
   btrbk stats
   ```

9. **List All Snapshots and Backups**:

   ```bash
   btrbk list all
   ```

10. **Print Filesystem Usage**:

    ```bash
    btrbk usage
    ```

11. **List Btrfs Subvolumes**:

    ```bash
    btrbk ls /mnt
    ```

12. **Print Origin Information for a Subvolume**:

    ```bash
    btrbk origin /mnt/subvol
    ```

13. **List File Changes Between Related Subvolumes**:

    ```bash
    btrbk diff /mnt/subvol1 /mnt/subvol2
    ```

14. **Calculate Accurate Disk Space Usage**:

    ```bash
    btrbk extents /mnt
    ```

## Configuration Example for Conflict Resolution

### Basic Configuration

```ini
# Global settings
snapshot_dir  = .snapshots
snapshot_preserve_min = 1d
snapshot_preserve     = 1w

# Source filesystem
volume /mnt/source
subvolume home

# Target filesystem
target /mnt/backup
subvolume home

# Backup settings
backup_dir = .backup
backup_preserve_min = 1d
backup_preserve     = 1m
```

## Additional Tips

- **Verbose Output**: Increase verbosity for debugging:

  ```bash
  btrbk -v run
  ```

- **Lockfile Usage**: Prevent concurrent runs:

  ```bash
  btrbk --lockfile=/var/lock/btrbk.lock run
  ```

- **Override Configuration**: Temporarily override settings:

  ```bash
  btrbk --override=snapshot_preserve_min=1h run
  ```

This cheat-sheet provides a concise and organized reference for using `btrbk` to manage Btrfs snapshots and backups, specifically tailored to resolve the UUID and FSID conflict on `/dev/sdd3` and `/dev/sdd4`. For detailed documentation, refer to the official `btrbk` documentation.
