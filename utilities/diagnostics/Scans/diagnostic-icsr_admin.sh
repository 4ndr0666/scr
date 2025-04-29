#!/bin/bash

# Update package lists and upgrade all upgradable packages
sudo pacman -Syu --noconfirm

# Fix broken systemd services links by reinstalling related packages.
systemctl list-unit-files | grep enabled | awk '{print $1}' > /tmp/enabled_services.txt
while read service; do systemctl disable "$service"; done < /tmp/enabled_services.txt # Disable all services
temporarily.
while read service; do systemctl enable "$service"; done < /tmp/enabled_services.txt # Enable them again which
should fix any broken symbolic links.

rm /tmp/enabled_services.txt # Remove temporary file used for storing enabled services names.

echo "Cleaning pacman cache..."
paccache -r    # Removes cached versions except three most recent ones per package (-r flag)
paccache -ruk0 # Removes all cached versions of uninstalled packages (-u flag) and keep none (-k0)

echo "Checking for orphaned packages..."
orphans=$(pacman -Qdtq)
if [ -z "$orphans" ]; then
    echo "No orphans to remove."
else
    sudo pacman -Rns $orphans
fi

echo "System health check-up..."
df -h /        # Check disk space usage on root partition.
free -m        # Check free memory in MB.

# Checking for failed systemd services
failed_services=$(systemctl --state=failed)
if [[ !  $failed_services ]]; then
   echo 'All Systemd Services are running fine'
else
   systemctl --state=failed
fi

echo "All tasks completed successfully."

# List installed packages sorted by installation size:
echo "Listing installed packages sorted by install size..."
pacman -Qi | awk '/^Name/{name=$3} /^Installed Size/{print $4,$5,name}' | sort -hr > /tmp/package_sizes.txt
cat /tmp/package_sizes.txt # Display the list
rm /tmp/package_sizes.txt  # Remove temporary file

# Check if any user accounts have no password set:
echo "Checking for users without passwords..."
awk -F: '($2 == "") {print}' /etc/shadow > /tmp/unsecured_users.txt
if [ ! -s "/tmp/unsecured_users.txt" ]; then echo "No unsecured users."; else cat "/tmp/unsecured_users.txt"; fi
rm "/tmp/unsecured_users.txt"

# Find largest directories/files within root directory (/):
echo "Finding large directories/files within root directory..."
du --threshold=1G / | sort -hr > /tmp/large_dirs.txt
cat "/tmp/large_dirs.txt"
rm "/tmp/large_dirs.txt"

# List all systemd services sorted by startup time:
echo "Listing systemd services sorted by startup time..."
systemd-analyze blame | awk '{print $1,$2}' | sort -h > /tmp/service_startup_times.txt
cat "/tmp/service_startup_times.txt"
rm "/tmp/service_startup_times.txt"

# Define desired permissions and owners for each directory/file.
declare -A perm_map=(
    ["/etc"]='755:root:root'
    ["/var/log"]='700:syslog:adm'
)

for dir in "${!perm_map[@]}"; do
  if [[ -d "$dir" ]]; then
      IFS=":" read -r perm user group <<< ${perm_map[$dir]}

      current_perm=$(stat -c '%a' $dir)
      current_user=$(stat -c '%U' $dir)
      current_group=$(stat -c '%G' $dir)

     # Check permission
     if [[ "$current_perm" != "$perm" ]]; then
          chmod $perm $dir

          echo "Permissions of '$directory have been changed to '$perms'"
       else
           echo "Permissions of '$directory are already set correctly."
       fi

     # Check owner
     if [[ "$current_user" != "$user"]] || [["$current_group" !=  "$group"]] ; then
         chown ${user}:${group} ${directory}

         echo "Ownership of '${directory}' has been changed to '${user}:${group}'."

        else
            echo "'$directory does not exist on your system.'"
        fi
   fi
done;
