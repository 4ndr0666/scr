#!/usr/bin/env python3
# dork_cli_menu.py

import json
from rich.console import Console
from rich.table import Table

console = Console()

def load_dork_patterns(json_file="dork_patterns.json"):
    """Load the dork patterns/categories from a JSON file."""
    with open(json_file, 'r') as f:
        return json.load(f)

def cli_dork_menu(dork_patterns, company="TARGET"):
    """Display interactive CLI menu for dork categories and patterns. Returns the chosen dork string."""
    while True:
        console.print("\n[bold red]Google Dork Patterns[/bold red]")
        for i, category in enumerate(dork_patterns, 1):
            console.print(f"[cyan]{i}.[/cyan] {category['category']}")
        sel = input("Select a category number, or [Q]uit: ").strip()
        if sel.lower() == 'q':
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
            table.add_column("Pattern Name", style="bold")
            table.add_column("Query")
            for j, pat in enumerate(category['patterns'], 1):
                # Replace all JS-style {companyName} with Python style {company}
                pattern_query = pat['query'].replace("{companyName}", "{company}")
                table.add_row(str(j), pat['name'], pattern_query.format(company=company))
            console.print(table)
            sel2 = input("Select pattern number, or [B]ack: ").strip()
            if sel2.lower() == 'b':
                break
            try:
                pidx = int(sel2) - 1
                pattern = category['patterns'][pidx]
                dork_query = pattern['query'].replace("{companyName}", "{company}").format(company=company)
                console.print(f"\n[green]Your Dork:[/green] {dork_query}")
                return dork_query
            except:
                console.print("[red]Invalid selection.[/red]")
                continue

if __name__ == "__main__":
    company = input("Enter company/target name: ").strip() or "TARGET"
    dork_patterns = load_dork_patterns()
    dork = cli_dork_menu(dork_patterns, company)
    if dork:
        print(f"Ready to use dork: {dork}")
