#!/usr/bin/env python3
# url_scraper.py
#
# A high-performance, production-grade brute-force and recursive image enumerator.
# This version integrates key UX and robustness features from its Bash predecessors,
# including interactive confirmation, explicit pattern overrides, and enhanced reporting.

import argparse
import asyncio
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin, urlparse

# --- Third-party library imports ---
try:
    import httpx
    from bs4 import BeautifulSoup
except ImportError:
    print("\033[1;31mError: Missing required Python packages.\033[0m", file=sys.stderr)
    print(
        "Please install them by running: pip install httpx beautifulsoup4",
        file=sys.stderr,
    )
    sys.exit(1)


# --- XDG Base Directory Specification ---
def get_xdg_dir(kind: str, fallback: str) -> Path:
    """Retrieves an XDG base directory path."""
    var = f"XDG_{kind.upper()}_HOME"
    return Path(os.environ.get(var, str(Path.home() / fallback)))


XDG_DATA = get_xdg_dir("data", ".local/share/image-enum")
XDG_CACHE = get_xdg_dir("cache", ".cache/image-enum")
DOWNLOADS_DIR = XDG_DATA / "downloads"
LOG_FILE = XDG_CACHE / "enum.log"


# --- Constants ---
IMG_EXTS: list[str] = [
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".gif",
    ".bmp",
    ".tiff",
    ".tif",
    ".svg",
    ".jfif",
    ".pjpeg",
    ".pjp",
    ".avif",
    ".heic",
]
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
)


# --- ANSI Color Formatting ---
def color(txt: str, code: str) -> str:
    """Wraps text in ANSI color codes."""
    return f"\033[{code}m{txt}\033[0m"


GREEN = lambda x: color(str(x), "1;32")
YELLOW = lambda x: color(str(x), "1;33")
RED = lambda x: color(str(x), "1;31")
BLUE = lambda x: color(str(x), "1;34")
CYAN = lambda x: color(str(x), "1;36")
BOLD = lambda x: color(str(x), "1;37")


# --- Pre-flight Checks ---
def check_dependencies() -> None:
    """Verifies that required command-line tools are installed."""
    if not shutil.which("aria2c"):
        print(RED("Error: 'aria2c' command not found."))
        print(YELLOW("This is required for downloading files. Please install it."))
        print(YELLOW("  - On Arch Linux: sudo pacman -S aria2"))
        print(YELLOW("  - On Debian/Ubuntu: sudo apt-get install aria2"))
        sys.exit(1)


# --- Core Logic ---
class ImageEnumerator:
    """
    Encapsulates the logic for enumerating and downloading images.
    """

    def __init__(self, headers: list[str], timeout: int = 10):
        self.headers = {
            h.split(":", 1)[0].strip(): h.split(":", 1)[1].strip() for h in headers
        }
        if "User-Agent" not in self.headers:
            self.headers["User-Agent"] = DEFAULT_USER_AGENT
        self.timeout = timeout
        self.found_urls: set[str] = set()
        self.status_counts = Counter()

    @staticmethod
    def _log(msg: str) -> None:
        """Appends a message to the log file."""
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(msg + "\n")

    @staticmethod
    def _extract_brute_pattern(url: str) -> tuple[str, int, int, str]:
        """
        Heuristically identifies a numeric sequence in a URL filename.
        """
        parsed_url = urlparse(url)
        filename = Path(parsed_url.path).name
        file_stem, file_ext = os.path.splitext(filename)
        if file_ext.lower() not in IMG_EXTS:
            file_ext = ""

        numeric_parts = list(re.finditer(r"\d+", file_stem))
        if not numeric_parts:
            raise ValueError(
                "No numeric sequence found in filename for auto-detection."
            )

        match = numeric_parts[-1]
        num_str = match.group(0)
        start, end = match.span()
        pattern = file_stem[:start] + "{num}" + file_stem[end:]
        return pattern, int(num_str), len(num_str), file_ext

    async def _check_url(self, client: httpx.AsyncClient, url: str) -> tuple[str, int]:
        """Performs an async HEAD request to check a URL's status."""
        try:
            response = await client.head(url, follow_redirects=True)
            return url, response.status_code
        except httpx.RequestError:
            return url, 0  # 0 indicates a client-side error

    async def _check_urls_parallel(self, urls: set[str], verbose: bool) -> None:
        """Checks a list of URLs in parallel, providing live feedback."""
        print(BLUE(f"Checking {len(urls)} candidate URLs..."))
        tasks = []
        # Use a semaphore to limit concurrent connections
        semaphore = asyncio.Semaphore(50)

        async with httpx.AsyncClient(
            headers=self.headers, timeout=self.timeout
        ) as client:

            async def throttled_check(url: str) -> tuple[str, int]:
                async with semaphore:
                    return await self._check_url(client, url)

            for url in urls:
                tasks.append(asyncio.create_task(throttled_check(url)))

            for i, future in enumerate(asyncio.as_completed(tasks)):
                url, code = await future
                self.status_counts[code] += 1

                # Live status line
                summary = (
                    f"  {GREEN(self.status_counts[200])} OK | "
                    f"{YELLOW(self.status_counts[403])} Forbidden | "
                    f"{RED(self.status_counts[404])} Not Found | "
                    f"{CYAN(self.status_counts[0])} Errors"
                )
                print(f"Progress: {i + 1}/{len(urls)} | {summary}", end="\r")

                if code == 200:
                    self.found_urls.add(url)

                if verbose:
                    # In verbose mode, print every result on a new line
                    print(" " * 100, end="\r")  # Clear the progress line
                    if code == 200:
                        print(GREEN(f"[{code}] {url}"))
                    elif code in {401, 403}:
                        print(YELLOW(f"[{code}] {url}"))
                    elif code == 404:
                        print(RED(f"[{code}] {url}"))
                    elif code == 0:
                        print(RED(f"[ERR] {url} (Connection Error)"))
                    else:
                        print(CYAN(f"[{code}] {url}"))
        print("\n" + "=" * 40)  # Newline after progress bar is done

    def _download_batch(self, outdir: Path) -> None:
        """Uses aria2c to download a list of URLs efficiently."""
        if not self.found_urls:
            print(YELLOW("No URLs found to download."))
            return

        outdir.mkdir(parents=True, exist_ok=True)
        listfile = XDG_CACHE / "aria2_urls.txt"
        with listfile.open("w", encoding="utf-8") as f:
            for url in sorted(self.found_urls):
                f.write(url + "\n")

        aria_args = [
            "aria2c",
            "-c",
            "-x16",
            "-s16",
            "-j10",
            "--console-log-level=warn",
            "-d",
            str(outdir),
            "-i",
            str(listfile),
        ]
        for key, value in self.headers.items():
            aria_args.extend(["--header", f"{key}: {value}"])

        print(
            CYAN(f"\n[aria2c] Downloading {len(self.found_urls)} files to {outdir} ...")
        )
        self._log(f"Download started: {len(self.found_urls)} files to {outdir}")

        try:
            subprocess.run(aria_args, check=True, capture_output=True, text=True)
            print(GREEN("Download complete."))
        except subprocess.CalledProcessError as e:
            print(RED(f"aria2c failed. Stderr:\n{e.stderr}"))
        except KeyboardInterrupt:
            print(YELLOW("\nDownload interrupted by user."))

    def _save_found_urls(self) -> None:
        """Saves the list of found URLs to a cache file."""
        if not self.found_urls:
            return
        out_path = XDG_CACHE / "found_urls.txt"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            for url in sorted(self.found_urls):
                f.write(url + "\n")
        print(GREEN(f"Valid URLs saved to: {out_path}"))

    def _print_summary(self, candidates_count: int) -> None:
        """Prints a final summary of the enumeration results."""
        print(BOLD("Enumeration Summary:"))
        print(f"  - Candidates generated: {candidates_count}")
        print(f"  - Successful (200 OK):  {GREEN(self.status_counts[200])}")
        print(f"  - Forbidden (403):      {YELLOW(self.status_counts[403])}")
        print(f"  - Not Found (404):      {self.status_counts[404]}")
        print(f"  - Connection Errors:    {RED(self.status_counts[0])}")

        other_codes = {
            k: v for k, v in self.status_counts.items() if k not in [0, 200, 403, 404]
        }
        if other_codes:
            print(f"  - Other Status Codes:   {CYAN(dict(other_codes))}")

    async def run_brute(
        self, url: str, min_r: int, max_r: int, pattern: Optional[str], verbose: bool
    ) -> None:
        """Orchestrates the brute-force enumeration mode."""
        print(BOLD("[Brute Mode]"))
        try:
            if pattern:
                if "{num}" not in pattern:
                    raise ValueError(
                        "Custom pattern must include the '{num}' placeholder."
                    )
                base_pat = pattern
                width = 2  # Default width for custom patterns, user should zero-pad if needed
                ext = Path(url).suffix
                print(f"  Using custom pattern: {base_pat}")
            else:
                base_pat, _, width, ext = self._extract_brute_pattern(url)
                print(
                    f"  Auto-detected pattern: {base_pat.replace('{num}', '[N]')}{ext or '[EXTS]'}"
                )

            print(f"  Range: {min_r} - {max_r} | Zero-padding width: {width}")

        except ValueError as e:
            print(RED(f"Error: {e}"))
            sys.exit(1)

        parsed_url = urlparse(url)
        base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
        dir_path = Path(parsed_url.path).parent

        candidates: set[str] = set()
        for i in range(min_r, max_r + 1):
            num_str = str(i).zfill(width)
            filename_stem = base_pat.format(num=num_str)

            extensions_to_try = [ext] if ext else IMG_EXTS
            for e in extensions_to_try:
                full_path = str(dir_path / (filename_stem + e))
                candidates.add(urljoin(base_url, full_path))

        await self._check_urls_parallel(candidates, verbose)
        self._print_summary(len(candidates))

    async def run_recursive(self, start_url: str, depth: int, verbose: bool) -> None:
        """Orchestrates the recursive spider mode."""
        print(BOLD(f"[Recursive Mode] Starting at {start_url} (depth: {depth})"))

        async with httpx.AsyncClient(
            headers=self.headers, timeout=self.timeout
        ) as client:
            try:
                # Pre-flight check for content type
                head_resp = await client.head(start_url, follow_redirects=True)
                content_type = head_resp.headers.get("content-type", "")
                if "text/html" not in content_type:
                    print(
                        YELLOW(
                            f"Warning: Start URL content-type is '{content_type}', not 'text/html'."
                        )
                    )
                    if input("Continue anyway? (y/n): ").lower() != "y":
                        sys.exit(0)
            except httpx.RequestError as e:
                print(RED(f"Could not connect to start URL: {e}"))
                sys.exit(1)

        urls_to_visit: set[tuple[str, int]] = {(start_url, 0)}
        visited_urls: set[str] = set()

        async with httpx.AsyncClient(
            headers=self.headers, timeout=self.timeout, follow_redirects=True
        ) as client:
            while urls_to_visit:
                current_url, current_depth = urls_to_visit.pop()
                if current_url in visited_urls or current_depth > depth:
                    continue

                visited_urls.add(current_url)
                if verbose:
                    print(f"  Crawling (depth {current_depth}): {current_url}")

                try:
                    response = await client.get(current_url)
                    self.status_counts[response.status_code] += 1
                    soup = BeautifulSoup(response.text, "html.parser")

                    links = soup.find_all(["a", "img"], href=True) + soup.find_all(
                        ["img"], src=True
                    )

                    for link in links:
                        href = link.get("href") or link.get("src")
                        if not href:
                            continue

                        abs_url = urljoin(current_url, href)
                        if any(abs_url.lower().endswith(ext) for ext in IMG_EXTS):
                            if abs_url not in self.found_urls:
                                print(GREEN(f"    + Found image: {abs_url}"))
                                self.found_urls.add(abs_url)

                        elif urlparse(abs_url).netloc == urlparse(start_url).netloc:
                            if abs_url not in visited_urls:
                                urls_to_visit.add((abs_url, current_depth + 1))
                except Exception as e:
                    if verbose:
                        print(RED(f"    Error processing {current_url}: {e}"))

        print("\n" + "=" * 40)
        print(BOLD("Crawl Complete."))
        print(f"  - Pages visited: {len(visited_urls)}")
        print(f"  - Unique images found: {GREEN(len(self.found_urls))}")


# --- CLI Entrypoint ---
def main() -> None:
    """Parses command-line arguments and executes the appropriate mode."""
    check_dependencies()

    parser = argparse.ArgumentParser(
        description="A high-performance brute-force and recursive image enumerator.",
        formatter_class=argparse.RawTextHelpFormatter,
    )

    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--brute",
        metavar="URL",
        help="Run in brute-force mode with a sample image URL.",
    )
    mode_group.add_argument(
        "--recursive",
        metavar="URL",
        help="Run in recursive spider mode from a starting URL.",
    )
    mode_group.add_argument(
        "--menu",
        action="store_true",
        help="Show an interactive menu (not implemented).",
    )

    brute_group = parser.add_argument_group("Brute Mode Options")
    brute_group.add_argument(
        "--min", type=int, default=1, help="Min number in sequence (default: 1)."
    )
    brute_group.add_argument(
        "--max", type=int, default=100, help="Max number in sequence (default: 100)."
    )
    brute_group.add_argument(
        "--pattern",
        help="Manual pattern override. Use '{num}' as the placeholder (e.g., 'img_{num}_thumb').",
    )

    rec_group = parser.add_argument_group("Recursive Mode Options")
    rec_group.add_argument(
        "--depth",
        type=int,
        default=2,
        help="Max crawl depth for the spider (default: 2).",
    )

    gen_group = parser.add_argument_group("General Options")
    gen_group.add_argument(
        "--download", action="store_true", help="Download found images using aria2c."
    )
    gen_group.add_argument(
        "-H",
        "--header",
        action="append",
        default=[],
        help="Add custom header (e.g., 'Referer: ...').",
    )
    gen_group.add_argument("-c", "--cookie", help="Set the Cookie header.")
    gen_group.add_argument("-A", "--user-agent", help="Set the User-Agent header.")
    gen_group.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Show all status codes, including 404s.",
    )
    gen_group.add_argument(
        "-y", "--yes", action="store_true", help="Bypass confirmation prompts."
    )

    args = parser.parse_args()

    # --- Input Validation ---
    if args.brute and args.max < args.min:
        parser.error(f"--max ({args.max}) cannot be less than --min ({args.min}).")

    # --- Confirmation Prompt ---
    if not args.yes:
        print(BOLD("Operation Summary:"))
        if args.brute:
            print(f"  Mode:      {CYAN('Brute-force')}")
            print(f"  Target:    {args.brute}")
            print(f"  Range:     {args.min} to {args.max}")
        elif args.recursive:
            print(f"  Mode:      {CYAN('Recursive')}")
            print(f"  Target:    {args.recursive}")
            print(f"  Depth:     {args.depth}")
        if args.download:
            print(f"  Download:  {GREEN('Enabled')}")

        if input("\nProceed with this operation? (y/n): ").strip().lower() != "y":
            print("Operation cancelled.")
            sys.exit(0)
        print("-" * 20)

    headers = args.header
    if args.user_agent:
        headers.append(f"User-Agent: {args.user_agent}")
    if args.cookie:
        headers.append(f"Cookie: {args.cookie}")

    enumerator = ImageEnumerator(headers)

    try:
        if args.brute:
            asyncio.run(
                enumerator.run_brute(
                    args.brute, args.min, args.max, args.pattern, args.verbose
                )
            )
        elif args.recursive:
            asyncio.run(
                enumerator.run_recursive(args.recursive, args.depth, args.verbose)
            )

        if args.download:
            enumerator._download_batch(DOWNLOADS_DIR)
        else:
            print(YELLOW("\nDry run complete. Use --download to fetch images."))

        enumerator._save_found_urls()

    except KeyboardInterrupt:
        print(YELLOW("\nOperation cancelled by user."))
        sys.exit(130)
    except Exception as e:
        print(RED(f"\nAn unexpected error occurred: {e}"))
        sys.exit(1)


if __name__ == "__main__":
    # Note: Interactive menu from original script is removed in favor of robust CLI flags.
    # The --menu flag is kept as a placeholder in argparse for historical context.
    if "--menu" in sys.argv:
        print(
            YELLOW(
                "Interactive menu is deprecated. Please use command-line flags. Use -h for help."
            )
        )
        sys.exit(1)
    main()
