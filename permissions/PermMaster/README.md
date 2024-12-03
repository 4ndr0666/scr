# PermMaster

![PermMaster Logo](https://example.com/logo.png)

**PermMaster** is a comprehensive multi-tool designed for managing system permissions on Arch Linux. Whether you're setting up a new system, restoring permissions from a factory snapshot, or auditing and fixing permission issues, PermMaster provides a suite of functionalities to ensure your system's security and integrity.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [1. Capturing Factory Permissions from a Live ISO](#1-capturing-factory-permissions-from-a-live-iso)
  - [2. Applying Factory Permissions to the Installed System](#2-applying-factory-permissions-to-the-installed-system)
- [Troubleshooting](#troubleshooting)
- [Logging and Reporting](#logging-and-reporting)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## Features

- **Create Permissions Snapshots:** Capture current permissions, ACLs, and extended attributes.
- **Apply Permissions Snapshots:** Restore permissions from previously taken snapshots.
- **Backup Current Permissions:** Safeguard existing permission states before making changes.
- **Audit and Fix with Pacman:** Utilize `pacman` to identify and rectify permission discrepancies in package-managed files.
- **Reset Permissions:** Restore standard permissions for system directories, `/etc`, `/home`, and package files.
- **Generate Detailed Reports:** Create JSON reports detailing actions taken for auditing purposes.
- **User-Friendly Interface:** Intuitive menu-driven interface with color-coded feedback and confirmation prompts.

---

## Prerequisites

Before using PermMaster, ensure your system meets the following requirements:

- **Operating System:** Arch Linux or Arch-based distributions.
- **Privileges:** Root (superuser) access is required to perform permission changes.
- **Dependencies:** PermMaster relies on several system utilities. The script will automatically check and prompt to install missing dependencies.

---

## Installation

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/4ndr0666/permmaster.git
   ```

2. **Navigate to the Script Directory:**

   ```bash
   cd permmaster
   ```

3. **Make the Script Executable:**

   ```bash
   chmod +x perm_master.sh
   ```

4. **Run PermMaster:**

   ```bash
   sudo ./perm_master.sh
   ```

   *Note: Running the script with `sudo` ensures it has the necessary permissions to perform system-wide changes.*

---

## Usage

PermMaster is designed to be user-friendly with a menu-driven interface. Below are the steps to capture factory permissions from a live ISO and apply them to your installed system.

### **1. Capturing Factory Permissions from a Live ISO**

To capture the factory (default) permissions and ownerships from a live ISO, follow these steps:

1. **Boot into the Live ISO:**
   
   - Insert your Arch Linux live USB or DVD and boot your system using it.
   - Ensure you are running in a live environment where the system files have factory permissions.

2. **Open Terminal in Live Environment:**

3. **Run PermMaster to Create a Snapshot:**

   ```bash
   sudo ./perm_master.sh
   ```

4. **Select "Create Permissions Snapshot" (Option 1):**
   
   - **Enter Snapshot File Path:**
     - When prompted, specify a location to save the snapshot. For example:
       ```
       Enter the full path to save the snapshot (without extension) [permissions_snapshot]: /mnt/usb/factory_permissions
       ```
       *Ensure `/mnt/usb/` is a mounted USB drive or external storage where you have write access.*

   - **Enter Directory to Snapshot:**
     - Typically, you would snapshot the root directory:
       ```
       Enter the directory to snapshot [/]: /
       ```

5. **Wait for Snapshot Creation:**
   
   - PermMaster will capture permissions, ACLs, and extended attributes.
   - Upon completion, you'll see a success message indicating the snapshot files have been saved:
     ```
     [✓] Permissions snapshot saved to /mnt/usb/factory_permissions.*
     ```

6. **Safely Eject the External Storage:**
   
   - Ensure all snapshot files (`.perms`, `.acl`, `.attrs`) are successfully copied to your external storage.

### **2. Applying Factory Permissions to the Installed System**

After capturing the factory permissions from the live ISO, you can apply them to your installed system.

1. **Boot into Your Installed Arch Linux System:**

2. **Transfer Snapshot Files to the Installed System:**
   
   - Connect the external storage containing the snapshot files.
   - Mount the external storage if not auto-mounted. For example:
     ```bash
     sudo mount /dev/sdX1 /mnt/usb
     ```
     *Replace `/dev/sdX1` with your actual device identifier.*

3. **Open Terminal in Installed Environment:**

4. **Run PermMaster to Apply the Snapshot:**

   ```bash
   sudo ./perm_master.sh
   ```

5. **Select "Apply Permissions Snapshot" (Option 2):**
   
   - **Enter Snapshot File Path:**
     - Provide the path to the snapshot files. For example:
       ```
       Enter the permissions snapshot file prefix [permissions_snapshot]: /mnt/usb/factory_permissions
       ```
   
   - **Enter Base Directory to Apply Permissions:**
     - Typically, you would apply to the root directory:
       ```
       Enter the base directory to apply permissions to [/]: /
       ```

6. **Wait for Permissions to Be Applied:**
   
   - PermMaster will restore permissions, ACLs, and extended attributes based on the snapshot.
   - Upon completion, you'll see a success message:
     ```
     [✓] Permissions applied from /mnt/usb/factory_permissions.*
     ```

7. **Verify Permissions:**
   
   - It's advisable to manually verify critical directories and files to ensure permissions have been correctly applied.

---

## Troubleshooting

- **Permissions Errors:**
  
  - **Symptom:** Errors related to insufficient permissions or inability to change ownership.
  - **Solution:** Ensure you are running PermMaster with root privileges (`sudo`). Verify that the snapshot files have the correct ownership and permissions.

- **Snapshot Not Found:**
  
  - **Symptom:** Errors indicating that snapshot files are missing.
  - **Solution:** Confirm that the snapshot files (`.perms`, `.acl`, `.attrs`) exist at the specified path and are accessible.

- **Dependency Issues:**
  
  - **Symptom:** Missing commands or utilities.
  - **Solution:** Run PermMaster; it will prompt to install any missing dependencies. Ensure you have an active internet connection to allow `pacman` to install required packages.

- **Execute Permission Errors:**
  
  - **Symptom:** Errors indicating that executables cannot be run.
  - **Solution:** Use the provided one-liner to check and set execute permissions:
    ```bash
    command -v mpv >/dev/null 2>&1 || { echo "mpv not found. Installing mpv..."; sudo pacman -S --noconfirm mpv && echo "mpv installed successfully."; } && sudo chmod +x "$(command -v mpv)" || { echo "Failed to set execute permissions for mpv."; }
    ```

---

## Logging and Reporting

PermMaster maintains a detailed log of all actions performed, stored at `/var/log/perm_master.log`. This log is invaluable for auditing changes and troubleshooting issues.

- **Generating a Detailed Report:**
  
  - Select "Generate Detailed Report" (Option 12) from the menu.
  - The report will be saved in JSON format with a timestamped filename, e.g., `perm_master_report_20241127012345.json`.
  - **Location:** `/var/log/perm_master_report_YYYYMMDDHHMMSS.json`
  
  - **Usage Example:**
    ```bash
    sudo ./perm_master.sh
    ```
    Select Option `12` and follow the prompts to generate the report.

---

## Best Practices

- **Regular Snapshots:**
  
  - Create permission snapshots periodically, especially before making significant system changes or installing new software.

- **Backup Before Applying Changes:**
  
  - Always backup current permissions before applying a new snapshot to prevent unintended access issues.

- **Review Logs:**
  
  - Regularly inspect `/var/log/perm_master.log` to monitor actions and identify potential issues.

- **Test in a Controlled Environment:**
  
  - Before applying snapshots to critical systems, test the process in a virtual machine or non-production environment.

---

## Contributing

Contributions are welcome! If you have suggestions for improvements, encounter bugs, or wish to add new features, please follow these steps:

1. **Fork the Repository:**

   Click the "Fork" button at the top-right corner of the repository page.

2. **Create a Feature Branch:**

   ```bash
   git checkout -b feature/YourFeatureName
   ```

3. **Commit Your Changes:**

   ```bash
   git commit -m "Add Your Feature Description"
   ```

4. **Push to Your Fork:**

   ```bash
   git push origin feature/YourFeatureName
   ```

5. **Open a Pull Request:**

   Navigate to your forked repository on GitHub and click "Compare & pull request."

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments

- Inspired by the need for robust permission management tools on Arch Linux.
- Utilizes powerful utilities like `chmod`, `chown`, `find`, `getfacl`, and `setfacl` for effective permission handling.

---

*For any further assistance or inquiries, please contact the author at [andr0666@icloud.com](mailto:andr0666@icloud.com).*

```
