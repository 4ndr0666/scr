# ssh_audit.sh — Deterministic SSH audit + alignment for Kali/Linux hosts

**Purpose:**  
Pin host keys, install `authorized_keys` from GitHub and optional sources, harden `sshd`, verify a clean key-only handshake, and emit a per-host report. Designed for repeatable use in homelab and production.

- **Client:** `andro@theworkpc` (`192.168.1.226`)
- **Typical Host:** `kali@4ndr0kali` (e.g., `192.168.1.92`)
- **Default alias:** `kali` in `~/.ssh/config`

---

## What it does

1. Ensures client prerequisites and sane SSH client settings.
2. Pins the server’s **ED25519** host key into `~/.ssh/known_hosts` (hashed).
3. Installs `authorized_keys` on the host from:
   - `https://github.com/<github_user>.keys` (required)
   - plus `--key-url` and/or `--key-file` if provided (de-duped).
4. Hardens `sshd_config`:
   - `PasswordAuthentication no`
   - `KbdInteractiveAuthentication no`
   - `PubkeyAuthentication yes`
   - `PermitRootLogin no`
   - `X11Forwarding` and `AllowTcpForwarding` set by flags (default **no**)
   - Prefer only the host’s ED25519 HostKey when present
   - Optional `AllowUsers <user>`
5. Writes a **Host block** for alias `kali` in `~/.ssh/config`.
6. Verifies the handshake:
   - Server host key algorithm is **ssh-ed25519**
   - Auth method is **publickey**
7. Outputs a per-host Markdown report to `~/.ssh_align/reports/`.

---

## Requirements

- Client tools: `ssh`, `ssh-keygen`, `ssh-keyscan`, `curl`, `nc` (auto-installed via distro pkg manager).
- Ability to reach host TCP/22.
- Initial access with either:
  - existing key auth, or
  - temporary password auth enabled on the host (only needed once to push keys).

---

## Usage

```bash
ssh_audit.sh [--hosts "ip1 ip2"] [--user USER] [--github USER]
             [--key-url URL] [--key-file PATH]
             [--mode enforce|report|strict]
             [--allow-forwarding yes|no] [--allow-x11 yes|no] [--no-allowusers]
             [--version] [-h|--help]
````

**Defaults:**
`--user kali` · `--github 4ndr0666` · `--hosts "192.168.1.92"` · `--mode enforce`
Reports: `~/.ssh_align/reports` · Logs: `~/.ssh_align/logs`

**Modes**

* `enforce` (default): install keys, harden `sshd`, verify, report.
* `report`: no changes, just verify and report.
* `strict`: enforce + fail if any post-checks mismatch.

---

## Common invocations

Initial alignment on a single host:

```bash
./ssh_audit.sh --hosts "192.168.1.92" --user kali --github 4ndr0666 --mode enforce
```

Dry report only:

```bash
./ssh_audit.sh --hosts "192.168.1.92" --user kali --github 4ndr0666 --mode report
```

Multiple hosts:

```bash
./ssh_audit.sh --hosts "192.168.1.92 192.168.1.93" --user kali --github 4ndr0666
```

Disallow forwarding and X11 explicitly (defaults already “no”):

```bash
./ssh_audit.sh --hosts "192.168.1.92" --allow-forwarding no --allow-x11 no
```

Add extra public keys from a URL or file, merged with your GitHub keys:

```bash
./ssh_audit.sh --hosts "192.168.1.92" \
  --key-url https://example.com/pubkeys.txt \
  --key-file /path/to/extra_authorized_keys
```

---

## Post-run verification

Quick handshake check:

```bash
ssh -vvv -o ControlMaster=no -o ControlPath=none kali \
  | grep -E 'Server host key:|Authenticated to .* using "publickey"'
```

Expected lines:

* `Server host key: ssh-ed25519 SHA256:<fingerprint>`
* `Authenticated to ... using "publickey"`

---

## Outputs

* **Client config:** `~/.ssh/config` updated with alias `kali`.
* **Known hosts:** `~/.ssh/known_hosts` hashed entry for the host.
* **Reports:** `~/.ssh_align/reports/<ip>.md`
* **Logs:** `~/.ssh_align/logs/<ip>_YYYYMMDDThhmmss.log`

---

## Security notes

* GitHub key import uses `https://github.com/<user>.keys`. Keep your GitHub keys current.
* Script enforces non-interactive sudo on the host for `sshd_config` edits.
* `AllowUsers <user>` can be enforced by default. Disable with `--no-allowusers` if you manage access via other means (e.g., groups).

---

## Troubleshooting

* **Port 22 closed:** open on firewall or adjust port and client Host block manually.
* **Host key changed:** the script re-pins ED25519. Verify out-of-band if unexpected.
* **Password login still works:** ensure `PasswordAuthentication no` in `sshd_config`. Re-run with `--mode strict`.

---

## Help

```bash
./ssh_audit.sh --help
./ssh_audit.sh --version
```
