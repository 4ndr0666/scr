# THORIUM BROWSER: HARDENED DEPLOYMENT ARCHITECTURE
**Revision:** 1.0.0 (Strict Manifest V2 Survival & Hardware Isolation Override)
**Target Environment:** Linux / Wayland / Hyprland
**Objective:** Establish a stateless, telemetry-silenced, hardware-decoupled browsing environment with cryptographic persistence for deprecated Manifest V2 network-interception tools.

---

## 1. ARCHITECTURAL OVERVIEW & THREAT MODEL

This repository houses the configuration and deployment protocols for a highly customized installation of the Thorium Browser. Upstream Chromium is designed for mass-market convenience, resulting in aggressive telemetry collection, volatile caching to non-volatile storage (SSD wear), and an over-reliance on unstable GPU hardware acceleration. 

Furthermore, Google's aggressive deprecation of the Manifest V2 (MV2) extension architecture threatens the functionality of critical DevOps, privacy, and session-manipulation tools. 

This deployment matrix actively combats these vectors through a multi-layered suppression strategy:
1. **Hardware Decoupling:** Total annihilation of the GPU rendering pipeline. All compositing, rasterization, and video decoding are forced onto the CPU to guarantee stability and prevent graphic driver exploits.
2. **Volatile Caching:** Relocation of the browser's disk cache to `/dev/shm` (RAM disk), ensuring that payload data and temporary files are vaporized upon process termination or power loss.
3. **Cryptographic Tool Anchoring:** Sideloading of specific local extensions with static IDs, shielded from automated deactivation via an injected Enterprise Policy failsafe.

---

## 2. MANIFEST V2 SURVIVAL PROTOCOL & EXTENSION CRYPTOGRAPHY

Chromium dynamically generates Extension IDs based on the absolute file path of an unpacked extension. If a repository is moved, the ID mutates, instantly breaking any whitelists or associated configurations. To deploy our specific toolkit natively and ensure survival past the MV2 deprecation timeline, we utilize cryptographic anchoring.

### 2.1 The Cryptographic Anchor
The 32-character Extension ID (e.g., `khgmaagajnamgehoopgmmbeoggboffeb`) is calculated via a Base16 encoding of the first 32 characters of a SHA-256 hash derived from the extension's RSA public key. By injecting a static `.pem` key into the `manifest.json` of our local clones, the Chromium engine is forced to calculate the exact same ID regardless of the absolute path on the disk.

### 2.2 Allowed Ordnance Roster
This deployment is hardcoded to natively allow the following tools via the `--allowlisted-extension-id` execution parameter. These are loaded unpacked under dev mode.

| Tool Name | Cryptographic ID |
| :--- | :--- |
| **4ndr0cookie** | `khgmaagajnamgehoopgmmbeoggboffeb` |
| **Edit This Cookie** | `fngmhnnpilhplaeedifhccceomclgfbg` |
| **Devtools Advanced Location**| `pboglnnmnkkbdgflckmjhakpdejmnpli` |
| **Image Max URL** | `momhpkepmajdopjgahiglmboldkepibg` |
| **uBlock Origin** | `cgbcahbpdhpcegmbfconppldiemgcoii` |
| **JShelter** | `ammoloihpcbognfddfjcljgembpibcmb` |

---

## 3. ENTERPRISE POLICY ENFORCEMENT

Command-line flags are treated as "suggestions" by the Chromium engine and can be overridden by internal updates or Safe Browsing daemon checks. To grant our MV2 extensions absolute immunity from deprecation, we escalate their status to "Enterprise Managed."

### 3.1 Policy Injection
The system-level policy file must be deployed with `root` privileges. This JSON payload forces the engine to accept Manifest V2 architecture and whitelists our specific toolset from being classified as malicious or unsupported.

**Target Path:** `/etc/chromium/policies/managed/01_mv2_survival.json`
**Permissions:** `chmod 644`

```json
{
  "ExtensionManifestV2Availability": 2,
  "ExtensionInstallAllowlist": [
    "khgmaagajnamgehoopgmmbeoggboffeb",
    "fngmhnnpilhplaeedifhccceomclgfbg",
    "pboglnnmnkkbdgflckmjhakpdejmnpli",
    "momhpkepmajdopjgahiglmboldkepibg",
    "cgbcahbpdhpcegmbfconppldiemgcoii",
    "ammoloihpcbognfddfjcljgembpibcmb"
  ]
}

```

---

## 4. THE EPHEMERAL VAPORIZATION PROTOCOL

Standard browsing sessions contaminate the host system with persistent cookies, local storage blobs, and DOM caches. This architecture introduces a secondary execution vector: **The Temporary Profile**.

Accessible via the desktop launcher's `[Desktop Action temp-profile]` right-click menu, this command passes `--user-data-dir=/tmp/ephemeral-profile`.

* **The Mechanism:** The entire browser state (profile, preferences, cache) is instantiated inside the Linux `/tmp` directory.
* **The Result:** Because `/tmp` is mapped to volatile RAM (tmpfs) on modern Linux distributions, the moment the system reboots, or the directory is manually purged, all traces of the browsing session are cryptographically eradicated. No forensic footprint remains on the SSD.

---

## 5. THE EXECUTION MATRIX: COMMAND-LINE GLOSSARY

The core of this deployment lies in the `Exec=` lines of the `.desktop` file. Below is the technical documentation for every flag injected into the execution chain:

### Security & Isolation

* `--process-per-site`: A memory optimization that forces multiple tabs of the *same* domain to share a single process, keeping RAM explosion in check while still offering origin separation.
* `--force-webrtc-ip-handling-policy=default_public_interface_only`: Plugs the critical WebRTC protocol leak, preventing the browser from exposing the machine's local subnet IP address through VPNs and proxies.

### Hardware Decoupling (GPU Annihilation)

* `--disable-gpu`: Severs communication with the system graphical unit.
* `--disable-gpu-compositing` / `--disable-gpu-rasterization`: Forces the CPU to handle all painting, layer calculation, and pixel rendering.
* `--disable-accelerated-video-decode` / `--disable-accelerated-2d-canvas`: Disables hardware decoding for HTML5 video and canvas elements, ensuring zero reliance on unstable `libva` or `vdpau` drivers.

### Performance & Telemetry Suppression

* `--disk-cache-dir=/dev/shm/thorium-cache`: Re-routes the browser's heavy I/O cache writes away from the SSD and directly into the Linux shared memory partition. Results in instantaneous cache retrieval and zero drive degradation.
* `--no-pings`: Disables HTML5 hyperlink auditing (`<a ping>`), a common tracking mechanism used to log user click-throughs.
* `--disable-breakpad` / `--disable-crash-reporter`: Completely disables the Chromium crash-dump generation and upload daemons.
* `--silent-debugger-extension-api`: Suppresses the "Thorium is being controlled by automated software" infobar when utilizing developer tools or automation extensions.

### Wayland Integration

* `--ozone-platform=wayland`: Bypasses the XWayland compatibility layer, forcing native Wayland rendering for precise fractional scaling and crisp font rendering.
* `--enable-features=WaylandWindowDecorations`: Hooks into the compositor to draw native window borders, ensuring the application matches the system GTK/Qt theme.

---

## 6. HYPRLAND & XDG DESKTOP INTEGRATION

To ensure the window manager executes the browser via our hardened `.desktop` file (rather than invoking the raw, undefended binary), strict MIME type and keybinding configurations must be enforced.

### 6.1 MIME Type Associations

The XDG desktop portal must recognize `thorium-browser.desktop` as the absolute handler for web protocols. Ensure `~/.config/mimeapps.list` reflects the following:

```ini
[Default Applications]
x-scheme-handler/http=thorium-browser.desktop
x-scheme-handler/https=thorium-browser.desktop
text/html=thorium-browser.desktop
application/http=thorium-browser.desktop

```

### 6.2 Hyprland Keybinds

Use `gtk-launch` to ensure the desktop file is parsed locally.

```text
# HYPRLAND CONFIGURATION: BROWSER BIND
bindd = $mainMod, B, open hardened browser, exec, gtk-launch thorium-browser

```

---

## 7. CANONICAL ASSETS: `thorium-browser.desktop`

**Target Deployment Path:** `~/.local/share/applications/thorium-browser.desktop`
**Post-Install Requirement:** Execute `update-desktop-database ~/.local/share/applications/` upon saving.

Below is the complete, uninterrupted, production-ready configuration file matching the exact canonical deployment standard.

```ini
[Desktop Entry]
Version=1.0
Name=Thorium Browser
GenericName=Web Browser
# Gnome and KDE 3 uses Comment.
Comment=Access the Internet
Exec=/usr/bin/thorium-browser --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U
StartupWMClass=thorium
Keywords=browser
StartupNotify=true
Terminal=false
X-MultipleArgs=True
Icon=thorium-browser
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;
Actions=new-window;new-private-window;temp-profile;content-shell;safe-mode;dark-mode;

[Desktop Action new-window]
Name=New Window
Exec=/usr/bin/thorium-browser --new-window --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=/usr/bin/thorium-browser --incognito --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U

[Desktop Action temp-profile]
Name=Open New Window with a temporary profile
Exec=/usr/bin/thorium-browser --temp-profile --user-data-dir=/tmp/ephemeral-profile --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U

[Desktop Action content-shell]
Name=Open Thorium Shell
Exec=/usr/bin/thorium-shell --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U

[Desktop Action safe-mode]
Name=Open in Safe Mode
Exec=/usr/bin/thorium-browser --no-experiments --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U

[Desktop Action dark-mode]
Name=Open in Dark Mode
Exec=/usr/bin/thorium-browser --force-dark-mode --allowlisted-extension-id=khgmaagajnamgehoopgmmbeoggboffeb --allowlisted-extension-id=fngmhnnpilhplaeedifhccceomclgfbg --allowlisted-extension-id=pboglnnmnkkbdgflckmjhakpdejmnpli --allowlisted-extension-id=momhpkepmajdopjgahiglmboldkepibg --allowlisted-extension-id=cgbcahbpdhpcegmbfconppldiemgcoii --allowlisted-extension-id=ammoloihpcbognfddfjcljgembpibcmb --silent-debugger-extension-api --ozone-platform=wayland --process-per-site --disk-cache-dir=/dev/shm/thorium-cache --force-dark-mode --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-accelerated-video-decode --disable-accelerated-2d-canvas --no-pings --disable-breakpad --disable-crash-reporter --force-webrtc-ip-handling-policy=default_public_interface_only  --enable-features=WaylandWindowDecorations,WebUIDarkMode --disable-features=Crashpad-For-Testing,Crashpad-Forwarding,WebBluetooth,WebUsb,WebSerial,WebNfc,Third-Party-Keyboard-Workaround,Usb-Keyboard-Detect,Virtual-Keyboard %U

```
