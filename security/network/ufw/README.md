# ufw.sh: Operational Firewall & VPN Hardening Utility

This script is a comprehensive state manager for system security, designed to configure and enforce a hardened operational posture on Linux systems. It orchestrates UFW (Uncomplicated Firewall), a VPN client (ExpressVPN), DNS settings, and kernel parameters (sysctl) to create a secure, repeatable, and auditable network environment.

Its core function is to establish a **system-level kill switch**, ensuring that no traffic leaks outside the VPN tunnel, while intelligently managing DNS and providing safe access to local network resources.

---

## Features

System-Level Kill Switch:* When --vpn is active, all outbound traffic is blocked by default, with explicit rules created to only allow traffic through the VPN interface (tun0).

DNS Leak Protection: Automatically backs up your original DNS settings, allows the VPN client to set its own, and then creates firewall rules that permit DNS queries only* to the VPN's DNS servers.

Safe Teardown (`--disconnect`):* A dedicated function to safely disconnect the VPN, restore original DNS settings, and reset the firewall to a standard "allow-all-outbound" state.

Advanced Kernel Hardening:* Applies a robust set of sysctl parameters to harden the network stack against common attacks. The configuration file is named 99-zz-ufw-hardening.conf to ensure it loads last and overrides all other system defaults.

Automatic LAN Access:* Intelligently detects your primary network interface and local subnet, creating rules to allow access to local devices (e.g., SSH, SMB, router admin pages) even when the kill switch is active.

Full UFW State Management:* Resets UFW to a clean slate on every run, then builds the rule set from scratch for a predictable state.

Comprehensive Logging & Auditing:* All actions, commands, and errors are logged to $XDG_DATA_HOME/logs/ufw.log (typically ~/.local/share/logs/ufw.log).

Pre-flight Checks:* Verifies all required dependencies (ufw, ipcalc, etc.) are present before execution.

Operational Safety:* Includes flags for --dry-run to preview changes and --status to audit the current configuration without making changes.

Optional JDownloader2 Rules:* Integrates specific incoming rules for JDownloader2, which are protected by the kill switch.

---

## Dependencies

Before running, ensure the following command-line utilities are installed:

Required:* ufw, ip, sysctl, ipcalc (often in the ipcalc or init-system-helpers package), expressvpn (if using --vpn).

Optional:* lsattr, chattr for immutable file flags (highly recommended).

---

## Installation

Install the script to a location in your **PATH** and make it executable:

```bash
curl -fsSL https://your.repo/path/to/ufw.sh -o /usr/local/bin/ufw.sh && chmod +x /usr/local/bin/ufw.sh
```

> Note: Replace the URL with the raw file URL from your repository.

---

## Usage

#### Primary Workflow: Setup -> Status -> Teardown

1. **Activate VPN & Kill Switch:**

Connect to the VPN and apply the full hardening configuration. Use --backup on the first run.


sudo ufw.sh --vpn --backup
    ```

2.  **Verify the Configuration:**
    Check the status of UFW, the VPN connection, and DNS settings.
    ```bash
    sudo ufw.sh --status
    ```

3.  **Safely Disconnect and Restore:**
    When finished, disconnect the VPN and reset the firewall to its default state.
    ```bash
    sudo ufw.sh --disconnect
    ```

### Other Commands

*   **Apply JDownloader2 rules within the VPN kill switch:**
    ```bash
    sudo ufw.sh --vpn --jdownloader
    ```

*   **Preview all changes without applying them (Dry Run):**
    ```bash
    sudo ufw.sh --vpn --dry-run
    ```

*   **Set `vm.swappiness` to a custom value (e.g., 10):**
    ```bash
    sudo ufw.sh --swappiness 10
    ```

---

## Options

| Option | Description |
|---|---|
| `--vpn` | Activates the master kill switch, connects ExpressVPN, and applies VPN-only rules. |
| `--disconnect` | Safely disconnects the VPN, restores DNS, and resets UFW to default policies. |
| `--jdownloader` | Adds incoming rules for JDownloader2 (intended to be used with `--vpn`). |
| `--backup` | Creates timestamped backups of configuration files before modification. |
| `--silent` | Suppresses all console output. Actions are still logged to the log file. |
| `--dry-run` | Simulates all actions without making any actual changes to the system. |
| `--status` | Displays the current status of UFW, VPN, DNS, and sysctl settings, then exits. |
| `--swappiness N` | Sets the `vm.swappiness` kernel parameter to the integer value `N`. |
| `--help, -h` | Shows this help message. |

---

## How It Works (The `--vpn` Process)

1.  **Backup:** If `--backup` is used, original versions of `/etc/default/ufw`, `/etc/resolv.conf`, and the script's `sysctl` file are saved.
2.  **VPN Connection:** The script initiates the ExpressVPN connection. The VPN client then modifies `/etc/resolv.conf` to point to its own DNS servers.
3.  **DNS Parsing:** The script reads the now-modified `/etc/resolv.conf` to learn the IP addresses of the VPN's DNS servers.
4.  **Firewall Reset:** UFW is completely reset (`ufw --force reset`).
5.  **Default Policies:** UFW's default policies are set to **DENY** for incoming, **DENY** for routed, and **DENY** for outgoing traffic. This is the foundation of the kill switch.
6.  **Rule Layering:** A minimal set of `allow` rules are layered on top of the deny-all policy:
    *   Allow all outbound traffic *only* on the VPN interface (e.g., `tun0`).
    *   Allow outbound DNS traffic (`port 53`) *only* to the VPN's DNS servers.
    *   Allow inbound/outbound traffic on the primary interface (e.g., `enp2s0`) *only* for the local network subnet.
    *   Allow limited incoming SSH traffic.
7.  **Final State:** The firewall is enabled, locking all non-local and non-VPN traffic.

---

## Troubleshooting

*   **No Internet after `--vpn`:** This is the kill switch working correctly. If the VPN fails to connect, all traffic is blocked as intended. Run `sudo ufw.sh --disconnect` to restore connectivity.
*   **Cannot access local devices:** Ensure the `ipcalc` dependency is installed. The script needs it to correctly identify your local subnet.
*   **DNS Issues:** Check the log file for errors related to parsing or backing up `/etc/resolv.conf`. Run `sudo ufw.sh --disconnect` to restore the original file.
*   **IPv6:** This script **enables** IPv6 support within UFW (`IPV6=yes`). This is a critical security feature to ensure that the kill switch properly blocks potential IPv6 leaks if your ISP and VPN provider support it.

---

## Security Review Checklist

*   [ ] Disable root SSH login (`PermitRootLogin no` in `sshd_config`).
*   [ ] Use key-based SSH auth (`PasswordAuthentication no`).
*   [ ] After running, verify LAN rules are correct with `sudo ufw.sh --status`.
*   [ ] Confirm DNSSEC and DNSOverTLS status with `resolvectl status`.
*   [ ] Manually inspect `/etc/resolv.conf` to ensure it points to the VPN's DNS servers.
*   [ ] Run an external DNS leak test (e.g., dnsleaktest.com) to verify protection.
*   [ ] Audit the script's actions in the log file: `cat ~/.local/share/logs/ufw.log`.

---

## Uninstall

To completely remove the script and its configurations:
bash

1. Reset the firewall to its defaults
sudo ufw --force reset

2. Remove the script binary
sudo rm -f /usr/local/bin/ufw.sh

3. Remove the custom sysctl hardening file
sudo rm -f /etc/sysctl.d/99-zz-ufw-hardening.conf

4. Reload sysctl to unload the custom settings
sudo sysctl --system

5. Remove the log file
rm -f ~/.local/share/logs/ufw.lo

