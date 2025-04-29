# 🚀 DEPLOYMENT GUIDE – Memory Police

## 🛠️ Step-by-Step

### 1. Copy Files

```sh
cp mem-police.sh mem-police-install.sh mem-police-uninstall.sh ./
```

### 2. Install

```sh
chmod +x mem-police-install.sh
sudo ./mem-police-install.sh
```

Creates:
- `/usr/local/bin/mem-police.sh`
- `/etc/mem_police.conf`
- `@reboot` cronjob for autostart

### 3. Configure

Edit `/etc/mem_police.conf` to match your memory tolerances.

### 4. Start Immediately

```sh
sudo /usr/local/bin/mem-police.sh &
```

### 5. Uninstall

```sh
sudo ./mem-police-uninstall.sh
```

### ✅ Notes

- You **do not** need systemd.
- Script sleeps and polls every 60s.
- Safe for embedded, minimal, or rescue environments.
```

---
