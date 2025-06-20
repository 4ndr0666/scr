# CODEX.md — System Hardening and UFW/VPN Integration

## Work Order & Security Checklist

---

### 1. **Further Enhancements for UFW/VPN Script**

**Status:** Open
**Owner:** All contributors
**Purpose:** Polish and extend the main script for robustness, transparency, and ease of use.

#### 1.1 Add a `--status` flag

* **Goal:** Allow operators to *only* display the current status of UFW, sysctl, ExpressVPN, and DNS routing.
* **Acceptance:**

  * `./ufw.sh --status` shows:

    * UFW status + rules (with comments if supported)
    * ExpressVPN status (`connected`/`disconnected`)
    * sysctl kernel params applied by the script
    * DNS servers in use for each interface (via `resolvectl` if present)
  * No config changes are made.
* **Notes:** Dry-run and silent flags should be honored.

#### 1.2 Usage Examples in Help Text

* **Goal:** Help users quickly see common/advanced usages.
* **Acceptance:**

  * Add typical and edge-case CLI invocations to the `usage` output, e.g.:

    ```
    ./ufw.sh --vpn
    ./ufw.sh --backup --dry-run
    ./ufw.sh --jdownloader
    ./ufw.sh --status
    ```
* **Notes:** Keep all output copy-pasteable.

#### 1.3 One-liner Installer

* **Goal:** Make onboarding trivial for ops/new devs.
* **Acceptance:**

  * Provide a curl/bash one-liner to download and install the script to `/usr/local/bin`.
  * Example:

    ```bash
    curl -fsSL https://your.repo/script/ufw.sh -o /usr/local/bin/ufw.sh && chmod +x /usr/local/bin/ufw.sh
    ```
* **Notes:** Update README.md with this.

#### 1.4 UFW Comment Compatibility Check

* **Goal:** Support both old and new UFW versions (with/without `comment`).
* **Acceptance:**

  * At runtime, detect if `ufw` supports the `comment` keyword.
  * If not, strip `comment` from rules before applying.
* **Notes:** Should be transparent to the user and logged.

#### 1.5 Refactor/Remove Unused TMP\_DIRS/TMP\_FILES

* **Goal:** Remove vestigial temp file tracking if not needed.
* **Acceptance:**

  * If not used anywhere, delete related logic/variables.

#### 1.6 Swappiness Parameterization

* **Goal:** Make `vm.swappiness` tunable from CLI/env.
* **Acceptance:**

  * E.g., `./ufw.sh --swappiness 10`
  * Fallback to default if not set.

---

### 2. **System Hardening and SSH Security Tasks**

#### 2.1 Disable Root Login via SSH

* **Task:** Set `PermitRootLogin no` in `/etc/ssh/sshd_config`
* **Acceptance:**

  * `grep -q '^PermitRootLogin no' /etc/ssh/sshd_config`
* **Verification:**

  * Attempt root SSH login fails.

#### 2.2 Restrict SSH to Specific IP Ranges

* **Task:**

  * Add `ufw allow from <trusted-ip> to any port 22`
  * Remove `ufw allow 22` if present.
* **Acceptance:**

  * SSH is only accessible from whitelisted sources.

#### 2.3 Use Key-Based SSH Authentication

* **Task:**

  * Generate keypair if not present.
  * Copy to server.
  * Set `PasswordAuthentication no`.
* **Verification:**

  * Only SSH keys permitted; password login is denied.

#### 2.4 Disable SSH Completely (if not required)

* **Task:**

  * `systemctl disable --now sshd`
  * Confirm port 22 is closed: `ss -tunlp | grep 22` is empty.

---

### 3. **Service Minimization and DNS Security**

#### 3.1 Disable Unneeded Network Services

* **Task:**

  * Set `LLMNR=no` and `MulticastDNS=no` in `/etc/systemd/resolved.conf`
  * Restart service.
  * Confirm via `ss -tunlp | grep 5355` (should be empty).
* **Acceptance:**

  * No mDNS/LLMNR listeners.

#### 3.2 Ensure DNSSEC, DNS over TLS, and Correct DNS Routing

* **Task:**

  * Confirm `resolvectl status` shows DNSSEC=yes and DNSOverTLS=yes.
  * Ensure VPN interface (e.g., `tun0`) is using VPN DNS.
  * If not, set via `resolvectl dns tun0 <vpn_dns>` and recheck.

#### 3.3 Local DNS Caching with dnsmasq (optional)

* **Task:**

  * Install/configure `dnsmasq` if local caching is wanted.
  * Point `/etc/resolv.conf` to `127.0.0.1`.
  * Ensure no DNS leaks occur after VPN connect/disconnect.

---

### 4. **JDownloader2 Killswitch and Hardening**

* **Task:**

  * Ensure JD2 only binds to/tunnels via VPN interface (deny on all others).
  * Apply both allow/deny rules for relevant ports (see prior feedback).
* **Verification:**

  * Traffic for JD2 ports halts if VPN is disconnected.
  * Use `iftop`, `tcpdump`, or JDownloader logs to confirm.

---

### 5. **Verification and Validation Steps**

* **Task:**

  * Test DNS leak scenarios (dnsleaktest.com, etc.).
  * Test UFW persistence across reboot.
  * Attempt various failure scenarios (VPN drop, SSH misconfig, etc.).
  * Document all observed behavior in CHANGELOG.md.

---

### 6. **General Practices**

* All changes must be **logged and documented** (see LOG\_FILE, CHANGELOG.md).
* Before every release/merge, run an **audit cycle** against this checklist and update project status.

---

## References

* See README.md for detailed usage, examples, and onboarding.
* For current config, refer to `ufw.sh`, `CHANGELOG.md`, and `/etc/sysctl.d/99-ufw-custom.conf`.

---

**End of Work Order — CODEX.md**
