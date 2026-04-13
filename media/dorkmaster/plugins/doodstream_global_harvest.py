#!/usr/bin/env python3
# plugins/doodstream_global_harvest.py
# 4NDR0666OS — PURE GLOBAL DOODSTREAM URL HARVEST (ATSCAN + Optimized Dork Menu)

from rich.prompt import Prompt, Confirm
from rich.console import Console
import subprocess
from pathlib import Path

console = Console()

# Optimized Dork Arsenal (2026 meta)
DORK_MENU = [
    ("1", "High-Yield Main", 'site:dood.to OR site:dood.wf OR site:dood.pm OR site:doodstream.com (onlyfans OR fansly OR leaked OR mega OR pack OR full OR collection OR 2025 OR 4k OR 1080p)'),
    ("2", "Telegram + Mega Focused", '(site:dood.to OR site:dood.wf) (onlyfans OR leaked) (mega.nz OR t.me OR telegram) (pack OR full)'),
    ("3", "Fresh 2025-2026 Content", 'site:dood.to OR site:dood.wf (onlyfans OR leaked OR full pack) after:2024'),
    ("4", "Studio / Premium Leaks", 'site:dood.to OR site:dood.wf (brazzers OR realitykings OR blacked OR vixen OR naughtyamerica OR bangbros) (full OR leaked OR 4k)'),
    ("5", "Direct /d/ Links Only", '"dood.to/d/" OR "dood.wf/d/" OR "dood.pm/d/" (onlyfans OR mega OR leaked OR pack)'),
    ("6", "Custom Dork", None),
]

def run_atscan_dood_harvest(dork: str):
    output_file = "doodstream_global_harvest.txt"
    console.print(f"[bold red]Launching ATSCAN with:[/bold red] {dork[:120]}...")

    cmd = [
        "perl", "./ATSCAN/atscan.pl",
        "--dork", dork,
        "--level", "3",
        "--motor", "google,bing,duck,mojeek,yandex",
        "--save", output_file,
        "--getlinks",
        "--unique"
    ]

    try:
        subprocess.run(cmd, check=True, timeout=900, capture_output=True, text=True)
        console.print("[green]ATSCAN completed.[/green]")
    except Exception as e:
        console.print(f"[red]ATSCAN error: {e}[/red]")
        return

    # Extract & save DoodStream links
    dood_links = []
    try:
        with open(output_file, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line and any(x in line for x in ["dood.to", "dood.wf", "dood.pm", "doodstream"]):
                    dood_links.append(line)
    except Exception as e:
        console.print(f"[red]Failed to parse results: {e}[/red]")
        return

    unique_links = list(dict.fromkeys(dood_links))
    console.print(f"\n[bold green]HARVEST COMPLETE — {len(unique_links)} unique DoodStream links[/bold green]")

    if unique_links:
        save_path = Path("doodstream_global_urls.txt")
        save_path.write_text("\n".join(unique_links) + "\n", encoding="utf-8")
        console.print(f"[bold green]→ Saved to {save_path}[/bold green]")

        if Confirm.ask("Show first 20 links?"):
            for link in unique_links[:20]:
                console.print(f"  → {link}")


def run(config, console):
    """Single-purpose global harvest with optimized dork menu"""
    console.print("\n[bold red]=== DOODSTREAM GLOBAL HARVEST v2.0 (Optimized Dorks) ===[/bold red]")
    console.print("[dim]Pure anonymous public link enumeration[/dim]\n")

    while True:
        console.print("[bold cyan]Optimized Dork Menu[/bold cyan]")
        for num, name, _ in DORK_MENU:
            console.print(f"   {num}. {name}")

        choice = Prompt.ask("Select dork", choices=[x[0] for x in DORK_MENU] + ["0"])

        if choice == "0":
            break

        selected = next((d for n, _, d in DORK_MENU if n == choice), None)
        
        if selected is None:  # Custom
            dork = Prompt.ask("Enter custom dork")
        else:
            dork = selected

        run_atscan_dood_harvest(dork)

        if not Confirm.ask("Run another harvest?"):
            break

    console.print("[green]DoodStream global harvest session closed.[/green]")


if __name__ == "__main__":
    run(None, console)
