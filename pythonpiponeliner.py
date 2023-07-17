import subprocess

# Get the list of outdated packages
outdated_packages = subprocess.check_output(['python3', '-m', 'pip', 'list', 'outdated'],
stderr=subprocess.DEVNULL).decode().splitlines()

# Upgrade each package individually
for package in outdated_packages:
    package_name = package.split()[0]
    subprocess.call(['python3', '-m', 'pip', 'install', '--break-system-packages', '-U', package_name])
