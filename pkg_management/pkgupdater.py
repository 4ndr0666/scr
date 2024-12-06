#!/usr/bin/env python3

import subprocess
from datetime import datetime, timedelta
import sys
import concurrent.futures

# Number of days to consider packages outdated
if len(sys.argv) < 2:
    print("Please provide the number of days as a command-line argument.")
    sys.exit(1)

try:
    outdated_days = int(sys.argv[1])
except ValueError:
    print("Invalid number of days. Please provide an integer value.")
    sys.exit(1)

# Run Pacman to check for updates
update_info = subprocess.check_output(["pacman", "-Qu"])

# Extract package names from the update info
package_names = []
for line in update_info.decode().split('\n'):
    if line.strip():
        package_name = line.split()[0]
        package_names.append(package_name)

# Create a list to store outdated packages
outdated_packages = []

# Function to check build date for a package
def check_package(package_name):
    try:
        build_date_info = subprocess.check_output(["pacman", "-Si", package_name])
        for line in build_date_info.decode().split('\n'):
            if line.startswith("Build Date"):
                build_date_str = line.split(':', 1)[1].strip()
                build_date = datetime.strptime(build_date_str, "%a %d %b %Y %H:%M:%S %Z")
                if datetime.now() - build_date > timedelta(days=outdated_days):
                    return package_name
    except subprocess.CalledProcessError:
        pass

# Use multithreading to check build date for each package
with concurrent.futures.ThreadPoolExecutor() as executor:
    results = executor.map(check_package, package_names)
    outdated_packages = [package for package in results if package is not None]

if not outdated_packages:
    print("No updates found.")
    sys.exit()

# Print the list of packages to be updated
print("Packages to be updated:")
for package in outdated_packages:
    print(package)

# Prompt for confirmation before updating
confirmation = input("Do you want to update the packages? (y/n): ")
if confirmation.lower() != "y":
    print("Update cancelled.")
    sys.exit()

# Create and run the update query
if outdated_packages:
    update_query = ["sudo", "pacman", "-Sy"]
    update_query.extend(outdated_packages)
    subprocess.run(update_query)
    print("Packages updated successfully.")
else:
    print("No outdated packages found.")
