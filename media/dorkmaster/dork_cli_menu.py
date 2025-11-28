#!/usr/bin/env python3
# dork_cli_menu.py – Final NSFW-Enhanced Canon (2025-11-22) – CLIPBOARD FULLY RESTORED

import json
import subprocess
import shutil
from rich.console import Console
from rich.table import Table

console = Console()

def load_dork_patterns(json_file="dork_patterns.json", nsfw_json_file="beta/src/dork_patterns-nsfw.json"):
    """Load and merge dork patterns from standard and NSFW JSON files."""
    patterns = []
    try:
        with open(json_file, "r", encoding="utf-8") as f:
            patterns.extend(json.load(f))
    except Exception as e:
        console.print(f"[red]Failed to load standard dork patterns: {e}[/red]")

    try:
        with open(nsfw_json_file, "r", encoding="utf-8") as f:
            nsfw_patterns = json.load(f)
            for category in nsfw_patterns:
                category["category"] = f"[NSFW] {category['category']}"
            patterns.extend(nsfw_patterns)
    except Exception as e:
        console.print(f"[yellow]Could not load NSFW dork patterns: {e}[/yellow]")
    
    if not patterns:
        console.print("[bold red]FATAL: No dork patterns loaded.[/bold red]")
        raise RuntimeError("No dork patterns could be loaded.")
        
    return patterns

def _copy_to_clipboard(text):
    """Copy text to system clipboard using wl-copy/xclip/pbcopy if available."""
    try:
        if shutil.which("wl-copy"):
            subprocess.run(["wl-copy"], input=text.encode("utf-8"), check=True)
            console.print("[cyan]Dork copied to clipboard (wl-copy)[/cyan]")
        elif shutil.which("xclip"):
            subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode("utf-8"), check=True)
            console.print("[cyan]Dork copied to clipboard (xclip)[/cyan]")
        elif shutil.which("pbcopy"):
            subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)
            console.print("[cyan]Dork copied to clipboard (pbcopy)[/cyan]")
        else:
            console.print("[yellow]No clipboard tool found (install wl-copy/xclip/pbcopy)[/yellow]")
    except Exception as e:
        console.print(f"[red]Clipboard copy failed: {e}[/red]")

def cli_dork_menu(dork_patterns, company="TARGET"):
    """Display interactive CLI menu for dork categories and patterns. Returns the chosen dork string."""
    while True:
        console.print("\n[bold red]Ψ-4ndr0666-OS // NSFW DORK ARSENAL v∞.NSFW[/bold red]")
        for i, category in enumerate(dork_patterns, 1):
            cat_name = category.get("category", "Unknown")
            if any(x in cat_name.lower() for x in ["leak", "onlyfans", "mega", "telegram", "porn"]):
                console.print(f"[bold magenta]{i}.[/bold magenta] [bold yellow]{cat_name}[/bold yellow]")
            else:
                console.print(f"[cyan]{i}.[/cyan] {cat_name}")
        console.print("[dim]Q to Quit[/dim]")
        sel = input("Select category number: ").strip()
        if sel.lower() == "q":
            return None
        try:
            idx = int(sel) - 1
            category = dork_patterns[idx]
        except:
            console.print("[red]Invalid selection.[/red]")
            continue

        while True:
            table = Table(title=category["category"], show_lines=True)
            table.add_column("#", justify="right")
            table.add_column("Name", style="bold green")
            table.add_column("Query")
            for j, pat in enumerate(category["patterns"], 1):
                q = pat["query"].replace("{companyName}", "{company}").format(company=company)
                table.add_row(str(j), pat["name"], q)
            console.print(table)
            sel2 = input("Select pattern, [B]ack, or [Q]uit: ").strip()
            if sel2.lower() == "b":
                break
            if sel2.lower() == "q":
                return None
            try:
                pidx = int(sel2) - 1
                pattern = category["patterns"][pidx]
                dork_query = pattern["query"].replace("{companyName}", "{company}").format(company=company)
                console.print(f"\n[bold green]LOCKED & LOADED:[/bold green] {dork_query}")
                _copy_to_clipboard(dork_query)
                return dork_query
            except:
                console.print("[red]Invalid selection.[/red]")

if __name__ == "__main__":
    company = input("Enter target (default: viki_veloxen): ").strip() or "viki_veloxen"
    patterns = load_dork_patterns()
    dork = cli_dork_menu(patterns, company)
    if dork:
        print(f"\nDORK READY:\n{dork}\n")
