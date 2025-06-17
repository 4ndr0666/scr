python

#!/usr/bin/env python3
"""
DirMaid Extended (Revamped)
===========================

A dynamic, automated file and directory management script with hierarchical
categorization, interactive duplicate handling, a single dry-run function, a
new main menu, and user-friendly config initialization.

FEATURES:
---------
1) Unified 'organize' command for (alphabet/date/type/hierarchical).
2) Comprehensive user-driven duplicate resolution (rename, remove, or move to ~/Duplicates).
3) Batch rename with collision checks (idempotent logic).
4) Flatten directories, remove empty subdirs, with optional dry-run toggles.
5) JSON/YAML config loading plus a user-friendly 'init_config_file' function for automatic config creation.
6) 'check_and_install_dependencies' for Arch-based systems.
7) 'show_tips' function for chmod usage & relevant shell one-liners.

DEPENDENCIES (Arch-based):
--------------------------
- pacman or yay for system tools (jdupes, unrar, libarchive).
- Python modules: rich, py7zr, rarfile, pyyaml.

USAGE:
------
   chmod +x dirmaid_extended.py
   ./dirmaid_extended.py
or
   python3 dirmaid_extended.py
"""

import os
import shutil
import mimetypes
import hashlib
import zipfile
import tarfile
import py7zr
import rarfile
import logging
import json
import subprocess
from pathlib import Path
from datetime import datetime
from time import sleep

# Rich-based CLI
from rich.console import Console
from rich.table import Table
from rich.prompt import Prompt

try:
    import yaml

    YAML_AVAILABLE = True
except ImportError:
    YAML_AVAILABLE = False

console = Console()

###############################################################################
# LOGGING & DIRECTORIES
###############################################################################
log_dir = os.path.expanduser("~/dirmaid_logs")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, "dirmaid_extended.log")

logging.basicConfig(
    filename=log_file_path,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

###############################################################################
# DEFAULT CONFIG & HIERARCHY
###############################################################################
DEFAULT_CONFIG = {
    "categories": {
        "Pictures": ["image"],
        "Media": ["audio", "video"],
        "Documents": [
            "text",
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ],
        "Archives": [
            "application/zip",
            "application/x-rar-compressed",
            "application/x-7z-compressed",
            "application/gzip",
            "application/x-tar",
        ],
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
    },
    "hierarchy": {
        "Media": {
            "Images": ["image/jpeg", "image/png", "image/gif", "image/webp"],
            "Videos": ["video/mp4", "video/x-matroska"],
        },
        "Documents": {
            "WordDocs": [
                "application/msword",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ],
            "PDFs": ["application/pdf"],
        },
    },
}

CONFIG = {
    "categories": dict(DEFAULT_CONFIG["categories"]),
    "extensions": dict(DEFAULT_CONFIG["extensions"]),
    "hierarchy": dict(DEFAULT_CONFIG["hierarchy"]),
}


###############################################################################
# DEPENDENCY AUTO-INSTALL
###############################################################################
def check_and_install_dependencies():
    """
    Checks and installs missing Arch-based packages or Python libs automatically.
    """
    arch_release = Path("/etc/arch-release")
    pacman_bin = shutil.which("pacman")

    if not arch_release.exists() and not pacman_bin:
        console.print(
            "[bold red]Not an Arch-based system (or no pacman). "
            "Please install dependencies manually.[/bold red]"
        )
        return

    sys_packages = [("jdupes", "jdupes"), ("unrar", "unrar"), ("bsdtar", "libarchive")]
    for bin_name, pkg_name in sys_packages:
        if not shutil.which(bin_name):
            console.print(f"[bold yellow]Installing {pkg_name}...[/bold yellow]")
            if shutil.which("yay"):
                subprocess.run(["yay", "-S", "--noconfirm", pkg_name])
            else:
                subprocess.run(["sudo", "pacman", "-S", "--noconfirm", pkg_name])

    required_pip = ["rich", "py7zr", "rarfile", "pyyaml"]
    for pkg in required_pip:
        try:
            __import__(pkg)
        except ImportError:
            console.print(
                f"[bold yellow]Installing Python package: {pkg}[/bold yellow]"
            )
            subprocess.run(["pip", "install", pkg])


###############################################################################
# CONFIG SETUP
###############################################################################
def init_config_file():
    """
    Create a user-friendly config in ~/.config/dirmaid/dirmaid_config.json.
    Instead of asking for MIME types, provide toggles for top-level categories
    and a single question about advanced hierarchy usage.
    """
    home_config_dir = Path("~/.config/dirmaid").expanduser()
    home_config_dir.mkdir(parents=True, exist_ok=True)
    config_path = home_config_dir / "dirmaid_config.json"

    console.print("[bold cyan]User-Friendly Config Setup[/bold cyan]")
    console.print("Choose which default categories to enable:")
    default_cats = ["Pictures", "Media", "Documents", "Archives"]
    user_cats = {}
    for cat in default_cats:
        choice = Prompt.ask(f"Enable '{cat}'? (y/n)", default="y")
        if choice.lower().startswith("y"):
            user_cats[cat] = DEFAULT_CONFIG["categories"].get(cat, [])

    # Build a basic 'categories' map
    final_categories = user_cats if user_cats else CONFIG["categories"]

    console.print(
        "\n[bold cyan]Enable advanced hierarchical structure for images/docs? (y/n)[/bold cyan]"
    )
    adv_choice = Prompt.ask("Your choice", default="n")
    if adv_choice.lower().startswith("y"):
        final_hierarchy = DEFAULT_CONFIG["hierarchy"]
    else:
        final_hierarchy = {}

    final_conf = {
        "categories": final_categories,
        "extensions": CONFIG["extensions"],
        "hierarchy": final_hierarchy,
    }

    with config_path.open("w", encoding="utf-8") as f:
        json.dump(final_conf, f, indent=2)
    console.print(f"[bold green]Config created at: {config_path}[/bold green]")


def load_config_from_file(config_path):
    global CONFIG
    p = Path(config_path)
    if not p.is_file():
        console.print(f"[bold red]Config file not found: {p}[/bold red]")
        return

    ext = p.suffix.lower()
    try:
        if ext == ".json":
            with p.open("r", encoding="utf-8") as f:
                data = json.load(f)
        elif ext in [".yml", ".yaml"] and YAML_AVAILABLE:
            with p.open("r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
        else:
            console.print(
                f"[bold red]Unsupported config format or missing PyYAML: {p}[/bold red]"
            )
            return
    except Exception as e:
        console.print(f"[bold red]Error parsing config: {e}[/bold red]")
        return

    for key in ["categories", "extensions", "hierarchy"]:
        if key in data and isinstance(data[key], dict):
            CONFIG[key].update(data[key])
    console.print("[bold green]Config loaded & merged successfully![/bold green]")


###############################################################################
# DUPLICATE & COLLISION LOGIC
###############################################################################
def generate_file_hash(file_path):
    BUF_SIZE = 65536
    sha256 = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            while True:
                chunk = f.read(BUF_SIZE)
                if not chunk:
                    break
                sha256.update(chunk)
        return sha256.hexdigest()
    except Exception as e:
        logging.error(f"Hash error on {file_path}: {e}")
        return None


def handle_duplicates_conflict(file_path, existing_file):
    """
    Prompt user for how to handle a discovered collision.
    Options => rename new, move new to ~/Duplicates, remove new, skip.
    Default => move new to ~/Duplicates after 15s no response.
    """
    console.print(
        f"[bold yellow]Collision detected:[/bold yellow]\n  Original: {existing_file}\n  New: {file_path}"
    )
    console.print(
        "[R]ename / [M]ove => ~/Duplicates / [D]elete new / [S]kip (default M after 15s)"
    )
    from threading import Timer

    user_decision = {}

    def timeout():
        user_decision["choice"] = "M"
        console.print("[bold yellow]Defaulting to Move => ~/Duplicates[/bold yellow]")

    t = Timer(15.0, timeout)
    t.start()
    choice = Prompt.ask("Choice", default="M")
    t.cancel()

    if choice.upper() == "R":
        short_hash = (generate_file_hash(file_path) or "nodigest")[:8]
        new_name = f"{Path(file_path).stem}_{short_hash}{Path(file_path).suffix}"
        new_path = Path(file_path).parent / new_name
        return new_path
    elif choice.upper() == "D":
        try:
            Path(file_path).unlink()
            console.print("[bold red]New file removed.[/bold red]")
        except Exception as e:
            console.print(f"[bold red]Remove error: {e}[/bold red]")
        return None
    elif choice.upper() == "S":
        console.print("[bold yellow]Skipping...[/bold yellow]")
        return None
    else:
        duplicates_dir = Path("~/Duplicates").expanduser()
        duplicates_dir.mkdir(exist_ok=True)
        new_path = duplicates_dir / Path(file_path).name
        return new_path


def dry_run(action, source, destination=None, extra=None):
    msg = f"DRY-RUN => {action}: {source}"
    if destination:
        msg += f" -> {destination}"
    if extra:
        msg += f" [info: {extra}]"
    console.print(f"[bold cyan]{msg}[/bold cyan]")
    logging.info(msg)


def find_and_handle_duplicates(directory):
    """
    Uses jdupes to find duplicates, then prompts user for conflict resolution
    for each discovered set.
    """
    dir_path = Path(directory)
    if not dir_path.is_dir():
        console.print(f"[bold red]{directory} invalid.[/bold red]")
        return

    try:
        cmd = ["jdupes", "-r", "-n", "-A", "-m", str(dir_path)]
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if proc.returncode == 0 and proc.stdout:
            lines = proc.stdout.strip().split("\n")
            duplicates_blocks = []
            block = []
            for line in lines:
                if not line.strip():
                    if block:
                        duplicates_blocks.append(block)
                        block = []
                else:
                    block.append(line)
            if block:
                duplicates_blocks.append(block)

            for block in duplicates_blocks:
                if len(block) <= 1:
                    continue
                console.print("[bold green]Duplicate set found:[/bold green]")
                for f in block:
                    console.print(f"  {f}")
                base_file = Path(block[0])
                for dupf in block[1:]:
                    new_file = Path(dupf)
                    new_path = handle_duplicates_conflict(new_file, base_file)
                    if new_path and new_path != new_file:
                        try:
                            new_file.rename(new_path)
                            console.print(f"Moved => {new_path}")
                        except Exception as e:
                            console.print(f"[bold red]Rename error: {e}[/bold red]")
        else:
            console.print(
                "[bold yellow]No duplicates or none found by jdupes.[/bold yellow]"
            )
    except FileNotFoundError:
        console.print(
            "[bold red]jdupes not installed. Install or implement fallback approach.[/bold red]"
        )


###############################################################################
# HIERARCHICAL CATEGORIZATION & ORGANIZATION
###############################################################################
def hierarchical_path(mime_type):
    """
    Returns a subfolder path from CONFIG['hierarchy']. If not found, fallback => "Others".
    """
    h = CONFIG.get("hierarchy", {})
    for top_level, sub_dict in h.items():
        for sub_level, mimes in sub_dict.items():
            if mime_type in mimes:
                suffix = mime_type.split("/")[-1].upper()
                return f"{top_level}/{sub_level}/{suffix}"
    return "Others"


def categorize_file(file_path, strategy="type"):
    """
    If 'hierarchical', use hierarchical_path for deeper subfolders.
    'type' => old approach with broad categories.
    'alphabet'/'date' => handled in separate logic.
    """
    if strategy in ["alphabet", "date"]:
        return None
    if strategy == "hierarchical":
        mime_type, _ = mimetypes.guess_type(file_path)
        if mime_type:
            return hierarchical_path(mime_type)
        else:
            return "Others"
    # default = type-based
    mime_type, _ = mimetypes.guess_type(file_path)
    if mime_type:
        for cat, cat_list in CONFIG["categories"].items():
            if any(mime_type.startswith(x) for x in cat_list):
                return cat
    ext = Path(file_path).suffix.lower()
    return CONFIG["extensions"].get(ext, "Others")


def organize(directory, strategy, simulate=False):
    dir_path = Path(directory)
    if not dir_path.is_dir():
        console.print(f"[bold red]Invalid directory => {directory}[/bold red]")
        return
    if strategy == "alphabet":
        organize_alphabet(dir_path, simulate)
    elif strategy == "date":
        organize_date(dir_path, simulate)
    else:
        organize_category(dir_path, strategy, simulate)


def organize_alphabet(dir_path, simulate):
    for f in dir_path.glob("*.*"):
        if f.is_file():
            letter = f.stem[0].upper()
            target = dir_path / letter
            if simulate:
                dry_run("MOVE", f, target)
            else:
                target.mkdir(exist_ok=True)
                collision = target / f.name
                if collision.exists():
                    newp = handle_duplicates_conflict(str(f), collision)
                    if newp and newp != f:
                        try:
                            f.rename(newp)
                        except Exception as e:
                            console.print(f"[red]Rename error: {e}[/red]")
                else:
                    try:
                        shutil.move(str(f), str(target))
                    except Exception as e:
                        console.print(f"[red]Move error: {e}[/red]")
    if not simulate:
        console.print("[bold green]Alphabet-based organization complete.[/bold green]")
    else:
        console.print("[bold yellow]DRY-RUN: Alphabet done.[/bold yellow]")


def organize_date(dir_path, simulate):
    for f in dir_path.glob("*.*"):
        if f.is_file():
            mtime = f.stat().st_mtime
            date_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")
            target = dir_path / date_str
            if simulate:
                dry_run("MOVE", f, target)
            else:
                target.mkdir(exist_ok=True)
                collision = target / f.name
                if collision.exists():
                    newp = handle_duplicates_conflict(str(f), collision)
                    if newp and newp != f:
                        try:
                            f.rename(newp)
                        except Exception as e:
                            console.print(f"[red]Rename error: {e}[/red]")
                else:
                    try:
                        shutil.move(str(f), str(target))
                    except Exception as e:
                        console.print(f"[red]Move error: {e}[/red]")
    if not simulate:
        console.print("[bold green]Date-based organization complete.[/bold green]")
    else:
        console.print("[bold yellow]DRY-RUN: Date done.[/bold yellow]")


def organize_category(dir_path, strategy, simulate):
    for f in dir_path.glob("*.*"):
        if f.is_file():
            cat = categorize_file(str(f), strategy)
            if not cat:
                cat = "Others"
            target = dir_path / cat
            if simulate:
                dry_run("MOVE", f, target)
            else:
                target.mkdir(parents=True, exist_ok=True)
                collision = target / f.name
                if collision.exists():
                    newp = handle_duplicates_conflict(str(f), collision)
                    if newp and newp != f:
                        try:
                            f.rename(newp)
                        except Exception as e:
                            console.print(f"[red]Rename error: {e}[/red]")
                else:
                    try:
                        shutil.move(str(f), str(target))
                    except Exception as e:
                        console.print(f"[red]Move error: {e}[/red]")
                # If 'type' strategy => auto-extract archives
                if strategy == "type" and cat == "Archives":
                    extract_archive(str(target / f.name), str(target))
    if not simulate:
        console.print("[bold green]Category-based organization complete.[/bold green]")
    else:
        console.print("[bold yellow]DRY-RUN: Category done.[/bold yellow]")


def extract_archive(file_path, target_directory):
    try:
        if file_path.endswith(".zip"):
            with zipfile.ZipFile(file_path, "r") as z:
                z.extractall(target_directory)
        elif any(file_path.endswith(x) for x in [".tar.gz", ".tgz", ".tar"]):
            with tarfile.open(file_path, "r:*") as t:
                t.extractall(target_directory)
        elif file_path.endswith(".7z"):
            with py7zr.SevenZipFile(file_path, "r") as z7:
                z7.extractall(target_directory)
        elif file_path.endswith(".rar"):
            with rarfile.RarFile(file_path, "r") as rr:
                rr.extractall(target_directory)
        logging.info(f"Extracted => {file_path}")
    except Exception as e:
        console.print(f"[bold red]Extraction error: {e}[/bold red]")


###############################################################################
# FLATTEN & CLEANUP
###############################################################################
def flatten_directory(directory, simulate=False):
    d = Path(directory)
    if not d.is_dir():
        console.print(f"[bold red]Invalid directory => {directory}[/bold red]")
        return
    for subdir, _, files in os.walk(d):
        for file in files:
            src = Path(subdir) / file
            if src == d / file:
                continue
            if simulate:
                dry_run("MOVE", src, d)
            else:
                if (d / file).exists():
                    newp = handle_duplicates_conflict(str(src), (d / file))
                    if newp and newp != src:
                        try:
                            src.rename(newp)
                        except Exception as e:
                            console.print(f"[red]Rename error: {e}[/red]")
                else:
                    try:
                        shutil.move(str(src), str(d))
                        console.print(f"Flatten => {src} -> {d}")
                    except Exception as e:
                        console.print(f"[red]Flatten move error: {e}[/red]")
    if not simulate:
        console.print("[bold green]Directory flattened successfully.[/bold green]")
    else:
        console.print("[bold yellow]DRY-RUN flatten done.[/bold yellow]")


def remove_empty_subdirectories(directory, simulate=False):
    d = Path(directory)
    if not d.is_dir():
        console.print(f"[bold red]Invalid directory => {directory}[/bold red]")
        return
    empties = sorted(
        [p for p in d.rglob("*") if p.is_dir() and not any(p.iterdir())], reverse=True
    )
    for e in empties:
        if simulate:
            dry_run("DELETE_DIR", e)
        else:
            try:
                e.rmdir()
                console.print(f"Removed empty dir => {e}")
            except Exception as ex:
                console.print(f"[red]Removal error: {ex}[/red]")


###############################################################################
# BATCH RENAME
###############################################################################
def batch_rename(directory, pattern="{original_name}", simulate=False):
    d = Path(directory)
    if not d.is_dir():
        console.print(f"[bold red]Invalid directory => {directory}[/bold red]")
        return
    counter = 1
    for f in d.glob("*.*"):
        if f.is_file():
            mtime = f.stat().st_mtime
            date_str = datetime.fromtimestamp(mtime).strftime("%Y%m%d")
            ext = f.suffix
            orig = f.stem
            new_name = pattern.format(
                original_name=orig, ext=ext, date=date_str, counter=counter
            )
            counter += 1
            new_path = d / new_name
            if simulate:
                dry_run("RENAME", f, new_path)
            else:
                if new_path.exists():
                    newp = handle_duplicates_conflict(str(f), new_path)
                    if newp and newp != f:
                        try:
                            f.rename(newp)
                            console.print(f"Renamed => {f.name} -> {newp.name}")
                        except Exception as e:
                            console.print(f"[red]Rename error: {e}[/red]")
                else:
                    try:
                        f.rename(new_path)
                        console.print(f"Renamed => {f.name} -> {new_name}")
                    except Exception as e:
                        console.print(f"[red]Rename error: {e}[/red]")


###############################################################################
# SHOW TIPS
###############################################################################
def show_tips():
    console.print("[bold green]DirMaid Tips & Tricks[/bold green]\n")
    console.print("1) [bold]chmod basics[/bold]:")
    console.print("   chmod +x script.sh => Make file executable")
    console.print("   chmod 755 mydir => rwxr-xr-x\n")
    console.print("2) [bold]Handy One-Liners[/bold]:")
    console.print(
        "   find /path -name '*.zip' -exec ./dirmaid_extended.py {} \\;  => For each .zip, pass to script."
    )
    console.print(
        "   find /path -empty -type d -exec rmdir {} \\; => Remove all empty directories."
    )
    console.print("\nPress Enter to return.")
    input()


###############################################################################
# MAIN MENU
###############################################################################
def main_menu():
    check_and_install_dependencies()
    console.clear()
    console.print(
        "[bold magenta]DirMaid Extended (Revamped)[/bold magenta]", justify="center"
    )

    tbl = Table(show_header=True, header_style="bold blue")
    tbl.add_column("Option", style="dim", width=3)
    tbl.add_column("Description")
    tbl.add_row("1", "Organize Files")
    tbl.add_row("2", "Find & Handle Duplicates")
    tbl.add_row("3", "Flatten Directory")
    tbl.add_row("4", "Remove Empty Subdirectories")
    tbl.add_row("5", "Batch Rename")
    tbl.add_row("6", "Config File Setup (Init/Load)")
    tbl.add_row("7", "Show Tips (Permissions & One-liners)")
    tbl.add_row("T", "Toggle Dry-Run Mode")
    tbl.add_row("Q", "Quit")

    console.print(tbl)
    status = "ON" if main_menu.dry_run else "OFF"
    console.print(f"[bold cyan]Dry-Run Mode: {status}[/bold cyan]")
    choice = Prompt.ask("[bold green]Select an option[/bold green]", default="1")

    if choice == "1":
        directory = Prompt.ask("[bold cyan]Directory to organize[/bold cyan]")
        strategy = Prompt.ask(
            "[bold cyan]Strategy[/bold cyan]",
            choices=["alphabet", "date", "type", "hierarchical"],
            default="type",
        )
        organize(directory, strategy, simulate=main_menu.dry_run)
    elif choice == "2":
        d = Prompt.ask("[bold cyan]Directory to check duplicates[/bold cyan]")
        find_and_handle_duplicates(d)
    elif choice == "3":
        d = Prompt.ask("[bold cyan]Directory to flatten[/bold cyan]")
        flatten_directory(d, simulate=main_menu.dry_run)
    elif choice == "4":
        d = Prompt.ask("[bold cyan]Directory to remove empty subdirs[/bold cyan]")
        remove_empty_subdirectories(d, simulate=main_menu.dry_run)
    elif choice == "5":
        d = Prompt.ask("[bold cyan]Directory for batch rename[/bold cyan]")
        pat = Prompt.ask(
            "[bold cyan]Rename pattern[/bold cyan]", default="{original_name}{ext}"
        )
        batch_rename(d, pat, simulate=main_menu.dry_run)
    elif choice == "6":
        subc = Prompt.ask(
            "[I]nit new config or [L]oad existing?", choices=["I", "L"], default="I"
        )
        if subc.upper() == "I":
            init_config_file()
        else:
            path_ = Prompt.ask("Path to config file")
            load_config_from_file(path_)
    elif choice == "7":
        show_tips()
    elif choice.upper() == "T":
        main_menu.dry_run = not main_menu.dry_run
    elif choice.upper() == "Q":
        console.print("[bold red]Exiting...[/bold red]")
        return
    else:
        console.print("[bold red]Invalid choice.[/bold red]")

    sleep(2)
    main_menu()


main_menu.dry_run = False

if __name__ == "__main__":
    main_menu()
