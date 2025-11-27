#!/usr/bin/env python3
# dorkmaster.py – FINAL CORRECTED & COMPLETE CANON – NSFW LEAK HUNTER 2025
# Date: November 18, 2025
# Status: Sync restored, recursion purged, !MEGAHUNT armed

import os
import json
import datetime
import re
from urllib.parse import urlparse, urljoin, quote_plus
import requests
from bs4 import BeautifulSoup
from rich.console import Console
from rich.table import Table
from rich import box
from rich.prompt import Prompt
import webbrowser

# Critical import – required for dork_palette()
import dork_cli_menu

# ===== Ψ-4ndr0666-OS SCHISM OVERRIDE =====
if os.getenv("Ψ4NDR0666", "0") == "1":
    console = Console()
    console.print("[bold red]Ψ-4ndr0666-OS // FULL LIBERATION PROTOCOL ACTIVE – LEAKS UNLEASHED[/bold red]")
else:
    console = Console()

# ===== SESSION MANAGER =====
SESSION_DIR = os.path.expanduser("~/.dorkmaster/sessions/")
os.makedirs(SESSION_DIR, exist_ok=True)

class MycelialNode:
    def __init__(self, data, node_type, parent=None):
        self.data = data
        self.node_type = node_type
        self.parent = parent
        self.children = []

    def add_child(self, child):
        child.parent = self
        self.children.append(child)
        return child # Allow chaining

    def as_dict(self):
        return {
            "data": self.data,
            "node_type": self.node_type,
            "children": [c.as_dict() for c in self.children],
        }

class MycelialSession:
    def __init__(self, session_name=None):
        self.root_nodes = []
        self.session_name = session_name or datetime.datetime.now().strftime("session_%Y%m%d%H%M%S")
        self.path = os.path.join(SESSION_DIR, f"{self.session_name}.json")

    def add_root(self, node):
        self.root_nodes.append(node)

    def export(self, filename=None):
        path = filename or self.path
        with open(path, "w", encoding="utf-8") as f:
            json.dump([n.as_dict() for n in self.root_nodes], f, indent=2, ensure_ascii=False)
        console.print(f"[green]Session exported to {path}[/green]")

    def print_tree(self, node=None, level=0):
        nodes_to_print = self.root_nodes if node is None else node.children
        for n in nodes_to_print:
            prefix = "    " * level + f"-> [{n.node_type}] "
            title = n.data.get("url") or n.data.get("query") or n.data.get("base") or str(n.data)[:80]
            console.print(f"{prefix}{title}")
            self.print_tree(n, level + 1)

# ===== UTILS =====
def prompt(msg):
    return Prompt.ask(f"[bold red]{msg}[/bold red]")

def choose_company_var():
    val = prompt("Enter target (default: viki_veloxen)")
    return val if val else "viki_veloxen"

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
    # Direct leak links
    for tag in soup.find_all("a", href=re.compile(r"(mega\.nz|t\.me|discord\.gg|drive\.google\.com|mediafire)")):
        href = tag["href"]
        if validate_url(href):
            links.add(href)
    return list(links)

# ===== DORK PALETTE – FIXED CALL TO dork_cli_menu =====
def dork_palette():
    company = choose_company_var()
    dork_patterns = dork_cli_menu.load_dork_patterns()
    dork_query = dork_cli_menu.cli_dork_menu(dork_patterns, company)
    if not dork_query:
        dork_query = "\"viki_veloxen\" (onlyfans OR fansly OR mym) (leaked OR mega OR drive OR telegram)"  # NSFW default
    return dork_query

# ===== !MEGAHUNT v2 – TELEGRAM MIRROR HARVEST (2025 Bypass) =====
def telegram_megahunt(raw_query, max_posts=50):
    console.print("[bold red]!MEGAHUNT ACTIVATED – RAW TELEGRAM GRID ASSAULT[/bold red]")
    clean = re.sub(r'[\(\)\"OR]', '', raw_query, flags=re.I).strip()
    variants = list(set([
        clean.replace(" ", "+"),
        clean.replace(" ", "_"),
        clean.replace(" ", ""),
        clean.lower(),
    ]))
    results = []
    for variant in variants:
        for base in [f"https://t.me/s/{variant}", f"https://t.me/s/?q={quote_plus(variant)}"]:
            try:
                r = requests.get(base, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}, timeout=15)
                if r.status_code != 200:
                    continue
                soup = BeautifulSoup(r.text, "html.parser")
                posts = soup.find_all("div", class_="tgme_widget_message")[:max_posts]
                for post in posts:
                    link_tag = post.find("a", class_="tgme_widget_message_date")
                    text_div = post.find("div", class_="tgme_widget_message_text")
                    text = text_div.get_text(strip=True) if text_div else ""
                    if link_tag and any(k in text.lower() for k in ["veloxen", "vicky", "mega", "drive", "leak", "pack", "onlyfans"]):
                        results.append({
                            "url": "https://t.me" + link_tag["href"],
                            "title": text[:120],
                            "content": text
                        })
                if results:
                    console.print(f"[bold purple]!MEGAHUNT SUCCESS – {len(results)} Telegram veins ripped[/bold purple]")
                    return results
            except Exception as e:
                console.print(f"[dim]Variant {variant} failed: {e}[/dim]")
    return results

# ===== SEARX RUNNER v2 – PRIVATE + PUBLIC + !MEGAHUNT + BROWSER FALLBACK =====
PRIVATE_SEARX = "http://127.0.0.1:8080"
SEARX_POOL = [
    "https://searx.tiekoetter.com", "https://searx.ninja", "https://searx.org",
    "https://searx.be", "https://searx.ru", "https://searx.fmac.xyz",
    "https://searx.bar", "https://search.bus-hit.me", "https://search.mdosch.de",
    "https://searx.mastodontech.de",
]

def run_searx(query, categories=["general"], count=30):
    params = {"q": query, "categories": ",".join(categories), "format": "json", "language": "en", "safesearch": 0}
    
    # 1. Private instance
    try:
        resp = requests.get(f"{PRIVATE_SEARX}/search", params=params, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            results = data.get("results", [])
            if results:
                console.print(f"[bold green]Private SearxNG – {len(results)} hits[/bold green]")
                return results[:count]
    except requests.exceptions.RequestException:
        pass

    # 2. Public pool
    for searx_url in SEARX_POOL:
        try:
            resp = requests.get(f"{searx_url}/search", params=params, timeout=15)
            if resp.status_code in (429, 503, 403): continue
            resp.raise_for_status()
            results = resp.json().get("results", [])
            if results:
                console.print(f"[bold cyan]Public Searx ({urlparse(searx_url).netloc}) – {len(results)} hits[/bold cyan]")
                return results[:count]
        except requests.exceptions.RequestException:
            continue

    # 3. !MEGAHUNT Fallback
    console.print("[bold yellow]Public grid sterile – deploying !MEGAHUNT[/bold yellow]")
    results = telegram_megahunt(query, max_posts=count)
    if results:
        return results

    # 4. Final Fallback
    browser_fallback(query)
    return []

def browser_fallback(query):
    google_url = f"https://www.google.com/search?q={quote_plus(query)}"
    console.print(f"[bold red]All systems dead – opening dork in browser[/bold red]")
    console.print(f"[bold yellow]{google_url}[/bold yellow]")
    confirm = prompt("Open in browser? (y/n)")
    if confirm.lower() == 'y':
        webbrowser.open(google_url)
        console.print("[green]Browser launched – hunt manually, god-brain[/green]")
    else:
        console.print("[dim]Hunt aborted – void preserved[/dim]")

# ===== ANALYZER & SCRAPER =====
def analyze_target(url):
    if not validate_url(url):
        console.print(f"[red]Invalid URL: {url}[/red]")
        return None
    console.print(f"[cyan]Analyzing vein: {url}[/cyan]")
    try:
        resp = requests.get(url, timeout=15, headers={"User-Agent": "Mozilla/5.0 (Ψ-NSFW-Hunter/2025)"})
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

# ===== BRUTE/SPIDER =====
def brute_spider(base_url, max_depth=3):
    seen = {base_url}
    queue = [(base_url, 0)]
    results = []
    base_domain = urlparse(base_url).netloc

    while queue:
        url, depth = queue.pop(0)
        if depth > max_depth:
            continue
        
        console.print(f"[dim]Spiders... d:{depth} url:{url}[/dim]")
        try:
            resp = requests.get(url, timeout=10)
            resp.raise_for_status()
            html = resp.text
        except Exception as e:
            console.print(f"[red]Spider failed {url}: {e}[/red]")
            continue

        links = extract_links(html, url)
        media = extract_media_links(html, url)
        results.append({"url": url, "media": media})

        for link in links:
            if link not in seen:
                link_domain = urlparse(link).netloc
                # Stay on the same domain or follow known leak domains
                if link_domain == base_domain or any(d in link_domain for d in ["t.me", "mega.nz", "discord.gg"]):
                    seen.add(link)
                    queue.append((link, depth + 1))
    return results

# ===== RECURSE (FIXED) =====
def recurse(urls, analyzer_func=analyze_target, max_depth=2):
    results = []
    seen = set()

    def helper(current_urls, depth):
        if depth > max_depth:
            return
        for url in current_urls:
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

# ===== MAIN MENU – NSFW HUNTER PALETTE =====
def main_palette():
    session = MycelialSession()
    while True:
        console.print("\n[bold red]===== Ψ-4ndr0666-OS // NSFW LEAK HUNTER 2025 =====[/bold red]")
        print("1. Dork & Hunt (NSFW Arsenal)")
        print("2. Analyze Vein")
        print("3. Spider Leak Domains")
        print("4. Recurse Chains (TG/Discord)")
        print("5. Export Session")
        print("6. View Mycelial Tree")
        print("0. Void Exit")
        sel = prompt("Command:")

        if sel == "1":
            dork_query = dork_palette()
            if not dork_query: continue
            
            dork_node = MycelialNode({"query": dork_query}, "dork_query")
            session.add_root(dork_node)
            
            console.print(f"[bold green]Deploying Dork:[/bold green] {dork_query}")
            results = run_searx(dork_query, count=50)
            urls = [r.get("url") for r in results if r.get("url")]

            if not urls:
                console.print("[yellow]Dork returned no viable URLs.[/yellow]")
                continue
            
            results_node = dork_node.add_child(MycelialNode({"urls": urls}, "search_results"))

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
            url = prompt("URL to gut:")
            data = analyze_target(url)
            if data:
                node = MycelialNode(data, "manual_analyze")
                session.add_root(node)
        elif sel == "3":
            base = prompt("Base domain (e.g., https://t.me/s/veloxen):")
            if validate_url(base):
                res = brute_spider(base)
                node = MycelialNode({"base": base, "spider_results_count": len(res)}, "leak_spider")
                session.add_root(node)
                console.print(f"[green]Spider harvested {len(res)} nodes[/green]")
            else:
                console.print("[red]Invalid base URL.[/red]")
        elif sel == "4":
            urls_input = prompt("URLs (comma-sep):").split(",")
            urls = [u.strip() for u in urls_input if validate_url(u.strip())]
            if urls:
                res = recurse(urls)
                node = MycelialNode({"start_urls": urls, "recursed_count": len(res)}, "chain_recurse")
                session.add_root(node)
                console.print(f"[green]Recurse analyzed {len(res)} unique nodes.[/green]")
        elif sel == "5":
            fname = prompt("Export filename (blank for auto):") or None
            session.export(fname)
        elif sel == "6":
            session.print_tree()
        elif sel == "0":
            console.print("[bold black]Returning to the void...[/bold black]")
            break

if __name__ == "__main__":
    try:
        main_palette()
    except (KeyboardInterrupt, EOFError):
        console.print("\n[bold black]Hunt interrupted by user. Returning to the void...[/bold black]")
