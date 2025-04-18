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


def extract_first_numeric_portion(filename):
    """
    Extracts the FIRST numeric portion from a filename, ignoring trailing digits.
    Example:
      'sis-roma-9-1-scaled.jpg' -> returns (prefix='sis-roma-', number='9',
                                            suffix='-1-scaled', extension='.jpg')
    If no numeric portion is found, returns None.
    """
    # Pattern breakdown:
    #   ^(.*?)    -> capture everything up to the first digits (prefix)
    #   (\d+)     -> capture the first group of digits
    #   (.*)      -> capture any remaining characters until final extension
    #   (\.(?:jpg|jpeg|png|gif|bmp))$ -> capture the extension
    pattern = re.compile(r"^(.*?)(\d+)(.*)(\.(?:jpg|jpeg|png|gif|bmp))$", re.IGNORECASE)
    match = pattern.search(filename)
    if match:
        prefix = match.group(1)
        number_str = match.group(2)       # the digits we will enumerate
        suffix = match.group(3)
        extension = match.group(4)
        return prefix, number_str, suffix, extension
    return None


def build_url_sequence(base_url, start_num, end_num, width=2,
                       prefix="", suffix="", extension=""):
    """
    Builds a list of URLs from start_num to end_num by replacing the
    *first* numeric group with zero-padded numbers (of length 'width').
    
    The rest (prefix, suffix, extension) remain intact.
    """
    urls = []
    for i in range(start_num, end_num + 1):
        new_num_str = str(i).zfill(width)
        # Construct the new filename
        new_filename = f"{prefix}{new_num_str}{suffix}{extension}"
        # Replace the old filename in base_url with new_filename
        # This is the simplest approach if the old 'filename' is at the end:
        url_before_filename = base_url.rsplit('/', 1)[0]  # everything before last '/'
        new_url = f"{url_before_filename}/{new_filename}"
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
    Auto-detect the *first* numeric portion in the filename, then expand outward
    until hitting CONSECUTIVE_404_THRESHOLD failures in each direction.
    
    Example:
      If the filename is 'sis-roma-9-1-scaled.jpg', the enumerated part is '9',
      with prefix='sis-roma-', suffix='-1-scaled', extension='.jpg'.
      We then attempt 8,7,6,... downward, and 10,11,12,... upward until repeated 404s.
    """
    filename = base_url.rsplit('/', 1)[-1]  # only the filename
    extracted = extract_first_numeric_portion(filename)
    if not extracted:
        color_print("No numeric portion found in URL filename; cannot enumerate.", LIGHT_RED)
        return []

    prefix, number_str, suffix, extension = extracted
    numeric_value = int(number_str)
    width = len(number_str)

    found_nums = {numeric_value}
    consecutive_fails = 0

    # Scan backwards
    current = numeric_value - 1
    while current > 0 and consecutive_fails < CONSECUTIVE_404_THRESHOLD:
        test_filename = f"{prefix}{str(current).zfill(width)}{suffix}{extension}"
        test_url = base_url.rsplit('/', 1)[0] + "/" + test_filename
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
        test_filename = f"{prefix}{str(current).zfill(width)}{suffix}{extension}"
        test_url = base_url.rsplit('/', 1)[0] + "/" + test_filename
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
    url_list = build_url_sequence(base_url, min_found, max_found,
                                  width=width,
                                  prefix=prefix,
                                  suffix=suffix,
                                  extension=extension)
    color_print(f"Enumerated {len(url_list)} images from {min_found} to {max_found}:", CYAN)
    check_urls_in_sequence(url_list)
    return url_list
