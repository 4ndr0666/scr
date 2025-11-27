#!/usr/bin/env python3
# flaru.py
# Ψ-4ndr0666 All-in-One Modular OSINT/Media/Leak Terminal Suite

import sys
import os
import re
import shutil
import subprocess
import json
import asyncio
import webbrowser
from collections import Counter
from pathlib import Path
from urllib.parse import urljoin, urlparse

try:
    import httpx
    from bs4 import BeautifulSoup
    from prompt_toolkit import prompt
    from prompt_toolkit.formatted_text import HTML
    from prompt_toolkit.styles import Style
    import pyperclip
except ImportError:
    print("\033[1;31mMissing required packages.\033[0m", file=sys.stderr)
    print("Install with: pip install prompt_toolkit pyperclip httpx beautifulsoup4")
    sys.exit(1)

# --- ANSI/Color Formatting ---
CYAN = "\033[38;5;51m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
RESET = "\033[0m"
BOLD = "\033[1m"

style = Style.from_dict(
    {
        "prompt": "fg:#15FFFF bold",
        "menu": "fg:#FFD700 bold",
        "success": "fg:#00FFAF bold",
        "error": "fg:#FF5F5F bold",
    }
)


def color_block(msg, type_):
    color = {"info": YELLOW, "success": GREEN, "error": RED}.get(type_, CYAN)
    print(f"{color}{BOLD}{msg}{RESET}")


# --- XDG Session Paths ---
def get_xdg_dir(kind, fallback):
    var = f"XDG_{kind.upper()}_HOME"
    return Path(os.environ.get(var, str(Path.home() / fallback)))


XDG_DATA = get_xdg_dir("data", ".local/share/image-enum")
XDG_CACHE = get_xdg_dir("cache", ".cache/image-enum")
XDG_CONFIG = get_xdg_dir("config", ".config/image-enum")
DOWNLOADS_DIR = XDG_DATA / "downloads"
LOG_FILE = XDG_CACHE / "enum.log"

SESSION_FILE = os.path.expanduser("$XDG_CACHE/dorkmaster/dorkmaster_session.json")
SESSION = {
    "targets": [],
    "dorks": [],
    "urls": [],
    "domains": [],
    "images": [],
    "exports": [],
}


def load_session():
    if os.path.exists(SESSION_FILE):
        try:
            with open(SESSION_FILE, "r") as f:
                SESSION.update(json.load(f))
        except Exception:
            pass


def save_session():
    with open(SESSION_FILE, "w") as f:
        json.dump(SESSION, f, indent=2)


def opsec_warning():
    color_block(
        "!! Always use VPN, Tor, or proxy for sensitive searches/downloads. Only operate in a VM or isolated env for dump/warez scraping !!",
        "error",
    )


# --- Modal Dorkmaster (Google Dork Picker) ---
DORK_CATEGORIES = [
    (
        "Media/Leak Indexes",
        [
            ("Index-of Videos", 'intitle:"index of" (mp4|avi|mkv|mov|webm) "{target}"'),
            (
                "Index-of Photos",
                'intitle:"index of" (jpg|jpeg|png|webp|gif|bmp|tif) "{target}"',
            ),
            ("Index-of Archives", 'intitle:"index of" (zip|rar|7z|tar|gz) "{target}"'),
            ("Mega.nz Media", 'site:mega.nz "{target}" (mp4|zip|rar|jpg|pdf)'),
            ("Drive Media", 'site:drive.google.com "{target}" (mp4|zip|rar|jpg|pdf)'),
            ("Forum Leaks", '"{target}" (dump|pack|leak|collection|mega|drive)'),
            ("Pastebin Drops", '"{target}" site:pastebin.com'),
            ("4plebs/chan", '"{target}" site:4plebs.org'),
        ],
    ),
    (
        "Targeted Domain Dorking",
        [
            ("All .com subdomains", "site:*.{target}.com"),
            ("All .net subdomains", "site:*.{target}.net"),
            ("Contact Emails", '"contact@{target}"'),
            ("Support Emails", '"support@{target}"'),
            ("PDF Documents", '"{target}" filetype:pdf'),
            ("Word Docs", '"{target}" filetype:doc'),
        ],
    ),
    (
        "Advanced OSINT/Leak Dorks",
        [
            ("Open Cameras", 'inurl:view/view.shtml | inurl:axis-cgi/mjpg "{target}"'),
            ("Exposed .env", '"DB_PASSWORD" filetype:env'),
            ("GitHub Leaks", '"{target}" site:github.com inurl:config'),
            ("Cloud Buckets", 'site:storage.googleapis.com "{target}"'),
        ],
    ),
]


def copy_to_clipboard(text):
    try:
        pyperclip.copy(text)
        print(f"{GREEN}Copied to clipboard.{RESET}")
    except Exception:
        print(
            f"{YELLOW}Clipboard copy failed (try installing xclip/wl-clipboard/pyperclip).{RESET}"
        )


def open_browser(query):
    url = f"https://www.google.com/search?q={query.replace(' ', '+')}"
    try:
        webbrowser.open(url)
        print(f"{GREEN}Opened in browser:{RESET} {url}")
    except Exception:
        print(f"{YELLOW}Failed to open browser. Copy the URL manually.{RESET}")


def run_dork_modal():
    print(f"{CYAN}{BOLD}Ψ-4ndr0666 Dorkmaster Modal{RESET}")
    target = prompt(
        HTML("<prompt>Enter target (public figure, domain, keyword):</prompt> "),
        style=style,
    ).strip()
    if not target:
        print(f"{RED}No target. Exiting.{RESET}")
        return
    while True:
        print(f"\n{CYAN}Dork Categories:{RESET}")
        for i, (cat, _) in enumerate(DORK_CATEGORIES):
            print(f"{YELLOW}{i+1}{RESET}. {cat}")
        print(f"{YELLOW}0{RESET}. Exit")
        cat_in = prompt(
            HTML("<prompt>Select category (number):</prompt> "), style=style
        ).strip()
        if cat_in == "0":
            return
        if not cat_in.isdigit() or not (1 <= int(cat_in) <= len(DORK_CATEGORIES)):
            print(f"{RED}Invalid category.{RESET}")
            continue
        cat_idx = int(cat_in) - 1
        cat_name, patterns = DORK_CATEGORIES[cat_idx]
        while True:
            print(f"\n{CYAN}{BOLD}{cat_name}{RESET}")
            for j, (name, pattern) in enumerate(patterns):
                dork = pattern.format(target=target)
                print(f"{YELLOW}{j+1}{RESET}. {name}: {CYAN}{dork}{RESET}")
            print(f"{YELLOW}0{RESET}. Back to Categories")
            pat_in = prompt(
                HTML("<prompt>Pick dork pattern (number), [C]ustom, or 0:</prompt> "),
                style=style,
            ).strip()
            if pat_in == "0":
                break
            if pat_in.lower().startswith("c"):
                custom = prompt(
                    HTML(
                        "<prompt>Enter your custom dork (use {target} for substitution):</prompt> "
                    ),
                    style=style,
                )
                dork = custom.format(target=target)
                copy_to_clipboard(dork)
                SESSION["dorks"].append(dork)
                if (
                    prompt(
                        HTML("<prompt>Open in browser? (y/n):</prompt> "), style=style
                    )
                    .strip()
                    .lower()
                    .startswith("y")
                ):
                    open_browser(dork)
                continue
            if not pat_in.isdigit() or not (1 <= int(pat_in) <= len(patterns)):
                print(f"{RED}Invalid selection.{RESET}")
                continue
            name, patt = patterns[int(pat_in) - 1]
            dork = patt.format(target=target)
            copy_to_clipboard(dork)
            SESSION["dorks"].append(dork)
            if (
                prompt(HTML("<prompt>Open in browser? (y/n):</prompt> "), style=style)
                .strip()
                .lower()
                .startswith("y")
            ):
                open_browser(dork)
            else:
                print(
                    f"{YELLOW}Not opening browser. Copy/paste dork manually if needed.{RESET}"
                )


IMG_EXTS = [
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


def check_aria2c():
    if not shutil.which("aria2c"):
        print(RED("Error: 'aria2c' command not found."))
        print(YELLOW("This is required for downloading files. Please install it."))
        print(YELLOW("  - On Arch Linux: sudo pacman -S aria2"))
        print(YELLOW("  - On Debian/Ubuntu: sudo apt-get install aria2"))
        return False
    return True


class ImageEnumerator:
    def __init__(self, headers, timeout=10):
        self.headers = {
            h.split(":", 1)[0].strip(): h.split(":", 1)[1].strip() for h in headers
        }
        if "User-Agent" not in self.headers:
            self.headers["User-Agent"] = DEFAULT_USER_AGENT
        self.timeout = timeout
        self.found_urls = set()
        self.status_counts = Counter()

    @staticmethod
    def _extract_brute_pattern(url):
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

    async def _check_url(self, client, url):
        try:
            response = await client.head(url, follow_redirects=True)
            return url, response.status_code
        except httpx.RequestError:
            return url, 0

    async def _check_urls_parallel(self, urls, verbose):
        print(BLUE(f"Checking {len(urls)} candidate URLs..."))
        tasks = []
        semaphore = asyncio.Semaphore(50)
        async with httpx.AsyncClient(
            headers=self.headers, timeout=self.timeout
        ) as client:

            async def throttled_check(url):
                async with semaphore:
                    return await self._check_url(client, url)

            for url in urls:
                tasks.append(asyncio.create_task(throttled_check(url)))
            for i, future in enumerate(asyncio.as_completed(tasks)):
                url, code = await future
                self.status_counts[code] += 1
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
                    print(" " * 100, end="\r")
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
        print("\n" + "=" * 40)

    def _download_batch(self, outdir):
        if not self.found_urls:
            print(YELLOW("No URLs found to download."))
            return
        if not check_aria2c():
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
        try:
            subprocess.run(aria_args, check=True, capture_output=True, text=True)
            print(GREEN("Download complete."))
        except subprocess.CalledProcessError as e:
            print(RED(f"aria2c failed. Stderr:\n{e.stderr}"))
        except KeyboardInterrupt:
            print(YELLOW("\nDownload interrupted by user."))

    def _save_found_urls(self):
        if not self.found_urls:
            return
        out_path = XDG_CACHE / "found_urls.txt"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            for url in sorted(self.found_urls):
                f.write(url + "\n")
        print(GREEN(f"Valid URLs saved to: {out_path}"))

    def _print_summary(self, candidates_count):
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

    async def run_brute(self, url, min_r, max_r, pattern, verbose):
        print(BOLD("[Brute Mode]"))
        try:
            if pattern:
                if "{num}" not in pattern:
                    raise ValueError(
                        "Custom pattern must include the '{num}' placeholder."
                    )
                base_pat = pattern
                width = 2
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
            return
        parsed_url = urlparse(url)
        base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
        dir_path = Path(parsed_url.path).parent
        candidates = set()
        for i in range(min_r, max_r + 1):
            num_str = str(i).zfill(width)
            filename_stem = base_pat.format(num=num_str)
            extensions_to_try = [ext] if ext else IMG_EXTS
            for e in extensions_to_try:
                full_path = str(dir_path / (filename_stem + e))
                candidates.add(urljoin(base_url, full_path))
        await self._check_urls_parallel(candidates, verbose)
        self._print_summary(len(candidates))

    async def run_recursive(self, start_url, depth, verbose):
        print(BOLD(f"[Recursive Mode] Starting at {start_url} (depth: {depth})"))
        async with httpx.AsyncClient(
            headers=self.headers, timeout=self.timeout
        ) as client:
            try:
                head_resp = await client.head(start_url, follow_redirects=True)
                content_type = head_resp.headers.get("content-type", "")
                if "text/html" not in content_type:
                    print(
                        YELLOW(
                            f"Warning: Start URL content-type is '{content_type}', not 'text/html'."
                        )
                    )
                    if input("Continue anyway? (y/n): ").lower() != "y":
                        return
            except httpx.RequestError as e:
                print(RED(f"Could not connect to start URL: {e}"))
                return

        urls_to_visit = {(start_url, 0)}
        visited_urls = set()
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


# --- Reddit/Chan Media Downloader (script.py) ---
def run_reddit_downloader():
    subreddit = prompt(
        HTML("<prompt>Enter subreddit to rip images from:</prompt> "), style=style
    ).strip()
    sort = prompt(
        HTML('<prompt>Sort method ("Top", "Hot", "new"):</prompt> '), style=style
    ).strip()
    limit = prompt(HTML("<prompt>Number of memes:</prompt> "), style=style).strip()
    if not (subreddit and sort and limit.isdigit()):
        print(RED("All inputs required and limit must be a number."))
        return
    limit = int(limit)
    headers = {"user-agent": "my-app/0.0.1"}
    url = f"https://www.reddit.com/r/{subreddit}.json"
    try:
        resp = httpx.get(
            url, params={"sort": sort, "limit": limit}, headers=headers, timeout=15
        )
        data = resp.json()
        postlist = data["data"]["children"]
        if not postlist:
            print(RED("No results found."))
            return
        dl_dir = Path(f"Subreddit/{subreddit}")
        dl_dir.mkdir(parents=True, exist_ok=True)
        for idx, post in enumerate(postlist):
            img_url = post["data"].get("url", "")
            if any(img_url.lower().endswith(ext) for ext in IMG_EXTS):
                try:
                    img_data = httpx.get(img_url, timeout=20).content
                    out_path = dl_dir / f"file{idx}.png"
                    with open(out_path, "wb") as f:
                        f.write(img_data)
                    print(GREEN(f"[{idx+1}/{limit}] Downloaded: {img_url}"))
                except Exception as e:
                    print(YELLOW(f"[{idx+1}/{limit}] Failed: {img_url} ({e})"))
        print(GREEN(f"Done. Images saved to {dl_dir}/"))
    except Exception as e:
        print(RED(f"Failed to rip subreddit: {e}"))


# --- Unified Menu Integration ---
def main_menu():
    load_session()
    while True:
        print(f"\n{CYAN}{BOLD}Ψ === // DORKMASTER //{RESET}")
        print(f"{YELLOW}1.{RESET} Dork Google for Media Links")
        print(f"{YELLOW}2.{RESET} Brute-Force/Enumerate Images")
        print(f"{YELLOW}3.{RESET} Recursive Web Album Crawl")
        print(f"{YELLOW}4.{RESET} Reddit/Chan Dump")
        print(f"{YELLOW}5.{RESET} Batch Export/Clipboard All Results")
        print(f"{YELLOW}6.{RESET} OpSec Help & Info")
        print(f"{YELLOW}7.{RESET} Exit")
        choice = prompt(
            HTML("<prompt>Select mode [1-7]:</prompt> "), style=style
        ).strip()
        if choice == "1":
            opsec_warning()
            run_dork_modal()
        elif choice == "2":
            opsec_warning()
            url = prompt(
                HTML("<prompt>Sample image URL:</prompt> "), style=style
            ).strip()
            min_r = int(
                prompt(
                    HTML("<prompt>Min number in sequence (default 1):</prompt> "),
                    style=style,
                )
                or "1"
            )
            max_r = int(
                prompt(
                    HTML("<prompt>Max number in sequence (default 100):</prompt> "),
                    style=style,
                )
                or "100"
            )
            pattern = prompt(
                HTML("<prompt>Manual pattern override (optional):</prompt> "),
                style=style,
            ).strip()
            verbose = (
                prompt(
                    HTML("<prompt>Show verbose output? (y/n):</prompt> "), style=style
                )
                .strip()
                .lower()
                .startswith("y")
            )
            download = (
                prompt(HTML("<prompt>Download images? (y/n):</prompt> "), style=style)
                .strip()
                .lower()
                .startswith("y")
            )
            enumerator = ImageEnumerator([])
            asyncio.run(
                enumerator.run_brute(
                    url, min_r, max_r, pattern if pattern else None, verbose
                )
            )
            if download:
                enumerator._download_batch(DOWNLOADS_DIR)
            enumerator._save_found_urls()
            SESSION["urls"].extend(list(enumerator.found_urls))
            save_session()
        elif choice == "3":
            opsec_warning()
            start_url = prompt(
                HTML("<prompt>Start URL for recursion:</prompt> "), style=style
            ).strip()
            depth = int(
                prompt(
                    HTML("<prompt>Max crawl depth (default 2):</prompt> "), style=style
                )
                or "2"
            )
            verbose = (
                prompt(
                    HTML("<prompt>Show verbose output? (y/n):</prompt> "), style=style
                )
                .strip()
                .lower()
                .startswith("y")
            )
            download = (
                prompt(HTML("<prompt>Download images? (y/n):</prompt> "), style=style)
                .strip()
                .lower()
                .startswith("y")
            )
            enumerator = ImageEnumerator([])
            asyncio.run(enumerator.run_recursive(start_url, depth, verbose))
            if download:
                enumerator._download_batch(DOWNLOADS_DIR)
            enumerator._save_found_urls()
            SESSION["urls"].extend(list(enumerator.found_urls))
            save_session()
        elif choice == "4":
            opsec_warning()
            run_reddit_downloader()
        elif choice == "5":
            save_session()
            print(f"{GREEN}Session exported to {SESSION_FILE}.{RESET}")
            try:
                with open(SESSION_FILE) as f:
                    pyperclip.copy(f.read())
                print(f"{GREEN}Session JSON copied to clipboard!{RESET}")
            except Exception as e:
                print(f"{YELLOW}Clipboard export failed: {e}{RESET}")
        elif choice == "6":
            print("\n")
            color_block("Ψ-4ndr0666 OpSec Tips:", "info")
            print(
                f"{BOLD}1.{RESET} Always use a VPN, Tor, or proxy, especially for leaky/gray-area queries."
            )
            print(f"{BOLD}2.{RESET} Run this toolkit from a VM or sandbox.")
            print(
                f"{BOLD}3.{RESET} Never download direct dumps/archives to your real machine."
            )
            print(
                f"{BOLD}4.{RESET} When in doubt, research the legal risks before proceeding."
            )
            print(
                f"{BOLD}5.{RESET} If exporting results, review output for sensitive/private info before sharing."
            )
            input(f"{CYAN}Press Enter to continue...{RESET}")
        elif choice == "7":
            save_session()
            print(f"{CYAN}Session saved. Goodbye!{RESET}")
            break
        else:
            color_block("Invalid selection.", "error")


if __name__ == "__main__":
    main_menu()
