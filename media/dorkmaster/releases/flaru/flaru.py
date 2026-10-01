#!/usr/bin/env python3
# flaru.py
# Ψ-4ndr0666 FLARU OSINT/Leak Terminal Suite Orchestrator
# Refactored with Rich TUI

import os
import sys
import subprocess
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.prompt import Prompt
from rich import box

# Initialize Console
console = Console()

# Determine base directory of the script
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PLUGINS_DIR = os.path.join(BASE_DIR, "plugins")

# Core Scripts definition
# Format: (Display Name, Script Filename)
CORE_SCRIPTS = [
    ("Image Enumerator", "image_enum.py"),
    ("Reddit Ripper", "script.py"),
    ("Searchmaster Dorker", "searchmaster.py"),
    ("Brute/Recursive Image Enum", "url_scrapper.py"),
]

def launch_script(script_name, script_path):
    """Launches a script using the current python interpreter, prompting for args if needed."""
    # Ensure path is absolute or properly relative
    if not os.path.isabs(script_path):
         script_path = os.path.join(BASE_DIR, script_path)

    if not os.path.isfile(script_path):
        console.print(f"[bold red][!] Missing script: {script_path}[/bold red]")
        return
    
    # --- Argument Interception Logic ---
    script_filename = os.path.basename(script_path)
    cmd_args = []

    console.print(f"[bold blue]Preparing to launch {script_name}...[/bold blue]")

    if script_filename == "image_enum.py":
        target_url = Prompt.ask("[bold yellow]Enter Target URL[/bold yellow]")
        if target_url:
            cmd_args.append(target_url)
        else:
            console.print("[red]Aborted: URL required.[/red]")
            return

    elif script_filename == "script.py": # Reddit Ripper
        subreddit = Prompt.ask("[bold yellow]Enter Subreddit Name[/bold yellow]")
        if subreddit:
            cmd_args.append(subreddit)
            # Optional args
            sort = Prompt.ask("Sort type (hot/top/new)", default="top")
            cmd_args.append(sort)
            limit = Prompt.ask("Limit", default="20")
            cmd_args.append(limit)
        else:
            console.print("[red]Aborted: Subreddit required.[/red]")
            return

    elif script_filename == "url_scrapper.py":
        target_url = Prompt.ask("[bold yellow]Enter Base URL[/bold yellow]")
        if target_url:
            cmd_args.append(target_url)
            # Optional args for url_scrapper
            depth = Prompt.ask("Recursion Depth", default="1")
            cmd_args.extend(["-d", depth])
            pattern = Prompt.ask("Regex Pattern (Optional)", default="")
            if pattern:
                cmd_args.extend(["-p", pattern])
        else:
            console.print("[red]Aborted: URL required.[/red]")
            return

    # -----------------------------------
    
    try:
        # Determine executor based on extension/shebang assumptions
        # For .py files in this suite, we use sys.executable
        cmd = [sys.executable, script_path] + cmd_args
        
        # If it's an executable plugin without .py extension, run directly
        if not script_path.endswith(".py") and os.access(script_path, os.X_OK):
            cmd = [os.path.abspath(script_path)] + cmd_args

        # Pass execution to the subprocess
        console.print(f"[dim]Executing: {' '.join(cmd)}[/dim]")
        subprocess.run(cmd, check=False, cwd=BASE_DIR)
        
        console.print(f"\n[bold green]{script_name} finished.[/bold green]")
        Prompt.ask("\nPress Enter to return to menu")
    except Exception as e:
        console.print(f"[bold red][!] Execution failed: {e}[/bold red]")
        Prompt.ask("\nPress Enter to continue")

def discover_plugins():
    """Scans the plugins directory for executable files."""
    if not os.path.isdir(PLUGINS_DIR):
        return []
    found = []
    try:
        for fn in os.listdir(PLUGINS_DIR):
            path = os.path.join(PLUGINS_DIR, fn)
            # Consider it a plugin if it's a file and executable OR a python script
            if os.path.isfile(path):
                 if os.access(path, os.X_OK) or fn.endswith(".py"):
                    found.append((f"Plugin: {fn}", path))
    except Exception as e:
        console.print(f"[yellow]Error scanning plugins: {e}[/yellow]")
    return found

def main_menu():
    while True:
        console.clear()
        
        # -- Header --
        console.print(Panel.fit(
            "[bold cyan]Ψ-4ndr0666 FLARU OSINT Suite[/bold cyan]\n"
            "[dim]Advanced Leak & Reconnaissance Unit[/dim]",
            border_style="cyan"
        ))

        # -- Build Menu Items --
        # Combine Core Scripts and Plugins into one indexed list
        menu_items = []
        menu_items.extend(CORE_SCRIPTS)
        
        plugins = discover_plugins()
        if plugins:
            menu_items.extend(plugins)
        
        # -- Display Table --
        table = Table(show_header=True, header_style="bold magenta", box=box.ROUNDED, expand=True)
        table.add_column("ID", justify="right", style="cyan", width=4)
        table.add_column("Tool Name", style="white")
        table.add_column("Filename", style="dim")

        for i, (name, path) in enumerate(menu_items, start=1):
            table.add_row(str(i), name, path)
        
        console.print(table)
        console.print(f"[dim]Found {len(plugins)} plugins in '{PLUGINS_DIR}/'[/dim]\n")

        # -- Prompt --
        console.print("[bold]0.[/bold] Exit")
        
        choice_str = Prompt.ask("Select Tool ID", default="0")
        
        if choice_str == '0':
            console.print("[bold blue]Exiting FLARU. Stay safe.[/bold blue]")
            break
            
        try:
            choice = int(choice_str)
            if 1 <= choice <= len(menu_items):
                name, path = menu_items[choice - 1]
                launch_script(name, path)
            else:
                console.print("[bold red]Invalid selection.[/bold red]")
                time.sleep(1)
        except ValueError:
             console.print("[bold red]Invalid input.[/bold red]")
             time.sleep(1)

if __name__ == "__main__":
    import time # Delayed import for menu loop sleep
    try:
        main_menu()
    except (KeyboardInterrupt, EOFError):
        console.print("\n[yellow]Aborted.[/yellow]")
        sys.exit(0)