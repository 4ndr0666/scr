# ufw.sh: Operational Firewall, WireGuard Kill Switch & Kernel Hardening Utility

`ufw.sh` is a state manager for host network security on Arch Linux and systemd-based distributions. It orchestrates **UFW (Uncomplicated Firewall)**, **MegaVPN (WireGuard via NetworkManager `nmcli`)**, **DNS leak protection (`resolvconf` / `openresolv` with `systemd-resolved` fallback)**, and **kernel network hardening (`sysctl`)**—including built-in exposure mitigation and runtime auditing for **CVE-2026-98432** (Linux IPv4 TCP handshake RCU use-after-free / Multipath TCP remote root exploit chain).

Its primary job is to enforce a **fail-closed, system-level VPN kill switch** while preserving local subnet reachability, preventing DNS and IPv6 leaks, and hardening the kernel TCP/IP stack without clobbering sibling `/etc/sysctl.d/` configurations.

## Architectural Requirements (The Dual-Manager Symbiosis)

This script is engineered for hardened environments employing aggressive MAC address rotation and relies on a symbiotic relationship between two network managers:

1. **NetworkManager (Dynamic Frontend):** Handles physical interface initialization, runtime MAC address spoofing/randomization, and WireGuard (`nmcli`) connection lifecycle management.
2. **systemd-networkd (Persistent Backend):** Anchors core routing tables, establishes the primary default gateway, and natively maintains kernel queueing disciplines (`cake`) across interface flaps.

> **CRITICAL:** Do not disable `systemd-networkd`. Because this script dynamically queries interface states and locks down default routes via UFW, stopping `systemd-networkd` strips the default gateway from the spoofed interface and causes a loss of external routing. Both managers must run concurrently.

## Key Capabilities

* **Fail-Closed WireGuard Kill Switch (`--vpn`):** Sets UFW default policies to `deny incoming`, `deny routed`, and `deny outgoing`. Even if the WireGuard handshake times out or fails to come up, the script proceeds fail-closed so no traffic leaks in plaintext.
* **WireGuard Transport Endpoint Pinning:** Dynamically inspects `wg show <iface> endpoints` and permits outbound UDP on the physical interface to the active WireGuard server endpoint `<IP>:<PORT>`, ensuring periodic key renegotiations and keepalives survive `conntrack` state flushes or idle timeouts.
* **Resolvconf-First DNS Leak Protection:** Detects `resolvconf` (`openresolv`) symlinks and headers, querying `resolvconf -l <vpn_iface>*` for per-interface VPN DNS servers rather than trusting merged `/etc/resolv.conf` ordering. Retains automatic `resolvectl` (`systemd-resolved`) and literal `/etc/resolv.conf` fallbacks, then locks outbound port 53 (TCP/UDP) exclusively to the VPN tunnel.
* **CVE-2026-98432 (MPTCP / IPv4 TCP RCU UAF) Mitigation & Auditing:**
  * Disables Multipath TCP socket creation (`net.mptcp.enabled=0`) and subflow joining (`net.mptcp.allow_join_initial_addr_port=0`) both at runtime and persistently in `/etc/sysctl.d/99-zz-ufw-hardening.conf`.
  * Enforces `net.ipv4.tcp_syncookies=1`, `net.ipv4.tcp_max_syn_backlog=8192`, and `net.ipv4.tcp_rfc1337=1` to harden the IPv4 TCP SYN handshake path.
  * Audits `ss -M -tulnp` on every run to flag pre-existing MPTCP listeners (such as services built with Go 1.24+) that were opened prior to toggling `net.mptcp.enabled=0` and require a service restart.
  * Scans the current boot's kernel journal (`journalctl -k -b`) for crash or KASAN/oops signatures in `ip_options_build`, `tcp_v4_syn_recv_sock`, and `tcp_v4_reqsk_destructor`.
* **Physical-First LAN Subnet Calculation:** Filters out `wireguard`, `lo`, and virtual tunnel interfaces when detecting the primary physical NIC (`PRIMARY_IF`), then uses a pure-bash bitwise CIDR calculator (`cidr_to_network`) to allow LAN inbound/outbound traffic without requiring `ipcalc`.
* **Scoped Sysctl Ownership (`99-zz-ufw-hardening.conf`):** Owns only network kill-switch, MPTCP, rp_filter (`.all`, `.default`, and `.*`), and TCP buffer/congestion (`cake` + `bbr`) keys. Deliberately avoids overwriting keys owned by dedicated sibling files (`kernel.dmesg_restrict` in `99-4ndr0-hardening.conf`, `net.ipv4.icmp_echo_ignore_all` in `99-4ndr0-stealth.conf`, `net.ipv4.conf.all.log_martians` in `99-sysctl.conf`, and `vm.swappiness` in `99-vm-zram-parameters.conf` unless `--swappiness N` is explicitly passed).
* **Symlink-Aware Teardown (`--disconnect`):** Disconnects all active NetworkManager WireGuard profiles, restores `/etc/resolv.conf` (preserving its exact symlink target if managed by `resolvconf` or `systemd-resolved`), and resets UFW to standard default policies (`deny incoming`, `allow outgoing`, `deny routed`, `limit 22/tcp`).

## Dependencies

| Category | Packages / Binaries | Purpose |
| :--- | :--- | :--- |
| **Required** | `ufw`, `ip` (`iproute2`), `ss`, `sysctl` (`procps-ng`), `awk`, `grep`, `sed`, `systemctl`, `timeout`, `coreutils` | Core firewall, routing, socket inspection, and sysctl orchestration |
| **VPN & DNS** | `nmcli` (`networkmanager`), `wg` (`wireguard-tools`), `resolvconf` (`openresolv`) or `resolvectl` (`systemd`) | MegaVPN WireGuard profile management, endpoint inspection, and per-interface DNS extraction |
| **Optional** | `fzf`, `lsattr` & `chattr` (`e2fsprogs`) | Interactive WireGuard profile selection (`fzf`) and immutable flag management (`+i` on `99-zz-ufw-hardening.conf`) |

## Installation

Copy `ufw.sh` into `/usr/local/bin/ufw.sh` and set executable permissions:

```bash
sudo install -Dm755 ufw.sh /usr/local/bin/ufw.sh
```

## Usage

### Primary Workflow: Setup -> Audit -> Teardown

1. **Activate MegaVPN, Kill Switch & Kernel Hardening:**
   Connect a specific NetworkManager WireGuard profile (or auto-select if only one WireGuard profile exists, or pick interactively via `fzf`) and apply full UFW + sysctl hardening:
   ```bash
   sudo ufw.sh --vpn --profile megavpn-us --backup
   ```

2. **Verify Active Firewall, WireGuard, DNS & MPTCP Posture:**
   Inspect UFW rules, active WireGuard interfaces, DNS records, and CVE-2026-98432 MPTCP socket state without modifying the system:
   ```bash
   sudo ufw.sh --status
   ```

3. **Safely Disconnect and Restore Defaults:**
   Bring down active WireGuard tunnels, restore `/etc/resolv.conf` (including symlink targets), and reset UFW to default outbound-allowed state:
   ```bash
   sudo ufw.sh --disconnect
   ```

### Additional Commands

* **Apply baseline hardening and MPTCP mitigation without connecting a VPN:**
  ```bash
  sudo ufw.sh --backup
  ```
* **Enable JDownloader2 incoming ports (9666/tcp, 3129/tcp) inside the VPN kill switch:**
  ```bash
  sudo ufw.sh --vpn --jdownloader
  ```
* **Preview all commands without modifying system state (Dry Run):**
  ```bash
  sudo ufw.sh --vpn --dry-run
  ```
* **Explicitly override `vm.swappiness` (opt-in; otherwise left to `99-vm-zram-parameters.conf`):**
  ```bash
  sudo ufw.sh --vpn --swappiness 10
  ```

## Command-Line Options

| Option | Description |
| :--- | :--- |
| `--vpn` | Connects MegaVPN (WireGuard via `nmcli`), sets UFW default outbound to `deny`, and locks traffic and DNS to the VPN tunnel. |
| `--profile NAME` | Specifies the NetworkManager WireGuard connection `NAME` to activate with `--vpn`. Auto-selects if only one exists or prompts via `fzf` on interactive TTYs. |
| `--disconnect` | Disconnects active WireGuard connections, restores `/etc/resolv.conf`, and resets UFW to default policies (`deny incoming`, `allow outgoing`). |
| `--jdownloader` | Opens TCP ports `9666` (Remote Control) and `3129` (Flashgot) for JDownloader2. |
| `--backup` | Creates timestamped backups of `/etc/sysctl.d/99-zz-ufw-hardening.conf` and `/etc/default/ufw` in `/etc/ufw/backups/`. |
| `--silent` | Suppresses console output while continuing to write structured logs to `~/.local/share/logs/ufw.log`. |
| `--dry-run` | Logs and simulates all actions without modifying firewall rules, sysctl files, or network connections. |
| `--status` | Outputs UFW rules, WireGuard status, `99-zz-ufw-hardening.conf`, `net.mptcp.*` sysctls, `ss -M -tulnp`, and DNS configuration, then exits. |
| `--swappiness N` | Explicitly writes `vm.swappiness=N` (`0`–`200`) into `99-zz-ufw-hardening.conf`. If omitted, `vm.swappiness` is untouched. |
| `--help, -h` | Displays usage information and exits. |

## Execution Lifecycle (`--vpn`)

1. **Initialization & Privilege Verification:** Initializes `~/.local/share/logs/ufw.log` (preserving ownership for `SUDO_USER`), parses CLI flags, and verifies root privileges (`EUID == 0`).
2. **Interface Discovery:** Identifies the physical default-route interface (`PRIMARY_IF`) while filtering out existing `wireguard`, `lo`, and virtual tunnel devices so re-runs never confuse an active tunnel with the physical LAN NIC.
3. **Symlink-Aware DNS Backup:** Records `/etc/resolv.conf` (or its `SYMLINK:<target>` metadata) to `/etc/resolv.conf.ufw-orig`. An `EXIT` trap automatically restores `/etc/resolv.conf` if the script aborts abnormally mid-setup, while keeping the backup intact across successful runs for `--disconnect`.
4. **MegaVPN WireGuard Connection:** Brings down any conflicting active WireGuard profiles, activates the target profile via `timeout 45 nmcli connection up`, and polls `nmcli` for up to 10 seconds to confirm active state.
5. **Per-Interface DNS Resolution:** Queries `resolvconf -l <vpn_iface>*` (or `resolvectl dns <vpn_iface>` on `systemd-resolved` hosts) to extract the true VPN upstream DNS servers.
6. **Sysctl Hardening & CVE-2026-98432 Mitigation:** Writes `/etc/sysctl.d/99-zz-ufw-hardening.conf`, applies `chattr +i`, disables `net.mptcp.enabled` and `net.mptcp.allow_join_initial_addr_port`, enables `tcp_syncookies`, and loads `cake` + `bbr` when kernel modules are present.
7. **UFW Lockdown:** Enables `IPV6=yes` in `/etc/default/ufw`, resets UFW, sets `deny incoming`, `deny routed`, and `deny outgoing` (when `--vpn` is set), permits SSH (`limit`) and local CIDR traffic on `PRIMARY_IF`, allows UDP to the WireGuard peer endpoint on `PRIMARY_IF`, allows outbound traffic on `VPN_IFACES`, restricts port 53 to `VPN_DNS_SERVERS`, and enables UFW.
8. **Post-Flight Verification:** Audits `net.mptcp.enabled`, checks `ss -M -tulnp` for lingering MPTCP sockets, checks kernel logs for `ip_options_build` traces, and prints active listening sockets (`ss -tunlp`) and verbose UFW rules.

## CVE-2026-98432 Remediation Reference (Arch Linux)

**CVE-2026-98432** is a race condition leading to a use-after-free in the Linux kernel's IPv4 TCP connection setup path (`tcp_v4_syn_recv_sock()` transferring `ireq->ireq_opt` without copying, racing with concurrent SYN retransmission handling in `ip_options_build()`). While the underlying lifetime bug is in IPv4 TCP option handling (fixed upstream via `kfree_rcu()` in `inet_sock_destruct()` and `tcp_v4_reqsk_destructor()`), the demonstrated unauthenticated remote root exploit targets servers with a **Multipath TCP (MPTCP)** listener.

* **Kernel Patch Verification (Durable Fix):** Ensure your running Arch Linux kernel is updated and rebooted into an upstream release containing the `kfree_rcu()` fix (`>= 7.2.10` / `7.3` for `linux`, `>= 6.12.113` or `>= 6.18.56` or `>= 6.6.159` for `linux-lts`):
  ```bash
  sudo pacman -Syu
  uname -r
  ```
* **Immediate Exposure Reduction (Enforced by `ufw.sh`):**
  * `net.mptcp.enabled=0` blocks creation of new MPTCP sockets.
  * `net.mptcp.allow_join_initial_addr_port=0` restricts MPTCP subflow joins.
  * UFW default `deny incoming` blocks unsolicited external TCP SYN handshakes to local listeners (with SSH rate-limited via `limit`).
  * Any long-running service that opened an MPTCP listener *before* `net.mptcp.enabled=0` was applied (such as daemons compiled with Go 1.24+) must be restarted (or launched with `GODEBUG=multipathtcp=0`) after running `ufw.sh`; `ufw.sh` automatically flags any such lingering sockets via `ss -M -tulnp`.

## Troubleshooting

* **No Internet after `--vpn`:** This is the fail-closed kill switch operating as designed when the VPN tunnel fails to establish or drops. Run `sudo ufw.sh --disconnect` to restore normal routing and DNS.
* **Network drops completely on interface MAC flap:** Verify `systemd-networkd` is active (`systemctl status systemd-networkd`).
* **Lingering MPTCP socket warning in `audit_mptcp_exposure`:** Setting `net.mptcp.enabled=0` stops new MPTCP sockets from being created, but existing listeners remain open until the owning process restarts. Identify the PID in the `ss -M -tulnp` output and run `sudo systemctl restart <service>`.

## Uninstall

```bash
# 1. Disconnect VPN, restore /etc/resolv.conf, and reset UFW to default policies
sudo ufw.sh --disconnect

# 2. Remove the script binary
sudo rm -f /usr/local/bin/ufw.sh

# 3. Remove the immutable attribute and delete the custom sysctl hardening file
sudo chattr -i /etc/sysctl.d/99-zz-ufw-hardening.conf 2>/dev/null || true
sudo rm -f /etc/sysctl.d/99-zz-ufw-hardening.conf

# 4. Reload sysctl settings from remaining system files
sudo sysctl --system

# 5. Remove the log file
rm -f ~/.local/share/logs/ufw.log
```
