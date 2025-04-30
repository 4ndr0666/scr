# mem-police

A minimal daemon to enforce per-process memory limits via simple “startfile” timing.

---

## 🛠️ Features

- **Configurable Thresholds**: Define memory usage limits in megabytes.
- **Grace Period**: Set a delay before terminating over-consuming processes.
- **Process Whitelisting**: Exclude specific processes from monitoring.
- **Logging**: Outputs events to standard output for easy logging.
- **Lightweight**: Minimal dependencies, written in C for efficiency.

---

## 📦 Installation

1. **Compile**

   ```sh

   cc -O2 -std=c11 -Wall -Wextra -pedantic \
      -D_POSIX_C_SOURCE=200809L \
      -o mem-police mem-police.c

   ```

2. **Install**

   ```sh

   sudo install -m 755 mem-police /usr/local/bin/

   ```

3. **Configuration File**

   Create `/etc/mem_police.conf` with content:

   ```ini

   # Mem-police Config

   THRESHOLD_MB=700
   KILL_SIGNAL=15
   KILL_DELAY=60
   SLEEP=30
   WHITELIST=systemd X bash sshd NetworkManager dbus gnome-keyring-daemon wayfire swaybg

   ```

   Make sure the file is readable by root only:

   ```sh

   sudo chown root:root /etc/mem_police.conf
   sudo chmod 600     /etc/mem_police.conf

   ```

---

## ⚙️ Configuration

| Variable       | Description                                                 | Default  |
| -------------- | ----------------------------------------------------------- | -------- |
| `THRESHOLD_MB` | Max resident memory per process (MB)                        | *required* |
| `KILL_SIGNAL`  | Signal to send (e.g. `SIGTERM`, `15`)                       | *required* |
| `KILL_DELAY`   | Seconds over threshold before enforcing kill                | *required* |
| `SLEEP`        | Polling interval in seconds                                 | 30       |
| `WHITELIST`    | Process commands to exempt (space-separated list)           | *required* |

---

## ▶️ Usage

Run as root or a user with permission to send signals:

```sh

sudo mem-police

```

It will:
- Scan `/proc` every `SLEEP` seconds.
- Track processes exceeding `THRESHOLD_MB`.
- After `KILL_DELAY`, send `KILL_SIGNAL`, then `SIGKILL` if still alive.
- Log actions to **stdout** (or redirect as desired).

```sh

sudo mem-police 2>&1 | tee /var/log/mem-police.log

```

---

### 🧪 Testing

Use the TAP‐style tester:

```sh

chmod +x mem-police-tester.sh
sudo ./mem-police-tester.sh 800 1024

```

It will output a TAP plan (1..4) and ok/not ok lines for each startfile and kill check.

---

## ⏪ Uninstallation

1. Remove binary:

   ```sh

   sudo rm /usr/local/bin/mem-police

   ```

2. Remove config:

   ```sh

   sudo rm /etc/mem_police.conf

   ```

3. (Optional) Clean up start-timer files:

   ```sh

   sudo rm /tmp/mempolice-*.start

   ```

---

## 🛠️ License

This project is licensed under the MIT License. See the [LICENSE](MIT) file for details.
