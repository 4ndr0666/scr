# mem-police

A minimal daemon to enforce per-process memory limits via simple “startfile” timing.

---

## 🛠️ Features

- **Configurable Thresholds**: Define memory usage limits in megabytes.  
- **Grace Period**: Delay before terminating over-consuming processes.  
- **Process Whitelisting**: Exclude specific processes from monitoring.  
- **Logging**: Events output to standard output.  
- **Lightweight**: Minimal dependencies, written in C.

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
3. **Configure**  
   Create `/etc/mem_police.conf` with your settings:
   ```ini
   THRESHOLD_MB=700
   KILL_SIGNAL=15
   KILL_DELAY=60
   SLEEP=30
   WHITELIST=systemd X bash sshd NetworkManager dbus gnome-keyring-daemon wayfire swaybg
   ```
   Then secure it:
   ```sh
   sudo chown root:root /etc/mem_police.conf
   sudo chmod 600 /etc/mem_police.conf
   ```

---

## ⚙️ Configuration

| Variable      | Description                                 | Default    |
|---------------|---------------------------------------------|------------|
| THRESHOLD_MB  | Max resident memory per process (MB)        | (required) |
| KILL_SIGNAL   | Signal number or name (e.g. 15, SIGTERM)    | (required) |
| KILL_DELAY    | Seconds above threshold before termination  | (required) |
| SLEEP         | Scan interval in seconds                    | 30         |
| WHITELIST     | Space-separated process names to ignore     | (required) |

---

## ▶️ Usage

Run as root or with sufficient privileges:
```sh
sudo mem-police
```
Logs are written to stdout; to persist:
```sh
sudo mem-police 2>&1 | tee /var/log/mem-police.log
```

---

## 🧪 Testing

Use the TAP-style tester:
```sh
chmod +x mem-police-tester.sh
sudo ./mem-police-tester.sh 800 1024
```
It outputs a TAP plan and `ok`/`not ok` lines for each check.

---

## ⏪ Uninstallation

```sh
sudo rm /usr/local/bin/mem-police
sudo rm /etc/mem_police.conf
rm -f /tmp/mempolice-*.start
```

---

## 🛡️ License

This project is licensed under the MIT License. See [LICENSE](https://opensource.org/licenses/MIT) for details.
