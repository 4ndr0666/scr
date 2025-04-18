#!/usr/bin/env python3
"""
integration.py

Provides supporting functions:
  1. open_in_browser: Open enumerated URLs in new browser tabs.
  2. download_with_aria2: Download enumerated URLs using aria2.
  3. store_urls: Store enumerated URLs in a text file (idempotent).

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
    """Open each URL in a new browser tab with a slight delay."""
    for url in url_list:
        try:
            webbrowser.open_new_tab(url)
            time.sleep(0.3)
        except Exception as e:
            print(f"Error opening URL {url}: {e}")


def download_with_aria2(url_list, out_dir):
    """
    Leverage aria2 to download enumerated URLs.
    Writes URLs to a temporary file, calls aria2c with standard arguments only
    (no --disable-rpc), preventing unrecognized-option errors.
    """
    if not url_list:
        print("No URLs to download.")
        return

    if not os.path.isdir(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    tmpfile = os.path.join(tempfile.gettempdir(), f"aria2_input_{int(time.time())}.txt")
    try:
        with open(tmpfile, 'w', encoding='utf-8') as f:
            for url in url_list:
                f.write(url + "\n")

        cmd = ["aria2c", "-d", out_dir, "-i", tmpfile]
        print(f"Running aria2c. Download directory: {out_dir}")
        print(f"Command: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as err:
        print(f"Error downloading with aria2: {err}")
    finally:
        if os.path.isfile(tmpfile):
            os.remove(tmpfile)


def store_urls(url_list, out_file):
    """
    Stores URLs in a file using an idempotent approach.
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
