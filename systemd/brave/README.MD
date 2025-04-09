### **Systemd User Service Integration**

**Overview:**  
Create a systemd user unit that launches Brave‑beta with the required flags. This method leverages systemd’s process management and logging while decoupling the launch logic from the Waybar configuration.

**Implementation Steps:**

1. **Create a Service Unit File:**  
   Save the following content as `~/.config/systemd/user/brave-beta.service`:

   ```ini
   [Unit]
   Description=Brave Beta Browser

   [Service]
   ExecStart=/usr/bin/brave-beta \
       --allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne \
       --enable-features=UsesOzonePlatform,AllowLegacyMV2Extensions,BraveGoogleSignInPermission,ExtensionManifestV2,FluentOverlayScrollbar,IsolatedWebApps,ToastRefinements,WaylandPerSurfaceScale,WaylandTextInputV3,WaylandUiScale \
       --disable-crash-reporter=,beta
   Restart=on-failure

   [Install]
   WantedBy=default.target
   ```

2. **Reload and Enable:**  
   Enable and start the service using:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now brave-beta.service
   ```
3. **Update Waybar Module:**  
   Change the module’s click command to invoke systemctl:
   ```json
   "custom/brave": {
       "format": "",
       "on-click": "systemctl --user start brave-beta.service"
   }
   ```
