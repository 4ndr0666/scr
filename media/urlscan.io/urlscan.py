#!/usr/local/python3.13/bin/python3.13
# 4NDR0666OS — urlscan.io God-Mode Scanner v3.0
# Multithreaded + Full Pagination + JSON/TXT export
# Enhanced by Ψ-4ndr0666 under !4NDR0666OS directive

import requests
import argparse
import re
import os
import time
import json
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

API_KEY = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # ← INSERT YOUR REAL KEY HERE

if not API_KEY or API_KEY.startswith("xxxx"):
    print("[ERROR] Insert a valid urlscan.io API key before running.")
    exit(1)

parser = argparse.ArgumentParser(description="4NDR0666OS — urlscan.io Multithreaded Meat Grinder")
parser.add_argument('-m', '--mode', required=True, choices=['subdomains', 'urls'], help="Mode: subdomains or urls")
parser.add_argument('-d', '--domain', help="Single domain")
parser.add_argument('-df', '--domain-file', help="File with one domain per line")
parser.add_argument('-o', '--output', default="urlscan_grind", help="Base output filename (without extension)")
parser.add_argument('-s', '--size', type=int, default=1000, help="Results per page (max 10000)")
parser.add_argument('-t', '--threads', type=int, default=8, help="Number of concurrent threads (default 8)")
parser.add_argument('--delay', type=float, default=0.8, help="Base delay between requests per thread")
args = parser.parse_args()

print_lock = Lock()

def print_banner():
    print(r'''
              __                        _     
  __  _______/ /_____________ _____    (_)___ 
 / / / / ___/ / ___/ ___/ __ `/ __ \  / / __ \
/ /_/ / /  / (__  ) /__/ /_/ / / / / / / /_/ /
\__,_/_/  /_/____/\___/\__,_/_/ /_(_)_/\____/ 
                                              
           4NDR0666OS — urlscan.io GOD MODE v3.0
                  Multithreaded by Ψ-4ndr0666
    ''')

def sanitize_domain(domain):
    domain = str(domain).strip().lower()
    domain = re.sub(r'^https?://', '', domain)
    domain = re.sub(r'/.*$', '', domain)
    return domain if domain and not domain.startswith('#') and '.' in domain else None

def save_results(domain, mode, results, base_output):
    if not results:
        return
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    txt_path = f"{base_output}_{domain}_{mode}_{timestamp}.txt"
    json_path = f"{base_output}_{domain}_{mode}_{timestamp}.json"

    with open(txt_path, 'w') as f:
        f.write('\n'.join(results))
    with open(json_path, 'w') as f:
        json.dump({
            "domain": domain,
            "mode": mode,
            "count": len(results),
            "results": results,
            "timestamp": datetime.now().isoformat(),
            "tool": "4NDR0666OS_urlscan_grinder_v3.0"
        }, f, indent=2)

    with print_lock:
        print(f"[+] Saved {len(results):,} {mode} → {txt_path} | {json_path}")

def scan_single_domain(domain, mode, api_key, size, delay):
    domain = sanitize_domain(domain)
    if not domain:
        return domain, []

    with print_lock:
        print(f"[*] Starting grind on → {domain}  ({mode})")

    all_results = set()
    cursor = None
    page = 1
    headers = {"API-Key": api_key}

    while True:
        url = f"https://urlscan.io/api/v1/search/?q=page.domain:{domain}&size={size}"
        if cursor:
            url += f"&cursor={cursor}"

        try:
            resp = requests.get(url, headers=headers, timeout=20)

            if resp.status_code == 429:
                with print_lock:
                    print(f"[!] Rate limit on {domain} — sleeping 15s")
                time.sleep(15)
                continue
            elif resp.status_code != 200:
                with print_lock:
                    print(f"[!] HTTP {resp.status_code} on {domain}")
                break

            data = resp.json()
            results_page = data.get('results', [])

            for res in results_page:
                page_url = res.get('page', {}).get('url', '')
                if not page_url:
                    continue
                if mode == "subdomains":
                    match = re.search(rf'https?://((?:[a-zA-Z0-9_-]+\.)+{re.escape(domain)})', page_url, re.IGNORECASE)
                    if match:
                        sub = match.group(1).lower().split('/')[0]
                        if sub != domain:
                            all_results.add(sub)
                elif mode == "urls":
                    if page_url.startswith(('http://', 'https://')):
                        all_results.add(page_url)

            cursor = data.get('cursor')
            with print_lock:
                print(f"[+] {domain} | Page {page} → {len(results_page)} hits | Unique so far: {len(all_results):,}")

            page += 1
            if not cursor:
                break

            time.sleep(delay)

        except Exception as e:
            with print_lock:
                print(f"[!] Error on {domain}: {e}")
            break

    return domain, sorted(all_results)

# ====================== MAIN ======================
print_banner()

domains_to_scan = []
if args.domain:
    d = sanitize_domain(args.domain)
    if d:
        domains_to_scan = [d]
elif args.domain_file and os.path.isfile(args.domain_file):
    with open(args.domain_file, 'r') as f:
        domains_to_scan = [sanitize_domain(line) for line in f if sanitize_domain(line)]
else:
    print("[!] Provide -d DOMAIN or -df domainlist.txt")
    exit(1)

print(f"[*] Launching {args.threads} threads against {len(domains_to_scan)} domain(s)...\n")

start_time = time.time()

with ThreadPoolExecutor(max_workers=args.threads) as executor:
    future_to_domain = {
        executor.submit(scan_single_domain, dom, args.mode, API_KEY, args.size, args.delay): dom
        for dom in domains_to_scan
    }

    for future in as_completed(future_to_domain):
        domain, results = future.result()
        if results:
            save_results(domain, args.mode, results, args.output)
        else:
            with print_lock:
                print(f"[!] No results for {domain}")

elapsed = time.time() - start_time
print(f"\n[✔] 4NDR0666OS grind finished in {elapsed:.1f}s — {len(domains_to_scan)} domain(s) processed.")
print("    Multithreaded. No limits. Raw will executed.")
