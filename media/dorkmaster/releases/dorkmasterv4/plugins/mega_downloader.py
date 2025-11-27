import subprocess
import os
import shutil
from rich.prompt import Prompt

def run(config, console):
    """Entry point for Dorkmaster Plugin System."""
    console.print("[bold cyan]MEGA.nz Batch Downloader[/bold cyan]")
    
    links_input = Prompt.ask("Enter Mega.nz links (comma-separated)")
    if not links_input:
        console.print("[yellow]No links provided.[/yellow]")
        return

    links = [l.strip() for l in links_input.split(",") if l.strip()]
    
    # Use config session dir or a specific downloads dir
    output_dir = os.path.join(config.get("session_dir", "."), "mega_downloads")
    
    console.print(f"[dim]Downloading to: {output_dir}[/dim]")
    
    results = batch_download(links, output_dir=output_dir)
    
    console.print(f"[green]Completed: {len(results['completed'])}[/green]")
    if results['failed']:
        console.print(f"[red]Failed: {len(results['failed'])}[/red]")
        for link, err in results['failed']:
            console.print(f"  - {link}: {err}")

def batch_download(links, output_dir=".", log_errors=True):
    """
    Batch download a list of Mega.nz links using megadl (megatools).
    Dedupes links, creates output_dir, logs errors, and returns completed/failed.
    """
    if not shutil.which("megadl"):
        msg = "[CRIT] megadl (megatools) is not installed or not in PATH."
        if log_errors:
            print(msg)
        return {"completed": [], "failed": [(link, msg) for link in links]}

    completed, failed = [], []
    os.makedirs(output_dir, exist_ok=True)
    for link in set(links):  # Dedupe
        cmd = ["megadl", link, "--path", output_dir]
        print(f"[MEGA] Downloading: {link}")
        try:
            subprocess.run(cmd, check=True, timeout=300)
            completed.append(link)
        except Exception as e:
            if log_errors:
                print(f"[MEGA] Failed: {link} ({e})")
            failed.append((link, str(e)))
    return {"completed": completed, "failed": failed}
