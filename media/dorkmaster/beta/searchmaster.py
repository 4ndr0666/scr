#!/usr/bin/env python3
# searchmaster.py
# Refactored with Rich TUI by Ψ-4ndr0666

import os
import sys
import re
import time
import webbrowser
import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse, urljoin
import pyperclip

# --- Rich Imports ---
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.prompt import Prompt, Confirm, IntPrompt
from rich.text import Text
from rich.progress import track
from rich import box

# Initialize Console
console = Console()

# --- CONFIG definition ---
CONFIG = {
    "PREDEFINED_DORKS_URL": "https://raw.githubusercontent.com/4ndr0666/Dorking/main/Dorks/google_dorks.txt",
    "ARCHIVE_BASE_URL": "https://4plebs.org",
    "REQUEST_DELAY_SECONDS": 1,
    "DOWNLOAD_DIR": "downloads",
    "USER_AGENT": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
}

# --- LOCAL_FALLBACK_DORKS definition ---
LOCAL_FALLBACK_DORKS = [
    "inurl:\"view/index.shtml\"",
    "intitle:\"index of\" \"parent directory\"",
    "intext:\"powered by WordPress\""
]

# --- Helper functions ---
def copy_to_clipboard(text: str) -> None:
    """Copies text to the clipboard."""
    try:
        pyperclip.copy(text)
        console.print("[bold green]Copied to clipboard.[/bold green]")
    except pyperclip.PyperclipException:
        console.print("[bold yellow]Could not copy to clipboard. Pyperclip may not be configured correctly.[/bold yellow]")

def log_message(message: str, level: str) -> None:
    """Prints a log message."""
    color = "white"
    if level == "INFO": color = "blue"
    elif level == "ERROR": color = "red"
    elif level == "WARN": color = "yellow"
    elif level == "CRITICAL": color = "bold red"
    
    console.print(f"[{color}][{level}][/{color}] {message}")

def _prompt_and_open_browser(query: str) -> None:
    """Asks the user if they want to open the query in a browser."""
    if Confirm.ask("Open in browser?"):
        webbrowser.open(f"https://www.google.com/search?q={query}")

def process_search_intent(intent: str) -> str:
    """Processes the user's search intent. (Stub)"""
    return intent

def probe_additional_parameters(intent: str) -> str:
    """Probes for additional parameters. (Stub)"""
    return intent

def fetch_predefined_dorks() -> list[str]:
    """Fetches predefined Google dorks from a URL, with a local fallback."""
    with console.status("[bold blue]Fetching predefined dorks...", spinner="dots"):
        try:
            response = requests.get(CONFIG["PREDEFINED_DORKS_URL"], timeout=10)
            response.raise_for_status()
            dorks = [d for d in response.text.strip().splitlines() if d]
            if dorks:
                console.print(f"[bold green]Successfully fetched {len(dorks)} dorks.[/bold green]")
                return dorks
        except requests.exceptions.RequestException as e:
            console.print(f"[bold red]Failed to fetch predefined dorks: {e}[/bold red]")
            log_message(f"Error fetching predefined dorks: {e}", "ERROR")

    console.print("[bold yellow]Using local fallback dorks instead.[/bold yellow]")
    return LOCAL_FALLBACK_DORKS

# --- Automated 4chan Archive Automation Functions ---
class ThreadResult:
    """Represents a parsed thread from 4chan archive search results."""
    def __init__(self, thread_id: str, board: str, subject: str, post_excerpt: str, image_count: int, thread_url: str):
        self.thread_id = thread_id
        self.board = board
        self.subject = subject
        self.post_excerpt = post_excerpt
        self.image_count = image_count
        self.thread_url = thread_url
        self.external_links: list[str] = []
        self.passwords: list[str] = []

    def display_details(self) -> None:
        """Prints the formatted thread information using Rich panels."""
        content = Text()
        content.append(f"URL: {self.thread_url}\n", style="bold blue")
        content.append(f"Images: {self.image_count}\n", style="cyan")
        content.append(f"Excerpt: {self.post_excerpt[:300]}...\n", style="white")
        
        if self.external_links:
            content.append(f"\nDetected External Links ({len(self.external_links)}):\n", style="bold green")
            for i, link in enumerate(self.external_links):
                content.append(f"  [{i+1}] {link}\n", style="green")
        
        if self.passwords:
            content.append(f"\nDetected Passwords ({len(self.passwords)}):\n", style="bold yellow")
            for pwd in self.passwords:
                content.append(f"  - '{pwd}'\n", style="yellow")

        console.print(Panel(content, title=f"Thread {self.thread_id} (/{self.board}/) - {self.subject}", border_style="blue"))

def get_session() -> requests.Session:
    """Returns a requests session with a custom User-Agent."""
    session = requests.Session()
    session.headers.update({'User-Agent': CONFIG["USER_AGENT"]})
    return session

def perform_4plebs_search(
    session: requests.Session,
    board: str,
    keywords: str,
    date_from: str = "",
    date_to: str = "",
    exclude_terms: str = ""
) -> list[ThreadResult]:
    """Performs a search on 4plebs.org for the specified board and keywords."""
    search_url = f"{CONFIG['ARCHIVE_BASE_URL']}/{board}/search/"
    results: list[ThreadResult] = []

    full_query = f"{keywords} {' '.join([f'-{t}' for t in exclude_terms.split()])}".strip()
    payload = {'q': full_query, 'board': board, 'start': date_from, 'end': date_to, 'image_only': 'on'}

    console.print(f"[blue]Searching /{board}/ for '{full_query}'...[/blue]")
    try:
        # Wrap the network call in a status spinner
        with console.status(f"Querying /{board}/...", spinner="bouncingBall"):
            response = session.post(search_url, data=payload, timeout=30)
            response.raise_for_status()
            time.sleep(CONFIG["REQUEST_DELAY_SECONDS"])

        soup = BeautifulSoup(response.text, 'lxml')
        threads = soup.find_all('div', class_='search_thread')

        if not threads:
            log_message(f"No threads found for query on /{board}/: {full_query}", "INFO")
            return []

        for thread_div in threads:
            thread_link_tag = thread_div.find('a', class_='thread_link')
            if not (thread_link_tag and thread_link_tag.has_attr('href')):
                continue
            
            thread_url = urljoin(CONFIG["ARCHIVE_BASE_URL"], thread_link_tag['href'])
            thread_id_match = re.search(r'thread/(\d+)', thread_url)
            thread_id = thread_id_match.group(1) if thread_id_match else "N/A"
            
            subject_tag = thread_div.find('span', class_='subject')
            subject = subject_tag.get_text(strip=True) if subject_tag else "No Subject"
            
            text_div = thread_div.find('div', class_='text')
            post_excerpt = text_div.get_text(separator=' ', strip=True) if text_div else "No excerpt."
            
            image_count_tag = thread_div.find('span', class_='post_file_count')
            image_count = 0
            if image_count_tag:
                count_match = re.search(r'\[(\d+) Images\]', image_count_tag.get_text())
                if count_match:
                    image_count = int(count_match.group(1))
            
            results.append(ThreadResult(thread_id, board, subject, post_excerpt, image_count, thread_url))
        return results

    except requests.exceptions.RequestException as e:
        console.print(f"[bold red]Network error for /{board}/ search: {e}[/bold red]")
        log_message(f"Network error for /{board}/ search: {e}", "ERROR")
    return []

def parse_thread_for_details(session: requests.Session, thread_result: ThreadResult) -> None:
    """Fetches a thread page and parses it for external links and passwords."""
    with console.status(f"[bold blue]Investigating thread {thread_result.thread_id}...[/bold blue]", spinner="clock"):
        try:
            response = session.get(thread_result.thread_url, timeout=30)
            response.raise_for_status()
            time.sleep(CONFIG["REQUEST_DELAY_SECONDS"])
            soup = BeautifulSoup(response.text, 'lxml')
            
            patterns = {
                "mega": re.compile(r'https?://(?:www\.)?mega\.nz/(?:file|folder)/[a-zA-Z0-9_-]+(?:#.+)?', re.IGNORECASE),
                "gdrive": re.compile(r'https?://drive\.google\.com/(?:file/d/|open\?id=)[a-zA-Z0-9_-]+', re.IGNORECASE),
                "torrent": re.compile(r'magnet:\?xt=urn:[a-zA-Z0-9:]+', re.IGNORECASE),
                "direct_dl": re.compile(r'https?://[^\s"<>()]+?\.(?:zip|rar|7z|mp4|mkv|webm|jpg|png|gif|webp|pdf)(?:\?[^\s"<>()]*)?', re.IGNORECASE),
                "password_explicit": re.compile(r'(?:password|pass|pwd|key|decryption)\s*[:=]\s*([a-zA-Z0-9!@#$%^&*()_+=\-{}\[\]|;:",.<>/?`~]+)', re.IGNORECASE),
                "password_generic": re.compile(r'(?:pass|pwd|key)\s*(?:is|:)\s*(\S+)', re.IGNORECASE)
            }
            
            post_content_divs = soup.find_all('div', class_=['op', 'post_text'])
            for post_tag in post_content_divs:
                post_content = post_tag.get_text(separator=' ', strip=True)
                
                for link_type in ["mega", "gdrive", "torrent", "direct_dl"]:
                    for link in patterns[link_type].findall(post_content):
                        cleaned_link = re.sub(r'[\.,;\'"]+$', '', link)
                        if cleaned_link not in thread_result.external_links:
                            thread_result.external_links.append(cleaned_link)
                
                for pass_type in ["password_explicit", "password_generic"]:
                    for pwd in patterns[pass_type].findall(post_content):
                        if len(pwd) > 3 and "protected" not in pwd.lower() and "required" not in pwd.lower() and pwd not in thread_result.passwords:
                            thread_result.passwords.append(pwd)

            if not thread_result.external_links and not thread_result.passwords:
                console.print(f"[yellow]No explicit external links or passwords detected in thread {thread_result.thread_id}.[/yellow]")

        except requests.exceptions.RequestException as e:
            console.print(f"[bold red]Network error for {thread_result.thread_url}: {e}[/bold red]")

def manage_download_or_instruction(link: str, password: str = None) -> None:
    """Provides detailed instructions or attempts direct download for a given link."""
    console.print(Panel(f"Target: [bold underline]{link}[/bold underline]", title="Link Management", border_style="green"))
    
    console.print("[bold red]CRITICAL SECURITY WARNINGS:[/bold red]")
    console.print("1. [bold]ALWAYS[/bold] use a [yellow]VPN or Tor Browser[/yellow].")
    console.print("2. [bold]Consider[/bold] using a [yellow]Virtual Machine (VM)[/yellow].")
    
    link_type = "Unknown"
    if "mega.nz" in link: link_type = "Mega.nz"
    elif "drive.google.com" in link: link_type = "Google Drive"
    elif "magnet:?" in link: link_type = "Torrent/Magnet"
    elif any(ext in link.lower() for ext in ['.zip', '.rar', '.7z', '.mp4', '.mkv', '.pdf']): link_type = "Direct File Link"

    console.print(f"\nDetected Link Type: [bold cyan]{link_type}[/bold cyan]")
    if password: console.print(f"Associated Password: [bold yellow]'{password}'[/bold yellow]")

    if link_type == "Mega.nz":
        console.print("[green]Recommended:[/green] Use `megadl` (megatools) command-line client.")
    elif link_type == "Google Drive":
        console.print("[green]Browser Recommended:[/green] Copy the link and paste it into your (Tor) browser.")
    elif link_type == "Torrent/Magnet":
        console.print("[green]Use a Torrent Client:[/green] Copy the magnet link.")
    elif link_type == "Direct File Link":
        if Confirm.ask(f"Attempt direct download to '{CONFIG['DOWNLOAD_DIR']}'?"):
            try:
                console.print("[blue]Attempting direct download...[/blue]")
                file_name = os.path.basename(urlparse(link).path)
                file_path = os.path.join(CONFIG["DOWNLOAD_DIR"], file_name)
                
                with get_session().get(link, stream=True, timeout=60) as r:
                    r.raise_for_status()
                    with open(file_path, 'wb') as f:
                        for chunk in r.iter_content(chunk_size=8192): f.write(chunk)
                
                console.print(f"[bold green]Downloaded:[/bold green] {file_name}")
                if file_name.lower().endswith(('.zip', '.rar', '.7z')) and password:
                    console.print(f"[yellow]Archive password:[/yellow] '{password}'")
            except requests.exceptions.RequestException as e:
                console.print(f"[bold red]Failed to download: {e}[/bold red]")
    
    console.print("[blue]Link copied to clipboard.[/blue]")
    copy_to_clipboard(link)

# --- Menu Functions ---

def menu_select_predefined_dork(dorks: list[str]) -> None:
    if not dorks:
        console.print("[yellow]No dorks available.[/yellow]")
        return

    table = Table(title="Predefined Dorks", box=box.SIMPLE)
    table.add_column("ID", justify="right", style="cyan", no_wrap=True)
    table.add_column("Dork", style="green")

    for i, dork in enumerate(dorks, start=1):
        table.add_row(str(i), dork)

    console.print(table)
    
    choice = IntPrompt.ask("Select a dork ID", default=0)
    if 1 <= choice <= len(dorks):
        selected_dork = dorks[choice - 1]
        console.print(Panel(selected_dork, title="Selected Dork", border_style="green"))
        copy_to_clipboard(selected_dork)
        _prompt_and_open_browser(selected_dork)
    elif choice != 0:
        console.print("[red]Invalid choice.[/red]")

def menu_build_custom_dork() -> None:
    intent = Prompt.ask("Describe your search intent (plain English)")
    # Mocking the processing functions for now
    console.print(f"\n[bold]Generated Query:[/bold] [green]site:example.com \"{intent}\"[/green]")
    copy_to_clipboard(f'site:example.com "{intent}"')
    _prompt_and_open_browser(f'site:example.com "{intent}"')

def menu_automated_search() -> None:
    console.print(Panel("[bold]Automated 4chan Archive Search[/bold]\n[red]DISCLAIMER: Use VPN/Tor/VM.[/red]", border_style="red"))
    
    boards_input = Prompt.ask("Target Boards (comma separated)", default="s,gif")
    boards = [b.strip().lower().replace('/', '') for b in boards_input.split(',')]
    
    keywords = Prompt.ask("Search Keywords")
    if not keywords:
        console.print("[red]Keywords required.[/red]")
        return

    all_threads: list[ThreadResult] = []
    session = get_session()
    
    # Search phase
    for board in boards:
        found = perform_4plebs_search(session, board, keywords)
        all_threads.extend(found)
        if found:
            console.print(f"[green]Found {len(found)} threads on /{board}/[/green]")
    
    if not all_threads:
        console.print("[yellow]No threads found.[/yellow]")
        return

    # Sort and Display
    all_threads.sort(key=lambda x: x.image_count, reverse=True)
    
    table = Table(title=f"Search Results for '{keywords}'", box=box.ROUNDED)
    table.add_column("#", justify="right", style="cyan")
    table.add_column("Board", style="magenta")
    table.add_column("Subject", style="white")
    table.add_column("Images", justify="right", style="green")
    table.add_column("Snippet", style="dim")

    for i, t in enumerate(all_threads):
        table.add_row(str(i + 1), f"/{t.board}/", t.subject[:40], str(t.image_count), t.post_excerpt[:50]+"...")

    console.print(table)

    # Interaction Loop
    while True:
        action = Prompt.ask("\n[bold cyan][I][/]nvestigate, [bold cyan][O][/]pen ID, or [bold cyan][B][/]ack").lower()
        
        if action == 'b':
            break
        
        if action == 'o':
            idx = IntPrompt.ask("Thread ID to open") - 1
            if 0 <= idx < len(all_threads):
                webbrowser.open(all_threads[idx].thread_url)
            else:
                console.print("[red]Invalid ID[/red]")
        
        elif action == 'i':
            idx = IntPrompt.ask("Thread ID to investigate") - 1
            if 0 <= idx < len(all_threads):
                thread = all_threads[idx]
                parse_thread_for_details(session, thread)
                thread.display_details()
                
                if thread.external_links and Confirm.ask("Manage a link?"):
                    link_idx = IntPrompt.ask("Link ID", default=1) - 1
                    if 0 <= link_idx < len(thread.external_links):
                        pwd = thread.passwords[0] if thread.passwords else None
                        manage_download_or_instruction(thread.external_links[link_idx], pwd)
            else:
                console.print("[red]Invalid ID[/red]")

def main_menu() -> None:
    while True:
        console.clear()
        console.print(Panel.fit(
            "[bold cyan]Searchmaster v2.0[/bold cyan]\n" 
            "[dim]Automated Dorking & Archive Intelligence[/dim]",
            border_style="cyan"
        ))
        
        table = Table(show_header=False, box=None)
        table.add_column("Key", style="bold yellow", justify="right")
        table.add_column("Action")
        
        table.add_row("1", "Optimize Intent (English -> Dork)")
        table.add_row("2", "Predefined Dorks")
        table.add_row("3", "4chan Archive Search")
        table.add_row("4", "Help")
        table.add_row("0", "Exit")
        
        console.print(table)
        
        choice = Prompt.ask("\nSelect Option", choices=["1", "2", "3", "4", "0"])
        
        if choice == '1':
            menu_build_custom_dork()
            Prompt.ask("\nPress Enter to continue")
        elif choice == '2':
            dorks = fetch_predefined_dorks()
            menu_select_predefined_dork(dorks)
            Prompt.ask("\nPress Enter to continue")
        elif choice == '3':
            menu_automated_search()
            # No pause here, submenu handles it
        elif choice == '4':
            console.print(Panel("This tool assists in OSINT operations via Google Dorks and Archive parsing.", title="Help"))
            Prompt.ask("\nPress Enter to continue")
        elif choice == '0':
            console.print("[bold blue]Goodbye![/bold blue]")
            break

def main() -> None:
    # Ensure download dir exists
    if not os.path.exists(CONFIG["DOWNLOAD_DIR"]):
        os.makedirs(CONFIG["DOWNLOAD_DIR"])
        
    if len(sys.argv) > 1:
        # Quick CLI mode
        intent = ' '.join(sys.argv[1:])
        console.print(f"[cyan]Quick Mode:[/cyan] {intent}")
        # (Stub logic for quick mode)
    else:
        main_menu()

if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        console.print("\n[yellow]Aborted.[/yellow]")
        sys.exit(0)
    except Exception as e:
        console.print(f"[bold red]Unexpected Error:[/bold red] {e}")
        sys.exit(1)
