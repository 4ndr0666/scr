# ================================
# enumerator.py
# ================================
#!/usr/bin/env python3
"""
enumerator.py

Core logic for image enumeration and status checking.
Splits image URL processing from the main interface for clarity.

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
LIGHT_RED   = "\033[1;31m"
ORANGE      = "\033[0;33m"
CYAN        = "\033[0;36m"
WHITE       = "\033[0m"

MAX_LOOKAHEAD = 999
CONSECUTIVE_404_THRESHOLD = 5


def color_print(message, color=WHITE, end="\n"):
    """Prints a message in the specified color."""
    print(f"{color}{message}{RESET_COLOR}", end=end)


def get_status_code(url):
    """
    Attempts a HEAD request for minimal data.
    If HEAD is blocked or returns 405, retries with GET.
    Returns status code (int) or 0 on error.
    """
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/58.0.3029.110 Safari/537.3"
        )
    }
    try:
        response = requests.head(url, headers=headers, timeout=5)
        if response.status_code == 405:  # HEAD blocked
            response = requests.get(url, headers=headers, stream=True, timeout=5)
        return response.status_code
    except requests.RequestException:
        return 0


def extract_numeric_portion(filename):
    """
    Extracts a numeric portion from a filename (e.g., '39.jpg').
    Returns int if found, else None.
    """
    match = re.search(r"(\d+)\.(?:jpg|jpeg|png|gif|bmp)$", filename, re.IGNORECASE)
    return int(match.group(1)) if match else None


def build_url_sequence(base_url, start_num, end_num, width=2):
    """
    Builds a list of URLs from start_num to end_num,
    replacing the numeric portion in base_url with zero-padded
    numbers of length 'width'.
    """
    urls = []
    for i in range(start_num, end_num + 1):
        new_num_str = str(i).zfill(width)
        new_url = re.sub(
            r"(\d+)\.(jpg|jpeg|png|gif|bmp)$",
            lambda m: f"{new_num_str}.{m.group(2)}",
            base_url,
            flags=re.IGNORECASE
        )
        urls.append(new_url)
    return urls


def check_urls_in_sequence(url_list):
    """
    Checks the status codes for a list of URLs, printing color-coded results.
    Returns (success_count, redirect_count, error_count).
    """
    total = success = redirected = errors = 0
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
        f"\n[Summary] {success} OK | {redirected} Redirected | {errors} Broken (out of {total} total)",
        WHITE
    )
    return success, redirected, errors


def auto_enumerate_images(base_url):
    """
    Auto-detect a numeric portion in the filename, then expand outward
    until encountering CONSECUTIVE_404_THRESHOLD failures in each direction.
    Builds the final list of discovered images, checks statuses.
    """
    filename = base_url.split('/')[-1]
    numeric_value = extract_numeric_portion(filename)
    if numeric_value is None:
        color_print("No numeric portion found in URL filename; cannot enumerate.", LIGHT_RED)
        return []

    match_width = re.search(r"(\d+)\.(?:jpg|jpeg|png|gif|bmp)$", filename, re.IGNORECASE)
    width = len(match_width.group(1)) if match_width else 2

    found_nums = {numeric_value}
    consecutive_fails = 0

    # Scan backwards
    current = numeric_value - 1
    while current > 0 and consecutive_fails < CONSECUTIVE_404_THRESHOLD:
        test_url = re.sub(
            r"(\d+)\.(jpg|jpeg|png|gif|bmp)$",
            lambda m: f"{str(current).zfill(width)}.{m.group(2)}",
            base_url,
            flags=re.IGNORECASE
        )
        if 200 <= get_status_code(test_url) <= 299:
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
            lambda m: f"{str(current).zfill(width)}.{m.group(2)}",
            base_url,
            flags=re.IGNORECASE
        )
        if 200 <= get_status_code(test_url) <= 299:
            found_nums.add(current)
            consecutive_fails = 0
        else:
            consecutive_fails += 1
        current += 1

    min_found = min(found_nums)
    max_found = max(found_nums)
    url_list = build_url_sequence(base_url, min_found, max_found, width=width)
    color_print(f"Enumerated {len(url_list)} images from {min_found} to {max_found}:", CYAN)
    check_urls_in_sequence(url_list)
    return url_list
