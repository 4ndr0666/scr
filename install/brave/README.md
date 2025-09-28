# 🛡️ Brave Unified Wrapper & Systemd Installer

An intelligent, idempotent installer and wrapper for the Brave browser, designed to provide a consistent, optimized, and centrally managed browsing experience on Linux systems.

This project automates the setup of a powerful wrapper script that establishes a baseline of sane defaults and merges them with your custom settings, hardening privacy, optimizing performance, and allowing for deep, declarative customization through a single environment file.

## Features

-   **Intelligent Configuration:** The wrapper provides a baseline of stable flags and intelligently merges them with your custom settings from a single file (`~/.config/brave/brave.env`).
-   **Declarative Control:** Manage everything from GPU settings to experimental features using simple environment variables.
-   **Robust Installation:** The installer can be run repeatedly without causing issues, ensuring the system is always in the desired state.
-   **Clear Privilege Separation:** Correctly handles `user` and `global` installations by separating privileged tasks (placing binaries) from user tasks (managing services), aligning with modern Linux security practices.
-   **Systemd User Service:** Installs a proper `systemd` user service for seamless integration with your desktop session, ensuring Brave starts correctly from any application launcher.
-   **Multi-Channel Support:** The wrapper can be symlinked to `brave-beta` or `brave-nightly` and will automatically launch the correct browser channel.
-   **Proactive Setup:** A default configuration file is automatically created on first install, ensuring the browser is runnable out-of-the-box.

## Why Use This?

Running Brave directly is fine, but it lacks consistency and ease of advanced configuration. This wrapper solves several key problems:

1.  **Consistency:** Ensures Brave always starts with your preferred set of optimized flags, regardless of how it's launched.
2.  **Performance:** Enables modern features like GPU rasterization and VA-API video decoding where appropriate, based on your system's detected capabilities.
3.  **Privacy:** Provides a simple, declarative way to disable web features you don't use (e.g., WebUSB, WebNFC), reducing the browser's attack surface.
4.  **Control:** Makes complex configurations (like forcing all traffic through a Tor proxy) declarative and simple to manage in one place.

## Installation

The script distinguishes between installing binaries for a single user or system-wide.

### Recommended: User Install

This method is recommended as it requires no root privileges and keeps all files contained within your home directory.

1.  **Make the script executable:**
    ```bash
    chmod +x brave-install.sh
    ```

2.  **Run the user installer:**
    ```bash
    ./brave-install.sh --user install
    ```
    This installs the wrapper to `~/.local/bin` and sets up the `systemd` user service. Ensure `~/.local/bin` is in your `PATH`. A default config file will be created automatically at `~/.config/brave/brave.env`.

### Advanced: Global Install

This method installs the wrapper binary to `/usr/local/bin`, making it available to all users on the system. It is a **two-step process** to respect system security boundaries.

1.  **Step 1: Install Binaries (with `sudo`):**
    ```bash
    sudo ./brave-install.sh --global install
    ```
    This command, run as root, places the wrapper script in `/usr/local/bin`. It cannot (and should not) touch your user's service configuration. It will then instruct you to run the next command.

2.  **Step 2: Enable User Service (without `sudo`):**
    ```bash
    ./brave-install.sh enable-user-service
    ```
    This command, run as your normal user, creates and enables the `systemd` user service that will use the globally installed wrapper.

## Configuration

Your browser's control plane is a single file: `~/.config/brave/brave.env`. The wrapper script sources this file on every launch. You can create or reset it to a default state by running `./brave-install.sh init-config`.

### Primary Variables

| Variable            | Description                                                                                              |
| ------------------- | -------------------------------------------------------------------------------------------------------- |
| `BRAVE_DISABLE_GPU` | Set to `1` to prevent the wrapper from adding any of its default GPU acceleration flags.                   |
| `BRAVE_ENABLE`      | Comma-separated list of features to enable (e.g., `Vulkan,VaapiVideoDecoder`).                           |
| `BRAVE_DISABLE`     | Comma-separated list of features to disable (e.g., `WebUSB,WebSerial`).                                  |
| `BRAVE_EXTRA_FLAGS` | A string of any other command-line flags to pass directly to the Brave binary. This is for ultimate control. |

### Example `brave.env` Configuration

This single example demonstrates how to combine variables to achieve a highly customized setup.

```bash
~/.config/brave/brave.env

--- GPU Control ---
Uncomment to completely disable the wrapper's default GPU optimizations.
Useful if you want to add all GPU flags manually in BRAVE_EXTRA_FLAGS.
BRAVE_DISABLE_GPU=1
--- Feature Control ---
Enable modern graphics backend and hardware video decode.
BRAVE_ENABLE="Vulkan,VaapiVideoDecoder"

Disable hardware APIs to reduce attack surface.
BRAVE_DISABLE="WebBluetooth,WebUSB,WebSerial,WebNFC"

--- Power-User Flags ---
This is where you put all other custom command-line flags.
BRAVE_EXTRA_FLAGS='

--force-dark-mode

--enable-features=WebUIDarkMode

--renderer-process-limit=2

--site-per-process

--proxy-server="socks5://127.0.0.1:9050"

--host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost"

--force-device-scale-factor=1.5

--- Other Environment Variables ---
Since this is a sourced script, you can set any other environment
variables here that you want the Brave process to inherit.
GTK_THEME="Adwaita:dark"
```

## Usage & Diagnostics

-   **Launching Brave:** Simply run `brave` from your terminal or use your desktop's application launcher.

-   **Print Effective Flags:** To see the exact command and full list of flags that will be used to launch Brave, run:
    ```bash
    brave --print-effective-flags
    ```

-   **Check the Systemd Journal:** If Brave fails to launch from your application menu, check the logs for your user service. **This command is the same for both user and global installs.**
    ```bash
    journalctl --user -u brave.service -f
    ```

## Uninstallation

Uninstallation is also a clean, two-step process for global installs.

1.  **Run the uninstaller with `sudo`:**
    This removes the system-wide binaries.
    ```bash
    sudo ./brave-install.sh --global uninstall
    ```

2.  **Run the uninstaller as your user:**
    This disables and removes your personal `systemd` user service.
    ```bash
    ./brave-install.sh --user uninstall
    ```
    *For a user-only install, you only need to run this second command.*
