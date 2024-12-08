## **Approach**

### **Automatically Detecting Custom Paths**

To identify custom paths, the script will:

1. **Retrieve a list of all files and directories installed by packages** using the package database (`pacman`).

2. **Scan the entire filesystem** to find all existing files and directories.

3. **Compare the two lists** to identify files and directories that are present on the filesystem but not part of any installed package.

4. **Exclude standard directories** (like `/home`, `/opt`, `/usr/local`) that are known to contain custom content but are expected on a standard system.

5. **Include the detected custom paths** in the permissions policy.

---

## **Updated Script**

```bash
#!/usr/bin/env bash

# Permissions Management Script
# Author: [Your Name]
# Description:
# Automates the management of file and directory permissions and ownerships based on a policy.
# Automatically detects custom paths and integrates them into the permissions policy.

set -euo pipefail

# --- Configuration ---
CONFIG_FILE="/etc/permissions_policy.yaml"     # Path to the permissions policy file
LOG_FILE="/var/log/permissions_management.log" # Path to the log file
BACKUP_DIR_BASE="/Nas/Backups/permissions"     # Base directory for backups
CRON_JOB="@daily root $0 audit"                # Cron job entry

# --- Functions ---

# Install dependencies if not present
install_dependencies() {
    local dependencies=("yq" "pacutils" "findutils")
    local to_install=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            to_install+=("$dep")
        fi
    done

    if [ "${#to_install[@]}" -ne 0 ]; then
        echo "Installing dependencies: ${to_install[*]}"
        sudo pacman -Syu --noconfirm "${to_install[@]}"
    fi
}

# Create necessary directories and set permissions
setup_directories() {
    sudo mkdir -p "$BACKUP_DIR_BASE"
    sudo chown root:root "$BACKUP_DIR_BASE"
    sudo chmod 700 "$BACKUP_DIR_BASE"

    sudo touch "$LOG_FILE"
    sudo chown root:root "$LOG_FILE"
    sudo chmod 600 "$LOG_FILE"
}

# Setup cron job for regular audits
setup_cron() {
    if ! sudo crontab -l 2>/dev/null | grep -Fq "$0 audit"; then
        (sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
        echo "Cron job added for regular audits."
    else
        echo "Cron job already exists."
    fi
}

# Generate permissions policy from package metadata and include custom paths
generate_permissions_policy() {
    echo "Generating permissions policy..."
    local temp_policy="/tmp/permissions_policy.yaml"

    echo "directories:" > "$temp_policy"
    echo "files:" >> "$temp_policy"

    # Get list of files and directories installed by packages
    local package_paths
    package_paths=$(sudo pacman -Ql | awk '{print $2}' | sort -u)

    # Get list of all files and directories on the system
    local system_paths
    system_paths=$(find / -xdev -path /proc -prune -o -path /sys -prune -o -path /run -prune -o -path /dev -prune -o -type f -o -type d -print 2>/dev/null | sort -u)

    # Identify custom paths
    local custom_paths
    custom_paths=$(comm -23 <(echo "$system_paths") <(echo "$package_paths"))

    # Combine package paths and custom paths
    local all_paths
    all_paths=$(echo -e "$package_paths\n$custom_paths" | sort -u)

    # Process all paths to generate permissions policy
    while IFS= read -r path; do
        if [ -e "$path" ]; then
            local owner group perms
            owner=$(stat -c '%U' "$path")
            group=$(stat -c '%G' "$path")
            perms=$(stat -c '%a' "$path")
            path_escaped=$(printf '%q' "$path")

            if [ -d "$path" ]; then
                echo "  - path: \"$path_escaped\"" >> "$temp_policy"
                echo "    owner: \"$owner\"" >> "$temp_policy"
                echo "    group: \"$group\"" >> "$temp_policy"
                echo "    permissions: \"$perms\"" >> "$temp_policy"
            elif [ -f "$path" ]; then
                echo "  - path: \"$path_escaped\"" >> "$temp_policy"
                echo "    owner: \"$owner\"" >> "$temp_policy"
                echo "    group: \"$group\"" >> "$temp_policy"
                echo "    permissions: \"$perms\"" >> "$temp_policy"
            fi
        fi
    done <<< "$all_paths"

    # Move the temporary policy to the final location
    sudo mv "$temp_policy" "$CONFIG_FILE"
    sudo chown root:root "$CONFIG_FILE"
    sudo chmod 600 "$CONFIG_FILE"

    echo "Permissions policy generated at $CONFIG_FILE"
}

# Logging function
log_action() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Load permissions policy
load_policy() {
    if ! command -v yq >/dev/null 2>&1; then
        echo "Error: 'yq' is required to parse the YAML configuration."
        exit 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file '$CONFIG_FILE' not found."
        exit 1
    fi
}

# Backup current permissions
backup_permissions() {
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local backup_dir="$BACKUP_DIR_BASE/$timestamp"
    sudo mkdir -p "$backup_dir"

    yq e '.directories[].path, .files[].path' "$CONFIG_FILE" | while IFS= read -r path; do
        if [ -e "$path" ]; then
            sudo getfacl -pR "$path" > "$backup_dir/$(echo "$path" | tr '/' '_').acl"
        else
            echo "Warning: $path does not exist. Skipping backup."
        fi
    done

    log_action "INFO" "Permissions backed up to $backup_dir"
    echo "Permissions backed up to $backup_dir"
}

# Audit permissions
audit_permissions() {
    local discrepancies=0

    yq e '.directories[] | [.path, .owner, .group, .permissions] | @tsv' "$CONFIG_FILE" | while IFS=$'\t' read -r path owner group perms; do
        if [ -d "$path" ]; then
            local curr_owner curr_group curr_perms
            curr_owner=$(stat -c '%U' "$path")
            curr_group=$(stat -c '%G' "$path")
            curr_perms=$(stat -c '%a' "$path")

            if [ "$curr_owner" != "$owner" ] || [ "$curr_group" != "$group" ] || [ "$curr_perms" != "$perms" ]; then
                echo "Discrepancy found in $path"
                discrepancies=$((discrepancies + 1))
            fi
        else
            echo "Warning: Directory $path does not exist."
            discrepancies=$((discrepancies + 1))
        fi
    done

    yq e '.files[] | [.path, .owner, .group, .permissions] | @tsv' "$CONFIG_FILE" | while IFS=$'\t' read -r path owner group perms; do
        if [ -f "$path" ]; then
            local curr_owner curr_group curr_perms
            curr_owner=$(stat -c '%U' "$path")
            curr_group=$(stat -c '%G' "$path")
            curr_perms=$(stat -c '%a' "$path")

            if [ "$curr_owner" != "$owner" ] || [ "$curr_group" != "$group" ] || [ "$curr_perms" != "$perms" ]; then
                echo "Discrepancy found in $path"
                discrepancies=$((discrepancies + 1))
            fi
        else
            echo "Warning: File $path does not exist."
            discrepancies=$((discrepancies + 1))
        fi
    done

    if [ "$discrepancies" -eq 0 ]; then
        echo "All permissions and ownerships are as per the policy."
    else
        echo "Total discrepancies found: $discrepancies"
        log_action "WARNING" "$discrepancies discrepancies found during audit."
    fi
}

# Fix permissions
fix_permissions() {
    local changes=0

    yq e '.directories[] | [.path, .owner, .group, .permissions] | @tsv' "$CONFIG_FILE" | while IFS=$'\t' read -r path owner group perms; do
        if [ -d "$path" ]; then
            local curr_owner curr_group curr_perms
            curr_owner=$(stat -c '%U' "$path")
            curr_group=$(stat -c '%G' "$path")
            curr_perms=$(stat -c '%a' "$path")

            if [ "$curr_owner" != "$owner" ] || [ "$curr_group" != "$group" ]; then
                sudo chown "$owner:$group" "$path"
                log_action "INFO" "Changed owner/group of $path to $owner:$group"
                changes=$((changes + 1))
            fi
            if [ "$curr_perms" != "$perms" ]; then
                sudo chmod "$perms" "$path"
                log_action "INFO" "Changed permissions of $path to $perms"
                changes=$((changes + 1))
            fi
        else
            echo "Warning: Directory $path does not exist."
        fi
    done

    yq e '.files[] | [.path, .owner, .group, .permissions] | @tsv' "$CONFIG_FILE" | while IFS=$'\t' read -r path owner group perms; do
        if [ -f "$path" ]; then
            local curr_owner curr_group curr_perms
            curr_owner=$(stat -c '%U' "$path")
            curr_group=$(stat -c '%G' "$path")
            curr_perms=$(stat -c '%a' "$path")

            if [ "$curr_owner" != "$owner" ] || [ "$curr_group" != "$group" ]; then
                sudo chown "$owner:$group" "$path"
                log_action "INFO" "Changed owner/group of $path to $owner:$group"
                changes=$((changes + 1))
            fi
            if [ "$curr_perms" != "$perms" ]; then
                sudo chmod "$perms" "$path"
                log_action "INFO" "Changed permissions of $path to $perms"
                changes=$((changes + 1))
            fi
        else
            echo "Warning: File $path does not exist."
        fi
    done

    if [ "$changes" -eq 0 ]; then
        echo "No changes were necessary."
    else
        echo "Total changes made: $changes"
        log_action "INFO" "Total changes made during fix: $changes"
    fi
}

# Main function
main() {
    # Ensure the script is run as the user 'andro'
    if [ "$(whoami)" != "andro" ]; then
        echo "This script must be run as the user 'andro'."
        exit 1
    fi

    # Parse command-line arguments
    local action="${1:-}"

    case "$action" in
        setup)
            install_dependencies
            setup_directories
            setup_cron
            generate_permissions_policy
            ;;
        backup)
            load_policy
            backup_permissions
            ;;
        audit)
            load_policy
            audit_permissions
            ;;
        fix)
            load_policy
            fix_permissions
            ;;
        *)
            echo "Usage: $0 {setup|backup|audit|fix}"
            exit 1
            ;;
    esac
}

# --- Execution ---

main "$@"
```

---

## **Explanation of Changes**

### **1. Automatic Custom Paths Detection**

- **Comparison of Package Paths and System Paths:**

  - The script retrieves a list of all files and directories installed by packages using `pacman -Ql`.

    ```bash
    package_paths=$(sudo pacman -Ql | awk '{print $2}' | sort -u)
    ```

  - It scans the entire filesystem to get all existing files and directories using `find`.

    ```bash
    system_paths=$(find / -xdev -path /proc -prune -o -path /sys -prune -o -path /run -prune -o -path /dev -prune -o -type f -o -type d -print 2>/dev/null | sort -u)
    ```

  - Custom paths are identified by finding the difference between the system paths and package paths.

    ```bash
    custom_paths=$(comm -23 <(echo "$system_paths") <(echo "$package_paths"))
    ```

- **Excluding Standard Directories:**

  - The script excludes special directories like `/proc`, `/sys`, `/run`, and `/dev` to avoid unnecessary entries and errors.

- **Combining All Paths:**

  - Both package-installed paths and custom paths are combined to create the complete permissions policy.

    ```bash
    all_paths=$(echo -e "$package_paths\n$custom_paths" | sort -u)
    ```

### **2. Eliminating the Need for `custom_paths.txt`**

- The script no longer requires manual input of custom paths.

- It intelligently detects custom paths automatically, as per your request.

### **3. Dependency on `findutils`**

- Added `findutils` to the list of dependencies to ensure the `find` command is available.

    ```bash
    local dependencies=("yq" "pacutils" "findutils")
    ```

### **4. Minor Improvements**

- **Error Handling:**

  - Suppressed `crontab -l` errors when the crontab is empty.

    ```bash
    if ! sudo crontab -l 2>/dev/null | grep -Fq "$0 audit"; then
    ```

- **Permissions and Ownership Retrieval:**

  - Used `stat` to retrieve current permissions and ownerships.

- **Logging Enhancements:**

  - Improved log messages for clarity.

---

## **Instructions**

### **1. Save and Make the Script Executable**

- **File Path:** `/home/andro/permissions_manager.sh`

```bash
nano /home/andro/permissions_manager.sh
```

- Paste the updated script content into the file.

- Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

- Make the script executable:

```bash
chmod +x /home/andro/permissions_manager.sh
```

### **2. Run the Script with 'setup' Action**

- The 'setup' action installs dependencies, sets up directories, configures cron, and generates the permissions policy.

```bash
./permissions_manager.sh setup
```

- **Notes:**

  - The script must be run as your user (`andro`), not as root.
  - It uses `sudo` internally where root privileges are required.

### **3. Verify the Permissions Policy**

- **File Path:** `/etc/permissions_policy.yaml`

- **Check that Custom Paths Are Included:**

  ```bash
  sudo nano /etc/permissions_policy.yaml
  ```

- The policy should include all files and directories on your system, including custom paths like `/home/andro`, `/opt`, etc.

### **4. Run 'backup', 'audit', and 'fix' Actions as Needed**

- **Backup Current Permissions:**

  ```bash
  ./permissions_manager.sh backup
  ```

- **Audit Permissions:**

  ```bash
  ./permissions_manager.sh audit
  ```

- **Fix Permissions:**

  ```bash
  ./permissions_manager.sh fix
  ```

### **5. Verify Cron Job for Regular Audits**

- The 'setup' action configures a daily cron job for auditing.

- **Check Cron Job:**

  ```bash
  sudo crontab -l
  ```

- You should see an entry similar to:

  ```cron
  @daily root /home/andro/permissions_manager.sh audit
  ```

### **6. Review the Log File**

- **File Path:** `/var/log/permissions_management.log`

- **Check for Any Errors or Warnings:**

  ```bash
  sudo cat /var/log/permissions_management.log
  ```

---

## **Addressing Your Concerns**

- **Fully Automated Custom Paths Detection:**

  - The script now automatically detects custom files and directories without any manual input or intervention.

- **Intelligent Comparison:**

  - By comparing the current filesystem with the package database, the script identifies all custom paths, ensuring comprehensive coverage.

- **Minimizing User Input:**

  - No need to populate a `custom_paths.txt` file; the script handles everything.

---

## **Considerations**

### **Performance Impact**

- **First Run May Be Slow:**

  - Scanning the entire filesystem and comparing paths can be time-consuming, especially on systems with large amounts of data.

- **Subsequent Runs:**

  - The 'audit' and 'fix' actions should be faster as they process the already generated permissions policy.

### **Potential Overhead**

- **Large Permissions Policy:**

  - The generated `permissions_policy.yaml` may be large due to the inclusion of all system paths.

- **Alternative Approach:**

  - If performance becomes an issue, consider limiting the scope to certain directories (e.g., `/home`, `/opt`, `/usr/local`).

### **Security Implications**

- **Sensitive Directories:**

  - Be cautious when modifying permissions and ownerships on system directories.

- **Testing:**

  - It's recommended to test the script in a controlled environment before deploying it on production systems.

---

## **Customization**

If you wish to limit the paths processed by the script or exclude certain directories, you can modify the `find` command in the `generate_permissions_policy` function.

**Example: Exclude `/mnt` and `/media`:**

```bash
system_paths=$(find / -xdev \
    -path /proc -prune -o \
    -path /sys -prune -o \
    -path /run -prune -o \
    -path /dev -prune -o \
    -path /mnt -prune -o \
    -path /media -prune -o \
    -type f -o -type d -print 2>/dev/null | sort -u)
```
