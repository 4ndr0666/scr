# mem-police

A lightweight daemon to monitor resident memory usage of processes and enforce configurable upper limits.

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
   KILL_SIGNAL=SIGTERM
   KILL_DELAY=20
   SLEEP=30
   WHITELIST="systemd X bash sshd NetworkManager dbus gnome-keyring-daemon wayfire swaybg"

   ```
   - **THRESHOLD_MB**: memory limit per process (in MB)  
   - **KILL_SIGNAL**: signal to send after delay (name or number)  
   - **KILL_DELAY**: seconds above threshold before killing  
   - **SLEEP**: seconds between scans  
   - **WHITELIST**: space-separated process names to ignore  

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

### Logging

Background & Redirect output:

```sh

sudo nohup mem-police 2>&1 | tee /var/log/mem-police.log

```

### Monitor & Iterate

- Check your logs (journalctl or /var/log/mem-police.log) for unexpected kills.
- Adjust thresholds, delays, or whitelist entries as needed.

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

## 🧪 Testing

A test script `mem-police-tester.sh` is provided to simulate a high memory usage scenario and verify that `mem-police` responds appropriately.

### Run the Tester

```sh

chmod +x mem-police-tester.sh
./mem-police-tester.sh 800

```

This script will:

1. Start `mem-police` if not already running.
2. Launch a Python process that consumes the specified amount of memory.
3. Monitor for the creation of a start file indicating the process is over the threshold.
4. Wait for the process to be terminated by `mem-police`.

---

## 🛠️ License

This project is licensed under the MIT License. See the [LICENSE](MIT) file for details.
