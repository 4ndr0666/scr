# mem-police

A high-performance, proactive daemon for per-process memory enforcement on Linux. 

Unlike global reactive OOM killers (like EarlyOOM or systemd-oomd) that wait for total system memory exhaustion, `mem-police` acts as a precise sniper. It enforces strict, per-process Resident Set Size (RSS) quotas, surgically terminating notoriously leaky user-space apps before they ever threaten the system state.

---

## 🛠️ Features

- **Proactive Memory Polling:** O(1) integer memory tracking via `/proc/[pid]/statm` (Zero string parsing overhead).
- **Regex Process Whitelisting:** Exclude vital system daemons or specific apps using PCRE2 regular expressions.
- **PID Reuse Immunity:** Tracks `/proc/[pid]/stat` initialization times to guarantee it never kills a reassigned, innocent process.
- **Configurable Thresholds:** Kill any process using more than *N* MB for *T* seconds.
- **Grace Period:** Wait *K* seconds after an initial `SIGTERM` before issuing a hard `SIGKILL`.
- **Systemd & Syslog Native:** Fully integrated with the Linux journal for clean, centralized logging.
- **Live Reload:** Send `SIGHUP` to reload the config without dropping the daemon, and `SIGUSR1` to dump the current tracking state to the journal.

---

## 📦 Dependencies

`mem-police` requires the PCRE2 library for regex pattern matching.
* **Debian/Ubuntu:** `sudo apt install libpcre2-dev`
* **Arch Linux:** `sudo pacman -S pcre2`
* **Fedora/RHEL:** `sudo dnf install pcre2-devel`

---

## 🚀 Installation

### 1. Build and Install (Via Makefile)

The included Makefile handles compiling the C daemon, linking PCRE2, and securely installing the binaries to `/usr/local/bin`.

```sh
git clone https://github.com/4ndr0666/mem-police.git
cd mem-police
make build
sudo make install
```

### 2. Configure

Create and secure your configuration file at `/etc/mem_police.conf`:

```ini
# /etc/mem_police.conf (CANONICAL)

THRESHOLD_MB=1500               # Max resident memory per process (MB)
THRESHOLD_DURATION=90           # Seconds process must be over limit before action
KILL_GRACE=30                   # Grace period after warning before SIGKILL (s)
KILL_SIGNAL=TERM                # Signal to send first (e.g. TERM, INT, KILL)
SLEEP=10                        # Scan interval (seconds)

# Whitelist (PCRE2 REGEX patterns, matched against /proc/PID/comm and /proc/PID/exe):
WHITELIST=^init$ ^systemd$ ^Xorg$ ^X$ ^wayland$ ^alacritty$ ^zsh$ ^bash$ ^sshd$ ^firefox$
```

**Secure your config!** (The daemon will refuse to run if permissions are too open).
```sh
sudo chown root:root /etc/mem_police.conf
sudo chmod 600 /etc/mem_police.conf
```

### 3. Enable the Daemon

`mem-police` must run as root to read kernel memory metrics and enforce signals. 

Copy the service file, then enable and start the daemon:
```sh
sudo cp mem-police.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mem-police.service
```

---

## ⚙️ Configuration Reference

| Variable             | Description                                  | Default / Required |
| -------------------- | ------------------------------------------ | ------------------ |
| `THRESHOLD_MB`       | Max resident memory per process (in MB)    | required           |
| `THRESHOLD_DURATION` | Seconds over threshold before signal       | required           |
| `KILL_GRACE`         | Seconds to wait before hard `SIGKILL`      | required           |
| `KILL_SIGNAL`        | Initial signal (e.g. `TERM`, `15`)         | required           |
| `SLEEP`              | Polling interval in seconds                | 10                 |
| `WHITELIST`          | Space-separated **Regex** patterns to skip | required           |

---

## ▶️ Operations & Logging

**View real-time logs:**
```sh
journalctl -u mem-police -f
```

**Reload configuration without restarting (Hot-Reload):**
```sh
sudo systemctl reload mem-police
# OR
sudo pkill -HUP mem-police
```

**Dump current tracking state to the systemd journal:**
```sh
sudo pkill -USR1 mem-police
```

**View Daemon Metrics:**
The daemon continuously exports the current number of tracked hogs and lifetime kills to a flat file for easy dashboard integration:
```sh
cat /var/run/mem-police/metrics
```

---

## 🧪 Testing

A TAP-compliant test script (`mem-police-tester.sh`) is installed alongside the daemon. It uses Python to safely allocate true Resident Set Size (RSS) memory, verifying the daemon's detection, state tracking, and termination protocols.

```sh
# Syntax: sudo mem-police-tester.sh [HOG_MB...]
sudo mem-police-tester.sh 2000
```

* Spawns true RSS memory-hogging processes.
* Tails the systemd journal automatically.
* Verifies atomic `.start` files are created in `/var/run/mem-police`.
* Validates that processes are successfully terminated after the duration threshold.

---

## 🔒 Security Posture

* **Root Enforcement:** `mem-police` explicitly checks `geteuid() == 0`. It must run as root.
* **Strict Permissions:** Refuses to start if `/etc/mem_police.conf` or `/var/run/mem-police/` are accessible to non-root users.
* **Atomic State:** Tracking files use `O_TRUNC` temporary files and `rename()` to guarantee atomic state writes, preventing corruption during sudden power loss.
* **No external APIs or Network:** Zero open ports.

---

## 🧹 Uninstallation

To cleanly remove all binaries, systemd units, and state directories:

```sh
sudo systemctl disable --now mem-police.service
sudo rm /etc/systemd/system/mem-police.service
sudo systemctl daemon-reload

cd mem-police
sudo make uninstall

sudo rm /etc/mem_police.conf
sudo rm -rf /var/run/mem-police
```

---

## 🛡️ License

MIT License. See [LICENSE](https://opensource.org/licenses/MIT).

---

## 🙋 Support

Open an issue or contact [4ndr0666](https://github.com/4ndr0666).
