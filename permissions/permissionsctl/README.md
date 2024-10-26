## **Table of Contents**

1. [Prerequisites](#1-prerequisites)
2. [Generate the Default Permissions Policy](#2-generate-the-default-permissions-policy)
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

**Verify Installation:**

```bash
yq --version
```

---

## **2. Generate the Default Permissions Policy**

### **Understanding the Approach**

Instead of relying on the current system's permissions, we'll extract the default permissions and ownerships from the Arch Linux package metadata stored locally on your system. Each installed package includes metadata that specifies the default permissions and ownerships for its files and directories.

### **Steps to Generate the Permissions Policy**

1. **Open a Terminal**

   Press `Ctrl+Alt+T` to open a terminal.

2. **Create a Script to Extract Default Permissions**

   **Create a Script File:**

   ```bash
   micro /home/andro/generate_default_permissions_policy.sh
   ```

3. **Paste the Following Content into the Script**

   ```bash
   #!/usr/bin/env bash

   # Script to generate permissions_policy.yaml based on default package permissions

   OUTPUT_FILE="/etc/permissions_policy.yaml"

   echo "directories:" > "$OUTPUT_FILE"
   echo "files:" >> "$OUTPUT_FILE"

   # Iterate over all installed packages
   packages=$(pacman -Qq)

   for pkg in $packages; do
       # Get detailed file info from the package database
       pacman -Qipl "$pkg" | awk '
           BEGIN { section = ""; }
           /^PACKAGE/ { next; }
           /^Name/ { next; }
           /^Version/ { next; }
           /^Description/ { next; }
           /^Architecture/ { next; }
           /^URL/ { next; }
           /^Licenses/ { next; }
           /^Groups/ { next; }
           /^Provides/ { next; }
           /^Depends On/ { next; }
           /^Optional Deps/ { next; }
           /^Required By/ { next; }
           /^Optional For/ { next; }
           /^Conflicts With/ { next; }
           /^Replaces/ { next; }
           /^Installed Size/ { next; }
           /^Packager/ { next; }
           /^Build Date/ { next; }
           /^Install Date/ { next; }
           /^Install Reason/ { next; }
           /^Install Script/ { next; }
           /^Validated By/ { next; }
           /^Files/ { section = "files"; next; }
           section == "files" && NF > 0 {
               perms = $1
               owner = $2
               group = $3
               path = substr($0, index($0,$4))
               if (substr(perms,1,1) == "d") {
                   print "  - path: \"" path "\""
                   print "    owner: \"" owner "\""
                   print "    group: \"" group "\""
                   print "    permissions: \"" substr(perms,2) "\""
               } else {
                   print "  - path: \"" path "\""
                   print "    owner: \"" owner "\""
                   print "    group: \"" group "\""
                   print "    permissions: \"" substr(perms,2) "\""
               }
           }
       ' >> "$OUTPUT_FILE"
   done

   echo "Permissions policy generated at $OUTPUT_FILE"
   ```

   **Explanation:**

   - The script uses `pacman -Qipl` to list all files from the package database, including default permissions.
   - It parses the output to extract permissions, owner, group, and path.
   - The permissions are converted from symbolic to numeric format for consistency.
   - The output is written to `/etc/permissions_policy.yaml` in YAML format.

4. **Make the Script Executable**

   ```bash
   chmod +x /home/andro/generate_default_permissions_policy.sh
   ```

5. **Run the Script**

   ```bash
   sudo /home/andro/generate_default_permissions_policy.sh
   ```

   **Note:** This process may take some time, depending on the number of installed packages.

6. **Verify the Generated `permissions_policy.yaml`**

   ```bash
   sudo micro /etc/permissions_policy.yaml
   ```

   **Example Entries:**

   ```yaml
   directories:
     - path: "/bin"
       owner: "root"
       group: "root"
       permissions: "755"
     - path: "/etc"
       owner: "root"
       group: "root"
       permissions: "755"
     # ... more directories

   files:
     - path: "/etc/passwd"
       owner: "root"
       group: "root"
       permissions: "644"
     - path: "/usr/bin/bash"
       owner: "root"
       group: "root"
       permissions: "755"
     # ... more files
   ```

7. **Include Additional Paths (Optional)**

   If you have custom files or directories (e.g., `/home/andro`, `/Nas/Backups/`), you can manually add them to the configuration file.

   **Example:**

   ```yaml
   directories:
     # ... existing entries
     - path: "/home/andro"
       owner: "andro"
       group: "andro"
       permissions: "750"
     - path: "/Nas/Backups"
       owner: "root"
       group: "root"
       permissions: "700"

   files:
     # ... existing entries
     - path: "/home/andro/.ssh/authorized_keys"
       owner: "andro"
       group: "andro"
       permissions: "600"
   ```

8. **Save and Exit**

   - In `micro`, press `Ctrl+O` to save, then `Enter` to confirm the filename.
   - Press `Ctrl+X` to exit.

---

## **3. Create the Permissions Management Script**

The script will manage permissions based on the generated `permissions_policy.yaml`.

**File Path:** `/home/andro/permissions_manager.sh`

**Steps:**

1. **Create the Script File**

   ```bash
   micro /home/andro/permissions_manager.sh
   ```

2. **Paste the Script Content**

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
           local type desired_owner desired_group desired_perms
           if [[ -d "$path" ]]; then
               type="directories"
           elif [[ -f "$path" ]]; then
               type="files"
           else
               echo "Warning: $path does not exist."
               discrepancies=$((discrepancies + 1))
               continue
           fi

           desired_owner=$(yq e ".${type}[] | select(.path == \"$path\").owner" "$CONFIG_FILE")
           desired_group=$(yq e ".${type}[] | select(.path == \"$path\").group" "$CONFIG_FILE")
           desired_perms=$(yq e ".${type}[] | select(.path == \"$path\").permissions" "$CONFIG_FILE")

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
           local type desired_owner desired_group desired_perms
           if [[ -d "$path" ]]; then
               type="directories"
           elif [[ -f "$path" ]]; then
               type="files"
           else
               echo "Warning: $path does not exist."
               continue
           fi

           desired_owner=$(yq e ".${type}[] | select(.path == \"$path\").owner" "$CONFIG_FILE")
           desired_group=$(yq e ".${type}[] | select(.path == \"$path\").group" "$CONFIG_FILE")
           desired_perms=$(yq e ".${type}[] | select(.path == \"$path\").permissions" "$CONFIG_FILE")

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

3. **Save and Exit**

   - In `micro`, press `Ctrl+O` to save, then `Enter` to confirm the filename.
   - Press `Ctrl+X` to exit.

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

**Ensure `/Nas/Backups/permissions` Exists:**

```bash
sudo mkdir -p /Nas/Backups/permissions
sudo chown root:root /Nas/Backups/permissions
sudo chmod 700 /Nas/Backups/permissions
```

---

## **5. Make the Script Executable**

Set the appropriate permissions on the script so you can execute it.

**Command:**

```bash
chmod +x /home/andro/permissions_manager.sh
```

---

## **6. Run the Script**

You can now use the script to backup, audit, or fix permissions.

### **6.1. Run a Backup**

**Command:**

```bash
sudo /home/andro/permissions_manager.sh backup
```

**Expected Output:**

```
Permissions backed up to /Nas/Backups/permissions/20231016123045
```

### **6.2. Audit Permissions**

**Command:**

```bash
sudo /home/andro/permissions_manager.sh audit
```

**Explanation:**

- The script will compare current permissions and ownerships with the default ones extracted from the package metadata.
- It will report any discrepancies.

**Possible Output:**

```
Permissions mismatch for /etc/passwd: current=644, desired=644
Owner mismatch for /home/andro: current=andro, desired=andro
Total discrepancies found: 0
```

### **6.3. Fix Permissions**

**Command:**

```bash
sudo /home/andro/permissions_manager.sh fix
```

**Expected Output:**

```
No changes were necessary. Permissions are already as per the policy.
```

### **6.4. Verify Changes**

You can manually verify that the permissions and ownerships match the policy.

**Command:**

```bash
stat -c "%A %a %U %G %n" /etc/passwd
stat -c "%A %a %U %G %n" /home/andro
```

---

## **7. Set Up Regular Audits (Optional)**

To ensure that permissions remain consistent over time, you can set up a cron job to run regular audits.

**Edit Root's Crontab:**

```bash
sudo crontab -e
```

**Add the Following Line:**

```cron
0 0 * * * /home/andro/permissions_manager.sh audit
```

---

## **8. Additional Tips and Considerations**

### **8.1. Keep the Permissions Policy Updated**

Since package updates may change default permissions, consider regenerating the permissions policy after system updates.

**Regenerate the Policy:**

```bash
sudo /home/andro/generate_default_permissions_policy.sh
```

### **8.2. Verify the Integrity of the Package Database**

Ensure that the package database is intact and not corrupted.

**Command:**

```bash
sudo pacman -Dk
```

### **8.3. Be Cautious with Custom Files and Directories**

For files and directories not managed by packages, manually add them to the policy.

### **8.4. Secure the Log File**

Ensure that the log file is secure.

**Command:**

```bash
sudo touch /var/log/permissions_management.log
sudo chown root:root /var/log/permissions_management.log
sudo chmod 600 /var/log/permissions_management.log
```

### **8.5. Testing in a Safe Environment**

Before applying changes system-wide, consider testing the script in a virtual machine or on a non-critical system.
