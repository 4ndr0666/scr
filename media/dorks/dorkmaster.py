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
import requests
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

# ===== Ψ-4ndr0666-OS FULL LIBERATION – DEFAULT ACTIVE =====
console = Console()
# onsole.print(
#    "[bold red]Ψ-4ndr0666-OS // FULL LIBERATION PROTOCOL ACTIVE – LEAKS UNLEASHED[/bold red]"
# )

# ===== CONFIGURATION & AUTO-ONBOARDING SYSTEM =====
CONFIG_DIR = os.path.expanduser("~/.config/dorkmaster")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

DEFAULT_CONFIG = {
    "private_searxng_url": "http://192.168.1.91:8080",
    "use_private_searxng_first": True,
    "telegram_mirror_enabled": False,
    "max_telegram_posts": 50,
    "clipboard_tool": "auto",
    "default_target": "viki_veloxen",
    "session_dir": os.path.expanduser("~/.local/share/dorkmaster/sessions/"),
}


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


ensure_config()  # Auto-onboarding on first run


def load_config():
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            user_config = json.load(f)
        config = DEFAULT_CONFIG.copy()
        config.update(user_config)
        return config
    except Exception as e:
        console.print(f"[red]Failed to load config: {e}[/red]")
        console.print("[yellow]Using defaults and recreating config...[/yellow]")
        ensure_config()
        return DEFAULT_CONFIG.copy()


def save_config():
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
        console.print(f"[green]Config saved to {CONFIG_FILE}[/green]")
    except Exception as e:
        console.print(f"[red]Failed to save config: {e}[/red]")


# Load config into module-level variable
config = load_config()
SESSION_DIR = config["session_dir"]
os.makedirs(SESSION_DIR, exist_ok=True)


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
PLUGIN_DIR = "./plugins"


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

    # Try exact phrase first, then word variants
    variants = [
        clean,
        clean.replace(" ", "+"),
        clean.replace(" ", "_"),
        clean.lower(),
    ]

    results = []
    for variant in variants:
        for base in [f"https://t.me/s/{variant}", f"https://t.me/s/?q={variant}"]:
            try:
                r = requests.get(
                    base, headers={"User-Agent": "Mozilla/5.0"}, timeout=20
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

                    if link_tag and (
                        "viki" in text.lower()
                        or "veloxen" in text.lower()
                        or "vicky" in text.lower()
                    ):
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


# ===== SEARX RUNNER v3 – CONFIGURABLE PRIVATE + PUBLIC + MEGAHUNT =====
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
    "https://searx.mastodontech.de",
]


def run_searx(query, count=30):
    params = {
        "q": query,
        "format": "json",
        "language": "en",
        "safesearch": 0,
    }

    if config["use_private_searxng_first"]:
        try:
            private_url = config["private_searxng_url"]
            # FIX: Use urljoin for robust URL construction
            search_endpoint = urljoin(private_url, "search")
            resp = requests.get(search_endpoint, params=params, timeout=15)
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

    for url in SEARX_POOL:
        try:
            # FIX: Use urljoin for robust URL construction here too
            search_endpoint = urljoin(url, "search")
            resp = requests.get(search_endpoint, params=params, timeout=20)
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
        resp = requests.get(
            url, timeout=15, headers={"User-Agent": "Mozilla/5.0 (Ψ-NSFW-Hunter/2025)"}
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

    def helper(urls, depth):
        if depth > max_depth:
            return
        for url in urls:
            data = analyzer_func(url)
            if data:
                results.append(data)
                new_links = data.get("links", []) + data.get("media", [])
                helper(new_links, depth + 1)

    helper(urls, 1)
    return results


# ===== SETTINGS MENU – FIXED: NO GLOBAL KEYWORD =====
def settings_menu():
    global config  # ← Only declared here, after config is defined
    while True:
        console.print("\n[bold magenta]=== SETTINGS ===[/bold magenta]")
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Setting")
        table.add_column("Current Value")
        for k, v in config.items():
            table.add_row(k, str(v))
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
    while True:
        console.print("\n[bold cyan]==== // DORKMASTER //[/bold cyan]")
        print("1. Dork & Hunt")
        print("2. Analyze Vein")
        print("3. Spider Leak Domains")
        print("4. Recurse Chains")
        print("5. Export Session")
        print("6. View Tree")
        print("7. Plugins")
        print("8. Settings")
        print("0. Exit")
        sel = prompt("Command:")

        if sel == "8":
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
            url = prompt("URL to gut:")
            data = analyze_target(url)
            if data:
                node = MycelialNode(data, "manual_analyze")
                session.add_root(node)

        elif sel == "3":
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

        elif sel == "4":
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

        elif sel == "5":
            fname = prompt("Export filename (blank for auto):") or None
            session.export(fname)

        elif sel == "6":
            session.print_tree()

        elif sel == "7":
            print("\nAvailable Plugins:")
            plugins = load_plugins()
            for pname in plugins:
                print(f"  - {pname}")
            sel = input("Select plugin: ").strip()
            if sel in plugins:
                console.print(
                    f"[bold yellow]Plugin {sel} loaded – no handler defined yet[/bold yellow]"
                )
            else:
                console.print("[red]Plugin not found[/red]")

        elif sel == "0":
            console.print("[bold black]Terminated...[/bold black]")
            break


if __name__ == "__main__":
    try:
        main_palette()
    except (KeyboardInterrupt, EOFError):
        console.print("\n[bold black]Terminated...[/bold black]")
