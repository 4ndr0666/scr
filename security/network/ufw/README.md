# ufw.sh: Operational Firewall & VPN Hardening Utility

This script is a comprehensive state manager for system security, designed to configure and enforce a hardened operational posture on Linux systems. It orchestrates UFW (Uncomplicated Firewall), a VPN client (ExpressVPN), DNS settings, and kernel parameters (sysctl) to create a secure, repeatable, and auditable network environment.

Its core function is to establish a **system-level kill switch**, ensuring that no traffic leaks outside the VPN tunnel, while intelligently managing DNS and providing safe access to local network resources.

---

## Architectural Requirements (The Dual-Manager Symbiosis)

This script is explicitly engineered for hardened environments employing aggressive MAC address rotation. It relies on a symbiotic relationship between two network managers to maintain stability under strict firewall rules:

1. **NetworkManager (Dynamic Frontend):** Handles the physical interface initialization and runtime MAC address spoofing/randomization.
2. **systemd-networkd (Persistent Backend):** Anchors the core routing tables, establishes the primary default gateway, and natively maintains complex kernel queueing disciplines across interface flaps.

**CRITICAL:** Do not disable `systemd-networkd`. Because this script dynamically queries interface states and locks down default routes via UFW, stopping `systemd-networkd` will strip the default gateway from the spoofed interface, resulting in a total loss of external routing. Both managers must run concurrently.

---

## Features

* **System-Level Kill Switch:** When `--vpn` is active, all outbound traffic is blocked by default, with explicit rules created to only allow traffic through the VPN interface (e.g., `tun0`).
* **Advanced DNS Leak Protection:** Natively detects `systemd-resolved` loopback stubs (`127.0.0.53`). Bypasses the stub by querying `resolvectl` for the true upstream VPN DNS servers, ensuring firewall rules lock DNS queries strictly to the encrypted tunnel.
* **Dynamic LAN Subnet Calculation:** Intelligently detects your primary network interface and uses a pure-bash CIDR calculation to deduce your local subnet. Automatically creates rules allowing access to local devices (e.g., SSH, SMB) even when the kill switch is active.
* **Dynamic QoS & Congestion Control:** Probes `/lib/modules/` at runtime to detect and apply `cake` queueing discipline and `bbr` congestion control, overriding generic kernel defaults to prevent bufferbloat.
* **Safe Teardown (`--disconnect`):** A dedicated function to safely disconnect the VPN, restore original DNS settings (including symlink restoration for `systemd-resolved`), and reset the firewall to a standard "allow-all-outbound" state.
* **Advanced Kernel Hardening:** Applies a robust set of sysctl parameters to harden the network stack against IP spoofing and routing manipulation. The configuration file is named `99-zz-ufw-hardening.conf` to ensure it loads last.
* **Full UFW State Management:** Resets UFW to a clean slate on every run, then builds the rule set from scratch for a predictable state.
* **Comprehensive Logging & Auditing:** All actions, commands, and errors are logged to `$XDG_DATA_HOME/logs/ufw.log` (typically `~/.local/share/logs/ufw.log`).
* **Operational Safety:** Includes flags for `--dry-run` to preview changes and `--status` to audit the current configuration without making changes.
* **Optional JDownloader2 Rules:** Integrates specific incoming rules for JDownloader2, protected by the kill switch.

---

## Dependencies

Before running, ensure the following command-line utilities are installed:

* **Required:** `ufw`, `ip`, `sysctl`, `ss`, `awk`
* **Optional:** `expressvpn` (if using `--vpn`), `resolvectl` (highly recommended for systemd environments), `lsattr`, `chattr` (for immutable file flags).

*(Note: `ipcalc` is no longer required as subnet bounds are calculated via native bash).*

---

## Installation

Install the script to a location in your **PATH** and make it executable:

```bash
curl -fsSL [https://your.repo/path/to/ufw.sh](https://your.repo/path/to/ufw.sh) -o /usr/local/bin/ufw.sh
chmod +x /usr/local/bin/ufw.sh

```

> Note: Replace the URL with the raw file URL from your repository.

---

## Usage

#### Primary Workflow: Setup -> Status -> Teardown

1. **Activate VPN & Kill Switch:**
Connect to the VPN and apply the full hardening configuration. Use `--backup` on the first run.
```bash
sudo ufw.sh --vpn --backup

```


2. **Verify the Configuration:**
Check the status of UFW, the VPN connection, listening sockets, and DNS settings.
```bash
sudo ufw.sh --status

```


3. **Safely Disconnect and Restore:**
When finished, disconnect the VPN and reset the firewall to its default state.
```bash
sudo ufw.sh --disconnect

```



### Other Commands

* **Apply JDownloader2 rules within the VPN kill switch:**
```bash
sudo ufw.sh --vpn --jdownloader

```


* **Preview all changes without applying them (Dry Run):**
```bash
sudo ufw.sh --vpn --dry-run

```


* **Set `vm.swappiness` to a custom value (e.g., 10):**
```bash
sudo ufw.sh --swappiness 10

```



---

## Options

| Option | Description |
| --- | --- |
| `--vpn` | Activates the master kill switch, connects ExpressVPN, and applies VPN-only rules. |
| `--disconnect` | Safely disconnects the VPN, restores DNS, and resets UFW to default policies. |
| `--jdownloader` | Adds incoming rules for JDownloader2 (intended to be used with `--vpn`). |
| `--backup` | Creates timestamped backups of configuration files before modification. |
| `--silent` | Suppresses all console output. Actions are still logged to the log file. |
| `--dry-run` | Simulates all actions without making any actual changes to the system. |
| `--status` | Displays the current status of UFW, VPN, DNS, active sockets, and sysctl settings, then exits. |
| `--swappiness N` | Sets the `vm.swappiness` kernel parameter to the integer value `N`. |
| `--help, -h` | Shows the help message. |

---

## How It Works (The `--vpn` Process)

1. **Backup:** If `--backup` is used, original versions of `/etc/default/ufw`, `/etc/resolv.conf`, and the script's sysctl file are saved. Symlinks are detected and preserved.
2. **VPN Connection:** The script initiates the ExpressVPN connection with a hard timeout to prevent hanging.
3. **DNS Parsing:** The script queries `resolvectl` (or reads `/etc/resolv.conf` as a fallback) to learn the true IP addresses of the VPN's upstream DNS servers, bypassing local stubs.
4. **Firewall Reset:** UFW is completely reset (`ufw --force reset`).
5. **Default Policies:** UFW's default policies are set to **DENY** for incoming, **DENY** for routed, and **DENY** for outgoing traffic. This forms the absolute kill switch.
6. **Rule Layering:** A minimal set of explicit `allow` rules are layered on top:
* Allow all outbound traffic *only* on the detected VPN interfaces (e.g., `tun0`).
* Allow outbound DNS traffic (`port 53`) *only* to the parsed VPN DNS servers.
* Calculate the local subnet from the primary interface and allow LAN inbound/outbound traffic.
* Allow limited incoming SSH traffic.


7. **Kernel Tuning:** Sysctl parameters are flushed to `/etc/sysctl.d/99-zz-ufw-hardening.conf`, immutable flags are set, and queueing disciplines (`cake`/`bbr`) are injected.
8. **Final State:** The firewall is enabled, executing a strict lockdown of all non-local and non-VPN traffic.

---

## Troubleshooting

* **No Internet after `--vpn`:** This is the kill switch working correctly. If the VPN fails to connect or interface detection fails, all traffic is blocked as intended. Run `sudo ufw.sh --disconnect` to restore connectivity.
* **Network drops completely on interface flap:** Ensure `systemd-networkd` is running. This script relies on `systemd-networkd` to populate the default routing tables when NetworkManager rotates the MAC address.
* **DNS Issues / No Resolution:** Check the log file for errors related to parsing or backing up `/etc/resolv.conf`. The script handles `systemd-resolved` symlinks natively, but manual tampering can break restoration. Run `sudo ufw.sh --disconnect` to restore the original state.
* **IPv6:** This script **enables** IPv6 support within UFW (`IPV6=yes`). This is a critical security feature to ensure that the kill switch properly captures and drops potential IPv6 leaks.

---

## Security Review Checklist

* [ ] Disable root SSH login (`PermitRootLogin no` in `/etc/ssh/sshd_config`).
* [ ] Use key-based SSH auth (`PasswordAuthentication no`).
* [ ] After running, verify listening sockets and active rules with `sudo ufw.sh --status`.
* [ ] Confirm DNSSEC and DNSOverTLS status with `resolvectl status`.
* [ ] Run an external DNS leak test (e.g., dnsleaktest.com) to verify protection.
* [ ] Audit the script's actions and execution timings in the log file: `cat ~/.local/share/logs/ufw.log`.

---

## Uninstall

To completely remove the script and its configurations:

```bash
# 1. Reset the firewall to its defaults
sudo ufw --force reset

# 2. Remove the script binary
sudo rm -f /usr/local/bin/ufw.sh

# 3. Remove the custom sysctl hardening file
sudo chattr -i /etc/sysctl.d/99-zz-ufw-hardening.conf
sudo rm -f /etc/sysctl.d/99-zz-ufw-hardening.conf

# 4. Reload sysctl to unload the custom settings
sudo sysctl --system

# 5. Remove the log file
rm -f ~/.local/share/logs/ufw.log

```
