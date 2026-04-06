#!/usr/bin/env python3
# ATSCAN + Dorkmaster Universal Gallery Temple Wrapper
# Fully prompted, no forced celebhottie

import subprocess
import asyncio
import sys
import os
from urllib.parse import urlparse
from pathlib import Path
from rich.console import Console
from rich.prompt import Prompt

console = Console()

# Import from dorkmaster (adjust filename if needed)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from compare import GalleryEnumerator, DOWNLOADS_DIR, download_with_aria2c
except ImportError:
    console.print("[red]Failed to import GalleryEnumerator from compare.py[/red]")
    sys.exit(1)

async def run_atscan_dork(dork_query: str, output_file: str = "atscan_hits.txt"):
    console.print(f"[cyan]Running ATSCAN dork:[/cyan] {dork_query}")
    cmd = ["perl", "./ATSCAN/atscan.pl", "--dork", dork_query, "--level", "3", "--motor", "google,bing,duck", "--save", output_file, "--getlinks"]
    try:
        subprocess.run(cmd, check=True, timeout=420, capture_output=True, text=True)
        console.print("[green]ATSCAN finished.[/green]")
        return output_file
    except Exception as e:
        console.print(f"[red]ATSCAN failed: {e}[/red]")
        return None

async def run_temple(domain: str, cdn_base: str):
    console.print(f"[bold cyan]Starting Universal Gallery Temple on {domain} | CDN: {cdn_base}[/bold cyan]")
    enum = GalleryEnumerator()
    media = await enum.run_full_enumeration(domain, cdn_base, numeric_range=(1000, 6000))
    console.print(f"[bold green]Temple complete — {len(media)} media links saved.[/bold green]")
    
    if media and Prompt.ask("Download all with aria2c now?", choices=["y", "n"], default="y") == "y":
        save_dir = Path("~/Downloads/hybrid_temple").expanduser()
        save_dir.mkdir(parents=True, exist_ok=True)
        download_with_aria2c(media, save_dir)
    return media

async def main():
    console.print("[bold red]=== ATSCAN + Universal Gallery Temple Hybrid Pipeline ===[/bold red]")

    # === SEED PHASE ===
    seed_url = Prompt.ask("Enter seed URL (or press Enter to skip and use custom dork)", default="")
    
    if seed_url:
        parsed = urlparse(seed_url)
        domain_from_seed = parsed.netloc.replace("www.", "")
        console.print(f"[cyan]Seed domain detected: {domain_from_seed}[/cyan]")
        
        # Smart dork based on seed
        dork = f'site:{domain_from_seed} (imagenes OR multimedia OR assets OR gallery OR fotos) (jpg OR png OR webp OR gif)'
    else:
        dork = Prompt.ask("Enter custom ATSCAN dork")

    hits_file = await run_atscan_dork(dork)

    # === TEMPLE PHASE ===
    console.print("\n[bold]Configure the Temple target (where we will enumerate galleries + brute CDN)[/bold]")
    
    if seed_url:
        suggested_domain = domain_from_seed
        suggested_cdn = f"https://{domain_from_seed}"
    else:
        suggested_domain = "celebhottie.com"
        suggested_cdn = "https://cdn.celebhottie.com"

    target_domain = Prompt.ask("Temple target domain", default=suggested_domain)
    target_cdn = Prompt.ask("Temple CDN base URL", default=suggested_cdn)

    await run_temple(target_domain, target_cdn)

    # Optional second temple run
    if Prompt.ask("Run temple on another domain?", choices=["y", "n"], default="n") == "y":
        extra_domain = Prompt.ask("Extra domain")
        extra_cdn = Prompt.ask("Extra CDN base", default=f"https://cdn.{extra_domain}")
        await run_temple(extra_domain, extra_cdn)

    console.print("\n[bold green]Pipeline finished. All results saved to temple_results/[/bold green]")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        console.print("\n[yellow]Pipeline stopped by user.[/yellow]")
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
