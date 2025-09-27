# 🛡️ Brave Unified Wrapper & Systemd Installer

This project automates the setup of a powerful wrapper script that dynamically generates browser configurations on-the-fly, hardening privacy settings, optimizing performance, and allowing for deep, declarative customization through a single environment file.

## Features

-   **Dynamic Flag Generation:** Automatically applies performance and privacy-enhancing flags on every launch.
-   **Centralized Configuration:** Control all your Brave settings, from experimental features to proxy settings, from a single file (`~/.config/brave/brave.env`).
-   **Idempotent & Atomic:** The installer can be run repeatedly without causing issues. It ensures the system is always in the desired state. File writes are atomic to prevent corruption.
-   **User & Global Installs:** Choose between a local user installation (`~/.local/bin`, recommended) or a system-wide installation (`/usr/local/bin`).
-   **Systemd Integration:** Installs a systemd user service for seamless integration with modern Linux desktops.
-   **Multi-Channel Support:** Automatically works for `brave`, `brave-beta`, and `brave-nightly` channels if they are installed.
-   **User-Friendly Scaffolding:** Includes a command to generate a well-commented configuration file to get you started.

## Why Use This?

Running Brave directly is fine, but it lacks consistency and ease of advanced configuration. This wrapper solves several problems:

1.  **Consistency:** Ensures Brave always starts with your preferred set of optimized flags, regardless of how it's launched (terminal, `.desktop` file, etc.).
2.  **Performance:** Enables modern features like Vulkan, GPU rasterization, and VA-API video decoding where appropriate.
3.  **Privacy:** Disables anti-features like the crash reporter and provides an easy way to disable web features you don't use (e.g., WebUSB, Bluetooth).
4.  **Control:** Makes complex configurations (like forcing all traffic through a Tor proxy) declarative and simple to manage.

## Quick Start

1.  **Make the script executable:**
    ```bash
    chmod +x brave-install.sh
    ```

2.  **Run the installer (user mode is recommended):**
    ```bash
    ./brave-install.sh --user install
    ```
    This will install the wrapper to `~/.local/bin/brave-wrapper` and create symlinks like `~/.local/bin/brave`. Make sure `~/.local/bin` is in your `PATH`.

3.  **Initialize your custom configuration file:**
    The script will now prompt you to do this.
    ```bash
    ./brave-install.sh --user init-config
    ```
    This creates a template at `~/.config/brave/brave.env`.

4.  **Customize!**
    Open the newly created file and uncomment/edit the options you want.
    ```bash
    nano ~/.config/brave/brave.env
    ```
    Your changes will apply the next time you start Brave.

## Detailed Usage

### Installing

-   **User Install (Recommended):**
    ```bash
    ./brave-install.sh --user install
    ```
-   **Global Install (Requires sudo):**
    ```bash
    ./brave-install.sh --global install
    ```

### Uninstalling

The uninstaller is safe and will only remove files and links it created.
bash

./brave-install.sh --user uninstall


### Configuration (`~/.config/brave/brave.env`)

This is the control center. After running `init-config`, you can edit this file to enable powerful features.

#### Example: Performance Tuning

To enable the Vulkan graphics backend and hardware-accelerated video decoding (requires `intel-media-driver` or similar), add this to your `brave.env`:
bash

~/.config/brave/brave.env
BRAVE_ENABLE="Vulkan,VaapiVideoDecoder"


#### Example: Privacy Hardening

To disable features that could increase your browser's fingerprint or attack surface, add:
bash

~/.config/brave/brave.env
BRAVE_DISABLE="WebBluetooth,WebUSB,WebSerial,WebNFC"


#### Example: Forcing a SOCKS5 Proxy (Tor)

To route all Brave traffic through a local Tor daemon running on port 9050:
bash

~/.config/brave/brave.env
BRAVE_EXTRA_FLAGS='--proxy-server="socks5://127.0.0.1:9050" --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost"'


### Diagnostics & Debugging

If the browser isn't behaving as you expect, the wrapper has tools to help.

-   **Print Effective Flags:** To see the exact command and full list of flags that will be used to launch Brave, run:
    ```bash
    # For user install:
    ~/.local/bin/brave --print-effective-flags
    
    # For global install:
    /usr/local/bin/brave --print-effective-flags
    ```

-   **Check the Systemd Journal:** The wrapper logs its startup decisions (like GPU and Wayland detection). If Brave fails to launch from your application menu, check the logs:
    ```bash
    # For user installs
    journalctl --user -u brave.service -f

    # For global installs (if launched via systemd --global)
    journalctl -t brave-wrapper -f
    ```
