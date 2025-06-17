#!/usr/bin/env python3
"""
integration.py
Provides supporting functions:
  1. open_in_browser: open enumerated URLs in a web browser tab-by-tab
  2. download_with_aria2: download enumerated URLs using aria2
  3. store_urls: store enumerated URLs in a text file with idempotent approach
Dependencies:
    - enumerator.py (relative import - not used in this snippet)
    - webbrowser (built-in)
    - subprocess, os, tempfile, time (built-in)
"""
import os
import subprocess
import tempfile
import time
import webbrowser
from typing import List, Set  # Import necessary types


def open_in_browser(url_list: List[str]) -> None:
    """
    Open each URL in a new browser tab.

    Args:
        url_list: A list of URLs (strings) to open.
    """
    if not url_list:
        print("No URLs to open in browser.")
        return

    print(f"Opening {len(url_list)} URLs in browser...")
    for url in url_list:
        webbrowser.open_new_tab(url)
    print("Finished opening URLs.")


def download_with_aria2(url_list: List[str], out_dir: str) -> None:
    """
    Leverage aria2 to download enumerated URLs.

    Writes URLs to a temporary file, calls aria2c with -i .

    Args:
        url_list: A list of URLs (strings) to download.
        out_dir: The directory to save downloaded files.
    """
    if not url_list:
        print("No URLs to download.")
        return

    # Create out_dir if not exist
    try:
        os.makedirs(out_dir, exist_ok=True)
        print(f"Download directory ensured: {out_dir}")
    except OSError as e:
        print(f"Error creating output directory {out_dir}: {e}")
        return  # Cannot proceed without a valid output directory

    tmpfile: str = os.path.join(
        tempfile.gettempdir(), f"aria2_input_{int(time.time())}.txt"
    )
    print(f"Writing {len(url_list)} URLs to temporary file: {tmpfile}")

    try:
        # Wrap file writing and subprocess call in the same try block
        with open(tmpfile, "w", encoding="utf-8") as f:
            for url in url_list:
                f.write(url + "\n")

        # Run aria2
        cmd: List[str] = ["aria2c", "-d", out_dir, "-i", tmpfile]
        print("Running aria2c command...")
        print(f"Command: {' '.join(cmd)}")

        # check=True is good, raises CalledProcessError on non-zero exit code
        subprocess.run(cmd, check=True)
        print("aria2c command finished successfully.")

    except FileNotFoundError:
        print("Error: aria2c command not found. Is aria2 installed and in your PATH?")
    except subprocess.CalledProcessError as err:
        print(f"Error downloading with aria2: {err}")
    except IOError as e:
        print(f"Error writing temporary file {tmpfile}: {e}")
    except Exception as e:  # Catch any other unexpected errors
        print(f"An unexpected error occurred during aria2 download: {e}")
    finally:
        # Cleanup temp file
        if os.path.isfile(tmpfile):
            try:
                os.remove(tmpfile)
                # print(f"Cleaned up temporary file: {tmpfile}") # Optional: add for debugging
            except OSError as e:
                print(f"Warning: Could not remove temporary file {tmpfile}: {e}")


def store_urls(url_list: List[str], out_file: str) -> int:
    """
    Stores URLs in a file with an idempotent approach.

    If the file already exists, do not duplicate URLs that are already present.
    Otherwise, create the file and write all URLs.

    Args:
        url_list: A list of URLs (strings) to store.
        out_file: The path to the output text file.

    Returns:
        The number of newly appended URLs.
    """
    if not url_list:
        print("No URLs to store.")
        return 0

    existing: Set[str] = set()
    if os.path.isfile(out_file):
        print(f"Reading existing URLs from {out_file}...")
        try:
            with open(out_file, "r", encoding="utf-8") as f:
                for line in f:
                    existing.add(line.strip())
            print(f"Found {len(existing)} existing URLs.")
        except IOError as e:
            print(
                f"Warning: Could not read existing file {out_file}: {e}. Proceeding as if empty."
            )
            # Decide how to handle: proceed assuming no existing, or return?
            # Assuming proceed is acceptable here.

    appended_count: int = 0
    print(f"Appending new URLs to {out_file}...")
    try:
        with open(out_file, "a", encoding="utf-8") as f:
            for url in url_list:
                if url not in existing:
                    f.write(url + "\n")
                    appended_count += 1
        print(f"Finished storing URLs. Appended {appended_count} new URLs.")
    except IOError as e:
        print(f"Error writing to file {out_file}: {e}")
        # Depending on requirements, you might want to raise the exception
        # or return a specific error code/value.
        return 0  # Indicate failure to append

    return appended_count
