### Converting the Mako Notification (Persistent) Service

**Rationale:**  
Mako is the notification daemon running in the background; managing it with systemd improves logging, restart behavior, and lets you standardize its launch.

**Example Unit File (`~/.config/systemd/user/mako.service`):**

```ini
[Unit]
Description=Mako Notification Daemon
After=graphical-session.target

[Service]
ExecStart=/usr/bin/mako --config=%h/.config/wayfire/mako/config
Restart=on-failure
# We use simple type since mako is a straightforward process
Type=simple

[Install]
WantedBy=default.target
```

**Actions:**  
- Save this unit file.
- Run:
  ```bash
  systemctl --user daemon-reload
  systemctl --user enable --now mako.service
  ```
- Remove or disable the corresponding autostart entry in your wayfire.ini.

**Citations:**  
- Archcraft’s guidelines stress using systemd for persistent daemons [citeturn0archcraft_wayfire_sysd_guide].
