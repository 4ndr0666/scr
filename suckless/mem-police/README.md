# 🧠 Memory Police

A suckless daemon that kills processes consuming too much RAM.  
Ideal for minimal environments with no systemd, D-Bus, or bloat.

## 📦 Features

- Shell-only, zero deps
- Cron-compatible patrol
- Configurable thresholds and kill behavior
- Whitelisting of critical processes

## ⚙️ Configuration

Edit `/etc/mem_police.conf`:

```sh
THRESHOLD_MB=500          # Max memory per process (MB)
KILL_SIGNAL=15            # Initial signal to send (15 = SIGTERM)
KILL_DELAY=5              # Seconds before fallback SIGKILL
WHITELIST="systemd bash"  # Commands to exclude
```

## 🚀 Install

```bash
sudo ./mem-police-install.sh
```

## 🔁 Uninstall

```bash
sudo ./mem-police-uninstall.sh
```
```

---
