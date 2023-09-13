#!/usr/bin/env python3
import os

def main():
    # Set the ownership and permissions for the sudo binary
    sudo_binary = "/usr/bin/sudo"
    os.chown(sudo_binary, 0, 0)  # UID 0, GID 0
    os.chmod(sudo_binary, 0o4111)  # Setuid bit with 755 permissions

if __name__ == "__main__":
    main()
