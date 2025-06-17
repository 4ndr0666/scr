#!/usr/bin/env python3
import os
import sys
import subprocess


def is_root():
    return os.geteuid() == 0


def main():
    sudo_binary = "/usr/bin/sudo"

    # Check if sudo binary exists
    if not os.path.isfile(sudo_binary):
        print(f"Error: {sudo_binary} not found.")
        return

    try:
        # Set the ownership to root (UID 0, GID 0)
        os.chown(sudo_binary, 0, 0)
        # Set permissions to setuid bit with 755
        os.chmod(sudo_binary, 0o4755)
        print(f"Successfully updated {sudo_binary} permissions and ownership.")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    if not is_root():
        try:
            # Attempt to restart the script with sudo
            subprocess.check_call(["sudo", sys.executable] + sys.argv)
        except subprocess.CalledProcessError as e:
            print(f"Script failed to restart with sudo: {e}")
    else:
        main()
