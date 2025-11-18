#!/usr/bin/env python3
# dork_cli_menu.py – Final NSFW-Enhanced Literal Canon (November 18, 2025)

import json
from rich.console import Console
from rich.table import Table

console = Console()


def load_dork_patterns(json_file="dork_patterns.json"):
    """Load the dork patterns/categories from a JSON file."""
    with open(json_file, "r", encoding="utf-8") as f:
        return json.load(f)


def cli_dork_menu(dork_patterns, company="TARGET"):
    """Display interactive CLI menu for dork categories and patterns. Returns the chosen dork string."""
    while True:
        console.print("\n[bold red]Ψ-4ndr0666-OS // NSFW DORK ARSENAL v∞.NSFW[/bold red]")
        for i, category in enumerate(dork_patterns, 1):
            cat_name = category["category"]
            if "Leak" in cat_name or "OnlyFans" in cat_name or "Telegram" in cat_name:
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
            table = Table(title=f"{category['category']}", show_lines=True)
            table.add_column("#", justify="right")
            table.add_column("Pattern Name", style="bold green")
            table.add_column("Query")
            for j, pat in enumerate(category["patterns"], 1):
                pattern_query = pat["query"].replace("{companyName}", "{company}")
                rendered = pattern_query.format(company=company)
                table.add_row(str(j), pat["name"], rendered)
            console.print(table)
            sel2 = input("Select pattern number, or [B]ack: ").strip()
            if sel2.lower() == "b":
                break
            try:
                pidx = int(sel2) - 1
                pattern = category["patterns"][pidx]
                dork_query = pattern["query"].replace("{companyName}", "{company}").format(company=company)
                console.print(f"\n[bold green]LOCKED & LOADED:[/bold green] {dork_query}")
                return dork_query
            except:
                console.print("[red]Invalid selection.[/red]")
                continue


if __name__ == "__main__":
    default_target = "viki_veloxen"
    company = input(f"Enter NSFW target (default: {default_target}): ").strip()
    if not company:
        company = default_target
    dork_patterns = load_dork_patterns()
    dork = cli_dork_menu(dork_patterns, company)
    if dork:
        print(f"\nFINAL DORK READY FOR DEPLOYMENT:\n{dork}\n")