# Backup Script Feature Matrix

| Feature | backupconfigs.sh | setup_config_backups.sh | system_iso.sh |
|---------|-----------------|-------------------------|---------------|
| Root escalation | yes | no (uses sudo selectively) | no (uses sudo selectively) |
| Progress bar | yes | no | no |
| Configuration file | no | yes (JSON) | partial (config file for iso paths) |
| Help option | no | yes | no |
| Dry-run mode | no | no | no |
| Dependency installation | no | jq via pacman | archiso, git, rsync, cdrtools |
| Cron scheduling | no | yes | no |
| ISO creation | no | no | yes |
| Logging | yes | yes | no |
| Interactive prompts | yes | yes | yes |
| Color output | minimal | yes | minimal |

## Gaps
- None of the existing scripts provide a dry-run mode.
- Only `setup_config_backups.sh` loads a configuration file, leaving the others with hard-coded paths.
- Dependency management is inconsistent across scripts.
- ISO creation is only available in `system_iso.sh`.

## Overlaps
- Both `backupconfigs.sh` and `setup_config_backups.sh` handle logging.
- All scripts rely on user interaction for input.

The new `bkp-unified.sh` script consolidates configuration-driven backups, root
escalation, logging under `$XDG_DATA_HOME`, optional ISO creation, and a
progress bar with an opt-in dry-run mode.
