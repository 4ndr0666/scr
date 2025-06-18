# mem-police

A minimal, suckless daemon for per-process memory enforcement on Linux.

---

## 🛠️ Features

- **Configurable memory threshold:** Kill any process using more than N MB for T seconds.
- **Grace period:** Wait K seconds above threshold before killing.
- **Process whitelisting:** Exclude critical or user-defined processes.
- **Logging:** All actions (kills, skips, errors) are logged.
- **No dependencies:** One C file, one config. No systemd, no Python.
- **XDG and root-friendly:** Respects UNIX conventions.

---

## 📦 Installation

### 1. Build and Install

```sh
# Compile the daemon
cc -O2 -std=c11 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L -o mem-police mem-police.c

# Install as root
sudo install -m 755 mem-police /usr/local/bin/
````

### 2. Configure

Create `/etc/mem_police.conf`:

```ini
# /etc/mem_police.conf

THRESHOLD_MB=800                # Max memory per process (MB)
THRESHOLD_DURATION=30           # Seconds process must be over limit before action
KILL_GRACE=5                    # Grace period after warning before kill (s)
KILL_SIGNAL=KILL                # Signal: name (e.g. KILL) or number (e.g. 9)
SLEEP=30                        # Scan interval (seconds)
WHITELIST=mem-police systemd X bash NetworkManager dbus gnome-keyring-daemon
```

**Secure your config!**

```sh
sudo chown root:root /etc/mem_police.conf
sudo chmod 600 /etc/mem_police.conf
```

---

## ⚙️ Configuration Reference

| Variable             | Description                                | Default / Required |
| -------------------- | ------------------------------------------ | ------------------ |
| `THRESHOLD_MB`       | Max resident memory per process (in MB)    | required           |
| `THRESHOLD_DURATION` | Seconds over threshold before kill         | required           |
| `KILL_GRACE`         | Grace period after warning (in seconds)    | required           |
| `KILL_SIGNAL`        | Kill signal (e.g. `KILL`, `SIGKILL`, `15`) | required           |
| `SLEEP`              | Scan interval in seconds                   | 30                 |
| `WHITELIST`          | Space-separated names to never kill        | required           |

---

## ▶️ Usage

### Start the Daemon (root only, not systemd)

Launch on login via `/etc/profile.d/mem-police.sh`:

```sh
# /etc/profile.d/mem-police.sh
[ "$(id -u)" -eq 0 ] && ! pgrep -x mem-police >/dev/null 2>&1 && /usr/local/bin/mem-police &
```

Or, start manually in a root shell:

```sh
sudo /usr/local/bin/mem-police &
```

To log all output:

```sh
sudo sh -c '/usr/local/bin/mem-police 2>&1 | tee /var/log/mem-police.log' &
```

---

## 🧪 Testing

TAP-style test script included:

```sh
sudo ./mem-police-tester.sh 800 1024
```

* Spawns memory-hogging processes
* Checks for `.start` files
* Verifies they are killed after exceeding threshold

**Note:** The daemon must be running as root before running the tester!

---

## 🔒 Security

* **mem-police must run as root** (so it can monitor and kill any user’s process).
* Config must be **`0600` and owned by root**.
* No systemd, no extra daemons, no open ports, no cron—just one process, one config.

---

## 🧹 Uninstallation

```sh
sudo pkill mem-police           # Stop the daemon if running
sudo rm /usr/local/bin/mem-police
sudo rm /etc/mem_police.conf
sudo rm -rf /var/run/mem-police /var/run/user/*/mem-police
rm -f /tmp/mempolice-*.start /dev/shm/hog.* /tmp/hog.*
```

---

## 🚑 Troubleshooting

* **Daemon fails to start:**

  * Check `/etc/mem_police.conf` for typos, missing values, or wrong permissions.
  * Must be `chmod 600`, owned by root.
* **Tester fails:**

  * Make sure daemon is running as root.
  * Check that `/var/run/user/$(id -u)/mem-police/` is writable.
* **No `.start` files:**

  * Directory permissions may be wrong; ensure user dir exists and is owned by the testing user.
* **Nothing is ever killed:**

  * Threshold or whitelist may be too generous.
  * Use smaller values to test.

---

## 🛡️ License

MIT License. See [LICENSE](https://opensource.org/licenses/MIT).

---

## 🙋 Support

Open an issue or contact [4ndr0666](https://github.com/4ndr0666).

---
