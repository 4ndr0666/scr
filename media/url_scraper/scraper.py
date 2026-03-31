#!/usr/bin/env python3
# scraper.py
# Ψ-4ndr0666 High-Performance Omni-Enumerator (v4.1.0-CERTIFIED)
#
# COHESION & SUPERSET REPORT:
# - Resolved: Terminal freezing and CDN tarpitting by deprecating aria2c subsystem.
# - Enhanced: Integrated gallery-dl as the primary transfer delegate for supreme CDN evasion.
# - Maintained: Unified Post-Exploitation prompt lifecycle & isatty() checks.
# - Maintained: Environmental dependency collision (lxml, certifi, platformdirs pinned).
# - Maintained: Stateful session tracking (Cookie acquisition via pre-flight).
# - Maintained: Padding mismatch 404s via unpadded fallback heuristic.
# - Maintained: Streamed GET WAF evasion & dynamic Referer injection.
# - Maintained: Async context manager lifecycle & core routing.

import argparse
import asyncio
import os
import re
import shutil
import subprocess
import sys
import tempfile
import webbrowser
from pathlib import Path
from typing import List, Set, Optional
from urllib.parse import urljoin, urlparse

try:
    import httpx
    from bs4 import BeautifulSoup
except ImportError:
    print("\033[1;31m[!] CRITICAL: Missing dependencies.\033[0m")
    print("Execute: pip install -r requirements.txt")
    sys.exit(1)


# --- XDG & Environment Setup ---
def get_xdg_dir(kind: str, fallback: str) -> Path:
    var = f"XDG_{kind.upper()}_HOME"
    return Path(os.environ.get(var, str(Path.home() / fallback)))


XDG_DATA = get_xdg_dir("data", ".local/share/akasha-enum")
XDG_CACHE = get_xdg_dir("cache", ".cache/akasha-enum")
DOWNLOADS_DIR = XDG_DATA / "downloads"
LOG_FILE = XDG_CACHE / "enum.log"

# --- Formatting Constants ---
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[1;32m"
RED = "\033[1;31m"
CYAN = "\033[0;36m"
YELLOW = "\033[0;33m"
MAGENTA = "\033[1;35m"


# --- Core Engine ---
class AkashaEnumerator:
    def __init__(self, headers: List[str]):
        self.headers_dict = {}
        self.headers_dict["User-Agent"] = (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        )
        self.headers_dict["Accept"] = (
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
        )
        self.headers_dict["Accept-Language"] = "en-US,en;q=0.9"
        self.headers_dict["Upgrade-Insecure-Requests"] = "1"

        for h in headers:
            if ":" in h:
                k, v = h.split(":", 1)
                self.headers_dict[k.strip()] = v.strip()

        self.client: Optional[httpx.AsyncClient] = None
        self.found_urls: Set[str] = set()

    async def __aenter__(self):
        limits = httpx.Limits(max_keepalive_connections=50, max_connections=100)
        self.client = httpx.AsyncClient(
            headers=self.headers_dict,
            limits=limits,
            timeout=15.0,
            follow_redirects=True,
            http2=True,
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.client:
            await self.client.aclose()

    async def _pre_flight(self, target_url: str):
        if not self.client:
            return
        parsed = urlparse(target_url)
        base_target = f"{parsed.scheme}://{parsed.netloc}/"
        try:
            print(f"{CYAN}[Ψ] Executing pre-flight request to establish session state...{RESET}")
            await self.client.get(base_target)
        except httpx.RequestError as e:
            print(f"{YELLOW}[-] Pre-flight warning: {e}{RESET}")

    async def _check_status(self, url: str) -> Optional[int]:
        if not self.client:
            return None
        try:
            request_headers = {}
            if "referer" not in [k.lower() for k in self.headers_dict.keys()]:
                request_headers["Referer"] = url[: url.rfind("/") + 1]

            request_headers["Range"] = "bytes=0-8192"
            request_headers["Sec-Fetch-Dest"] = "image"
            request_headers["Sec-Fetch-Mode"] = "no-cors"
            request_headers["Sec-Fetch-Site"] = "same-origin"
            request_headers["Sec-Ch-Ua"] = (
                '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"'
            )
            request_headers["Sec-Ch-Ua-Mobile"] = "?0"
            request_headers["Sec-Ch-Ua-Platform"] = '"Windows"'

            async with self.client.stream("GET", url, headers=request_headers) as resp:
                if resp.status_code in (200, 206):
                    return 200
                return resp.status_code
        except httpx.RequestError:
            return None

    async def _brute_worker(self, url_pattern: str, unpadded_url: str, sem: asyncio.Semaphore):
        async with sem:
            status = await self._check_status(url_pattern)
            if status == 200:
                print(f"{GREEN}[+] VALID:{RESET} {url_pattern}")
                self.found_urls.add(url_pattern)
                return

            if status in (404, 403) and url_pattern != unpadded_url:
                alt_status = await self._check_status(unpadded_url)
                if alt_status == 200:
                    print(f"{GREEN}[+] VALID (Unpadded):{RESET} {unpadded_url}")
                    self.found_urls.add(unpadded_url)
                    return
                print(f"{YELLOW}[-] INVALID (HTTP {alt_status}):{RESET} {unpadded_url}")
            elif status:
                print(f"{YELLOW}[-] INVALID (HTTP {status}):{RESET} {url_pattern}")
            else:
                print(f"{RED}[!] TIMEOUT:{RESET} {url_pattern}")

    async def run_brute(self, base_url: str, min_val: int, max_val: int, pad: int):
        print(f"\n{CYAN}[Ψ] Initiating Brute-Force Matrix (Range: {min_val}-{max_val}, Padding: {pad}){RESET}")
        if "{}" not in base_url:
            base_url += "{}"

        await self._pre_flight(base_url)

        tasks = []
        sem = asyncio.Semaphore(50)

        for i in range(min_val, max_val + 1):
            num_str_padded = str(i).zfill(pad)
            num_str_unpadded = str(i)

            target_padded = base_url.replace("{}", num_str_padded)
            target_unpadded = base_url.replace("{}", num_str_unpadded)

            tasks.append(
                asyncio.create_task(self._brute_worker(target_padded, target_unpadded, sem))
            )

        await asyncio.gather(*tasks)

    async def run_recursive(self, target_url: str):
        print(f"\n{CYAN}[Ψ] Initiating Recursive DOM Extraction on: {target_url}{RESET}")
        if not self.client:
            return

        await self._pre_flight(target_url)

        try:
            resp = await self.client.get(target_url)
            resp.raise_for_status()

            soup = BeautifulSoup(resp.text, "lxml")
            img_tags = soup.find_all("img", src=True)
            a_tags = soup.find_all("a", href=True)

            raw_links = [img["src"] for img in img_tags] + [a["href"] for a in a_tags]
            regex_links = re.findall(
                r'(?:http[s]?://|/)[^\s"\'<>]+(?:\.jpg|\.png|\.gif|\.webp|\.jpeg)',
                resp.text,
                re.IGNORECASE,
            )
            raw_links.extend(regex_links)

            for link in set(raw_links):
                absolute_url = urljoin(target_url, link).split("#")[0]
                if absolute_url.startswith("http"):
                    self.found_urls.add(absolute_url)
                    print(f"{GREEN}[+] EXTRACTED:{RESET} {absolute_url}")

        except Exception as e:
            print(f"{RED}[!] Extraction Failed: {e}{RESET}")


# --- Subsystem Integrations ---
class AkashaIntegrator:
    @staticmethod
    def open_browser(urls: Set[str]):
        if not urls:
            return
        print(f"{CYAN}[Ψ] Injecting {len(urls)} targets into default browser...{RESET}")
        for u in urls:
            webbrowser.open_new_tab(u)

    @staticmethod
    def store_idempotent(urls: Set[str], filename: str):
        if not urls:
            return
        existing = set()
        if os.path.exists(filename):
            with open(filename, "r", encoding="utf-8") as f:
                existing = set(line.strip() for line in f)

        new_urls = urls - existing
        if not new_urls:
            print(f"{YELLOW}[*] Storage: Zero new URLs to append.{RESET}")
            return

        with open(filename, "a", encoding="utf-8") as f:
            for u in sorted(new_urls):
                f.write(f"{u}\n")
        print(f"{GREEN}[+] Storage Complete: Appended {len(new_urls)} assets to {filename}{RESET}")

    @staticmethod
    def delegate_gallerydl(urls: Set[str], out_dir: Path):
        if not urls:
            return
        if not shutil.which("gallery-dl"):
            print(f"{RED}[!] CRITICAL: gallery-dl binary not found in PATH. Download skipped.{RESET}")
            return

        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"{CYAN}[Ψ] Delegating bulk transfer to gallery-dl (Target: {out_dir}){RESET}")

        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tmp:
            for u in urls:
                tmp.write(f"{u}\n")
            tmp_path = tmp.name

        try:
            cmd = ["gallery-dl", "-i", tmp_path, "-d", str(out_dir)]
            
            print(f"{MAGENTA}[*] Launching gallery-dl transfer matrix...{RESET}")
            subprocess.run(cmd, check=True)
            print(f"{GREEN}[+] Matrix Download Complete.{RESET}")
            
        except subprocess.CalledProcessError as e:
            print(f"{RED}[!] gallery-dl Subsystem Failure: {e}{RESET}")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


# --- Async Orchestrator ---
async def execute_sequence(engine_kwargs, args_obj):
    async with AkashaEnumerator(**engine_kwargs) as engine:
        if args_obj.get("brute"):
            await engine.run_brute(
                args_obj["url"],
                args_obj["min_val"],
                args_obj["max_val"],
                args_obj["pad"],
            )
        else:
            await engine.run_recursive(args_obj["url"])

        return engine.found_urls


# --- Interactive Menu System ---
def interactive_menu():
    print(f"\n{MAGENTA}{BOLD}==== Ψ-4NDR0666 OMNI-ENUMERATOR CONSOLE ===={RESET}")
    print(f"{CYAN}Welcome to the interactive reconnaissance matrix.{RESET}\n")

    target = input(f"{BOLD}Enter Target URL (e.g., https://example.com/img_{{}}.jpg): {RESET}").strip()
    if not target.startswith("http"):
        target = "https://" + target

    print(f"\n{BOLD}Select Operational Mode:{RESET}")
    print(f"  {GREEN}1){RESET} Recursive DOM Extraction (Scrape)")
    print(f"  {GREEN}2){RESET} Sequence Brute-Force (Zero-padded enumeration)")

    mode_choice = input("Choice [1/2]: ").strip()

    is_brute = mode_choice == "2"
    min_val, max_val, pad = 1, 100, 0

    if is_brute:
        try:
            min_val = int(input("Minimum Sequence Value [default: 1]: ") or 1)
            max_val = int(input("Maximum Sequence Value [default: 100]: ") or 100)
            pad = int(input("Zero-padding width (e.g. 3 for 001) [default: 0]: ") or 0)
        except ValueError:
            print(f"{RED}[!] Invalid integer input. Aborting.{RESET}")
            sys.exit(1)

    print(f"\n{MAGENTA}[*] Launching Engine...{RESET}")

    return {
        "url": target,
        "brute": is_brute,
        "scrape": not is_brute,
        "min_val": min_val,
        "max_val": max_val,
        "pad": pad,
        "store": None, 
        "download": False,
        "browser": False,
    }


# --- Primary CLI Invocation ---
def main():
    epilog_text = f"""
{BOLD}EXAMPLES:{RESET}
  {CYAN}1. Recursive DOM Extraction & Download:{RESET}
     python3 akasha_enum.py --scrape -u https://target.com/gallery --download
     
  {CYAN}2. Zero-Padded Sequence Brute Force (001 to 050):{RESET}
     python3 akasha_enum.py --brute -u "https://target.com/img_{{}}.jpg" --min 1 --max 50 --pad 3 --store valid.txt
     
  {CYAN}3. Stealth Extraction with Custom WAF/Auth Headers:{RESET}
     python3 akasha_enum.py --scrape -u https://target.com -A "Googlebot/2.1" -H "Authorization: Bearer token123"
     
  {CYAN}4. Launch Interactive Console Menu:{RESET}
     python3 akasha_enum.py --menu
"""

    parser = argparse.ArgumentParser(
        description=f"{MAGENTA}{BOLD}Ψ-4ndr0666 High-Performance Omni-Enumerator (v4.1.0-CERTIFIED){RESET}",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog=epilog_text,
    )

    parser.add_argument("-m", "--menu", action="store_true", help="Launch the interactive console menu (Overrides other flags)")
    parser.add_argument("-u", "--url", type=str, help="Target Base URL (use {} for brute injection point)")

    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--brute", action="store_true", help="Enable sequential zero-padding brute force")
    mode_group.add_argument("--scrape", action="store_true", help="Enable recursive DOM extraction")

    parser.add_argument("--min", type=int, default=1, help="Minimum sequence value (Brute mode)")
    parser.add_argument("--max", type=int, default=100, help="Maximum sequence value (Brute mode)")
    parser.add_argument("--pad", type=int, default=0, help="Zero-padding width (e.g., 3 for 001)")

    parser.add_argument("-H", "--header", action="append", default=[], help="Custom headers (Format: 'Key: Value')")
    parser.add_argument("-A", "--user-agent", help="Override default User-Agent")

    parser.add_argument("--browser", action="store_true", help="Open discovered assets in browser")
    parser.add_argument("--store", type=str, metavar="FILE", help="Save discovered assets to file (Idempotent)")
    parser.add_argument("--download", action="store_true", help="Download assets via gallery-dl subsystem")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    custom_headers = args.header
    if args.user_agent:
        custom_headers.append(f"User-Agent: {args.user_agent}")

    if args.menu:
        exec_args = interactive_menu()
    else:
        if not args.url or not (args.brute or args.scrape):
            print(f"{RED}[!] Error: CLI execution requires --url and a mode (--brute or --scrape). Use --menu for interactive mode.{RESET}")
            sys.exit(1)

        exec_args = {
            "url": args.url,
            "brute": args.brute,
            "scrape": args.scrape,
            "min_val": args.min,
            "max_val": args.max,
            "pad": args.pad,
            "store": args.store,
            "download": args.download,
            "browser": args.browser,
        }

    try:
        found_urls = asyncio.run(execute_sequence({"headers": custom_headers}, exec_args))

        if found_urls:
            print(f"\n{CYAN}--- Post-Exploitation Integrations ---{RESET}")
            asset_count = len(found_urls)

            if exec_args.get("store"):
                AkashaIntegrator.store_idempotent(found_urls, exec_args["store"])
            elif sys.stdin.isatty():
                ans = input(f"{BOLD}Store {asset_count} results to file? [y/N]: {RESET}").strip().lower()
                if ans == "y":
                    store_file = input(f"{BOLD}Enter filename [default: found_urls.txt]: {RESET}").strip() or "found_urls.txt"
                    AkashaIntegrator.store_idempotent(found_urls, store_file)

            if exec_args.get("download"):
                AkashaIntegrator.delegate_gallerydl(found_urls, DOWNLOADS_DIR)
            elif sys.stdin.isatty():
                ans = input(f"{BOLD}Download {asset_count} assets via gallery-dl? [y/N]: {RESET}").strip().lower()
                if ans == "y":
                    AkashaIntegrator.delegate_gallerydl(found_urls, DOWNLOADS_DIR)

            if exec_args.get("browser"):
                AkashaIntegrator.open_browser(found_urls)
            elif sys.stdin.isatty():
                ans = input(f"{BOLD}Open {asset_count} assets in browser? [y/N]: {RESET}").strip().lower()
                if ans == "y":
                    AkashaIntegrator.open_browser(found_urls)
        else:
            print(f"{YELLOW}[-] Sequence terminated. Zero assets acquired.{RESET}")

    except KeyboardInterrupt:
        print(f"\n{YELLOW}[!] User aborted sequence. Halting event loop.{RESET}")
        sys.exit(130)


if __name__ == "__main__":
    main()
