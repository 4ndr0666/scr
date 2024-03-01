#!/usr/bin/env python3

import os
import sys
import subprocess

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <application-name>")
        sys.exit(1)

    app_name = sys.argv[1]

    # Run the application with GDK_BACKEND=x11
    try:
        env = os.environ.copy()
        env["GDK_BACKEND"] = "x11"
        subprocess.run([app_name], env=env, check=True)
    except subprocess.CalledProcessError:
        # If the previous command fails, try running with QT_QPA_PLATFORM=xcb
        try:
            env["QT_QPA_PLATFORM"] = "xcb"
            subprocess.run([app_name], env=env, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Failed to run the application {app_name} with both GDK_BACKEND=x11 and QT_QPA_PLATFORM=xcb.")
            sys.exit(e.returncode)

if __name__ == "__main__":
    main()

