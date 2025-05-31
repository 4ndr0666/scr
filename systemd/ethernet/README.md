## 🚀 Complete Automated Ethernet Device Renaming Installation Script

This comprehensive script:

- Creates and installs `rename_eth.sh` to `/usr/local/bin/` which renames eth iface device from enp3s0 to enp2s0.
- Sets up a `udev` rule forcing this name to be persistent in `/etc/udev/rules.d/`
- Creates and enables the systemd service to automate the script at boot
- Ensures idempotent operations with clear messaging at every step.

## 📌 What this script precisely accomplishes:

- **Complete Automation:** No manual intervention required after execution.
- **Idempotency:** Safe to rerun at any time, with clear output and no redundant actions.
- **Immediate & Persistent:** Covers both instant renaming (via script & systemd) and persistent renaming across reboots (via udev rules).

