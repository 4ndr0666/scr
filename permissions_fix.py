import subprocess
import os

# Define the directories and their expected permissions and ownership
directories = [
    ("/4ndr0/home/TheCloud", "777", "root:root"),
    ("/home/Build", "755", "root:root"),
    ("/usr/lib/python3.10/site-packages", "755", "root:root"),
    ("/", "755", "root:root"),
    ("/bin/", "755", "root:root"),
    ("/boot/", "755", "root:root"),
    ("/dev/", "755", "root:root"),
    ("/etc/", "755", "root:root"),
    ("/home/", "755", "root:root"),
    ("/lib/", "755", "root:root"),
    ("/lib64/", "755", "root:root"),
    ("/opt/", "755", "root:root"),
    ("/proc/", "755", "root:root"),
    ("/root/", "700", "root:root"),
    ("/run/", "755", "root:root"),
    ("/sbin/", "755", "root:root"),
    ("/srv/", "755", "root:root"),
    ("/sys/", "755", "root:root"),
    ("/tmp/", "1777", "root:root"),
    ("/usr/", "755", "root:root"),
    ("/var/", "755", "root:root"),
]

# Loop through the directories
for directory, expected_permissions, expected_ownership in directories:
    # Get the current directory permissions
    process = subprocess.run(["stat", "-c", "%a", directory], capture_output=True, text=True)
    current_permissions = process.stdout.strip()

    if current_permissions:
        # Check if the permissions differ from the expected permissions
        if current_permissions != expected_permissions:
            # Set the expected permissions
            subprocess.run(["sudo", "chmod", expected_permissions, directory])
            print(f"Permissions fixed for directory: {directory}")
        else:
            print(f"No permission fix needed for directory: {directory}")
    else:
        print(f"Failed to retrieve permissions for directory: {directory}")

    # Get the current directory ownership
    process = subprocess.run(["stat", "-c", "%U:%G", directory], capture_output=True, text=True)
    current_ownership = process.stdout.strip()

    if current_ownership:
        # Check if the ownership differs from the expected ownership
        if current_ownership != expected_ownership:
            # Set the expected ownership
            subprocess.run(["sudo", "chown", expected_ownership, directory])
            print(f"Ownership fixed for directory: {directory}")
        else:
            print(f"No ownership fix needed for directory: {directory}")
    else:
        print(f"Failed to retrieve ownership for directory: {directory}")

print("Directory permissions and ownership check and fix complete.")
