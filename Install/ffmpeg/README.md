# Custom FFmpeg, SVP, MPV, and VapourSynth Installation Script

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Install Dependencies](#2-install-dependencies)
  - [3. Run the Installation Script](#3-run-the-installation-script)
  - [4. Configure the Dynamic Linker](#4-configure-the-dynamic-linker)
  - [5. Set Up the Custom Garuda Update Wrapper](#5-set-up-the-custom-garuda-update-wrapper)
- [Usage](#usage)
  - [Performing System Updates](#performing-system-updates)
- [Logging](#logging)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This project provides a comprehensive set of scripts to build and install custom versions of **FFmpeg**, **SVP (SmoothVideo Project)**, **MPV**, and **VapourSynth** with enhanced features tailored for specific workflows. Additionally, it includes a custom wrapper script for **Garuda Linux's** `garuda-update` utility to manage and preserve these custom binaries during system updates seamlessly.

## Features

- **Custom Builds:** Compile FFmpeg, x264, x265, and MPV from source with specific configurations.
- **Environment Configuration:** Automatically update environment variables to prioritize custom binaries.
- **System Update Integration:** Utilize a custom `garuda-update` wrapper to prevent conflicts with system package managers.
- **Logging:** Comprehensive logging for build and installation processes.
- **Error Handling:** Robust error checking to ensure successful installations.
- **Cleanup Functionality:** Remove previous installations and temporary files to maintain a clean environment.

## Prerequisites

Before proceeding with the installation, ensure that your system meets the following requirements:

- **Operating System:** Garuda Linux or any Arch-based distribution.
- **User Permissions:** Sudo privileges to install packages and modify system configurations.
- **Essential Tools:** Git, `make`, `gcc`, `g++`, `cmake`, `meson`, `ninja`, and other build tools.

## Installation

Follow the steps below to install the custom FFmpeg, SVP, MPV, and VapourSynth along with the custom Garuda update wrapper.

### 1. Clone the Repository

First, clone this repository to your local machine:

```bash
git clone https://github.com/yourusername/custom-ffmpeg-svp-mpv-vsp.git
cd custom-ffmpeg-svp-mpv-vsp
```

*Replace `https://github.com/yourusername/custom-ffmpeg-svp-mpv-vsp.git` with the actual repository URL.*

### 2. Install Dependencies

Ensure that all necessary build dependencies are installed. Run the provided installation script:

```bash
./install_ffmpeg-svp-mpv-vsp.sh
```

This script will:

- Verify and install required tools and dependencies.
- Build and install x264, x265, FFmpeg, and MPV from source.
- Install necessary VapourSynth plugins via the AUR helper `yay`.

**Note:** The script includes error handling and logging. Check the logs located at `$HOME/ffmpeg_mpv_build/logs/` if you encounter any issues.

### 3. Run the Installation Script

The `install_ffmpeg-svp-mpv-vsp.sh` script automates the process of building and installing the required binaries. To execute the script:

```bash
./install_ffmpeg-svp-mpv-vsp.sh
```

**Script Highlights:**

- **Logging:** Builds are logged to `$HOME/ffmpeg_mpv_build/logs/build.log` and installations to `$HOME/ffmpeg_mpv_build/logs/install.log`.
- **Error Handling:** The script exits upon encountering any errors, prompting you to check the respective log files.
- **Environment Variables:** Updates your `PATH`, `PKG_CONFIG_PATH`, and `LD_LIBRARY_PATH` to prioritize custom-built binaries.

### 4. Configure the Dynamic Linker

To ensure that the system recognizes the custom-built FFmpeg libraries, place the `ffmpeg.conf` file in the dynamic linker configuration directory and update the linker cache:

```bash
sudo cp ffmpeg.conf /etc/ld.so.conf.d/
sudo ldconfig
```

**Contents of `ffmpeg.conf`:**

```bash
echo "$FFMPEG_BUILD/lib" | sudo tee /etc/ld.so.conf.d/ffmpeg.conf
sudo ldconfig
```

This configuration ensures that the linker includes your custom FFmpeg libraries when resolving dependencies.

### 5. Set Up the Custom Garuda Update Wrapper

To prevent conflicts between your custom FFmpeg binaries and system updates, use the provided `custom_garuda_update.sh` wrapper script.

#### a. Copy the Wrapper Script

Copy the `custom_garuda_update.sh` script to `/usr/local/bin/`:

```bash
sudo cp custom_garuda_update.sh /usr/local/bin/
```

#### b. Set Proper Permissions

Ensure the script has the correct ownership and permissions:

```bash
sudo chown root:root /usr/local/bin/custom_garuda_update.sh
sudo chmod 755 /usr/local/bin/custom_garuda_update.sh
```

#### c. (Optional) Create an Alias

For convenience, you can create an alias in your shell configuration (`~/.bashrc` or `~/.zshrc`):

```bash
echo "alias garuda-update-custom='/usr/local/bin/custom_garuda_update.sh'" >> ~/.bashrc
source ~/.bashrc
```

Now, you can perform system updates using:

```bash
garuda-update-custom [garuda-update options]
```

## Usage

### Performing System Updates

To perform a system update while preserving your custom FFmpeg binaries, use the `custom_garuda_update.sh` wrapper script. This script automates the process of temporarily renaming your custom binaries, running the system update, and restoring the binaries afterward.

#### Steps:

1. **Initiate the Update:**

   ```bash
   sudo custom_garuda_update.sh [garuda-update options]
   ```

   *Alternatively, if you've set up an alias:*

   ```bash
   garuda-update-custom [garuda-update options]
   ```

2. **What Happens Internally:**

   - **Backup Phase:** The script renames your custom `ffmpeg`, `ffplay`, `ffprobe`, and `x264` binaries in `$HOME/bin` by appending a `.bak` suffix.
   - **Update Phase:** Executes `garuda-update` to perform the system update without conflicting with the custom binaries.
   - **Restore Phase:** Renames the `.bak` binaries back to their original names, restoring your custom versions.

3. **Logging:**

   - All actions are logged to `/var/log/custom-garuda-update/update_YYYYMMDD_HHMMSS.log`.
   - Review these logs for detailed information on the update process and any potential issues.

4. **Error Handling:**

   - If the update process encounters errors, the script ensures that your custom binaries are restored to prevent lingering conflicts.
   - Check the log files in `/var/log/custom-garuda-update/` for troubleshooting.

## Logging

Comprehensive logs are maintained for both the build/install processes and the update operations.

- **Build and Installation Logs:**
  - Location: `$HOME/ffmpeg_mpv_build/logs/`
  - Files:
    - `build.log`: Contains output from building the sources.
    - `install.log`: Contains output from the installation steps.

- **Update Process Logs:**
  - Location: `/var/log/custom-garuda-update/`
  - File: `update_YYYYMMDD_HHMMSS.log`
  - Purpose: Records the steps taken during the system update, including backup and restoration of custom binaries.

## Troubleshooting

If you encounter issues during installation or updates, follow these steps:

1. **Check Build Logs:**

   - Navigate to `$HOME/ffmpeg_mpv_build/logs/` and review `build.log` and `install.log` for any errors during the build or installation phases.

2. **Verify Custom Binaries:**

   - Ensure that your custom binaries are present in `$HOME/bin/` and have executable permissions:

     ```bash
     ls -l $HOME/bin/ffmpeg $HOME/bin/ffplay $HOME/bin/ffprobe $HOME/bin/x264
     ```

3. **Review Update Logs:**

   - Check `/var/log/custom-garuda-update/` for logs related to system updates and the renaming/restoration process.

4. **Environment Variables:**

   - Confirm that the following environment variables are correctly set:

     ```bash
     echo $PATH
     echo $PKG_CONFIG_PATH
     echo $LD_LIBRARY_PATH
     ```

   - They should include paths to your custom binaries and libraries:

     ```
     /home/yourusername/bin:/home/yourusername/ffmpeg_build/lib/pkgconfig:...
     ```

5. **Dynamic Linker Configuration:**

   - Ensure that `/etc/ld.so.conf.d/ffmpeg.conf` exists and contains the correct library path.

   - Re-run `sudo ldconfig` if necessary.

6. **Missing Dependencies:**

   - If you encounter missing dependencies, rerun the installation script or manually install the required packages.

7. **AUR Helper Issues:**

   - Ensure that `yay` or `paru` is installed and functioning correctly for installing AUR packages.

8. **Seek Community Support:**

   - If problems persist, consider reaching out to the [Garuda Linux Forums](https://forum.garudalinux.org/) or the [Arch Linux Forums](https://bbs.archlinux.org/) for assistance.

## Cleanup

If you need to remove previous installations and clean up temporary files, use the `--clean` option with the installation script:

```bash
./install_ffmpeg-svp-mpv-vsp.sh --clean
```

**Alternatively**, you can manually execute the cleanup steps by running the `cleanup_previous_installation` function within the script or following these steps:

1. **Remove Build Directories:**

   ```bash
   rm -rf $HOME/ffmpeg_sources
   rm -rf $HOME/ffmpeg_build
   rm -rf $HOME/mpv_build
   rm -rf $HOME/yay
   ```

2. **Remove Custom Binaries:**

   ```bash
   rm -f $HOME/bin/ffmpeg $HOME/bin/ffplay $HOME/bin/ffprobe $HOME/bin/x264
   ```

3. **Remove Conflicting Libraries and pkg-config Files:**

   ```bash
   find $HOME/ffmpeg_build/lib -name "libav*.so.*" -exec rm -f {} \;
   find $HOME/ffmpeg_build/lib/pkgconfig -name "libav*.pc" -exec rm -f {} \;
   ```

4. **Remove Logs (Optional):**

   ```bash
   rm -rf $HOME/ffmpeg_mpv_build/logs
   sudo rm -rf /var/log/custom-garuda-update/
   ```

## Contributing

Contributions are welcome! If you encounter issues or have suggestions for improvements, feel free to open an issue or submit a pull request.

1. **Fork the Repository:**

   ```bash
   git clone https://github.com/yourusername/custom-ffmpeg-svp-mpv-vsp.git
   cd custom-ffmpeg-svp-mpv-vsp
   ```

2. **Create a New Branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes:**

   - Edit scripts, documentation, or add new features.

4. **Commit Your Changes:**

   ```bash
   git commit -m "Add feature: your-feature-description"
   ```

5. **Push to Your Fork:**

   ```bash
   git push origin feature/your-feature-name
   ```

6. **Submit a Pull Request:**

   - Navigate to the original repository and open a pull request with your changes.

## License

This project is licensed under the [MIT License](LICENSE).

---

**Disclaimer:** Use these scripts at your own risk. Ensure you understand each step and its implications on your system. Always back up important data before performing system modifications.
