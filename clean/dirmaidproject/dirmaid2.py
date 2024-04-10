import shutil
import mimetypes
import hashlib
from datetime import datetime
from pathlib import Path
import subprocess
import logging
from time import sleep
import re

# Importing 'rich' for enhanced CLI experience
from rich.console import Console
from rich.table import Table
from rich.prompt import Prompt
from rich.progress import Progress

console = Console()
logging.basicConfig(filename='file_management.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

CONFIG = {
    "categories": {
        "Pictures": ["image"],
        "Media": ["audio", "video"],
        "Documents": ["text", "application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"],
        "Archives": ["application/zip", "application/x-rar-compressed", "application/x-7z-compressed", "application/gzip", "application/x-tar"],
    },
    "extensions": {
        ".pdf": "Documents",
        ".doc": "Documents",
        ".docx": "Documents",
        ".txt": "Documents",
        ".zip": "Archives",
        ".rar": "Archives",
        ".7z": "Archives",
        ".tar": "Archives",
        ".tar.gz": "Archives",
    }
}

def generate_file_hash(file_path):
    BUF_SIZE = 65536
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while chunk := f.read(BUF_SIZE):
            sha256.update(chunk)
    return sha256.hexdigest()

def categorize_file(file_path):
    mime_type, _ = mimetypes.guess_type(file_path)
    for category, types in CONFIG["categories"].items():
        if mime_type and any(mime_type.startswith(t) for t in types):
            return category
    ext = Path(file_path).suffix.lower()
    return CONFIG["extensions"].get(ext, "Others")

def handle_duplicates(file_path, target_directory):
    original_path = Path(file_path)
    new_path = target_directory / original_path.name
    file_hash = generate_file_hash(file_path)[:8]
    counter = 1
    while new_path.exists():
        new_path = target_directory / f"{original_path.stem}_{file_hash}_{counter}{original_path.suffix}"
        counter += 1
    return new_path

def find_duplicates(directory):
    command = ['jdupes', '-r', '-o', 'name', directory]
    process = subprocess.run(command, capture_output=True, text=True)
    if process.returncode == 0 and process.stdout:
        duplicates = process.stdout.strip().split('\n')
        console.print("[bold green]Duplicate files found:[/bold green]")
        for file in duplicates:
            console.print(file)
        logging.info(f"Duplicate files found: {', '.join(duplicates)}")
    else:
        console.print("[bold yellow]No duplicate files found.[/bold yellow]")

def organize_files(directory, method):
    directory_path = Path(directory)
    if method == "alphabet":
        organize_by_alphabet(directory_path)
    elif method == "date":
        organize_by_date(directory_path)
    elif method == "type":
        organize_by_type(directory_path)
    else:
        console.print(f"[bold red]Invalid organization method: {method}[bold red]")

def organize_by_alphabet(directory_path):
    for file_path in directory_path.glob('*.*'):
        if file_path.is_file():
            first_letter = file_path.stem[0].upper()
            target_dir = directory_path / first_letter
            target_dir.mkdir(exist_ok=True)
            shutil.move(str(file_path), str(target_dir / file_path.name))
    console.print("[bold green]Files organized by alphabet successfully![/bold green]")

def organize_by_date(directory_path):
    for file_path in directory_path.glob('*.*'):
        if file_path.is_file():
            mtime = file_path.stat().st_mtime
            date_folder = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d')
            target_dir = directory_path / date_folder
            target_dir.mkdir(exist_ok=True)
            shutil.move(str(file_path), str(target_dir / file_path.name))
    console.print("[bold green]Files organized by date successfully![/bold green]")

def organize_by_type(directory_path):
    for file_path in directory_path.glob('*.*'):
        if file_path.is_file():
            category = categorize_file(str(file_path))
            target_dir = directory_path / category
            target_dir.mkdir(exist_ok=True)
            shutil.move(str(file_path), str(target_dir / file_path.name))
    console.print("[bold green]Files organized by type successfully![/bold green]")

import os
import shutil
from pathlib import Path

def flatten_directory(directory):
    """
    Moves all files from subdirectories to the specified directory,
    effectively flattening the directory structure.
    """
    directory_path = Path(directory)
    if not directory_path.is_dir():
        console.print(f"[bold red]The specified directory does not exist: {directory}[/bold red]")
        return

    for subdir, _, files in os.walk(directory_path):
        for file in files:
            src_path = Path(subdir) / file
            dest_path = directory_path / file
            if src_path != dest_path:
                # Check if a file with the same name exists in the destination
                if dest_path.exists():
                    dest_path = handle_duplicates(str(src_path), directory_path)
                shutil.move(str(src_path), str(dest_path))
                console.print(f"Moved: {src_path} to {dest_path}")
    console.print("[bold green]Directory flattened successfully.[/bold green]")

def remove_empty_subdirectories(directory):
    """
    Removes all empty subdirectories from the specified directory.
    """
    directory_path = Path(directory)
    if not directory_path.is_dir():
        console.print(f"[bold red]The specified directory does not exist: {directory}[/bold red]")
        return

    empty_dirs = [d for d in directory_path.rglob('*') if d.is_dir() and not any(d.iterdir())]
    for d in empty_dirs:
        d.rmdir()
        console.print(f"Removed empty directory: {d}")
    console.print("[bold green]Empty subdirectories removed successfully.[/bold green]")

def main_menu():
    console.clear()
    console.print("[bold magenta]File Organizer 2.2[/bold magenta]", justify="center")

    table = Table(show_header=True, header_style="bold blue")
    table.add_column("Option", style="dim", width=12)
    table.add_column("Description")
    table.add_row("[1]", "Organize Files")
    table.add_row("[2]", "Generate File Hash")
    table.add_row("[3]", "Extract Archives")
    table.add_row("[4]", "Flatten Directory")
    table.add_row("[5]", "Remove Empty Subdirectories")
    table.add_row("[Q]", "Quit")

    console.print(table)
    choice = Prompt.ask("[bold green]Select an option[/bold green]", choices=["1", "2", "3", "4", "5", "Q"], default="1")

    if choice == '1':
        directory = Prompt.ask("[bold cyan]Enter the directory path[/bold cyan]")
        method = Prompt.ask("[bold cyan]Choose organization method (alphabet/date/type)[/bold cyan]", choices=["alphabet", "date", "type"])
        organize_files(directory, method=method)
        find_duplicates(directory)
    elif choice == '2':
        file_path = Prompt.ask("[bold cyan]Enter the file path[/bold cyan]")
        hash_result = generate_file_hash(file_path)
        console.print(f"[bold green]File hash: {hash_result}[/bold green]")
    elif choice == '3':
        directory = Prompt.ask("[bold cyan]Enter the directory path for archive extraction[/bold cyan]")
        extract_archive(directory)  # Assuming a corresponding function or logic exists
    elif choice == '4':
        directory = Prompt.ask("[bold cyan]Enter the directory path to flatten[/bold cyan]")
        flatten_directory(directory)
    elif choice == '5':
        directory = Prompt.ask("[bold cyan]Enter the directory path to remove empty subdirectories[/bold cyan]")
        remove_empty_subdirectories(directory)
    elif choice.upper() == 'Q':
        console.print("[bold red]Exiting...[/bold red]")
        exit()
    else:
        console.print("[bold red]Invalid option, please try again.[/bold red]")

    sleep(2)
    main_menu()

if __name__ == "__main__":
    main_menu()
