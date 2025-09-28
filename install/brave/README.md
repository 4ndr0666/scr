# 🛡️ Brave Unified Wrapper & Systemd Installer

An intelligent, idempotent installer and wrapper for the Brave browser, designed to provide a consistent, optimized, and centrally managed browsing experience on Linux systems.

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

## Configuration Guide

This is the control plane for your browser, located at `~/.config/brave/brave.env`. The wrapper script will `source` this file on every launch, loading your custom settings as environment variables.

### Primary Environment Variables

These are the main variables the wrapper script understands.

| Variable              | Description                                                                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------- |
| `BRAVE_ENABLE`        | Comma or space-separated list of features to enable.                                                    |
| `BRAVE_DISABLE`       | Comma or space-separated list of features to disable.                                                   |
| `BRAVE_EXTRA_FLAGS`   | A string of additional raw command-line flags. **This is the power-user tool for ultimate control.**      |
| `BRAVE_FORCE_GPU`     | Set to `1` to force GPU acceleration on, overriding the script's auto-detection.                        |
| `BRAVE_DISABLE_GPU`   | Set to `1` to force GPU acceleration off. Useful for troubleshooting rendering issues.                   |

### Recommended `BRAVE_ENABLE` Features

Uncomment these in your `brave.env` file to enable modern performance and functionality.

```bash
~/.config/brave/brave.env
```

--- Recommended Enables ---
Enables the modern, high-performance Vulkan graphics backend. Can offer better
performance and lower CPU usage than OpenGL on supported systems (most modern GPUs).
BRAVE_ENABLE="Vulkan"

Enables hardware-accelerated video decoding via VA-API. Massively reduces CPU
usage during video playback. Requires appropriate drivers (e.g., intel-media-driver).
BRAVE_ENABLE="Vulkan,VaapiVideoDecoder"

Enables drawing directly to screen memory, which can reduce latency on Wayland.
BRAVE_ENABLE="Vulkan,VaapiVideoDecoder,RawDraw"

Enables parallel downloading to speed up large file downloads.
BRAVE_ENABLE="ParallelDownloading"


### Recommended `BRAVE_DISABLE` Features

Uncomment these to reduce your browser's attack surface, disable features you don't use, and conserve system resources.

```bash
~/.config/brave/brave.env
```

--- Recommended Disables for Privacy & Security ---
Disable various web hardware APIs if you don't use them. This significantly
reduces the browser's attack surface.
BRAVE_DISABLE="WebBluetooth,WebUSB,WebSerial,WebNFC"

Disable Brave-specific cloud features you may not use.
BRAVE_DISABLE="SharingHub,ReadLater"


### Advanced Scenarios with `BRAVE_EXTRA_FLAGS`

This variable allows you to pass any command-line flags directly to the Brave binary.

#### Scenario 1: Force Dark Mode & Theming

```bash
~/.config/brave/brave.env
```

Force dark mode for both the browser UI and web content.
BRAVE_EXTRA_FLAGS='--force-dark-mode --enable-features=WebUIDarkMode'

On some Wayland systems, you may need to specify the GTK theme for it to apply correctly.
This is a standard environment variable, not a flag.
GTK_THEME="Adwaita:dark"


#### Scenario 2: Route All Traffic Through a Tor Proxy

This forces the browser to use a local Tor daemon (or any SOCKS5 proxy) for all of its traffic, enhancing privacy.

```bash
~/.config/brave/brave.env
```

BRAVE_EXTRA_FLAGS='--proxy-server="socks5://127.0.0.1:9050" --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost"'

#### Scenario 3: Create and Use an Alternate Profile

Run a completely separate, sandboxed instance of Brave with its own settings, extensions, and cookies.

```bash
~/.config/brave/brave.env
```

Point Brave to a different directory for its user profile.
BRAVE_EXTRA_FLAGS='--user-data-dir="${HOME}/.config/brave-work-profile"'

#### Scenario 4: HiDPI Scaling

Manually set the scaling factor for high-resolution displays, especially useful on Linux desktop environments where this can be inconsistent.

```bash
~/.config/brave/brave.env
```

BRAVE_EXTRA_FLAGS='--force-device-scale-factor=1.5'

---

## Diagnostics & Debugging

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
