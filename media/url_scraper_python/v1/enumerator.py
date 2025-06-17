#!/usr/bin/env python3
"""
enumerator.py

Core logic for image enumeration and status checking.
Split from the main script for clarity and maintainability.

Dependencies:
    - requests (pip install requests)
    - re (built-in)
"""

import re
import requests

# -------------------------
# Global Constants & Config
# -------------------------
RESET_COLOR = "\033[0m"
LIGHT_GREEN = "\033[1;32m"
LIGHT_RED = "\033[1;31m"
ORANGE = "\033[0;33m"
CYAN = "\033[0;36m"
WHITE = "\033[0m"

# Maximum lookahead
MAX_LOOKAHEAD = 999
# Consecutive 404 threshold
CONSECUTIVE_404_THRESHOLD = 5


# -------------------------
# Helper Functions
# -------------------------
def color_print(message, color=WHITE, end="\n"):
    """
    Prints a message in the specified color.
    """
    print(f"{color}{message}{RESET_COLOR}", end=end)


def get_status_code(url):
    """
    Attempts a HEAD request for minimal data. If HEAD is blocked or returns 405,
    retries with a GET request. Returns the final status code (int) or 0 on error.
    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/58.0.3029.110 Safari/537.3"
    }
    try:
        response = requests.head(url, headers=headers, timeout=5)
        # Some servers don't allow HEAD requests and respond with 405 Method Not Allowed
        if response.status_code == 405:
            response = requests.get(url, headers=headers, stream=True, timeout=5)
        return response.status_code
    except requests.RequestException:
        return 0


def extract_numeric_portion(filename):
    """
    Extracts the numeric portion from a filename like '39.jpg' using regex.
    Returns an integer if found, else None.
    """
    match = re.search(r"(\d+)\.(?:jpg|jpeg|png|gif|bmp)$", filename, re.IGNORECASE)
    if match:
        return int(match.group(1))
    return None


def build_url_sequence(base_url, start_num, end_num, width=2):
    """
    Build a list of URLs from start_num to end_num,
    replacing the numeric portion in base_url with zero-padded numbers of length 'width'.
    """
    urls = []
    for i in range(start_num, end_num + 1):
        new_num_str = str(i).zfill(width)
        # Use a regex sub to replace the trailing digits in the base URL
        new_url = re.sub(
            r"(\d+)\.(jpg|jpeg|png|gif|bmp)$",
            f"{new_num_str}.\\2",
            base_url,
            flags=re.IGNORECASE,
        )
        urls.append(new_url)
    return urls


def check_urls_in_sequence(url_list):
    """
    Checks the status codes for a list of URLs, printing color-coded results.
    Returns (success_count, redirect_count, error_count).
    """
    total = 0
    success = 0
    redirected = 0
    errors = 0

    for url in url_list:
        sc = get_status_code(url)
        total += 1
        if 200 <= sc <= 299:
            color_print(f"{url} [HTTP {sc}]", LIGHT_GREEN)
            success += 1
        elif 300 <= sc <= 399:
            color_print(f"{url} [HTTP {sc}]", ORANGE)
            redirected += 1
        else:
            color_print(f"{url} [HTTP {sc}]", LIGHT_RED)
            errors += 1

    color_print(
        f"\n[Summary] {success} OK | {redirected} Redirected | {errors} Broken "
        f"(out of {total} total)",
        WHITE,
    )
    return success, redirected, errors


def auto_enumerate_images(base_url):
    """
    Auto-detect a numeric portion in the filename, then expand outwards until
    encountering CONSECUTIVE_404_THRESHOLD errors in each direction.
    Finally, build the list of discovered images and check their statuses.
    """
    filename = base_url.split("/")[-1]
    numeric_value = extract_numeric_portion(filename)
    if numeric_value is None:
        color_print(
            "No numeric portion found in URL filename; cannot enumerate.", LIGHT_RED
        )
        return

    # Determine zero-padding width based on the discovered portion
    match_width = re.search(
        r"(\d+)\.(?:jpg|jpeg|png|gif|bmp)$", filename, re.IGNORECASE
    )
    width = len(match_width.group(1)) if match_width else 2

    # We'll track discovered indexes in a set to handle out-of-order findings
    found_nums = set()
    found_nums.add(numeric_value)

    # Scan backwards
    consecutive_fails = 0
    current = numeric_value - 1
    while current > 0 and consecutive_fails < CONSECUTIVE_404_THRESHOLD:
        test_url = re.sub(
            r"(\d+)\.(jpg|jpeg|png|gif|bmp)$",
            f"{str(current).zfill(width)}.\\2",
            base_url,
            flags=re.IGNORECASE,
        )
        sc = get_status_code(test_url)
        if 200 <= sc <= 299:
            found_nums.add(current)
            consecutive_fails = 0
        else:
            consecutive_fails += 1
        current -= 1

    # Scan forwards
    consecutive_fails = 0
    current = numeric_value + 1
    while current <= MAX_LOOKAHEAD and consecutive_fails < CONSECUTIVE_404_THRESHOLD:
        test_url = re.sub(
            r"(\d+)\.(jpg|jpeg|png|gif|bmp)$",
            f"{str(current).zfill(width)}.\\2",
            base_url,
            flags=re.IGNORECASE,
        )
        sc = get_status_code(test_url)
        if 200 <= sc <= 299:
            found_nums.add(current)
            consecutive_fails = 0
        else:
            consecutive_fails += 1
        current += 1

    # Build final sequence
    min_found = min(found_nums)
    max_found = max(found_nums)
    url_list = build_url_sequence(base_url, min_found, max_found, width=width)

    color_print(
        f"Enumerated {len(url_list)} images from {min_found} to {max_found}:", CYAN
    )
    check_urls_in_sequence(url_list)


# ──────────────────────────────────────────────────────────────────────────────
#  my_image_enumerator/main.py
# ──────────────────────────────────────────────────────────────────────────────
