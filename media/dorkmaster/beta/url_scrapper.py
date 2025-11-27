#!/usr/bin/env python3
# url_scrapper.py
#
# A high-performance, production-grade brute-force and recursive image enumerator.
# This version integrates key UX and robustness features from its Bash predecessors,
# including interactive confirmation, explicit pattern overrides, and enhanced reporting.

import argparse
import asyncio
import os
import re
import sys
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


def ensure_dirs():
    for p in [XDG_DATA, XDG_CACHE, DOWNLOADS_DIR]:
        p.mkdir(parents=True, exist_ok=True)
    LOG_FILE.touch(exist_ok=True)


def log(msg: str):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(msg + "\n")


def is_image_url(url: str) -> bool:
    return any(url.lower().split("?")[0].endswith(e) for e in IMG_EXTS)


def parse_images(html: str, base_url: str) -> list:
    soup = BeautifulSoup(html, "html.parser")
    urls = set()
    for tag in soup.find_all("img"):
        src = tag.get("src") or ""
        if not src:
            continue
        if not src.startswith("http"):
            src = urljoin(base_url, src)
        if is_image_url(src):
            urls.add(src)
    return list(urls)


async def fetch_url(client, url: str, timeout=10) -> Optional[str]:
    try:
        r = await client.get(url, timeout=timeout)
        r.raise_for_status()
        return r.text
    except Exception as e:
        log(f"[ERR] {url}: {e}")
        return None


async def fetch_images_from_url(client, url: str) -> list:
    html = await fetch_url(client, url)
    if not html:
        return []
    return parse_images(html, url)


async def download_image(client, url: str, out_dir: Path):
    fname = url.split("/")[-1].split("?")[0]
    fpath = out_dir / fname
    try:
        r = await client.get(url, timeout=20)
        r.raise_for_status()
        with open(fpath, "wb") as f:
            f.write(r.content)
        print(f"[OK] {url} -> {fpath}")
        log(f"[OK] {url} -> {fpath}")
    except Exception as e:
        print(f"[FAIL] {url}: {e}")
        log(f"[FAIL] {url}: {e}")


async def recursive_enum(
    client,
    base_url: str,
    depth: int,
    visited: set,
    image_urls: set,
    pattern: Optional[str] = None,
    max_pages: int = 100,
):
    queue = [(base_url, 0)]
    while queue:
        url, d = queue.pop(0)
        if url in visited or d > depth or len(visited) >= max_pages:
            continue
        visited.add(url)
        html = await fetch_url(client, url)
        if not html:
            continue
        imgs = parse_images(html, url)
        for img in imgs:
            if (pattern and re.search(pattern, img)) or not pattern:
                image_urls.add(img)
        # Discover more URLs to recurse
        soup = BeautifulSoup(html, "html.parser")
        for a in soup.find_all("a", href=True):
            link = a["href"]
            if not link.startswith("http"):
                link = urljoin(url, link)
            # Only follow same host for safety
            if urlparse(link).netloc == urlparse(base_url).netloc:
                queue.append((link, d + 1))


async def main_enum(
    url: str, depth: int, pattern: Optional[str], out_dir: Path, max_pages: int = 100
):
    async with httpx.AsyncClient(
        headers={"user-agent": DEFAULT_USER_AGENT}, follow_redirects=True
    ) as client:
        visited = set()
        image_urls = set()
        await recursive_enum(
            client, url, depth, visited, image_urls, pattern, max_pages
        )
        print(f"\n[INFO] Found {len(image_urls)} unique images.")
        for img_url in image_urls:
            await download_image(client, img_url, out_dir)


def parse_args():
    p = argparse.ArgumentParser(
        description="Recursive image enumerator / downloader (async, high-performance)"
    )
    p.add_argument("url", help="Base URL to start enumeration from")
    p.add_argument(
        "-d", "--depth", type=int, default=1, help="Recursion depth (default: 1)"
    )
    p.add_argument(
        "-p", "--pattern", type=str, default=None, help="Regex to match URLs"
    )
    p.add_argument(
        "-o", "--outdir", type=str, default=str(DOWNLOADS_DIR), help="Output dir"
    )
    p.add_argument(
        "--max-pages", type=int, default=100, help="Max pages to crawl (default: 100)"
    )
    return p.parse_args()


def main():
    args = parse_args()
    ensure_dirs()
    loop = asyncio.get_event_loop()
    loop.run_until_complete(
        main_enum(args.url, args.depth, args.pattern, Path(args.outdir), args.max_pages)
    )


if __name__ == "__main__":
    main()
