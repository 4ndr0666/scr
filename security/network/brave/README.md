### **System Audit & Action Plan: Brave Browser Resource Management (Revision 3)**

**Document ID:** AUD-2023-BB-03  
**Subject:** Final action plan for Brave resource management, incorporating all user-provided canonical paths and replacing the legacy `profile.d` startup mechanism with a robust systemd architecture.  
**Status:** Production-Ready Implementation Plan

---

### **1.0 Strategic Recommendation: Transition from `profile.d` to Systemd**

The current method of starting the `mem-police` daemon via `/etc/profile.d/mem-police.sh` is dependent on a root user login session and lacks automatic restart and monitoring capabilities.

This plan will replace that mechanism with a formal systemd service. This provides:
*   **Automatic Startup:** The daemon starts at boot, independent of any user login.
*   **Reliability:** The service will be automatically restarted if it ever crashes.
*   **Centralized Management:** All daemon control is handled via `systemctl`, aligning with modern Arch Linux system administration practices.

This is a direct upgrade to the stability and reliability of your custom daemon.

### **2.0 Phase 1: Decommissioning Legacy Startup Mechanism**

The first action is to remove the legacy `profile.d` script to prevent conflicts with the new systemd service.

**Action Item 2.1: Remove `mem-police.sh`**  
*Execute the following command to remove the script that initiates the daemon on root login.*

```bash
sudo rm /etc/profile.d/mem-police.sh
```

### **3.0 Phase 2: Implementation of Systemd Control Architecture**

**Action Item 3.1: Create the Brave Browser Startup Script**  
*Create the file `$HOME/.local/bin/bravebackgrounded` with the following content. This script contains the optimized flags for launching the browser.*

```bash
#!/usr/bin/env bash
# File: /home/YOUR_USERNAME/.local/bin/bravebackgrounded
# (Ensure you replace YOUR_USERNAME with your actual home directory name)
# Description: Optimized launcher for brave-beta.

BRAVE_BIN="/usr/bin/brave-beta"

"$BRAVE_BIN" \
  --allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne \
  --disable-crash-reporter \
  --ozone-platform=wayland \
  --disk-cache-size=104857600 \
  --extensions-process-limit=1 \
  --enable-gpu-rasterization \
  --enable-zero-copy \
  --enable-features=ProactiveTabFreezeAndDiscard \
  "$@" &
```
*After creating the file, ensure it is executable:*
```bash
chmod +x $HOME/.local/bin/bravebackgrounded
```

**Action Item 3.2: Create the Systemd User Service for Brave Containment**  
*Create the file `~/.config/systemd/user/brave.service`. This service will manage your `bravebackgrounded` script and apply strict cgroup resource limits.*

```ini
# ~/.config/systemd/user/brave.service
# Manages the Brave instance via its canonical script and applies Cgroup limits.

[Unit]
Description=Brave Web Browser with Cgroup Resource Controls
After=graphical-session.target

[Service]
# The %h specifier is the systemd-native, canonical way to refer to the user's home directory.
ExecStart=%h/.local/bin/bravebackgrounded

# ---- Cgroup Resource Control ----
MemoryMax=8G
MemoryHigh=6G
CPUWeight=50
CPUQuota=200%

[Install]
WantedBy=graphical-session.target
```

**Action Item 3.3: Create the Systemd System Service for the `mem-police` Daemon**  
*Create the file `/etc/systemd/system/mem-police.service`. This unit uses the exact path to your daemon binary and replaces the `profile.d` script entirely.*

```ini
# /etc/systemd/system/mem-police.service
# Manages the mem-police daemon using its canonical path.

[Unit]
Description=Memory Policing Daemon
After=network.target

[Service]
Type=forking
PIDFile=/var/run/mem-police.pid
ExecStart=/usr/bin/mem-police
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

### **4.0 Phase 3: System Activation and Verification**

**Action Item 4.1: Stop any existing `mem-police` instances.**  
*Before starting the new service, ensure the old, manually-started one is stopped.*
```bash
sudo pkill -x mem-police
```

**Action Item 4.2: Reload Daemons and Activate New Services.**  
*Execute these commands to make the system aware of the new unit files and to enable and start them immediately.*

*For the `mem-police` system service (run as root):*
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mem-police.service
```

*For the Brave user service (run as your user):*
```bash
systemctl --user daemon-reload
systemctl --user enable --now brave.service
```

**Action Item 4.3: Verify Final System State.**  
*Confirm that the services are active and running correctly.*

*Check the `mem-police` daemon:*
```bash
sudo systemctl status mem-police.service
```
*(Expected output shows "active (running)").*

*Check the Brave user service:*
```bash
systemctl --user status brave.service
```
*(Expected output shows "active (running)" and a tree of Brave processes under its cgroup).*

---

### **5.0 Conclusion**

This completes the migration. The legacy startup script has been removed. The `mem-police` daemon is now a reliable, auto-restarting system service managed by systemd. The Brave browser is contained within a resource-limited cgroup, also managed by systemd, using your specified startup script. The system now operates entirely on the canonical paths provided.
