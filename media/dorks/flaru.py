#!/usr/bin/env python3
# flaru.py
# Ψ-4ndr0666 FLARU OSINT/Leak Terminal Suite Orchestrator

import os
import sys
import subprocess
from prompt_toolkit.shortcuts import radiolist_dialog, input_dialog
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.styles import Style
import requests

CYAN = "\033[38;2;21;255;255m"
GREEN = "\033[38;2;21;255;128m"
RED = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET = "\033[0m"

SCRIPTS = [
    ("Image Enumerator", "image_enum.py"),
    ("Reddit Ripper", "script.py"),
    ("Searchmaster Dorker", "searchmaster.py"),
    ("Brute/Recursive Image Enum", "url_scrapper.py"),
]

PLUGINS_DIR = "plugins"

style = Style.from_dict({
    "dialog": "bg:#1e1e1e",
    "button": "fg:#15FFFF bold",
    "completion-menu.completion": "fg:#15FFFF bg:default",
    "completion-menu.completion.current": "fg:#15FFFF bg:#333333",
    "prompt": "ansicyan",
})

def launch_script(script):
    if not os.path.isfile(script):
        print(f"{RED}[!] Missing script: {script}{RESET}")
        return
    try:
        subprocess.run([sys.executable, script], check=False)
    except Exception as e:
        print(f"{RED}[!] Failed: {e}{RESET}")

def discover_plugins():
    if not os.path.isdir(PLUGINS_DIR):
        return []
    found = []
    for fn in os.listdir(PLUGINS_DIR):
        path = os.path.join(PLUGINS_DIR, fn)
        if os.access(path, os.X_OK) and os.path.isfile(path):
            found.append(path)
    return found

def run_plugin_menu():
    plugins = discover_plugins()
    if not plugins:
        print(f"{YELLOW}No executable plugins found in plugins/.{RESET}")
        return
    items = [(p, HTML(f"<style fg=\"#15FFFF\">{os.path.basename(p)}</style>")) for p in plugins]
    result = radiolist_dialog(
        title=HTML('<style fg="#15FFFF">Ψ-4ndr0666 Plugin Launcher</style>'),
        text=HTML('Select a <style fg="#15FFFF">plugin</style> to run.'),
        values=items,
        style=style,
    ).run()
    if result:
        subprocess.run([sys.executable, result])

def main_menu():
    while True:
        print(f"\n{CYAN}Ψ-4ndr0666 FLARU OSINT Terminal Suite{RESET}")
        options = [
            ("Image Enumerator", "image_enum.py"),
            ("Reddit Ripper", "script.py"),
            ("Searchmaster Dorker", "searchmaster.py"),
            ("Brute/Recursive Image Enum", "url_scrapper.py"),
            ("Run Plugin (Ψ Shell/Python)", "plugin"),
            ("Exit", "exit"),
        ]
        opts = [(k, HTML(f"<style fg=\"#15FFFF\">{k}</style>")) for k, v in options]
        result = radiolist_dialog(
            title=HTML('<style fg="#15FFFF">FLARU Main Menu</style>'),
            text=HTML("Select a function to launch:"),
            values=opts,
            style=style,
        ).run()
        if result is None or result == "Exit":
            print(f"{CYAN}Bye!{RESET}")
            break
        elif result == "Run Plugin (Ψ Shell/Python)":
            run_plugin_menu()
        else:
            for label, fn in options:
                if label == result:
                    launch_script(fn)
                    break

if __name__ == "__main__":
    main_menu()
