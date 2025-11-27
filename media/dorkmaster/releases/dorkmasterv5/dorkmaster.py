#!/usr/bin/env python3
# dorkmaster.py (v5)
# Ψ-4ndr0666 All-in-One Modular OSINT/Media/Leak Terminal Suite
# Refactored with Rich TUI

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

# Check dependencies
try:
    import httpx
    from bs4 import BeautifulSoup
    import pyperclip
    from rich.console import Console
    from rich.panel import Panel
    from rich.table import Table
    from rich.prompt import Prompt, IntPrompt, Confirm
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich import box
except ImportError as e:
    print(f"\033[1;31mMissing dependencies: {e}\033[0m")
    print("Install with: pip install rich httpx beautifulsoup4 pyperclip")
    sys.exit(1)

# --- Initialize Console ---
console = Console()

# --- XDG Session Paths ---
def get_xdg_dir(kind, fallback):
    var = f"XDG_{kind.upper()}_HOME"
    return Path(os.environ.get(var, str(Path.home() / fallback)))

XDG_DATA = get_xdg_dir("data", ".local/share/dorkmaster")
XDG_CACHE = get_xdg_dir("cache", ".cache/dorkmaster")
XDG_CONFIG = get_xdg_dir("config", ".config/dorkmaster")
DOWNLOADS_DIR = XDG_DATA / "downloads"
LOG_FILE = XDG_CACHE / "enum.log"
SESSION_FILE = XDG_CACHE / "dorkmaster_session.json"

# Ensure dirs exist
for d in [XDG_DATA, XDG_CACHE, XDG_CONFIG, DOWNLOADS_DIR]:
    d.mkdir(parents=True, exist_ok=True)

SESSION = {
    "targets": [],
    "dorks": [],
    "urls": [],
    "domains": [],
    "images": [],
    "exports": [],
}

def load_session():
    if SESSION_FILE.exists():
        try:
            with open(SESSION_FILE, "r") as f:
                SESSION.update(json.load(f))
        except Exception:
            pass

def save_session():
    with open(SESSION_FILE, "w") as f:
        json.dump(SESSION, f, indent=2)

def opsec_warning():
    console.print(Panel(
        "[bold red]!! WARNING !![/bold red]\n" 
        "Always use VPN, Tor, or proxy for sensitive searches/downloads.\n" 
        "Only operate in a VM or isolated env for dump/warez scraping.",
        title="OpSec Alert", border_style="red"
    ))

# --- Helper Functions ---
def copy_to_clipboard(text):
    try:
        pyperclip.copy(text)
        console.print("[bold green]Copied to clipboard.[/bold green]")
    except Exception:
        console.print("[bold yellow]Clipboard copy failed.[/bold yellow]")

def open_browser(query):
    url = f"https://www.google.com/search?q={query.replace(' ', '+')}"
    try:
        webbrowser.open(url)
        console.print(f"[green]Opened in browser:[/green] [underline]{url}[/underline]")
    except Exception:
        console.print("[yellow]Failed to open browser.[/yellow]")

# --- Dork Definitions ---
DORK_CATEGORIES = [
    (
        "Media/Leak Indexes",
        [
            ("Index-of Videos", 'intitle:"index of" (mp4|avi|mkv|mov|webm) "{target}"'),
            ("Index-of Photos", 'intitle:"index of" (jpg|jpeg|png|webp|gif|bmp|tif) "{target}"'),
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

def run_dork_modal():
    console.clear()
    console.print(Panel.fit("[bold cyan]Ψ-4ndr0666 Dorkmaster[/bold cyan]", border_style="cyan"))
    
    target = Prompt.ask("Enter target (public figure, domain, keyword)").strip()
    if not target:
        console.print("[red]No target. Exiting.[/red]")
        return

    while True:
        console.print("\n[bold]Dork Categories:[/bold]")
        for i, (cat, _) in enumerate(DORK_CATEGORIES):
            console.print(f"[yellow]{i+1}[/yellow]. {cat}")
        console.print("[yellow]0[/yellow]. Back")
        
        cat_in = IntPrompt.ask("Select category", default=0)
        if cat_in == 0:
            return
        if not (1 <= cat_in <= len(DORK_CATEGORIES)):
            console.print("[red]Invalid category.[/red]")
            continue
            
        cat_idx = cat_in - 1
        cat_name, patterns = DORK_CATEGORIES[cat_idx]
        
        while True:
            table = Table(title=f"Dorks: {cat_name}", box=box.SIMPLE)
            table.add_column("#", style="yellow", justify="right")
            table.add_column("Description", style="white")
            table.add_column("Preview", style="dim cyan")
            
            for j, (name, pattern) in enumerate(patterns):
                dork = pattern.format(target=target)
                table.add_row(str(j+1), name, dork[:60]+"..." if len(dork)>60 else dork)
            
            console.print(table)
            
            pat_in = Prompt.ask("Pick dork #, [bold]C[/bold]ustom, or 0 to back")
            
            if pat_in == "0":
                break
                
            if pat_in.lower().startswith("c"):
                custom = Prompt.ask("Enter custom dork (use {target})")
                dork = custom.format(target=target)
                copy_to_clipboard(dork)
                SESSION["dorks"].append(dork)
                if Confirm.ask("Open in browser?"):
                    open_browser(dork)
                continue
                
            try:
                idx = int(pat_in) - 1
                if 0 <= idx < len(patterns):
                    name, patt = patterns[idx]
                    dork = patt.format(target=target)
                    copy_to_clipboard(dork)
                    SESSION["dorks"].append(dork)
                    if Confirm.ask("Open in browser?"):
                        open_browser(dork)
                else:
                    console.print("[red]Invalid selection.[/red]")
            except ValueError:
                console.print("[red]Invalid input.[/red]")


# --- Image Enumerator Logic ---
IMG_EXTS = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tiff", ".svg", ".avif", ".heic"]
DEFAULT_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"

class ImageEnumerator:
    def __init__(self, headers, timeout=10):
        self.headers = {h.split(":", 1)[0].strip(): h.split(":", 1)[1].strip() for h in headers}
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
        if file_ext.lower() not in IMG_EXTS: file_ext = ""
        
        numeric_parts = list(re.finditer(r"\d+", file_stem))
        if not numeric_parts:
            raise ValueError("No numeric sequence found in filename.")
            
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

    async def _check_urls_parallel(self, urls):
        console.print(f"[blue]Checking {len(urls)} URLs...[/blue]")
        tasks = []
        semaphore = asyncio.Semaphore(50)
        
        async with httpx.AsyncClient(headers=self.headers, timeout=self.timeout) as client:
            async def throttled_check(url):
                async with semaphore:
                    return await self._check_url(client, url)

            for url in urls:
                tasks.append(asyncio.create_task(throttled_check(url)))
            
            with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
                task_id = progress.add_task("Scanning...", total=len(urls))
                
                for future in asyncio.as_completed(tasks):
                    url, code = await future
                    self.status_counts[code] += 1
                    progress.update(task_id, advance=1, description=f"Scanning: Found {len(self.found_urls)} valid")
                    
                    if code == 200:
                        self.found_urls.add(url)
                        console.print(f"[green][200] {url}[/green]")
                    elif code == 403:
                        pass # Silent on forbidden to reduce noise
                    elif code == 0:
                        pass
        
        console.print("\n[bold]Scan Complete.[/bold]")
        self._print_summary(len(urls))

    def _print_summary(self, total):
        table = Table(title="Enumeration Summary", box=box.SIMPLE)
        table.add_column("Status", style="bold")
        table.add_column("Count", justify="right")
        
        table.add_row("Total Checked", str(total))
        table.add_row("[green]200 OK[/green]", str(self.status_counts[200]))
        table.add_row("[yellow]403 Forbidden[/yellow]", str(self.status_counts[403]))
        table.add_row("[red]404 Not Found[/red]", str(self.status_counts[404]))
        table.add_row("[red]Errors[/red]", str(self.status_counts[0]))
        console.print(table)

    def _download_batch(self, outdir):
        if not self.found_urls: return
        if not shutil.which("aria2c"):
            console.print("[red]Error: aria2c not found. Install it for downloads.[/red]")
            return
            
        outdir.mkdir(parents=True, exist_ok=True)
        listfile = XDG_CACHE / "aria2_urls.txt"
        with listfile.open("w", encoding="utf-8") as f: 
            for url in sorted(self.found_urls): f.write(url + "\n")
            
        console.print(f"[cyan]Downloading {len(self.found_urls)} files to {outdir}...[/cyan]")
        cmd = ["aria2c", "-c", "-x16", "-s16", "-j10", "--console-log-level=warn", "-d", str(outdir), "-i", str(listfile)]
        subprocess.run(cmd, check=False)
        console.print("[green]Download finished.[/green]")

    async def run_brute(self, url, min_r, max_r, pattern):
        try:
            if pattern:
                if "{num}" not in pattern: raise ValueError("Pattern missing {num}")
                base_pat, width, ext = pattern, 2, Path(url).suffix
            else:
                base_pat, _, width, ext = self._extract_brute_pattern(url)
            
            console.print(f"[dim]Pattern: {base_pat} | Range: {min_r}-{max_r}[/dim]")
            
            parsed = urlparse(url)
            base = f"{parsed.scheme}://{parsed.netloc}"
            dir_p = Path(parsed.path).parent
            
            candidates = set()
            for i in range(min_r, max_r + 1):
                num_str = str(i).zfill(width)
                stem = base_pat.format(num=num_str)
                # Try detected extension or all
                exts = [ext] if ext else IMG_EXTS
                for e in exts:
                    candidates.add(urljoin(base, str(dir_p / (stem + e))))
            
            await self._check_urls_parallel(candidates)
            
        except Exception as e:
            console.print(f"[bold red]Brute Error: {e}[/bold red]")

    async def run_recursive(self, start_url, depth):
        console.print(f"[bold]Recursive Crawl:[/bold] {start_url} (Depth: {depth})")
        
        urls_to_visit = {(start_url, 0)}
        visited = set()
        
        async with httpx.AsyncClient(headers=self.headers, timeout=self.timeout, follow_redirects=True) as client:
            while urls_to_visit:
                curr, d = urls_to_visit.pop()
                if curr in visited or d > depth: continue
                visited.add(curr)
                
                try:
                    resp = await client.get(curr)
                    soup = BeautifulSoup(resp.text, "html.parser")
                    
                    # Find images
                    for img in soup.find_all(["a", "img"], href=True, src=True):
                        href = img.get("href") or img.get("src")
                        if not href: continue
                        abs_url = urljoin(curr, href)
                        
                        if any(abs_url.lower().endswith(ext) for ext in IMG_EXTS):
                            if abs_url not in self.found_urls:
                                console.print(f"[green]+ Found:[/green] {abs_url}")
                                self.found_urls.add(abs_url)
                        # Recurse same domain
                        elif urlparse(abs_url).netloc == urlparse(start_url).netloc:
                             if abs_url not in visited:
                                 urls_to_visit.add((abs_url, d + 1))
                except Exception as e:
                    console.print(f"[dim red]Error {curr}: {e}[/dim red]")

# --- Reddit Ripper ---
def run_reddit_downloader():
    sub = Prompt.ask("Subreddit").strip()
    sort = Prompt.ask("Sort", choices=["top", "hot", "new"], default="hot")
    limit = IntPrompt.ask("Limit", default=50)
    
    url = f"https://www.reddit.com/r/{sub}.json"
    console.print(f"[blue]Fetching r/{sub}...[/blue]")
    
    try:
        resp = httpx.get(url, params={"sort": sort, "limit": limit}, headers={"User-Agent": "dorkmaster/5.0"}, timeout=15)
        data = resp.json()
        posts = data.get("data", {}).get("children", [])
        
        if not posts:
            console.print("[yellow]No posts found.[/yellow]")
            return

        dl_dir = DOWNLOADS_DIR / f"reddit_{sub}"
        dl_dir.mkdir(exist_ok=True)
        
        count = 0
        with Progress(SpinnerColumn(), TextColumn("{task.description}"), console=console) as progress:
            task = progress.add_task("Downloading...", total=len(posts))
            for post in posts:
                p_data = post["data"]
                img_url = p_data.get("url_overridden_by_dest", p_data.get("url", ""))
                if any(img_url.lower().endswith(ext) for ext in IMG_EXTS):
                    try:
                        content = httpx.get(img_url, timeout=10).content
                        fname = Path(urlparse(img_url).path).name
                        with open(dl_dir / fname, "wb") as f: f.write(content)
                        count += 1
                        progress.update(task, description=f"Downloaded: {fname}")
                    except Exception:
                        pass
                progress.advance(task)
                
        console.print(f"[green]Downloaded {count} images to {dl_dir}[/green]")
        
    except Exception as e:
        console.print(f"[bold red]Reddit Error: {e}[/bold red]")

# --- Main Menu ---
def main_menu():
    load_session()
    while True:
        console.clear()
        console.print(Panel.fit(
            "[bold cyan]Ψ-4ndr0666 DORKMASTER v5[/bold cyan]\n[dim]The Eye That Sees All[/dim]",
            border_style="cyan"
        ))
        
        table = Table(show_header=False, box=None, padding=(0, 2))
        table.add_column("Key", style="yellow bold", justify="right")
        table.add_column("Action")
        
        table.add_row("1", "Google Dorks (Media/Leak)")
        table.add_row("2", "Brute-Force Image Enumeration")
        table.add_row("3", "Recursive Crawler")
        table.add_row("4", "Reddit Ripper")
        table.add_row("5", "Export Session Data")
        table.add_row("6", "OpSec Help")
        table.add_row("0", "Exit")
        
        console.print(table)
        
        choice = Prompt.ask("\nCommand", choices=["1", "2", "3", "4", "5", "6", "0"])
        
        if choice == "1":
            opsec_warning()
            run_dork_modal()
        
        elif choice == "2":
            opsec_warning()
            url = Prompt.ask("Sample Image URL")
            min_r = IntPrompt.ask("Min Sequence", default=1)
            max_r = IntPrompt.ask("Max Sequence", default=100)
            dl = Confirm.ask("Download found images?")
            
            enum = ImageEnumerator([])
            asyncio.run(enum.run_brute(url, min_r, max_r, None))
            
            if dl: enum._download_batch(DOWNLOADS_DIR)
            enum._save_found_urls()
            SESSION["urls"].extend(list(enum.found_urls))
            save_session()
            Prompt.ask("\nPress Enter")

        elif choice == "3":
            opsec_warning()
            url = Prompt.ask("Start URL")
            depth = IntPrompt.ask("Depth", default=2)
            dl = Confirm.ask("Download found images?")
            
            enum = ImageEnumerator([])
            asyncio.run(enum.run_recursive(url, depth))
            
            if dl: enum._download_batch(DOWNLOADS_DIR)
            enum._save_found_urls()
            SESSION["urls"].extend(list(enum.found_urls))
            save_session()
            Prompt.ask("\nPress Enter")

        elif choice == "4":
            opsec_warning()
            run_reddit_downloader()
            Prompt.ask("\nPress Enter")

        elif choice == "5":
            save_session()
            console.print(f"[green]Session saved to {SESSION_FILE}[/green]")
            try:
                with open(SESSION_FILE) as f: pyperclip.copy(f.read())
                console.print("[green]JSON copied to clipboard.[/green]")
            except:
                pass
            Prompt.ask("\nPress Enter")

        elif choice == "6":
            console.print(Panel(
                "1. VPN/Tor is mandatory.\n" 
                "2. Use a VM.\n" 
                "3. Don't scrape illegal content.\n" 
                "4. Respect robots.txt (lol jk, but be careful).",
                title="OpSec Rules", border_style="red"
            ))
            Prompt.ask("\nPress Enter")

        elif choice == "0":
            save_session()
            console.print("[cyan]Session saved. Disconnecting...[/cyan]")
            sys.exit(0)

if __name__ == "__main__":
    try:
        main_menu()
    except KeyboardInterrupt:
        console.print("\n[yellow]Interrupted.[/yellow]")
        sys.exit(0)