#!/usr/bin/env python3
"""
integration.py

Provides supporting functions:
  1. open_in_browser: open enumerated URLs in a web browser tab-by-tab
  2. download_with_aria2: download enumerated URLs using aria2
  3. store_urls: store enumerated URLs in a text file with idempotent approach

Dependencies:
    - enumerator.py (relative import)
    - webbrowser (built-in)
    - subprocess, os, tempfile, time
"""

import os
import subprocess
import webbrowser
import tempfile
import time


def open_in_browser(url_list):
    """
    Open each URL in a new browser tab.
    """
    for url in url_list:
        webbrowser.open_new_tab(url)


def download_with_aria2(url_list, out_dir):
    """
    Leverage aria2 to download enumerated URLs.
    Writes URLs to a temporary file, calls aria2c with -i <file>.
    """
    if not url_list:
        print("No URLs to download.")
        return

    # Create out_dir if not exist
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    # Create a temporary text file containing the URLs
    tmpfile = os.path.join(tempfile.gettempdir(), f"aria2_input_{int(time.time())}.txt")
    try:
        with open(tmpfile, 'w', encoding='utf-8') as f:
            for url in url_list:
                f.write(url + "\n")

        # Run aria2
        cmd = ["aria2c", "-d", out_dir, "-i", tmpfile]
        print(f"Running aria2c. Download directory: {out_dir}")
        print(f"Command: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)

    except subprocess.CalledProcessError as err:
        print(f"Error downloading with aria2: {err}")

    finally:
        # Cleanup temp file
        if os.path.isfile(tmpfile):
            os.remove(tmpfile)


def store_urls(url_list, out_file):
    """
    Stores URLs in a file with an idempotent approach:
      - If the file already exists, do not duplicate URLs that are already present.
      - Otherwise, create the file and write all URLs.

    Returns the number of newly appended URLs.
    """
    if not url_list:
        print("No URLs to store.")
        return 0

    existing = set()
    if os.path.isfile(out_file):
        with open(out_file, 'r', encoding='utf-8') as f:
            for line in f:
                existing.add(line.strip())

    appended_count = 0
    with open(out_file, 'a', encoding='utf-8') as f:
        for url in url_list:
            if url not in existing:
                f.write(url + "\n")
                appended_count += 1
    return appended_count
