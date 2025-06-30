#!/usr/bin/env python3
# image_enum.py
# Minimal, production-grade brute/recursive image enumerator/downloader for UNIX/Arch/XDG systems.

import re
import sys
import os
import argparse
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urljoin, urlparse
from typing import List, Optional

# --- XDG Paths ---
def get_xdg_dir(kind, fallback):
    var = f'XDG_{kind.upper()}_HOME'
    return Path(os.environ.get(var, str(Path.home() / fallback)))

XDG_DATA = get_xdg_dir('data', '.local/share/image-enum')
XDG_CACHE = get_xdg_dir('cache', '.cache/image-enum')
XDG_CONFIG = get_xdg_dir('config', '.config/image-enum')
DOWNLOADS_DIR = XDG_DATA / 'downloads'
LOG_FILE = XDG_CACHE / 'enum.log'

# --- Supported Image Extensions ---
IMG_EXTS = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.tiff', '.tif', '.svg',
            '.jfif', '.pjpeg', '.pjp', '.avif', '.heic']

# --- ANSI Colors ---
def color(txt, code):
    return f"\033[{code}m{txt}\033[0m"

GREEN = lambda x: color(x, '1;32')
YELLOW = lambda x: color(x, '1;33')
RED = lambda x: color(x, '1;31')
BLUE = lambda x: color(x, '1;34')
CYAN = lambda x: color(x, '1;36')
BOLD = lambda x: color(x, '1;37')

# --- Dependency Check ---
def check_dependencies(tools):
    missing = [t for t in tools if not shutil.which(t)]
    if missing:
        print(RED(f"Missing required tools: {', '.join(missing)}"))
        print("Install with: sudo pacman -S " + ' '.join(missing))
        sys.exit(1)

import shutil
check_dependencies(['curl', 'aria2c', 'seq'])

# --- Logging ---
def log(msg):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a") as f:
        f.write(msg + "\n")

# --- Pattern Extraction ---
def extract_pattern(url):
    """Identify numeric or alphanumeric sequences and extension in URL, return pattern, ranges, ext."""
    fname = urlparse(url).path.split('/')[-1]
    exts = [e for e in IMG_EXTS if fname.lower().endswith(e)]
    ext = exts[-1] if exts else Path(fname).suffix
    body = fname[: -len(ext)] if ext else fname

    # Find numeric and alphanumeric runs
    patterns = []
    for m in re.finditer(r'([0-9]+|[a-zA-Z]+)', body):
        patterns.append((m.group(), m.start(), m.end()))
    if not patterns:
        raise ValueError("No numeric or alpha patterns found in filename.")
    # Find largest numeric group for brute
    idx = max(range(len(patterns)), key=lambda i: len(patterns[i][0]) if patterns[i][0].isdigit() else 0)
    pat_str, start, end = patterns[idx]
    width = len(pat_str)
    if pat_str.isdigit():
        base_pat = body[:start] + '{num}' + body[end:]
        return base_pat, int(pat_str), width, ext
    # Alphanumeric or complex: let user override
    raise ValueError("Pattern extraction failed: complex/alpha pattern. Use --pattern.")

# --- Pattern Expansion ---
def expand_numeric_pattern(base_pat, num0, width, ext, min_range, max_range):
    return [base_pat.format(num=str(i).zfill(width)) + ext for i in range(min_range, max_range + 1)]

# --- Extension Variant Expansion ---
def all_exts_for(fname):
    root = re.sub(r'(\.[^.]+)$', '', fname)
    return [root + e for e in IMG_EXTS]

# --- Status Check: Parallel curl HEAD ---
def check_url(url, headers, timeout=6):
    cmd = ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--head', '--max-time', str(timeout)]
    for h in headers: cmd += ['-H', h]
    cmd += [url]
    try:
        code = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        return url, code
    except Exception:
        return url, 'ERR'

def batch_status(urls, headers, max_threads=16):
    results = []
    with ThreadPoolExecutor(max_workers=max_threads) as ex:
        futs = {ex.submit(check_url, u, headers): u for u in urls}
        for f in as_completed(futs):
            results.append(f.result())
    return results

# --- Download ---
def download_batch(urls, outdir, headers):
    outdir.mkdir(parents=True, exist_ok=True)
    listfile = outdir / 'urls.txt'
    with listfile.open('w') as f:
        for u in urls:
            f.write(u + "\n")
    aria_args = ['aria2c', '-c', '-x', '8', '-j', '4', '-d', str(outdir), '-i', str(listfile)]
    for h in headers:
        aria_args += ['--header', h]
    print(CYAN(f"[aria2c] Downloading {len(urls)} files to {outdir} ..."))
    log(f"Download started: {len(urls)} files to {outdir}")
    subprocess.run(aria_args)
    print(GREEN("Download complete."))

# --- Brute Mode Orchestration ---
def brute_mode(url, min_range, max_range, download, headers, dry_run):
    print(BOLD(f"[Brute] Pattern extracting: {url}"))
    try:
        base_pat, num0, width, ext = extract_pattern(url)
        print(f"Pattern: {base_pat.replace('{num}', '[N]')}, Range: {min_range}-{max_range}, Ext: {ext}")
    except Exception as e:
        print(RED(f"Auto pattern failed: {e}"))
        sys.exit(1)
    urls = []
    for fname in expand_numeric_pattern(base_pat, num0, width, ext, min_range, max_range):
        for f in all_exts_for(fname):
            # reconstruct dir
            upath = urlparse(url)
            url_base = url[:url.rfind(upath.path)] + upath.path[:-(len(upath.path.split('/')[-1]))]
            urls.append(urljoin(url_base, f))
    print(f"Enumerated {len(urls)} candidates.")

    # Batch status check
    print(BLUE("Checking URLs..."))
    checked = batch_status(urls, headers)
    found = [u for u, code in checked if code == '200']
    for u, code in checked:
        if code == '200':
            print(GREEN(f"[200] {u}"))
        elif code == '403':
            print(YELLOW(f"[403] {u}"))
        elif code == '404':
            print(RED(f"[404] {u}"))
        else:
            print(CYAN(f"[{code}] {u}"))
    print(BOLD(f"Found {len(found)} images."))
    log(f"Brute: Found {len(found)}/{len(urls)} images.")

    # Download
    if download and found:
        download_batch(found, DOWNLOADS_DIR, headers)
    elif not download:
        print(BLUE("Dry run, URLs only. Use --download to fetch images."))
    if found:
        out = XDG_CACHE / "found_urls.txt"
        with out.open("w") as f:
            for u in found:
                f.write(u + "\n")
        print(GREEN(f"Valid URLs saved: {out}"))

# --- Recursive Mode (Minimal) ---
def gen_minimal_spider(start_url, headers, outdir):
    # Heredoc string for scrapy runspider, saves URLs to file
    spider = f'''
import scrapy
class MinimalSpider(scrapy.Spider):
    name = "minimal"
    start_urls = ["{start_url}"]
    custom_settings = {{
        "LOG_LEVEL": "ERROR",
        "FEED_FORMAT": "txt",
        "FEED_URI": "{outdir}/scrapy_found.txt",
    }}
    def start_requests(self):
        hdrs = {headers}
        for url in self.start_urls:
            yield scrapy.Request(url, headers={{h.split(":",1)[0]:h.split(":",1)[1].strip() for h in hdrs}})
    def parse(self, response):
        exts = {IMG_EXTS}
        for sel in response.css('img'):
            src = sel.attrib.get('src')
            if src and any(src.lower().endswith(e) for e in exts):
                yield {{'url': response.urljoin(src)}}
        for href in response.css('a::attr(href)').getall():
            if any(href.lower().endswith(e) for e in exts):
                yield {{'url': response.urljoin(href)}}
            elif href.endswith('/'):
                yield response.follow(href, self.parse)
    '''
    return spider

def recursive_mode(start_url, download, headers):
    outdir = DOWNLOADS_DIR
    outdir.mkdir(parents=True, exist_ok=True)
    spiderfile = XDG_CACHE / "minimal_spider.py"
    with spiderfile.open('w') as f:
        f.write(gen_minimal_spider(start_url, headers, outdir))
    print(BLUE(f"[Scrapy] Running recursive spider on {start_url}"))
    log(f"Recursive: Starting on {start_url}")
    try:
        subprocess.run(['scrapy', 'runspider', str(spiderfile)], check=True)
    except Exception as e:
        print(RED(f"Scrapy error: {e}"))
        return
    found_file = outdir / "scrapy_found.txt"
    if found_file.exists():
        urls = set()
        with found_file.open() as f:
            for line in f:
                line = line.strip()
                if line.startswith("url:"):
                    urls.add(line.split("url:",1)[-1].strip())
        print(GREEN(f"Found {len(urls)} images."))
        for u in urls:
            print(GREEN(u))
        if download and urls:
            download_batch(list(urls), outdir, headers)
        if urls:
            out = XDG_CACHE / "found_urls.txt"
            with out.open("w") as f2:
                for u in urls:
                    f2.write(u + "\n")
            print(GREEN(f"Valid URLs saved: {out}"))
    else:
        print(RED("No URLs found."))

# --- Interactive Menu ---
def menu():
    print(BOLD("Image Enumerator & Downloader"))
    print("1) Brute-force enumeration (pattern mode)")
    print("2) Recursive directory spider (scrapy mode)")
    print("q) Quit")
    c = input("Select option: ").strip()
    if c == '1':
        url = input("Sample image URL: ").strip()
        minr = int(input("Min number in sequence: ").strip() or "1")
        maxr = int(input("Max number in sequence: ").strip() or "100")
        download = input("Download images? (y/n): ").strip().lower().startswith('y')
        brute_mode(url, minr, maxr, download, [], False)
    elif c == '2':
        url = input("Start URL: ").strip()
        download = input("Download images? (y/n): ").strip().lower().startswith('y')
        recursive_mode(url, download, [])
    else:
        print("Goodbye.")
        sys.exit(0)

# --- CLI Entrypoint ---
def main():
    ap = argparse.ArgumentParser(description="Brute/recursive image enumerator/downloader (minimal, Arch/XDG).")
    ap.add_argument('--mode', choices=['brute', 'recursive'], required=False)
    ap.add_argument('--url', help='Sample image URL (required)', required=False)
    ap.add_argument('--min', type=int, default=1, help='Min number in sequence (brute)')
    ap.add_argument('--max', type=int, default=100, help='Max number in sequence (brute)')
    ap.add_argument('--download', action='store_true', help='Download images')
    ap.add_argument('--user-agent', help='Custom User-Agent header')
    ap.add_argument('--header', action='append', default=[], help='Add custom header (can repeat)')
    ap.add_argument('--cookie', help='Cookie header')
    ap.add_argument('--dry-run', action='store_true', help='Enumerate only, no download')
    ap.add_argument('--menu', action='store_true', help='Show interactive menu')
    args = ap.parse_args()

    headers = []
    if args.user_agent:
        headers.append(f'User-Agent: {args.user_agent}')
    if args.cookie:
        headers.append(f'Cookie: {args.cookie}')
    headers += args.header

    if args.menu or not args.mode:
        menu()
        return

    if not args.url:
        print(RED("Error: --url required."))
        sys.exit(1)

    if args.mode == 'brute':
        brute_mode(args.url, args.min, args.max, args.download, headers, args.dry_run)
    elif args.mode == 'recursive':
        recursive_mode(args.url, args.download, headers)
    else:
        print(RED("Unknown mode."))
        sys.exit(1)

if __name__ == "__main__":
    main()
