## Brave-Browser

### Backups

**Cronjobs**:

    - **Tarball**: The following line will create a tarball of the dir titled "Brave-Browser-Beta" located in the users config           dir to the backup dir at /Nas/Backups/brave-beta:
```bash
0 */12 * * * /bin/bash -c 'mkdir -p /Nas/Backups/brave-beta && tar -czf /Nas/Backups/brave-beta/brave-beta-$(date+\%Y\%m\%d\%H\%M).tar.gz -C ~/.config/BraveSoftware Brave-Browser-Beta && cd /Nas/Backups/brave-beta && ls -tp | grep -v '/$' | tail -n +3 | xargs -I {} rm -- {}'
```
