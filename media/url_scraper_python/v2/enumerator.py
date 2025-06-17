#!/usr/bin/env python3
"""
enumerator.py
Core logic for image enumeration and status checking.
Split from the main script for clarity and maintainability

Dependencies:
    - requests (pip install requests)
"""

import re
import requests  # Moved import here
from typing import List, Tuple, Optional, Set

RESET_COLOR = "\033[0m"
LIGHT_GREEN = "\033[1;32m"
LIGHT_RED = "\033[1;31m"
ORANGE = "\033[0;33m"
CYAN = "\033[0;36m"
WHITE = "\033[0m"
MAX_LOOKAHEAD = 999  # Hard limit for forward scan distance
CONSECUTIVE_404_THRESHOLD = 2  # Number of consecutive failures to stop scanning
IMAGE_EXTENSIONS = (
    r"(jpg|jpeg|png|gif|bmp)"  # Regex pattern for common image extensions
)
session = requests.Session()


def color_print(message: str, color: str = WHITE, end: str = "\n") -> None:
    """
    Prints a message in the specified color.

    Args:
        message: The string message to print.
        color: The ANSI color code string. Defaults to WHITE.
        end: The string appended after the last value. Defaults to "\n".
    """
    print(f"{color}{message}{RESET_COLOR}", end=end)


def get_status_code(url: str) -> Optional[int]:
    """
    Attempts a HEAD request for minimal data. If HEAD is blocked or returns 405,
    retries with a GET request. Returns the final status code (int) or None on error.

    Args:
        url: The URL to check.

    Returns:
        The HTTP status code as an integer, or None if a request exception occurs.
    """
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/58.0.3029.110 Safari/537.3"
        )
    }
    try:
        # Use the session object
        response = session.head(url, headers=headers, timeout=5)
        if response.status_code == 405:
            # Some servers block HEAD -> try GET
            # stream=True is not strictly necessary here as we only need the status code
            response = session.get(url, headers=headers, timeout=5)
        return response.status_code
    except requests.RequestException:
        # Return None explicitly on error for any request issue (timeout, connection, etc.)
        return None


def extract_numeric_portion(filename: str) -> Optional[int]:
    """
    Extracts the numeric portion from a filename like '39.jpg' using regex.
    Assumes the numeric portion is followed by a dot and an image extension
    at the end of the string.

    Args:
        filename: The filename string to parse.

    Returns:
        An integer if a numeric portion followed by an image extension is found,
        otherwise None.
    """
    # Use the defined constant for extensions
    match = re.search(rf"(\d+)\.{IMAGE_EXTENSIONS}$", filename, re.IGNORECASE)
    if match:
        return int(match.group(1))
    return None  # Corrected typo


def build_url_sequence(
    base_url: str, start_num: int, end_num: int, width: int
) -> List[str]:
    """
    Build a list of URLs from start_num to end_num,
    replacing the numeric portion in base_url with zero-padded
    numbers of length 'width'.

    Args:
        base_url: The base URL containing a numeric portion to replace.
        start_num: The starting number for the sequence (inclusive).
        end_num: The ending number for the sequence (inclusive).
        width: The desired zero-padding width for the numbers.

    Returns:
        A list of generated URLs.
    """
    urls = []
    # Regex pattern to match trailing digits followed by an image extension
    pattern = rf"(\d+)\.{IMAGE_EXTENSIONS}$"

    for i in range(start_num, end_num + 1):
        new_num_str = str(i).zfill(width)
        # Use re.sub to replace the matched numeric part (\d+) with the new number,
        # keeping the original extension (\2 refers to the second capture group)
        new_url = re.sub(pattern, f"{new_num_str}.\\2", base_url, flags=re.IGNORECASE)
        urls.append(new_url)
    return urls  # Corrected typo


def check_urls_in_sequence(url_list: List[str]) -> Tuple[int, int, int]:
    """
    Checks the status codes for a list of URLs, printing color-coded results.

    Args:
        url_list: A list of URLs to check.

    Returns:
        A tuple containing the counts of (success, redirected, errors).
    """
    total = 0
    success = 0
    redirected = 0
    errors = 0

    for url in url_list:
        sc = get_status_code(url)
        total += 1
        if sc is None:
            # Handle the case where get_status_code returned None (request error)
            color_print(f"{url} [Error: Request Failed]", LIGHT_RED)
            errors += 1
        elif 200 <= sc <= 299:
            color_print(f"{url} [HTTP {sc}]", LIGHT_GREEN)
            success += 1
        elif 300 <= sc <= 399:
            color_print(f"{url} [HTTP {sc}]", ORANGE)
            redirected += 1
        else:
            color_print(f"{url} [HTTP {sc}]", LIGHT_RED)
            errors += 1

    # Print summary AFTER the loop finishes
    color_print(
        f"\n[Summary] {success} OK | {redirected} Redirected | {errors} Broken"
        f" (out of {total} total)",
        WHITE,
    )

    return success, redirected, errors  # Corrected typo


def auto_enumerate_images(base_url: str) -> List[str]:
    """
    Auto-detect a numeric portion in the filename, then expand outwards until
    encountering CONSECUTIVE_404_THRESHOLD errors in each direction.
    Finally, build the list of discovered images and check their statuses.

    Args:
        base_url: The initial URL containing a numeric portion to start from.

    Returns:
        A list of URLs that were checked in the enumerated range.
        Returns an empty list if no numeric portion is found or enumeration fails.
    """
    filename = base_url.split("/")[-1]
    numeric_value = extract_numeric_portion(filename)

    if numeric_value is None:
        color_print(
            "No numeric portion found in URL filename; cannot enumerate.", LIGHT_RED
        )
        return []  # Corrected incomplete line

    # Determine zero-padding width based on the discovered portion
    # This regex should match the same pattern as extract_numeric_portion
    match_width = re.search(rf"(\d+)\.{IMAGE_EXTENSIONS}$", filename, re.IGNORECASE)
    # We already checked numeric_value is not None, so match_width should not be None here
    width = (
        len(match_width.group(1)) if match_width else 1
    )  # Added a fallback width just in case, though logic implies match_width is not None

    found_nums: Set[int] = set()
    found_nums.add(numeric_value)  # Corrected missing parenthesis

    # Scan backwards
    color_print(f"Scanning backwards from {numeric_value}...", CYAN)
    consecutive_fails = 0
    current = numeric_value - 1
    while current > 0 and consecutive_fails < CONSECUTIVE_404_THRESHOLD:
        test_url = re.sub(
            rf"(\d+)\.{IMAGE_EXTENSIONS}$",  # Use constant pattern
            f"{str(current).zfill(width)}.\\2",
            base_url,
            flags=re.IGNORECASE,
        )
        sc = get_status_code(test_url)
        # Consider any non-success status code or request error as a "fail" for the threshold
        if sc is not None and 200 <= sc <= 299:
            found_nums.add(current)
            consecutive_fails = 0  # Reset counter on success
            # Optional: print found attempts during scan
            # color_print(f" Found: {test_url} [HTTP {sc}]", LIGHT_GREEN, end='\r')
        else:
            consecutive_fails += 1
            # Optional: print failed attempts during scan
            # color_print(f" Fail: {test_url} [HTTP {sc}]", LIGHT_RED, end='\r')
        # Print progress indicator (optional, but helpful for long scans)
        color_print(
            f" Checking: {test_url} [HTTP {sc if sc is not None else 'Error'}]",
            WHITE,
            end="\r",
        )
        current -= 1  # Corrected incomplete line
    print()  # Newline after scan progress

    # Scan forwards
    color_print(f"Scanning forwards from {numeric_value}...", CYAN)
    consecutive_fails = 0
    current = numeric_value + 1
    while current <= MAX_LOOKAHEAD and consecutive_fails < CONSECUTIVE_404_THRESHOLD:
        test_url = re.sub(
            rf"(\d+)\.{IMAGE_EXTENSIONS}$",  # Use constant pattern
            f"{str(current).zfill(width)}.\\2",
            base_url,
            flags=re.IGNORECASE,
        )
        sc = get_status_code(test_url)
        # Consider any non-success status code or request error as a "fail" for the threshold
        if sc is not None and 200 <= sc <= 299:
            found_nums.add(current)
            consecutive_fails = 0  # Reset counter on success
            # Optional: print found attempts during scan
            # color_print(f" Found: {test_url} [HTTP {sc}]", LIGHT_GREEN, end='\r')
        else:
            consecutive_fails += 1
            # Optional: print failed attempts during scan
            # color_print(f" Fail: {test_url} [HTTP {sc}]", LIGHT_RED, end='\r')
        # Print progress indicator (optional, but helpful for long scans)
        color_print(
            f" Checking: {test_url} [HTTP {sc if sc is not None else 'Error'}]",
            WHITE,
            end="\r",
        )
        current += 1  # Corrected incomplete line
    print()  # Newline after scan progress

    # Build final sequence
    if not found_nums:
        color_print("No images found during enumeration scan.", ORANGE)
        return []

    min_found = min(found_nums)
    max_found = max(found_nums)

    color_print(
        f"\nScan complete. Found numbers from {min_found} to {max_found}.", CYAN
    )

    url_list = build_url_sequence(base_url, min_found, max_found, width=width)

    color_print(f"Checking status of {len(url_list)} images in the range...", CYAN)
    check_urls_in_sequence(url_list)

    return url_list


# Example usage (optional, typically in a main block)

if __name__ == "__main__":
    # test_url = "http://example.com/images/photo_039.jpg"
    # enumerated_urls = auto_enumerate_images(test_url)
    # print("\nEnumeration finished. Checked URLs:")
    # for u in enumerated_urls:
    #     print(u)
    pass  # Added pass as the block is commented out
