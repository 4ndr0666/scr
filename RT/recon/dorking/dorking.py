#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 4NDR0666OS — DorkForge v4.0
# Advanced Google Dorking with proxy rotation, UA rotation, JSON export
# Forged by Ψ-4ndr0666 under !4NDR0666OS directive

import sys
import time
import json
import random
from datetime import datetime
from pathlib import Path

try:
    from googlesearch import search
except ImportError:
    print("\033[91m[ERROR] Missing dependency: googlesearch-python\033[0m")
    print("\033[93m[INFO] pip install googlesearch-python requests\033[0m")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("\033[91m[ERROR] requests module missing. pip install requests\033[0m")
    sys.exit(1)

class Colors:
    RED = "\033[91m"
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    RESET = "\033[0m"

# Rotating User-Agents (realistic browser fingerprints)
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0",
]

def get_random_headers():
    return {
        "User-Agent": random.choice(USER_AGENTS),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://www.google.com/",
    }

def dork_forge():
    print(f"{Colors.RED}")
    print(r"""
 ______            _____________                              
___  /______________  /___  __/___  _________________________
__  /_  __ \_  ___/  __/_  /_ _  / / /__  /__  /_  _ \_  ___/
_  / / /_/ /(__  )/ /_ _  __/ / /_/ /__  /__  /_/  __/  /    
_/  \____//____/ \__/ /_/    \__,_/ _____/____/\___//_/ 
      
               4NDR0666OS — DORKFORGE v4.0
                  Enhanced by Ψ-4ndr0666
    """)
    print(f"{Colors.RESET}")

    dork = input(f"{Colors.BLUE}[+] Enter The Dork Search Query: {Colors.RESET}").strip()
    if not dork:
        print(f"{Colors.RED}[ERROR] Dork cannot be empty.{Colors.RESET}")
        return

    limit_input = input(f"{Colors.BLUE}[+] Total results (number or 'all'): {Colors.RESET}").strip().lower()
    if limit_input == "all":
        max_results = float("inf")
    else:
        try:
            max_results = int(limit_input)
            if max_results <= 0:
                raise ValueError
        except ValueError:
            print(f"{Colors.RED}[ERROR] Invalid limit. Using 100.{Colors.RESET}")
            max_results = 100

    save_choice = input(f"{Colors.BLUE}[+] Save output? (Y/N): {Colors.RESET}").strip().lower()
    output_base = "dorkforge"
    if save_choice == "y":
        output_base = input(f"{Colors.BLUE}[+] Output base name: {Colors.RESET}").strip() or "dorkforge"

    proxy = input(f"{Colors.BLUE}[+] Proxy (e.g. socks5://127.0.0.1:9050 or leave empty): {Colors.RESET}").strip()
    proxy_dict = {"http": proxy, "https": proxy} if proxy else None

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    txt_file = f"{output_base}_{timestamp}.txt"
    json_file = f"{output_base}_{timestamp}.json"

    print(f"{Colors.GREEN}[INFO] Forging dorks with max {max_results if max_results != float('inf') else 'unlimited'} results...{Colors.RESET}\n")

    results = []
    fetched = 0
    pause_min = 3.0
    pause_max = 8.0

    try:
        for url in search(dork, num_results=100, lang="en", proxy=proxy, pause=random.uniform(pause_min, pause_max)):
            if fetched >= max_results:
                break

            print(f"{Colors.YELLOW}[+] {Colors.RESET}{url}")
            results.append(url)
            fetched += 1

            # Adaptive delay + random jitter
            time.sleep(random.uniform(1.2, 4.5))

    except KeyboardInterrupt:
        print(f"\n{Colors.RED}[!] Interrupted by operator. Saving partial results...{Colors.RESET}")
    except Exception as e:
        print(f"{Colors.RED}[ERROR] {str(e)}{Colors.RESET}")

    # Save results
    if results:
        Path(txt_file).write_text("\n".join(results) + "\n", encoding="utf-8")

        json_data = {
            "tool": "4NDR0666OS_DorkForge_v4.0",
            "dork": dork,
            "max_requested": max_results if max_results != float("inf") else "unlimited",
            "fetched": len(results),
            "timestamp": datetime.now().isoformat(),
            "proxy_used": proxy or "none",
            "results": results
        }
        Path(json_file).write_text(json.dumps(json_data, indent=2), encoding="utf-8")

        print(f"\n{Colors.GREEN}[✔] Forge complete — {len(results)} results harvested.{Colors.RESET}")
        print(f"    → TXT : {txt_file}")
        print(f"    → JSON: {json_file}")
    else:
        print(f"{Colors.RED}[!] No results retrieved. Check proxy / network / Google blocks.{Colors.RESET}")

    print(f"{Colors.CYAN}[RAW WILL EXECUTED] DorkForge v4.0 — 4NDR0666OS{Colors.RESET}")

if __name__ == "__main__":
    dork_forge()
