# Step-by-Step Instructions to Utilize the Permissions Management Script

Below are detailed instructions on how to set up and use the permissions management script tailored to your Arch Linux system, with your username `andro` and backup directory `/Nas/Backups/`.

---

## **Table of Contents**

1. [Prerequisites](#1-prerequisites)
2. [Create the Permissions Policy Configuration](#2-create-the-permissions-policy-configuration)
3. [Create the Permissions Management Script](#3-create-the-permissions-management-script)
4. [Adjust Script Variables](#4-adjust-script-variables)
5. [Make the Script Executable](#5-make-the-script-executable)
6. [Run the Script](#6-run-the-script)
7. [Set Up Regular Audits (Optional)](#7-set-up-regular-audits-optional)
8. [Additional Tips and Considerations](#8-additional-tips-and-considerations)

---

## **1. Prerequisites**

### **Install Necessary Dependencies**

The script requires the `yq` tool to parse YAML configuration files.

**Install `yq` on Arch Linux:**

Open a terminal and run:

```bash
sudo pacman -Syu yq
```

- `sudo`: Runs the command with superuser privileges.
- `pacman -Syu`: Synchronizes the package databases and updates the system.
- `yq`: YAML processor that the script uses to read the configuration file.

**Verify Installation:**

```bash
yq --version
```

---

## **2. Create the Permissions Policy Configuration**

Create the YAML configuration file that defines the desired permissions and ownerships.

**File Path:** `/etc/permissions_policy.yaml`

**Steps:**

1. **Create/Edit the Configuration File**

   Use your preferred text editor (`micro`, `vim`, etc.). Here, we'll use `micro`.

   ```bash
   sudo micro /etc/permissions_policy.yaml
   ```

   - `sudo`: Necessary to edit files in `/etc`.
   - `micro`: Simple command-line text editor.

2. **Add the Following Content:**

   Replace `youruser` with `andro` and adjust paths as needed.

   ```yaml
   # permissions_policy.yaml

   directories:
     - path: /etc
       owner: root
       group: root
       permissions: '755'
     - path: /var/log
       owner: root
       group: adm
       permissions: '750'
     - path: /home/andro
       owner: andro
       group: andro
       permissions: '750'
     - path: /home/andro/.ssh
       owner: andro
       group: andro
       permissions: '700'

   files:
     - path: /etc/passwd
       owner: root
       group: root
       permissions: '644'
     - path: /etc/shadow
       owner: root
       group: shadow
       permissions: '640'
     - path: /etc/sudoers
       owner: root
       group: root
       permissions: '440'
     - path: /home/andro/.ssh/authorized_keys
       owner: andro
       group: andro
       permissions: '600'
     - path: /home/andro/.bashrc
       owner: andro
       group: andro
       permissions: '644'
   ```

   **Notes:**

   - **Directories Section:**
     - Lists directories with their desired permissions.
     - Example: `/home/andro` should be owned by `andro:andro` with permissions `750`.

   - **Files Section:**
     - Lists files with their desired permissions.
     - Example: `/home/andro/.ssh/authorized_keys` should be `600`.

4. **Save and Exit:**

   - In `micro`, press `Ctrl+S` to save.
   - Press `Ctrl+Q` to exit.

---

## **3. Create the Permissions Management Script**

Create the script file that will manage permissions based on your configuration.

**File Path:** `/home/andro/permissions_manager.sh`

**Steps:**

1. **Navigate to Your Home Directory**

   ```bash
   cd /home/andro
   ```

2. **Create the Script File**

   ```bash
   micro permissions_manager.sh
   ```

3. **Paste the Script Content**

   Copy and paste the following script into the file:

   ```bash
   #!/usr/bin/env bash
   #
   # Permissions Management Script
   # Author: [Your Name]
   #
   # Description:
   # This script manages file and directory permissions and ownerships based on a policy
   # defined in a YAML configuration file. It can backup current permissions, audit them
   # against the policy, and fix discrepancies.

   set -euo pipefail

   # --- Configuration ---
   CONFIG_FILE="/etc/permissions_policy.yaml"     # Path to the permissions policy file
   LOG_FILE="/var/log/permissions_management.log" # Path to the log file
   BACKUP_DIR_BASE="/Nas/Backups/permissions"     # Base directory for backups

   # --- Logging Function ---
   log_action() {
       local level="$1"
       local message="$2"
       echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
   }

   # --- Load Permissions Policy ---
   load_policy() {
       if ! command -v yq >/dev/null 2>&1; then
           echo "Error: 'yq' is required to parse the YAML configuration."
           echo "Please install 'yq' and try again."
           exit 1
       fi

       if [[ ! -f "$CONFIG_FILE" ]]; then
           echo "Error: Configuration file '$CONFIG_FILE' not found."
           exit 1
       fi
   }

   # --- Backup Current Permissions ---
   backup_permissions() {
       local timestamp
       timestamp=$(date +%Y%m%d%H%M%S)
       local backup_dir="$BACKUP_DIR_BASE/$timestamp"
       mkdir -p "$backup_dir"

       # Backup permissions for all paths specified in the policy
       while IFS= read -r path; do
           if [[ -e "$path" ]]; then
               getfacl -R "$path" > "$backup_dir/$(echo "$path" | tr '/' '_').acl"
           else
               echo "Warning: $path does not exist. Skipping backup."
           fi
       done < <(yq e '.directories[].path, .files[].path' "$CONFIG_FILE")

       log_action "INFO" "Permissions backed up to $backup_dir"
       echo "Permissions backed up to $backup_dir"
   }

   # --- Audit Permissions ---
   audit_permissions() {
       local discrepancies=0

       # Audit permissions and ownerships for all paths specified in the policy
       while IFS= read -r path; do
           local type
           type=$(test -d "$path" && echo "directories" || echo "files")
           local desired_owner desired_group desired_perms

           desired_owner=$(yq e ".${type}[] | select(.path == \"$path\").owner" "$CONFIG_FILE")
           desired_group=$(yq e ".${type}[] | select(.path == \"$path\").group" "$CONFIG_FILE")
           desired_perms=$(yq e ".${type}[] | select(.path == \"$path\").permissions" "$CONFIG_FILE")

           if [[ -e "$path" ]]; then
               local current_owner current_group current_perms
               current_owner=$(stat -c '%U' "$path")
               current_group=$(stat -c '%G' "$path")
               current_perms=$(stat -c '%a' "$path")

               if [[ "$current_owner" != "$desired_owner" ]]; then
                   echo "Owner mismatch for $path: current=$current_owner, desired=$desired_owner"
                   discrepancies=$((discrepancies + 1))
               fi
               if [[ "$current_group" != "$desired_group" ]]; then
                   echo "Group mismatch for $path: current=$current_group, desired=$desired_group"
                   discrepancies=$((discrepancies + 1))
               fi
               if [[ "$current_perms" != "$desired_perms" ]]; then
                   echo "Permissions mismatch for $path: current=$current_perms, desired=$desired_perms"
                   discrepancies=$((discrepancies + 1))
               fi
           else
               echo "Warning: $path does not exist."
               discrepancies=$((discrepancies + 1))
           fi
       done < <(yq e '.directories[].path, .files[].path' "$CONFIG_FILE")

       if [[ "$discrepancies" -eq 0 ]]; then
           echo "All permissions and ownerships are as per the policy."
       else
           echo "Total discrepancies found: $discrepancies"
           log_action "WARNING" "$discrepancies discrepancies found during audit."
       fi
   }

   # --- Fix Permissions ---
   fix_permissions() {
       local changes=0

       # Fix permissions and ownerships for all paths specified in the policy
       while IFS= read -r path; do
           local type
           type=$(test -d "$path" && echo "directories" || echo "files")
           local desired_owner desired_group desired_perms

           desired_owner=$(yq e ".${type}[] | select(.path == \"$path\").owner" "$CONFIG_FILE")
           desired_group=$(yq e ".${type}[] | select(.path == \"$path\").group" "$CONFIG_FILE")
           desired_perms=$(yq e ".${type}[] | select(.path == \"$path\").permissions" "$CONFIG_FILE")

           if [[ -e "$path" ]]; then
               local current_owner current_group current_perms
               current_owner=$(stat -c '%U' "$path")
               current_group=$(stat -c '%G' "$path")
               current_perms=$(stat -c '%a' "$path")

               if [[ "$current_owner" != "$desired_owner" ]] || [[ "$current_group" != "$desired_group" ]]; then
                   chown "$desired_owner:$desired_group" "$path"
                   log_action "INFO" "Changed owner/group of $path to $desired_owner:$desired_group"
                   changes=$((changes + 1))
               fi
               if [[ "$current_perms" != "$desired_perms" ]]; then
                   chmod "$desired_perms" "$path"
                   log_action "INFO" "Changed permissions of $path to $desired_perms"
                   changes=$((changes + 1))
               fi
           else
               echo "Warning: $path does not exist."
           fi
       done < <(yq e '.directories[].path, .files[].path' "$CONFIG_FILE")

       if [[ "$changes" -eq 0 ]]; then
           echo "No changes were necessary. Permissions are already as per the policy."
       else
           echo "Total changes made: $changes"
           log_action "INFO" "Total changes made during fix: $changes"
       fi
   }

   # --- Main Function ---
   main() {
       if [[ "$EUID" -ne 0 ]]; then
           echo "This script must be run as root."
           exit 1
       fi

       if [[ $# -lt 1 ]]; then
           echo "Usage: $0 {backup|audit|fix}"
           exit 1
       fi

       load_policy

       case "$1" in
           backup)
               backup_permissions
               ;;
           audit)
               audit_permissions
               ;;
           fix)
               fix_permissions
               ;;
           *)
               echo "Invalid option: $1"
               echo "Usage: $0 {backup|audit|fix}"
               exit 1
               ;;
       esac
   }

   main "$@"
   ```

   **Notes:**

   - **Shebang Line:**
     - `#!/usr/bin/env bash` ensures the script uses the environment's Bash shell.

   - **Variables:**
     - `CONFIG_FILE`: Path to your permissions policy (`/etc/permissions_policy.yaml`).
     - `LOG_FILE`: Path to the log file (`/var/log/permissions_management.log`).
     - `BACKUP_DIR_BASE`: Base directory for backups (`/Nas/Backups/permissions`).

   - **Functions:**
     - `log_action()`: Logs actions with timestamps.
     - `load_policy()`: Checks for `yq` and the configuration file.
     - `backup_permissions()`: Backs up current permissions.
     - `audit_permissions()`: Audits current permissions against the policy.
     - `fix_permissions()`: Fixes permissions to match the policy.

   - **Main Function:**
     - Ensures the script is run as root.
     - Parses command-line arguments to determine which function to execute.

4. **Save and Exit:**

   - In `micro`, press `Ctrl+S` to save.
   - Press `Ctrl+Q` to exit.

---

## **4. Adjust Script Variables**

Ensure the script variables match your actual paths and values.

**Variables to Check:**

- **`CONFIG_FILE`**

  ```bash
  CONFIG_FILE="/etc/permissions_policy.yaml"
  ```

- **`LOG_FILE`**

  ```bash
  LOG_FILE="/var/log/permissions_management.log"
  ```

- **`BACKUP_DIR_BASE`**

  ```bash
  BACKUP_DIR_BASE="/Nas/Backups/permissions"
  ```

**Explanation:**

- **`CONFIG_FILE`**: Points to the configuration file you created.
- **`LOG_FILE`**: Path where the script will write logs.
- **`BACKUP_DIR_BASE`**: Base directory for storing backups.

**Ensure `/Nas/Backups/permissions` Exists:**

```bash
sudo mkdir -p /Nas/Backups/permissions
```

---

## **5. Make the Script Executable**

Set the appropriate permissions on the script so you can execute it.

**Command:**

```bash
chmod +x /home/andro/permissions_manager.sh
```

- `chmod +x`: Adds execute permission to the file.

---

## **6. Run the Script**

You can now use the script to backup, audit, or fix permissions.

### **6.1. Run a Backup**

**Command:**

```bash
sudo /home/andro/permissions_manager.sh backup
```

**Explanation:**

- **`sudo`**: The script must be run as root to access and modify system files.
- **`backup`**: Tells the script to perform a backup.

**Expected Output:**

```
Permissions backed up to /Nas/Backups/permissions/20231016123045
```

- The timestamp will reflect the current date and time.
- The backup files will be stored in the specified backup directory.

### **6.2. Audit Permissions**

**Command:**

```bash
sudo /home/andro/permissions_manager.sh audit
```

**Explanation:**

- **`audit`**: Tells the script to audit current permissions against the policy.

**Possible Output:**

```
Permissions mismatch for /home/andro: current=755, desired=750
Owner mismatch for /home/andro/.bashrc: current=root, desired=andro
Total discrepancies found: 2
```

**Notes:**

- The script reports any mismatches in permissions or ownerships.
- It logs discrepancies to `/var/log/permissions_management.log`.

### **6.3. Fix Permissions**

**Command:**

```bash
sudo /home/andro/permissions_manager.sh fix
```

**Explanation:**

- **`fix`**: Tells the script to apply the desired permissions and ownerships.

**Expected Output:**

```
Changed owner/group of /home/andro/.bashrc to andro:andro
Changed permissions of /home/andro to 750
Total changes made: 2
```

- The script applies the necessary changes to match the policy.

### **6.4. Verify Changes**

You can manually verify that the permissions and ownerships have been corrected.

**Command:**

```bash
stat -c "%A %a %U %G %n" /home/andro
stat -c "%A %a %U %G %n" /home/andro/.bashrc
```

**Expected Output:**

```
drwxr-x--- 750 andro andro /home/andro
-rw-r--r-- 644 andro andro /home/andro/.bashrc
```

- Permissions and ownerships should now match the policy.

---

## **7. Set Up Regular Audits (Optional)**

To ensure that permissions remain consistent over time, you can set up a cron job to run regular audits.

### **Edit Root's Crontab**

**Command:**

```bash
sudo crontab -e
```

- Opens the root user's crontab for editing.

### **Add the Following Line**

```cron
0 0 * * * /home/andro/permissions_manager.sh audit
```

- This schedules the audit to run daily at midnight.
- Adjust the timing as needed.

**Explanation of Cron Fields:**

- `0 0 * * *`: At minute 0, hour 0 (midnight), every day.
- `/home/andro/permissions_manager.sh audit`: Command to execute.

### **Save and Exit**

- In the editor, save the file to install the new cron job.

---

## **8. Additional Tips and Considerations**

### **8.1. Log File Permissions**

Ensure that the log file has appropriate permissions to prevent unauthorized access.

**Command:**

```bash
sudo touch /var/log/permissions_management.log
sudo chown root:root /var/log/permissions_management.log
sudo chmod 600 /var/log/permissions_management.log
```

- Sets ownership to `root:root` and permissions to `600` (read/write for owner only).

### **8.2. Backup Directory Permissions**

Ensure that the backup directory is secure.

**Command:**

```bash
sudo chown root:root /Nas/Backups/permissions
sudo chmod 700 /Nas/Backups/permissions
```

- Only `root` can access the backups.

### **8.3. Extending the Configuration**

Add more files or directories to the configuration as needed.

**Example:**

```yaml
- path: /usr/local/bin
  owner: root
  group: root
  permissions: '755'
```

### **8.4. Testing in a Safe Environment**

Before applying changes system-wide, consider testing the script on a non-critical system or using virtual machines.

### **8.5. Error Handling**

If you encounter errors, check the following:

- Ensure `yq` is installed and accessible.
- Verify paths in the configuration file.
- Check the script's syntax and permissions.

### **8.6. Updating the Script**

If you make changes to the script, remember to:

- Save the file.
- Ensure it remains executable:

  ```bash
  chmod +x /home/andro/permissions_manager.sh
  ```
