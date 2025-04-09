### GTK Themes Application Service

#### Create the Unit File

Create a new file at:

```
$HOME/.config/systemd/user/gtkthemes.service
```

with the following exact content:

```ini
[Unit]
Description=Apply GTK Themes, Icons, Cursor, and Fonts for Wayfire Session
Before=graphical-session.target

[Service]
Type=oneshot
ExecStart=/home/andro/.config/wayfire/scripts/gtkthemes
RemainAfterExit=yes

[Install]
WantedBy=default.target
```

**Notes:**

- The script is invoked using its full path (using your actual home directory `/home/andro` as seen in your other configurations).
- We set the service type to oneshot since it simply runs once and applies the theme.
- The directive `RemainAfterExit=yes` ensures that systemd treats the service as “active” after it runs, useful for dependency ordering.
- The `Before=graphical-session.target` line ensures this runs early during the session startup (adjust as needed based on your session configuration).

#### Checklist 

- [ ] **Verify Script Location:**  
  Confirm that your GTK themes script exists at  
  `/home/andro/.config/wayfire/scripts/gtkthemes`.
  
- [ ] **Create the Unit File:**  
  Save the above content as `$HOME/.config/systemd/user/gtkthemes.service`.

- [ ] **Reload Systemd User Daemon:**  
  Execute:
  ```bash
  systemctl --user daemon-reload
  ```

- [ ] **Enable and Start the Service:**  
  Run:
  ```bash
  systemctl --user enable --now gtkthemes.service
  ```

- [ ] **Verify the Service:**  
  Check the service status with:
  ```bash
  systemctl --user status gtkthemes.service
  ```
  You should see that it has run successfully (the service’s status should be “active (exited)” indicating it has finished its oneshot execution).

- [ ] **Check for Side Effects:**  
  Verify via your desktop environment (e.g., by inspecting your GTK theme settings) that the intended themes (Sweet-v40 for GTK, Colorful-Dark-Icons, JetBrainsMono Nerd Font Regular 9, and Breeze-Adapta-Cursor) have been applied.
