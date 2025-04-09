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
   ExecStart=/usr/bin/brave-beta --allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne --enable-features=UsesOzonePlatform,AllowLegacyMV2Extensions,BraveGoogleSignInPermission,ExtensionManifestV2,FluentOverlayScrollbar,IsolatedWebApps,ToastRefinements,WaylandPerSurfaceScale,WaylandTextInputV3,WaylandUiScale --disable-crash-reporter=,beta
   Restart=on-failure
   Type=simple

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
       "on-click": "systemctl --user start brave-beta.service",
       "on-click-right": "min-browser"
   }
   ```
   
**Points of Verification:**

Please verify on your side that:
- The Brave‑Beta service file is present in `$HOME/.config/systemd/user/`.
- The service starts with no errors (check using `systemctl --user status brave-beta.service`).
- Clicking the Brave module in your Waybar triggers Brave‑Beta as expected.

- **Binary Path:**  
  The service runs `/usr/bin/brave-beta`. Double-check (with, for example, `which brave-beta`) that the binary is indeed located at this path. (If not, update accordingly.)

- **Command-Line Arguments:**  
  The long command line passed to Brave‑Beta includes:
  - An allowlist extension ID,
  - A list of enabled features such as `UsesOzonePlatform`, `AllowLegacyMV2Extensions`, and others that improve integration with Wayland,  
  - Disabling crash reporting using `--disable-crash-reporter=,beta`.

  These arguments ensure that Brave‑Beta is launched with appropriate features (for instance, Wayland support via `WaylandPerSurfaceScale` and `WaylandTextInputV3`). This matches common recommendations when running Brave‑Beta on an Arch Linux system where systemd is used to manage services.

- **Restart Policy:**  
  The service uses `Restart=on-failure`, which ensures that if Brave‑Beta crashes for any reason, systemd will attempt a restart. This behavior is consistent with best practices for persistent applications.

- **Service Type:**  
  Using `Type=simple` is acceptable here because Brave‑Beta does not fork or require a more complex startup notification.

## Final Assessment

Your Brave‑Beta implementation is accurate if:

- The binary `/usr/bin/brave-beta` and its command arguments are correct for your installation.
- The service file (as given above) is placed in `$HOME/.config/systemd/user/` and enabled/reloaded correctly.
- The Waybar module correctly calls `systemctl --user start brave-beta.service`.
