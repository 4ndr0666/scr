#!/usr/bin/env python3

import os
import sys
import json
import datetime
import re
from urllib.parse import urlparse, urljoin
from collections import Counter, defaultdict
import requests
from bs4 import BeautifulSoup
from rich.console import Console
from rich.table import Table
from rich import box

import dork_cli_menu  # must be present in your project directory or PYTHONPATH

# ===== SESSION MANAGER =====
SESSION_DIR = os.path.expanduser("~/.dorkmaster/sessions/")
console = Console()

class MycelialNode:
    def __init__(self, data, node_type, parent=None):
        self.data = data
        self.node_type = node_type
        self.parent = parent
        self.children = []

    def add_child(self, child):
        child.parent = self
        self.children.append(child)

    def as_dict(self):
        return {
            "data": self.data,
            "node_type": self.node_type,
            "children": [c.as_dict() for c in self.children]
        }

class MycelialSession:
    def __init__(self, session_name=None):
        self.root_nodes = []
        self.session_name = session_name or datetime.datetime.now().strftime("session_%Y%m%d%H%M%S")
        self.path = os.path.join(SESSION_DIR, f"{self.session_name}.json")

    def add_root(self, node):
        self.root_nodes.append(node)

    def export(self, filename=None):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        path = filename or self.path
        with open(path, 'w') as f:
            json.dump([n.as_dict() for n in self.root_nodes], f, indent=2)
        console.print(f"[green]Session exported to {path}[/green]")

    def print_tree(self, node=None, level=0):
        nodes = self.root_nodes if node is None else node.children
        for n in nodes:
            prefix = "    " * level + f"- [{n.node_type}] "
            title = n.data.get('url', n.data.get('query', ''))
            console.print(f"{prefix}{title}")
            self.print_tree(n, level + 1)

# ===== UTILS =====
def prompt(msg):
    return input(f"{msg} ").strip()

def choose_company_var():
    val = prompt("Enter company/target name (for dork patterns):")
    return val if val else "TARGET"

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
        href = tag['href']
        if not href.startswith("http"):
            href = urljoin(base_url, href)
        if validate_url(href):
            links.add(href)
    return list(links)

def extract_media_links(html, base_url):
    soup = BeautifulSoup(html, "html.parser")
    links = set()
    # Images
    for tag in soup.find_all("img", src=True):
        src = tag['src']
        if not src.startswith("http"):
            src = urljoin(base_url, src)
        if validate_url(src):
            links.add(src)
    # Videos
    for tag in soup.find_all("video", src=True):
        src = tag['src']
        if not src.startswith("http"):
            src = urljoin(base_url, src)
        if validate_url(src):
            links.add(src)
    # Sources
    for tag in soup.find_all("source", src=True):
        src = tag['src']
        if not src.startswith("http"):
            src = urljoin(base_url, src)
        if validate_url(src):
            links.add(src)
    return list(links)

# ===== DORK PALETTE: FULLY DYNAMIC FROM JSON =====
def dork_palette():
    """
    Presents the Google dork pattern menu loaded from dork_patterns.json
    (via dork_cli_menu.py), with support for all pattern variants used
    in the modal/React UI. All categories and queries are always current.
    """
    company = choose_company_var()

    # Compute all variants for substitution
    company_dash = company.replace(" ", "-")
    company_us = company.replace(" ", "_")
    company_abbr = "".join([w[0] for w in company.split()]).lower()
    company_first = company.split()[0] if company.split() else company
    company_last = company.split()[-1] if company.split() else company

    # Load dynamic dork patterns from JSON
    dork_patterns = dork_cli_menu.load_dork_patterns()

    # Apply all advanced substitutions in ALL patterns/categories
    for cat in dork_patterns:
        for pat in cat['patterns']:
            pat['query'] = (
                pat['query']
                .replace("{company-dash}", company_dash)
                .replace("{company_us}", company_us)
                .replace("{company-abbr}", company_abbr)
                .replace("{company-first}", company_first)
                .replace("{company-last}", company_last)
                .replace("{company}", company)
            )

    # Let the user select the dork pattern/query
    dork_query = dork_cli_menu.cli_dork_menu(dork_patterns, company)
    if not dork_query:
        return None
    return {
        "category": "Unified",
        "pattern": "Custom",
        "query": dork_query
    }

# ===== SEARX RUNNER (WITH POOL/FAILOVER) =====
SEARX_POOL = [
    "https://searx.tiekoetter.com",
    "https://searx.ninja",
    "https://searx.org",
    "https://searx.be",
    "https://searx.ru",
    "https://searx.fmac.xyz",
    "https://searx.bar",
    "https://search.bus-hit.me",
    "https://search.mdosch.de",
    "https://searx.mastodontech.de"
]

def run_searx(query, categories=["general"], count=10):
    params = {
        "q": query,
        "categories": ",".join(categories),
        "format": "json",
        "language": "en",
        "safesearch": 0,
    }
    errors = []
    for searx_url in SEARX_POOL:
        try:
            resp = requests.get(f"{searx_url}/search", params=params, headers={
                "User-Agent": "Mozilla/5.0 (Flaru/NSFW/Recon)"
            }, timeout=20)
            if resp.status_code in (429, 503, 403):
                console.print(f"[yellow]Instance {searx_url} blocked/rate limited ({resp.status_code}). Trying next...[/yellow]")
                continue
            resp.raise_for_status()
            results = resp.json().get('results', [])
            if results:
                return results
        except Exception as e:
            errors.append(f"{searx_url}: {e}")
            continue
    console.print("[red]All Searx instances failed or are rate limited.[/red]")
    console.print("[yellow]Consider adding your own SearxNG instance, using a VPN/proxy, or exporting the query for manual investigation.[/yellow]")
    if errors:
        console.print("[dim]Error details from pool:[/dim]")
        for err in errors:
            console.print(f"[dim]{err}[/dim]")
    return []

# ===== ANALYZER & SCRAPER =====
def analyze_target(url):
    if not validate_url(url):
        console.print(f"[red]Invalid URL: {url}[/red]")
        return

    try:
        resp = requests.get(url, timeout=15, headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
        html = resp.text
    except Exception as e:
        console.print(f"[red]Failed to fetch {url}: {e}[/red]")
        return

    links = extract_links(html, url)
    media_links = extract_media_links(html, url)

    table = Table(title=f"Link Analysis: {url}", box=box.SIMPLE)
    table.add_column("Type")
    table.add_column("Count")
    table.add_row("Page Links", str(len(links)))
    table.add_row("Media Files", str(len(media_links)))
    console.print(table)

    if media_links:
        console.print("[cyan]Media files found:[/cyan]")
        for l in media_links:
            console.print(f"  {l}")
    return {"url": url, "links": links, "media": media_links}

# ===== BRUTE/SPIDER =====
def brute_spider(base_url, max_depth=2):
    seen = set()
    queue = [(base_url, 0)]
    results = []

    while queue:
        url, depth = queue.pop(0)
        if url in seen or depth > max_depth:
            continue
        seen.add(url)
        try:
            resp = requests.get(url, timeout=10)
            resp.raise_for_status()
            html = resp.text
        except Exception as e:
            console.print(f"[red]Failed to fetch {url}: {e}[/red]")
            continue

        links = extract_links(html, url)
        media = extract_media_links(html, url)
        results.append({"url": url, "media": media})

        for l in links:
            if l not in seen:
                queue.append((l, depth+1))
    return results

# ===== RECURSE =====
def recurse(urls, analyzer_func=analyze_target, max_depth=1):
    results = []
    def helper(urls, depth):
        if depth > max_depth:
            return
        for url in urls:
            data = analyzer_func(url)
            results.append(data)
            new_links = data.get('links', []) if data else []
            if new_links:
                helper(new_links, depth+1)
    helper(urls, 1)
    return results

# ===== EXPORT =====
def export_results(results, filename="results.json"):
    with open(filename, "w") as f:
        json.dump(results, f, indent=2)
    console.print(f"[green]Exported results to {filename}[/green]")

# ===== MAIN MENU =====
def main_palette():
    session = MycelialSession()
    while True:
        print("\n===== Flaru Mycelial OSINT Core =====")
        print("1. Dork (search, parse, chain)")
        print("2. Analyze Target")
        print("3. Brute/Spider (gallery/dir enumeration)")
        print("4. Recurse (analyze all found URLs/media)")
        print("5. Export/Batch")
        print("6. Session Tree")
        print("7. Help")
        print("0. Exit")
        sel = prompt("Menu:")
        if sel == "1":
            dork = dork_palette()
            if not dork:
                continue
            console.print(f"[bold green]Running Dork:[/bold green] {dork['query']}")
            results = run_searx(dork['query'])
            if not results:
                continue
            urls = [r.get('url') for r in results if r.get('url')]
            if urls:
                for i, u in enumerate(urls, 1):
                    console.print(f"[{i}] {u}")
                choice = prompt("Analyze a URL? (enter # or blank to skip):")
                if choice.isdigit():
                    idx = int(choice) - 1
                    if 0 <= idx < len(urls):
                        data = analyze_target(urls[idx])
                        node = MycelialNode(data, "analyze")
                        session.add_root(node)
        elif sel == "2":
            url = prompt("Enter URL to analyze:")
            data = analyze_target(url)
            if data:
                node = MycelialNode(data, "analyze")
                session.add_root(node)
        elif sel == "3":
            url = prompt("Enter base URL to spider/brute:")
            res = brute_spider(url)
            if res:
                node = MycelialNode({"url": url, "spider": res}, "spider")
                session.add_root(node)
                console.print(f"[green]Spidering complete. {len(res)} pages/media found.[/green]")
        elif sel == "4":
            url = prompt("Enter URL to recurse/analyze:")
            res = recurse([url])
            if res:
                node = MycelialNode({"url": url, "recurse": res}, "recurse")
                session.add_root(node)
                console.print(f"[green]Recursion complete. {len(res)} items found.[/green]")
        elif sel == "5":
            fname = prompt("Export filename (or blank for results.json):")
            session.export(fname if fname else None)
        elif sel == "6":
            session.print_tree()
        elif sel == "7":
            print("""
            [1] Dork: Select, run, and analyze Google dorks.
            [2] Analyze: Analyze a single URL for links/media.
            [3] Spider: Recursively crawl for galleries/media.
            [4] Recurse: Recursively analyze found URLs.
            [5] Export: Export all session results to JSON.
            [6] Session Tree: View the mycelial analysis tree.
            [0] Exit.
            """)
        elif sel == "0":
            break

if __name__ == "__main__":
    main_palette()
