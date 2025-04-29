#!/usr/bin/env python3
"""
scaffold.py
===========
Minimalistic Project Directory Scaffold Tool

Author: 4ndr0666 + SucklessCodeGPT
License: MIT
Version: 4.0 (First Stable)
"""

import os
import sys
import json
from pathlib import Path
from rich.console import Console
from rich.prompt import Prompt

console = Console()

# Default presets folder
PRESETS_DIR = Path(__file__).parent / "presets"

def load_presets():
    presets = {}
    if not PRESETS_DIR.is_dir():
        console.print(f"[bold red]Presets directory missing: {PRESETS_DIR}[/bold red]")
        sys.exit(1)

    for f in PRESETS_DIR.glob("*.json"):
        try:
            with open(f, "r") as file:
                presets[f.stem] = json.load(file)
        except Exception as e:
            console.print(f"[bold red]Failed loading preset {f.name}: {e}[/bold red]")
    return presets

def create_structure(base_path, structure, dry_run=True):
    for item in structure.get("directories", []):
        path = base_path / item
        if dry_run:
            console.print(f"[cyan]Would create directory:[/cyan] {path}")
        else:
            path.mkdir(parents=True, exist_ok=True)
            console.print(f"[green]Created directory:[/green] {path}")

    for file in structure.get("files", []):
        path = base_path / file
        if dry_run:
            console.print(f"[cyan]Would create file:[/cyan] {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch(exist_ok=True)
            console.print(f"[green]Created file:[/green] {path}")

def main():
    console.print("[bold magenta]SCAFFOLD[/bold magenta] - Minimal Project Directory Setup", justify="center")

    presets = load_presets()

    if not presets:
        console.print("[bold red]No presets found. Exiting.[/bold red]")
        sys.exit(1)

    console.print("\nAvailable Presets:\n")
    for idx, key in enumerate(presets.keys(), 1):
        console.print(f"[{idx}] {key}")

    choice = Prompt.ask("\nSelect preset number", default="1")

    try:
        selected_key = list(presets.keys())[int(choice)-1]
    except (IndexError, ValueError):
        console.print("[bold red]Invalid choice. Exiting.[/bold red]")
        sys.exit(1)

    target = Prompt.ask("Base directory to scaffold", default=os.getcwd())
    target_path = Path(target).resolve()

    dry = Prompt.ask("Dry-run first? (y/n)", default="y")
    dry_run = dry.lower().startswith("y")

    structure = presets[selected_key]
    create_structure(target_path, structure, dry_run=dry_run)

    if dry_run:
        proceed = Prompt.ask("Proceed with actual creation? (y/n)", default="n")
        if proceed.lower().startswith("y"):
            create_structure(target_path, structure, dry_run=False)
        else:
            console.print("[bold yellow]Dry-run completed. No changes made.[/bold yellow]")

if __name__ == "__main__":
    main()
