# README.md

---

# UFW Hardening Script (`ufw.sh`)

This script manages system firewall (UFW), VPN (ExpressVPN), DNS, sysctl network hardening, and JDownloader2 kill-switching for Linux servers and desktops. It is engineered for repeatable, auditable, and secure operations—ensuring that *all network traffic, DNS, and privileged system settings* are locked down according to security best practices, especially for VPN and SSH-centric workflows.

---

## Features

* **Full UFW reset and clean rule set with automatic comments (if supported)**
* **ExpressVPN auto-connect/disconnect** with integrated DNS leak prevention
* **JDownloader2 kill-switch**: traffic allowed only via VPN
* **Sysctl kernel parameter hardening** (IPv4/IPv6, TCP/UDP, swappiness, etc.)
* **Automatic backup and restore** of config files (with option to enable/disable)
* **Command-line flags** for dry-run, silent mode, status display, and granular control
* **Comprehensive logging** (to `$XDG_DATA_HOME` or `~/.local/share/logs/ufw.log`)
* **Root escalation** and dependency checking
* **Swappiness control** (e.g., `--swappiness 10`)
* **Compatibility:** detects UFW `comment` support; no-ops where unsupported

---

## Installation

One-line installer (run as root):

```bash
curl -fsSL https://your.repo/path/ufw.sh -o /usr/local/bin/ufw.sh && chmod +x /usr/local/bin/ufw.sh
```

> **Note:** Replace the URL with your actual repo raw URL.

---

## Usage

### Typical Commands

* **Connect VPN, lock down firewall, enforce DNS security:**

  ```bash
  sudo ufw.sh --vpn
  ```

* **Apply kill-switch rules for JDownloader2 traffic over VPN:**

  ```bash
  sudo ufw.sh --vpn --jdownloader
  ```

* **Preview all changes (dry-run, no actual changes):**

  ```bash
  sudo ufw.sh --vpn --dry-run
  ```

* **Show only firewall, sysctl, VPN, and DNS status:**

  ```bash
  sudo ufw.sh --status
  ```

* **Set vm.swappiness to a custom value (default 60):**

  ```bash
  sudo ufw.sh --vpn --swappiness 10
  ```

* **Silent mode (no console output, only logs):**

  ```bash
  sudo ufw.sh --vpn --silent
  ```

---

## Options

| Option           | Description                                    |
| ---------------- | ---------------------------------------------- |
| `--vpn`          | Connect ExpressVPN and apply VPN+DNS+UFW rules |
| `--jdownloader`  | Configure JDownloader2-specific firewall rules |
| `--backup`       | Create backups before modifying config files   |
| `--silent`       | Suppress console output (logs only)            |
| `--dry-run`      | Simulate actions without making changes        |
| `--status`       | Display current firewall/VPN/sysctl/DNS status |
| `--swappiness N` | Set vm.swappiness to N (default: 60)           |
| `--help, -h`     | Show help message                              |

---

## How it Works

* **Root Required:** Script will escalate to root if not started as root.
* **Backups:** Optionally backs up `/etc/ufw/backups`, `/etc/sysctl.d/99-ufw-custom.conf`, and `/etc/resolv.conf` before any change.
* **ExpressVPN:** Connects/disconnects as needed; rewrites DNS rules to prevent leaks.
* **JDownloader2:** Only allows relevant ports on the VPN interface, blocks all others.
* **Logging:** All actions, warnings, and errors are logged to `$LOG_FILE`.
* **UFW Comments:** Uses `comment` keyword if your UFW supports it (auto-detected).

---

## Example Workflow

1. **Lock system to VPN traffic only:**
   `sudo ufw.sh --vpn --backup`

2. **Add JDownloader2 kill-switch:**
   `sudo ufw.sh --vpn --jdownloader`

3. **Temporarily audit changes without modifying the system:**
   `sudo ufw.sh --vpn --dry-run`

4. **Display status:**
   `sudo ufw.sh --status`

---

## Troubleshooting

* If **ExpressVPN** is missing, VPN logic is skipped with a warning.
* If **UFW** or other dependencies are missing, the script exits with error.
* **Dry-run** does not actually apply any system changes—use to preview logic.
* For **SSH connections**, script warns about possible lockout if your SSH is not on the default port.
* **IPv6** is fully disabled in both sysctl and UFW by default.

---

## Security Review Checklist

* [ ] Disable root SSH login (`PermitRootLogin no`)
* [ ] Restrict SSH by source IP (`ufw allow from <trusted-ip> to any port 22`)
* [ ] Use key-based SSH auth and set `PasswordAuthentication no`
* [ ] Consider disabling SSH entirely if not needed
* [ ] Disable LLMNR and mDNS in `/etc/systemd/resolved.conf`
* [ ] Confirm DNSSEC and DNSOverTLS via `resolvectl status`
* [ ] Ensure `/etc/resolv.conf` is not leaking (check for ExpressVPN or dnsmasq)
* [ ] Run a DNS leak test after setup (dnsleaktest.com)
* [ ] For JDownloader2: verify all traffic is over VPN by monitoring `tun0`
* [ ] Audit logs: `cat ~/.local/share/logs/ufw.log`

---

## Uninstall

```bash
sudo ufw reset
sudo rm -f /usr/local/bin/ufw.sh
sudo rm -rf ~/.local/share/logs/ufw.log
```
