### Converting the Waybar Status Bar

**Rationale:**  
Waybar is a persistent element of your session’s interface. Running it as a systemd service ensures that it’s automatically restarted if it fails and managed consistently.

**Example Unit File (`~/.config/systemd/user/waybar.service`):**

```ini
[Unit]
Description=Waybar Status Bar
After=graphical-session.target

[Service]
ExecStart=/usr/bin/waybar --bar main-bar --config=%h/.config/wayfire/waybar/config --style=%h/.config/wayfire/waybar/style.css
Restart=on-failure
Type=simple

[Install]
WantedBy=default.target
```

**Actions:**  
- Save the file under the appropriate directory.
- Reload systemd:
  ```bash
  systemctl --user daemon-reload
  systemctl --user enable --now waybar.service
  ```
- Remove the manual launcher (e.g., the check in “statusbar” script) to avoid duplicates.

**Citations:**  
- The official Wayfire wiki and Archcraft community discussions both point to managing persistent UI elements like Waybar with systemd to improve reliability [citeturn0wayfire_configuration].
