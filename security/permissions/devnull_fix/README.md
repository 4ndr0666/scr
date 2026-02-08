# Permissions Rollback Script

## The `/dev/null` issue explained:

/dev/null is a special character device (c 1,3) that discards all writes — it's used everywhere for redirecting output (>/dev/null).
When pacman-fix-permissions hits /dev, it can:

- chmod /dev/null to 0644 → makes it non-writable for non-root
- or turn it into a regular file (if /dev is tmpfs and fix script overwrites nodes)

Result: any non-root process (your shell, cron jobs, sudo internals, daemons) fails on > /dev/null with "Permission denied" or "Not a character device".
This cascades: login shells error on profile sourcing, sudo can't redirect logs, cron jobs fail silently.

Since it's a kernel device node, mknod recreates it properly — udev usually persists it across boots.

### Backups / contingencies for /dev/null

Your tmpfs /tmp is fine — /dev is devtmpfs by default on Arch/Garuda, so no need for fstab tweaks.

To make /dev/null "immutable" against future fix scripts:

```bash
# After v4 run
sudo chattr +i /dev/null  # immutable flag (requires e2fsprogs)
```

Remove with -i if needed.

For full contingency — add this to weekly cron or your Vacuum.py:

```python
def check_dev_null():
    if not os.path.exists('/dev/null') or not os.stat('/dev/null').st_mode & 0o666:
        log_and_print(f"{FAILURE} /dev/null broken — recreating", "error")
        subprocess.run(["sudo", "rm", "-f", "/dev/null"])
        subprocess.run(["sudo", "mknod", "-m", "0666", "/dev/null", "c", "1", "3"])
        log_and_print(f"{SUCCESS} /dev/null recreated", "info")
```
