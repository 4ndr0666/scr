## Automating Snapshot Management

1. Create a script to automate regular snapshots.

```bash
#!/bin/bash
sudo timeshift --create --comments "Automated Snapshot" --tags D
```


2. Use `cron` or `systemd` to schedule the script:

$ crontab -e

# --- // Create a snapshot every day at 2 AM:
$ 0 2 * * * /path/to/snapshot_script.sh


3. Create a script to mount and compare snapshots:

```bash
#!/bin/bash
sudo mount -o subvol=@ /run/timeshift/backup/timeshift-btrfs/snapshots/$1/ /mnt/snapshot1
sudo mount -o subvol=@ /run/timeshift/backup/timeshift-btrfs/snapshots/$2/ /mnt/snapshot2
meld /mnt/snapshot1 /mnt/snapshot2
```

Run the script with the names of the snapshots you want to compare:

$ ./compare_snapshots.sh "Factory Snapshot" "Post-Change Snapshot"

