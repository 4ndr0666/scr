## **Permissions Management Script**

```bash
#!/usr/bin/env bash

# Permissions Management Script
# Author: [Your Name]
# Description:
# This script automates the management of file and directory permissions and ownerships based on a policy.
# It includes dependency installation, policy generation (including custom paths), backups, audits, fixes, and cron setup.

set -euo pipefail

# --- Configuration ---
CONFIG_FILE="/etc/permissions_policy.yaml"     # Path to the permissions policy file
LOG_FILE="/var/log/permissions_management.log" # Path to the log file
BACKUP_DIR_BASE="/Nas/Backups/permissions"     # Base directory for backups
CRON_JOB="@daily root $0 audit"                # Cron job entry
CUSTOM_PATHS_FILE="/etc/custom_paths.txt"      # File containing custom paths

# --- Functions ---

# Install dependencies if not present
install_dependencies() {
    local dependencies=("yq" "pacutils")
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
    if ! sudo crontab -l | grep -Fq "$0 audit"; then
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

    # Extract default permissions from package metadata
    sudo pacman -Qql | while read -r path; do
        if [ -e "$path" ]; then
            local owner group perms
            owner=$(stat -c '%U' "$path")
            group=$(stat -c '%G' "$path")
            perms=$(stat -c '%a' "$path")
            path=$(printf '%q' "$path")

            if [ -d "$path" ]; then
                echo "  - path: \"$path\"" >> "$temp_policy"
                echo "    owner: \"$owner\"" >> "$temp_policy"
                echo "    group: \"$group\"" >> "$temp_policy"
                echo "    permissions: \"$perms\"" >> "$temp_policy"
            elif [ -f "$path" ]; then
                echo "  - path: \"$path\"" >> "$temp_policy"
                echo "    owner: \"$owner\"" >> "$temp_policy"
                echo "    group: \"$group\"" >> "$temp_policy"
                echo "    permissions: \"$perms\"" >> "$temp_policy"
            fi
        fi
    done

    # Include custom paths
    if [ -f "$CUSTOM_PATHS_FILE" ]; then
        echo "Including custom paths..."
        while IFS= read -r custom_path; do
            if [ -e "$custom_path" ]; then
                local owner group perms
                owner=$(stat -c '%U' "$custom_path")
                group=$(stat -c '%G' "$custom_path")
                perms=$(stat -c '%a' "$custom_path")
                custom_path=$(printf '%q' "$custom_path")

                if [ -d "$custom_path" ]; then
                    echo "  - path: \"$custom_path\"" >> "$temp_policy"
                    echo "    owner: \"$owner\"" >> "$temp_policy"
                    echo "    group: \"$group\"" >> "$temp_policy"
                    echo "    permissions: \"$perms\"" >> "$temp_policy"
                elif [ -f "$custom_path" ]; then
                    echo "  - path: \"$custom_path\"" >> "$temp_policy"
                    echo "    owner: \"$owner\"" >> "$temp_policy"
                    echo "    group: \"$group\"" >> "$temp_policy"
                    echo "    permissions: \"$perms\"" >> "$temp_policy"
                fi
            else
                echo "Warning: Custom path $custom_path does not exist."
            fi
        done < "$CUSTOM_PATHS_FILE"
    else
        echo "No custom paths file found at $CUSTOM_PATHS_FILE."
    fi

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

## **Instructions and Explanation**

### **1. Save the Script**

- **File Path:** `/home/andro/permissions_manager.sh`

```bash
micro /home/andro/permissions_manager.sh
```

- Paste the script content into the file.

- Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

### **2. Make the Script Executable**

```bash
chmod +x /home/andro/permissions_manager.sh
```

### **3. Prepare the Custom Paths File**

- **File Path:** `/etc/custom_paths.txt`

- **Purpose:** Contains a list of your custom paths (directories and files) to be included in the permissions policy.

- **Example Content:**

```plaintext
/home/andro
/opt
```

- **Populate with Your Actual Paths:**

  - From your provided directory listings, include paths such as:

    - `/home/andro`
    - `/home/andro/.config`
    - `/home/andro/Documents`
    - `/opt`

- **Create and Edit the File:**

```bash
sudo micro /etc/custom_paths.txt
```

- **Paste Your Custom Paths:**

  - Add one path per line.

- **Save and Exit (`Ctrl+O`, `Enter`, `Ctrl+X`).**

### **4. Run the Script with 'setup' Action**

- This action installs dependencies, sets up directories, configures cron, and generates the permissions policy.

```bash
./permissions_manager.sh setup
```

- **Notes:**

  - The script must be run as your user (`andro`), not as root.
  - It uses `sudo` internally where root privileges are required.

### **5. Verify the Permissions Policy**

- **File Path:** `/etc/permissions_policy.yaml`

- **Check that Your Custom Paths Are Included:**

```bash
sudo micro /etc/permissions_policy.yaml
```

- Search for your custom paths to ensure they are present with correct ownerships and permissions.

### **6. Run 'backup', 'audit', and 'fix' Actions as Needed**

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

### **7. Set Up Cron Job for Regular Audits**

- The `setup` action already configures a daily cron job for auditing.

- **Verify Cron Job:**

```bash
sudo crontab -l
```

- You should see an entry similar to:

```cron
@daily root /home/andro/permissions_manager.sh audit
```

### **8. Review the Log File**

- **File Path:** `/var/log/permissions_management.log`

- **Check for Any Errors or Warnings:**

```bash
sudo cat /var/log/permissions_management.log
```

---

## **Script Explanation**

### **Key Features**

- **Self-Contained:** The script automates all steps, including dependency installation and setup tasks.

- **Custom Paths Inclusion:** Automatically includes your custom directories and files by reading from `/etc/custom_paths.txt`.

- **Minimal User Intervention:** Once the custom paths file is populated, the script handles everything else.

- **Safety Checks:** Ensures it's run by the correct user and handles errors gracefully.

- **Logging:** Actions are logged to `/var/log/permissions_management.log` for auditing.

- **Idempotency:** Running the script multiple times doesn't cause issues; it only makes necessary changes.

### **Main Functions**

1. **`install_dependencies`:**

   - Installs `yq` and `pacutils` if they're not already installed.

2. **`setup_directories`:**

   - Creates the backup directory and log file with appropriate permissions.

3. **`setup_cron`:**

   - Adds a cron job for daily audits if it doesn't already exist.

4. **`generate_permissions_policy`:**

   - Generates the permissions policy by scanning package-installed files and your custom paths.
   - Gathers ownership and permissions using `stat`.
   - Writes the policy to `/etc/permissions_policy.yaml`.

5. **`backup_permissions`:**

   - Creates backups of current permissions using `getfacl`.

6. **`audit_permissions`:**

   - Compares current permissions and ownerships against the policy.
   - Reports discrepancies.

7. **`fix_permissions`:**

   - Adjusts permissions and ownerships to match the policy.

### **Usage**

- **`setup`:**

  - Run this first to set up the environment and generate the policy.

- **`backup`:**

  - Use to backup current permissions.

- **`audit`:**

  - Use to check for discrepancies.

- **`fix`:**

  - Use to correct permissions and ownerships.

---

## **Addressing Your Points**

### **Automating Setup Steps**

- **Dependency Installation:**

  - The script checks for required dependencies (`yq`, `pacutils`) and installs them if missing.

- **Directory Creation and Permission Setting:**

  - Creates and sets permissions for backup directory and log file.

- **Cron Job Setup:**

  - Automatically adds a cron job for regular audits.

- **Permissions Policy Security:**

  - Sets secure permissions on `/etc/permissions_policy.yaml`.

### **Including Custom Paths**

- **Custom Paths File:**

  - Use `/etc/custom_paths.txt` to list all your custom directories and files.

- **Automation:**

  - The script reads this file and includes the paths in the policy automatically.

- **No Manual Intervention Required After Initial Setup**

  - Once you list your custom paths, the script handles the rest.

### **Handling Complex Directory Structures**

- The script is designed to handle any paths you provide, regardless of complexity.

- It scans each path, gathers the current ownership and permissions, and includes them in the policy.

---

## **Next Steps for You**

1. **Populate `/etc/custom_paths.txt` with All Custom Paths**

   - Include directories like `/home/andro` and `/opt`, as well as any subdirectories or specific files you want to manage.

   - Example:

     ```plaintext
     /home/andro
     /home/andro/.config
     /home/andro/Documents
     /opt
     /opt/4ndr0update
     /opt/JDownloader
     ```

2. **Run the Script with 'setup' Again**

   - This will regenerate the permissions policy including your custom paths.

   ```bash
   ./permissions_manager.sh setup
   ```

3. **Review and Confirm**

   - Check the generated policy file to ensure all your custom paths are included.

   - Run an audit to see if there are any discrepancies.

4. **Monitor Logs and Outputs**

   - Regularly check the log file and cron job outputs to stay informed about your system's permissions state.
