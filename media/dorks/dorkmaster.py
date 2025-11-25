#!/usr/bin/env python3
# flaru_terminal_suite.py
# Ψ-4ndr0666's unstoppable modular OSINT/media terminal launcher

import sys, os, subprocess, shutil, json
from prompt_toolkit import prompt
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.styles import Style
from collections import defaultdict

style = Style.from_dict({
    "prompt":      "fg:#15FFFF bold",
    "success":     "fg:#00FFAF bold",
    "error":       "fg:#FF5F5F bold",
    "menu":        "fg:#FFD700 bold",
    "info":        "fg:#FFFA72",
})

CYAN = "\033[38;5;51m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
RESET = "\033[0m"
BOLD = "\033[1m"

SESSION_FILE = os.path.expanduser("~/.flaru_session.json")
SESSION = {
    "targets": [],
    "dorks": [],
    "urls": [],
    "domains": [],
    "images": [],
    "exports": [],
}

def load_session():
    if os.path.exists(SESSION_FILE):
        try:
            with open(SESSION_FILE, "r") as f:
                SESSION.update(json.load(f))
        except Exception:
            pass

def save_session():
    with open(SESSION_FILE, "w") as f:
        json.dump(SESSION, f, indent=2)

def color_block(msg, type_):
    color = {"info": YELLOW, "success": GREEN, "error": RED}.get(type_, CYAN)
    print(f"{color}{BOLD}{msg}{RESET}")

def opsec_warning():
    color_block(
        "!! Always use VPN, Tor, or proxy for sensitive searches/downloads. Only operate in a VM or isolated env for dump/warez scraping !!",
        "error"
    )

def main_menu():
    load_session()
    while True:
        print(f"\n{CYAN}{BOLD}Ψ-4ndr0666 Flaru Terminal Suite{RESET}")
        print(f"{YELLOW}1.{RESET} Dork Google for Media Links")
        print(f"{YELLOW}2.{RESET} Brute-Force/Enumerate Images")
        print(f"{YELLOW}3.{RESET} Recursive Web Album Crawl")
        print(f"{YELLOW}4.{RESET} Reddit/Chan Dump")
        print(f"{YELLOW}5.{RESET} Batch Export/Clipboard All Results")
        print(f"{YELLOW}6.{RESET} OpSec Help & Info")
        print(f"{YELLOW}7.{RESET} Exit")

        choice = prompt(HTML('<prompt>Select mode [1-7]:</prompt> '), style=style).strip()
        if choice == '1':
            opsec_warning()
            run_dork_modal()
        elif choice == '2':
            opsec_warning()
            run_image_enum()
        elif choice == '3':
            opsec_warning()
            run_url_scrapper()
        elif choice == '4':
            opsec_warning()
            run_reddit_script()
        elif choice == '5':
            export_session()
        elif choice == '6':
            print_opsec()
        elif choice == '7':
            save_session()
            print(f"{CYAN}Session saved. Goodbye!{RESET}")
            break
        else:
            color_block("Invalid selection.", "error")


def run_dork_modal():
    # Use your existing dork modal logic, or shell out to your preferred dork builder.
    # For now, simple subprocess call to your python modal for demo:
    try:
        cmd = ["python3", "dorkmaster-modal.py"]
        subprocess.run(cmd)
        # Optionally, read new dorks/targets from session file, clipboard, or manual import
        # Here, you could add code to ingest/export found dorks
    except Exception as e:
        color_block(f"Failed to run dork modal: {e}", "error")

def run_image_enum():
    # Launch image_enum.py (supports --menu for interactive)
    img_enum = "./image_enum.py"
    if not os.path.exists(img_enum):
        color_block("image_enum.py not found in current directory!", "error")
        return
    try:
        print(f"{CYAN}Launching brute/recursive image enumerator...{RESET}")
        subprocess.run(["python3", img_enum, "--menu"])
    except Exception as e:
        color_block(f"Failed to run image_enum.py: {e}", "error")

def run_url_scrapper():
    # Launch url_scrapper.py (async/modern version)
    url_scrapper = "./url_scrapper.py"
    if not os.path.exists(url_scrapper):
        color_block("url_scrapper.py not found in current directory!", "error")
        return
    try:
        print(f"{CYAN}Launching advanced image enumerator...{RESET}")
        # Default to menu flag, or let user choose mode (extend as needed)
        subprocess.run(["python3", url_scrapper, "--menu"])
    except Exception as e:
        color_block(f"Failed to run url_scrapper.py: {e}", "error")

def run_reddit_script():
    # Launch your Reddit/chan scraper (script.py)
    reddit_script = "./script.py"
    if not os.path.exists(reddit_script):
        color_block("script.py not found in current directory!", "error")
        return
    try:
        print(f"{CYAN}Launching Reddit media downloader...{RESET}")
        subprocess.run(["python3", reddit_script])
    except Exception as e:
        color_block(f"Failed to run script.py: {e}", "error")

def export_session():
    # Export all found dorks/urls/domains/images to clipboard, file, or both
    save_session()
    print(f"{GREEN}Session exported to {SESSION_FILE}.{RESET}")
    try:
        import pyperclip
        with open(SESSION_FILE) as f:
            pyperclip.copy(f.read())
        print(f"{GREEN}Session JSON copied to clipboard!{RESET}")
    except ImportError:
        print(f"{YELLOW}pyperclip not installed. Install with: pip install pyperclip{RESET}")
    except Exception as e:
        print(f"{YELLOW}Clipboard export failed: {e}{RESET}")

def print_opsec():
    print("\n")
    color_block("Ψ-4ndr0666 OpSec Tips:", "info")
    print(f"{BOLD}1.{RESET} Always use a VPN, Tor, or proxy, especially for leaky/gray-area queries.")
    print(f"{BOLD}2.{RESET} Run this toolkit from a VM or sandbox.")
    print(f"{BOLD}3.{RESET} Never download direct dumps/archives to your real machine.")
    print(f"{BOLD}4.{RESET} When in doubt, research the legal risks before proceeding.")
    print(f"{BOLD}5.{RESET} If exporting results, review output for sensitive/private info before sharing.")
    input(f"{CYAN}Press Enter to continue...{RESET}")

if __name__ == "__main__":
    main_menu()

# ...continued from previous segment...

def ingest_file_lines(filepath, target_list, label="item"):
    """Ingests newlines from a file into a session list (avoids duplicates)."""
    if not os.path.exists(filepath):
        color_block(f"{filepath} not found for ingestion.", "error")
        return
    count = 0
    with open(filepath, "r") as f:
        for line in f:
            v = line.strip()
            if v and v not in target_list:
                target_list.append(v)
                count += 1
    print(f"{GREEN}Ingested {count} new {label}(s) from {filepath}.{RESET}")

def import_module_output():
    """
    Imports output files from submodules back into the main session.
    Typical file locations:
      - ~/.cache/image-enum/found_urls.txt
      - ~/.flaru_session.json
    """
    # Import from image_enum/url_scrapper found urls
    img_enum_path = os.path.expanduser("~/.cache/image-enum/found_urls.txt")
    ingest_file_lines(img_enum_path, SESSION["urls"], "URL")
    # Import from session file (self-updating, but allows for backup restore)
    if os.path.exists(SESSION_FILE):
        with open(SESSION_FILE, "r") as f:
            try:
                data = json.load(f)
                for k in ("dorks", "urls", "domains", "images"):
                    for v in data.get(k, []):
                        if v not in SESSION[k]:
                            SESSION[k].append(v)
            except Exception as e:
                color_block(f"Error importing from {SESSION_FILE}: {e}", "error")

def advanced_batch_tools_menu():
    print(f"\n{CYAN}Advanced Tools:{RESET}")
    print(f"{YELLOW}1.{RESET} Import URLs from last module output")
    print(f"{YELLOW}2.{RESET} Export all URLs/Dorks/Images to file")
    print(f"{YELLOW}3.{RESET} Pipe URLs to aria2c for batch download")
    print(f"{YELLOW}4.{RESET} Return to main menu")
    sel = prompt(HTML('<prompt>Pick option [1-4]:</prompt> '), style=style).strip()
    if sel == "1":
        import_module_output()
    elif sel == "2":
        out_path = prompt(HTML('<prompt>Filename to export all data to:</prompt> '), style=style)
        with open(out_path, "w") as f:
            json.dump(SESSION, f, indent=2)
        print(f"{GREEN}Exported all session data to {out_path}{RESET}")
    elif sel == "3":
        tmpfile = "/tmp/flaru_urls.txt"
        with open(tmpfile, "w") as f:
            for url in SESSION["urls"]:
                f.write(url + "\n")
        print(f"{CYAN}Running aria2c on all found URLs...{RESET}")
        subprocess.run(["aria2c", "-c", "-x8", "-j4", "-i", tmpfile])
    else:
        print("Returning.")

def main_menu():
    load_session()
    while True:
        print(f"\n{CYAN}{BOLD}Ψ-4ndr0666 Flaru Terminal Suite{RESET}")
        print(f"{YELLOW}1.{RESET} Dork Google for Media Links")
        print(f"{YELLOW}2.{RESET} Brute-Force/Enumerate Images")
        print(f"{YELLOW}3.{RESET} Recursive Web Album Crawl")
        print(f"{YELLOW}4.{RESET} Reddit/Chan Dump")
        print(f"{YELLOW}5.{RESET} Batch Export/Clipboard All Results")
        print(f"{YELLOW}6.{RESET} OpSec Help & Info")
        print(f"{YELLOW}7.{RESET} Advanced Tools (Import/Batch)")
        print(f"{YELLOW}8.{RESET} Exit")

        choice = prompt(HTML('<prompt>Select mode [1-8]:</prompt> '), style=style).strip()
        if choice == '1':
            opsec_warning()
            run_dork_modal()
        elif choice == '2':
            opsec_warning()
            run_image_enum()
        elif choice == '3':
            opsec_warning()
            run_url_scrapper()
        elif choice == '4':
            opsec_warning()
            run_reddit_script()
        elif choice == '5':
            export_session()
        elif choice == '6':
            print_opsec()
        elif choice == '7':
            advanced_batch_tools_menu()
        elif choice == '8':
            save_session()
            print(f"{CYAN}Session saved. Goodbye!{RESET}")
            break
        else:
            color_block("Invalid selection.", "error")

if __name__ == "__main__":
    main_menu()
