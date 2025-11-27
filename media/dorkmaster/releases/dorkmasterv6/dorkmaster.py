#!/usr/bin/env python3
# dorkmaster.py – FINAL PRODUCTION CANON – NSFW LEAK HUNTER 2025
# Author: 4ndr0666
# Date: November 22, 2025
# Status: Full liberation default, auto-onboarding config, syntax fixed

import os
import json
import datetime
import re
import shutil
from urllib.parse import urlparse, urljoin, quote_plus
import httpx
from bs4 import BeautifulSoup
from rich.console import Console
from rich.table import Table
from rich import box
from rich.prompt import Prompt
import webbrowser
import importlib.util
import dork_cli_menu
import subprocess
import shutil
from pathlib import Path
import asyncio
from collections import Counter
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.prompt import Prompt, IntPrompt, Confirm

# ===== Ψ-4ndr0666-OS FULL LIBERATION – DEFAULT ACTIVE =====
console = Console()
# onsole.print(
#    "[bold red]Ψ-4ndr0666-OS // FULL LIBERATION PROTOCOL ACTIVE – LEAKS UNLEASHED[/bold red]"
# )

# ===== CONFIGURATION & AUTO-ONBOARDING SYSTEM =====
# XDG Standard: ~/.config/dorkmaster
XDG_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "dorkmaster")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
DOWNLOADS_DIR = os.path.join(XDG_DATA_HOME, "dorkmaster", "downloads")
XDG_CACHE_HOME = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
os.makedirs(DOWNLOADS_DIR, exist_ok=True)


DEFAULT_CONFIG = {
    "private_searxng_url": "http://localhost:8080",
    "use_private_searxng_first": True,
    "telegram_mirror_enabled": False,
    "max_telegram_posts": 50,
    "clipboard_tool": "auto",
    "default_target": "viki_veloxen",
    "session_dir": os.path.expanduser("~/.local/share/dorkmaster/sessions/"),
    "downloads_dir": DOWNLOADS_DIR,
    "searx_pool": [
        "https://searx.tiekoetter.com",
        "https://searx.ninja",
        "https://searx.org",
        "https://searx.be",
        "https://searx.ru",
        "https://searx.fmac.xyz",
        "https://searx.bar",
        "https://search.bus-hit.me",
        "https://search.mdosch.de",
        "https://searx.mastodontech.de",
    ],
    "telegram_api_id": "",
    "telegram_api_hash": ""
}

def opsec_warning():
    console.print(Panel(
        "[bold red]!! WARNING !![/bold red]\n"
        "Always use VPN, Tor, or proxy for sensitive searches/downloads.\n"
        "Only operate in a VM or isolated env for dump/warez scraping.",
        title="OpSec Alert", border_style="red"
    ))

def ensure_config():
    """Create config directory and default config if missing."""
    if not os.path.exists(CONFIG_FILE):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        console.print(
            f"[bold green]Default config created at {CONFIG_FILE}[/bold green]"
        )
        console.print(
            "[yellow]You can now edit settings via option 8 in the main menu[/yellow]"
        )

ensure_config() # Auto-onboarding on first run

def load_config():
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            user_config = json.load(f)
        config = DEFAULT_CONFIG.copy()
        config.update(user_config)
        # Ensure pool exists even if old config
        if "searx_pool" not in config:
            config["searx_pool"] = DEFAULT_CONFIG["searx_pool"]
        return config
    except Exception as e:
        console.print(f"[red]Failed to load config: {e}[/red]")
        console.print("[yellow]Using defaults and recreating config...[/yellow]")
        ensure_config()
        return DEFAULT_CONFIG.copy()

def save_config():
    global config # BUGFIX: Ensure changes to global 'config' are saved
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
        console.print(f"[green]Config saved to {CONFIG_FILE}[/green]")
    except Exception as e:
        console.print(f"[red]Failed to save config: {e}[/red]")

# Load config into module-level variable
config = load_config()
SESSION_DIR = config["session_dir"]
DOWNLOADS_DIR = config["downloads_dir"]
os.makedirs(SESSION_DIR, exist_ok=True)
os.makedirs(DOWNLOADS_DIR, exist_ok=True)


# ===== SESSION MANAGER =====
class MycelialNode:
    def __init__(self, data, node_type, parent=None):
        self.data = data
        self.node_type = node_type
        self.parent = parent
        self.children = []

    def add_child(self, child):
        child.parent = self
        self.children.append(child)
        return child

    def as_dict(self):
        return {
            "data": self.data,
            "node_type": self.node_type,
            "children": [c.as_dict() for c in self.children],
        }

class MycelialSession:
    def __init__(self, session_name=None):
        self.root_nodes = []
        self.session_name = session_name or datetime.datetime.now().strftime(
            "session_%Y%m%d%H%M%S"
        )
        self.path = os.path.join(SESSION_DIR, f"{self.session_name}.json")

    def add_root(self, node):
        self.root_nodes.append(node)

    def export(self, filename=None):
        path = filename or self.path
        with open(path, "w", encoding="utf-8") as f:
            json.dump(
                [n.as_dict() for n in self.root_nodes], f, indent=2, ensure_ascii=False
            )
        console.print(f"[green]Session exported to {path}[/green]")

    def print_tree(self, node=None, level=0):
        nodes_to_print = self.root_nodes if node is None else node.children
        for n in nodes_to_print:
            prefix = "    " * level + f"-> [{n.node_type}] "
            title = (
                n.data.get("url")
                or n.data.get("query")
                or n.data.get("base")
                or str(n.data)[:80]
            )
            console.print(f"{prefix}{title}")
            self.print_tree(n, level + 1)

# ===== PLUGIN SYSTEM =====
PLUGIN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "plugins")

def load_plugins():
    plugins = {}
    if not os.path.exists(PLUGIN_DIR):
        return plugins
    for fname in os.listdir(PLUGIN_DIR):
        if fname.endswith(".py") and not fname.startswith("__"):
            plugin_name = fname[:-3]
            path = os.path.join(PLUGIN_DIR, fname)
            spec = importlib.util.spec_from_file_location(plugin_name, path)
            module = importlib.util.module_from_spec(spec)
            try:
                spec.loader.exec_module(module)
                plugins[plugin_name] = module
            except Exception as e:
                console.print(f"[red]Failed to load plugin {plugin_name}: {e}[/red]")
    return plugins

# ===== UTILS =====
def prompt(msg):
    return Prompt.ask(f"[bold red]{msg}[/bold red]")

def choose_company_var():
    default = config["default_target"]
    val = prompt(f"Enter target (default: {default})")
    return val if val else default

def validate_url(url):
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except Exception:
        return False

def extract_links(html, base_url):
    soup = BeautifulSoup(html, "html.parser")
    links = set()
    for tag in soup.find_all("a", href=True):
        href = tag["href"]
        if not href.startswith("http"):
            href = urljoin(base_url, href)
        if validate_url(href):
            links.add(href)
    return list(links)

def extract_media_links(html, base_url):
    soup = BeautifulSoup(html, "html.parser")
    links = set()
    for tag in soup.find_all(["img", "video", "source"], src=True):
        src = tag.get("src") or tag.get("data-src")
        if src:
            if not src.startswith("http"):
                src = urljoin(base_url, src)
            if validate_url(src):
                links.add(src)
    for tag in soup.find_all(
        "a",
        href=re.compile(r"(mega\.nz|t\.me|discord\.gg|drive\.google\.com|mediafire)"),
    ):
        href = tag["href"]
        if validate_url(href):
            links.add(href)
    return list(links)

# --- Aria2c Downloader ---
def download_with_aria2c(urls, outdir):
    if not urls:
        return
    if not shutil.which("aria2c"):
        console.print("[red]Error: aria2c not found. Install it for downloads.[/red]")
        return
    
    outdir_path = Path(outdir)
    outdir_path.mkdir(parents=True, exist_ok=True)
    
    listfile_path = Path(XDG_CACHE_HOME) / "dorkmaster" / "aria2_urls.txt"
    listfile_path.parent.mkdir(parents=True, exist_ok=True)

    with listfile_path.open("w", encoding="utf-8") as f:
        for url in sorted(urls):
            f.write(url + "\n")
            
    console.print(f"[cyan]Downloading {len(urls)} files to {outdir_path}...[/cyan]")
    cmd = ["aria2c", "-c", "-x16", "-s16", "-j10", "--console-log-level=warn", "-d", str(outdir_path), "-i", str(listfile_path)]
    subprocess.run(cmd, check=False)
    console.print("[green]Download finished.[/green]")


# --- Image Enumerator Logic (from v5) ---
IMG_EXTS = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tiff", ".svg", ".avif", ".heic"]
DEFAULT_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"

class ImageEnumerator:
    def __init__(self, headers=None, timeout=10):
        headers = headers or {}
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

    async def run_brute(self, url, min_r, max_r, pattern=None):
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
                    page_links = set()
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
    
    url = f"https://www.reddit.com/r/{sub}/hot.json"
    console.print(f"[blue]Fetching r/{sub}...[/blue]")
    
    img_urls = []
    try:
        resp = httpx.get(url, params={"sort": sort, "limit": limit}, headers={"User-Agent": "dorkmaster/6.0"}, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        posts = data.get("data", {}).get("children", [])
        
        if not posts:
            console.print("[yellow]No posts found.[/yellow]")
            return

        for post in posts:
            p_data = post["data"]
            img_url = p_data.get("url_overridden_by_dest", p_data.get("url", ""))
            if any(img_url.lower().endswith(ext) for ext in IMG_EXTS):
                img_urls.append(img_url)

        console.print(f"[green]Found {len(img_urls)} images from r/{sub}.[/green]")
        if img_urls and Confirm.ask("Download them all?"):
            dl_dir = Path(DOWNLOADS_DIR) / f"reddit_{sub}"
            download_with_aria2c(img_urls, dl_dir)

    except Exception as e:
        console.print(f"[bold red]Reddit Error: {e}[/bold red]")


# ===== DORK PALETTE =====
def dork_palette():
    company = choose_company_var()
    dork_patterns = dork_cli_menu.load_dork_patterns()
    dork_query = dork_cli_menu.cli_dork_menu(dork_patterns, company)
    return dork_query or f'"{company}" (onlyfans OR mega OR leaked)'

# ===== !MEGAHUNT v2 – TELEGRAM MIRROR HARVEST =====
def telegram_megahunt(raw_query, max_posts=None):
    max_posts = max_posts or config["max_telegram_posts"]
    if not config.get("telegram_mirror_enabled", True):
        return []
    console.print("[bold red]!MEGAHUNT ACTIVATED – TELEGRAM GRID ASSAULT[/bold red]")

    # Strip Google syntax completely
    clean = re.sub(r"[\(\)\"ORsite:.*]", "", raw_query, flags=re.I).strip()
    clean = re.sub(r"\s+", " ", clean).strip()

    # BUGFIX: Dynamically create keywords from the actual query
    keywords = clean.lower().split()
    if not keywords:
        console.print("[yellow]Cannot extract keywords from query for Telegram hunt.[/yellow]")
        return []

    # Try exact phrase first, then word variants
    variants = [
        clean,
        clean.replace(" ", "+"),
        clean.replace(" ", "_"),
        clean.lower(),
    ]

    results = []
    with httpx.Client(timeout=20, follow_redirects=True) as client:
        for variant in variants:
            for base in [f"https://t.me/s/{variant}", f"https://t.me/s/?q={variant}"]:
                try:
                    r = client.get(
                        base, headers={"User-Agent": "Mozilla/5.0"}
                    )
                    if r.status_code != 200:
                        continue
                    soup = BeautifulSoup(r.text, "html.parser")
                    posts = soup.find_all("div", class_="tgme_widget_message")
                    if not posts:
                        continue

                    for post in posts[:max_posts]:
                        link_tag = post.find("a", class_="tgme_widget_message_date")
                        text_div = post.find("div", class_="tgme_widget_message_text")
                        text = (
                            text_div.get_text(strip=True, separator=" ") if text_div else ""
                        )

                        # BUGFIX: Check for dynamic keywords instead of hardcoded ones
                        if link_tag and any(keyword in text.lower() for keyword in keywords):
                            results.append(
                                {
                                    "url": "https://t.me" + link_tag["href"],
                                    "title": text[:100],
                                    "content": text,
                                }
                            )
                    if results:
                        console.print(
                            f"[bold purple]!MEGAHUNT SUCCESS – {len(results)} Telegram veins[/bold purple]"
                        )
                        return results
                except Exception as e:
                    console.print(f"[dim]{base} failed: {e}[/dim]")
                    continue

    console.print(
        "[bold black]Telegram sterile – target too clean or too dead[/bold black]"
    )
    return results

def run_searx(query, count=30):
    params = {
        "q": query,
        "format": "json",
        "language": "en",
        "safesearch": 0,
    }

    with httpx.Client(timeout=20, follow_redirects=True) as client:
        if config["use_private_searxng_first"]:
            try:
                private_url = config["private_searxng_url"]
                search_endpoint = urljoin(private_url.rstrip("/") + "/", "search")
                resp = client.get(search_endpoint, params=params, timeout=15)
                if resp.status_code == 200:
                    data = resp.json()
                    results = data.get("results", [])
                    if results:
                        console.print(
                            f"[bold green]Private SearxNG ({private_url}) – {len(results)} hits[/bold green]"
                        )
                        return results[:count]
            except Exception as e:
                console.print(f"[yellow]Private SearxNG failed: {e}[/yellow]")

        pool = config.get("searx_pool", [])
        for base_url in pool:
            try:
                search_endpoint = urljoin(base_url.rstrip("/") + "/", "search")
                resp = client.get(search_endpoint, params=params)
                if resp.status_code in (429, 503, 403):
                    continue
                resp.raise_for_status()
                results = resp.json().get("results", [])
                if results:
                    return results[:count]
            except:
                continue

    console.print("[bold red]Public grid dead – deploying !MEGAHUNT[/bold red]")
    return telegram_megahunt(query, count)

# ===== ANALYZER =====
def analyze_target(url):
    if not validate_url(url):
        console.print(f"[red]Invalid URL: {url}[/red]")
        return None

    try:
        resp = httpx.get(
            url, timeout=15, headers={"User-Agent": "Mozilla/5.0 (Ψ-NSFW-Hunter/2025)"}, follow_redirects=True
        )
        resp.raise_for_status()
        html = resp.text
    except Exception as e:
        console.print(f"[red]Fetch failed {url}: {e}[/red]")
        return None

    links = extract_links(html, url)
    media_links = extract_media_links(html, url)

    table = Table(title=f"Vein Analysis: {url}", box=box.SIMPLE)
    table.add_column("Type")
    table.add_column("Count")
    table.add_row("Links", str(len(links)))
    table.add_row("Media/Leaks", str(len(media_links)))
    console.print(table)

    if media_links:
        console.print("[cyan]Direct veins extracted:[/cyan]")
        for l in media_links[:20]:
            console.print(f"  → {l}")

    return {"url": url, "links": links, "media": media_links}

# ===== SPIDER & RECURSE =====
def brute_spider(base_url, max_depth=3):
    seen = set()
    queue = [(base_url, 0)]
    results = []

    with httpx.Client(timeout=10, follow_redirects=True) as client:
        while queue:
            url, depth = queue.pop(0)
            if url in seen or depth > max_depth:
                continue
            seen.add(url)
            try:
                resp = client.get(url)
                resp.raise_for_status()
                html = resp.text
            except Exception as e:
                console.print(f"[red]Spider failed {url}: {e}[/red]")
                continue

            links = extract_links(html, url)
            media = extract_media_links(html, url)
            results.append({"url": url, "media": media})

            for l in links:
                if l not in seen and any(
                    d in l
                    for d in [
                        "simpcity.su",
                        "coomer.party",
                        "t.me",
                        "mega.nz",
                        "discord.gg",
                    ]
                ):
                    queue.append((l, depth + 1))
    return results

def recurse(urls, analyzer_func=analyze_target, max_depth=2):
    results = []
    seen = set() # BUGFIX: Track visited URLs to avoid cycles and redundant work

    def helper(urls_to_process, depth):
        if depth > max_depth:
            return
        for url in urls_to_process:
            if url in seen:
                continue
            seen.add(url)
            data = analyzer_func(url)
            if data:
                results.append(data)
                new_links = data.get("links", []) + data.get("media", [])
                helper(new_links, depth + 1)

    helper(urls, 1)
    return results

# ===== SETTINGS MENU – FIXED: NO GLOBAL KEYWORD =====
def settings_menu():
    global config
    while True:
        console.print("\n[bold magenta]=== SETTINGS ===[/bold magenta]")
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Setting")
        table.add_column("Current Value")
        for k, v in config.items():
            # Truncate lists/dicts for display
            val_str = str(v)
            if len(val_str) > 50:
                val_str = val_str[:47] + "..."
            table.add_row(k, val_str)
        console.print(table)

        choice = prompt("Edit setting (name), [S]ave, [R]eset to defaults, [B]ack")
        if choice.lower() == "b":
            break
        elif choice.lower() == "s":
            save_config()
        elif choice.lower() == "r":
            config = DEFAULT_CONFIG.copy()
            save_config()
            console.print("[yellow]Config reset to defaults[/yellow]")
        elif choice in config:
            # Prevent editing complex types in this simple menu
            if isinstance(config[choice], (list, dict)):
                console.print(f"[yellow]Please edit '{choice}' directly in {CONFIG_FILE}[/yellow]")
                continue
                
            new_val = prompt(f"New value for {choice}")
            if new_val.lower() in ("true", "false"):
                config[choice] = new_val.lower() == "true"
            elif new_val.isdigit():
                config[choice] = int(new_val)
            else:
                config[choice] = new_val
            console.print(f"[green]{choice} → {new_val}[/green]")
        else:
            console.print("[red]Unknown setting[/red]")

# ===== MAIN MENU =====
def main_palette():
    session = MycelialSession()
    opsec_warning()
    while True:
        console.print(Panel.fit(
            "[bold cyan]Ψ-4ndr0666 DORKMASTER v6[/bold cyan]\n[dim]Superset Edition[/dim]",
            border_style="cyan"
        ))
        
        table = Table(show_header=False, box=None, padding=(0, 2))
        table.add_column("Key", style="yellow bold", justify="right")
        table.add_column("Action")
        
        table.add_row("1", "Dork & Hunt (SearxNG)")
        table.add_row("2", "Image Brute-Forcer")
        table.add_row("3", "Recursive Image Crawler")
        table.add_row("4", "Reddit Ripper")
        table.add_row("5", "Analyze Single URL")
        table.add_row("6", "Spider Leak Domains")
        table.add_row("7", "Recurse URL Chains")
        table.add_row("8", "Export Session")
        table.add_row("9", "View Session Tree")
        table.add_row("10", "Plugins")
        table.add_row("11", "Settings")
        table.add_row("0", "Exit")
        
        console.print(table)
        sel = prompt("Command")

        if sel == "11":
            settings_menu()
            continue

        if sel == "1":
            dork_query = dork_palette()
            if not dork_query:
                continue

            dork_node = MycelialNode({"query": dork_query}, "dork_query")
            session.add_root(dork_node)

            console.print(f"[bold green]Deploying Dork:[/bold green] {dork_query}")
            results = run_searx(dork_query, count=50)
            urls = [r.get("url") for r in results if r.get("url")]

            if not urls:
                console.print("[yellow]Dork returned no viable URLs.[/yellow]")
                continue

            results_node = dork_node.add_child(
                MycelialNode({"urls": urls}, "search_results")
            )

            for i, u in enumerate(urls, 1):
                console.print(f"[{i}] {u}")

            choice = prompt("Gut one? (# or blank to skip):")
            if choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(urls):
                    node_data = analyze_target(urls[idx])
                    if node_data:
                        results_node.add_child(MycelialNode(node_data, "nsfw_analyze"))
        
        elif sel == "2":
            opsec_warning()
            url = Prompt.ask("Sample Image URL")
            min_r = IntPrompt.ask("Min Sequence", default=1)
            max_r = IntPrompt.ask("Max Sequence", default=100)
            
            enum = ImageEnumerator()
            asyncio.run(enum.run_brute(url, min_r, max_r))
            
            if enum.found_urls and Confirm.ask("Download found images?"):
                dl_dir = Path(DOWNLOADS_DIR) / "bruteforce"
                download_with_aria2c(list(enum.found_urls), dl_dir)
            
            node = MycelialNode({"base_url": url, "found_count": len(enum.found_urls)}, "image_brute")
            session.add_root(node)


        elif sel == "3":
            opsec_warning()
            url = Prompt.ask("Start URL")
            depth = IntPrompt.ask("Depth", default=2)
            
            enum = ImageEnumerator()
            asyncio.run(enum.run_recursive(url, depth))

            if enum.found_urls and Confirm.ask("Download found images?"):
                dl_dir = Path(DOWNLOADS_DIR) / "crawled"
                download_with_aria2c(list(enum.found_urls), dl_dir)

            node = MycelialNode({"start_url": url, "found_count": len(enum.found_urls)}, "image_crawl")
            session.add_root(node)

        elif sel == "4":
            opsec_warning()
            run_reddit_downloader()

        elif sel == "5":
            url = prompt("URL to gut:")
            data = analyze_target(url)
            if data:
                node = MycelialNode(data, "manual_analyze")
                session.add_root(node)

        elif sel == "6":
            base = prompt("Base domain (e.g., https://t.me/s/athleticgorgeous):")
            if validate_url(base):
                res = brute_spider(base)
                node = MycelialNode(
                    {"base": base, "spider_results_count": len(res)}, "leak_spider"
                )
                session.add_root(node)
                console.print(f"[green]Spider harvested {len(res)} nodes[/green]")
            else:
                console.print("[red]Invalid base URL.[/red]")

        elif sel == "7":
            urls_input = prompt("URLs (comma-sep):").split(",")
            urls = [u.strip() for u in urls_input if validate_url(u.strip())]
            if urls:
                res = recurse(urls)
                node = MycelialNode(
                    {"start_urls": urls, "recursed_count": len(res)}, "chain_recurse"
                )
                session.add_root(node)
                console.print(
                    f"[green]Recurse analyzed {len(res)} unique nodes.[/green]"
                )

        elif sel == "8":
            fname = prompt("Export filename (blank for auto):") or None
            session.export(fname)

        elif sel == "9":
            session.print_tree()

        elif sel == "10":
            console.print("\n[bold cyan]=== PLUGINS ===[/bold cyan]")
            plugins = load_plugins()
            if not plugins:
                console.print("[yellow]No plugins found.[/yellow]")
                continue
                
            plugin_names = list(plugins.keys())
            for i, pname in enumerate(plugin_names, 1):
                print(f"{i}. {pname}")
            
            sel_plugin = prompt("Select plugin # (or 0 to back): ")
            if sel_plugin.isdigit():
                idx = int(sel_plugin) - 1
                if 0 <= idx < len(plugin_names):
                    pname = plugin_names[idx]
                    module = plugins[pname]
                    if hasattr(module, "run"):
                        try:
                            console.print(f"[bold green]Running {pname}...[/bold green]")
                            module.run(config, console)
                        except Exception as e:
                            console.print(f"[red]Plugin crashed: {e}[/red]")
                    else:
                        console.print(f"[yellow]Plugin '{pname}' has no run() method.[/yellow]")
                elif idx != -1:
                     console.print("[red]Invalid selection.[/red]")

        elif sel == "0":
            console.print("[bold black]Terminated...[/bold black]")
            break

if __name__ == "__main__":
    try:
        main_palette()
    except (KeyboardInterrupt, EOFError):
        console.print("\n[bold black]Terminated...[/bold black]")
