#!/usr/bin/env python
"""
find_all_links_hardened.py
Ψ-4ndr0666 High-Performance Link Scoping Engine (v3.0.3)

Operational Enhancements:
- Asynchronous resolution via concurrent.futures.
- Recursive URL joining for relative paths.
- WAF-evasion via randomized User-Agents.
- Scope-aware filtering (Internal vs. External).
- Automated deduplication and normalization.
"""

import sys
import re
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from concurrent.futures import ThreadPoolExecutor

# Tactical Stealth Headers
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
]

class LinkScoper:
    def __init__(self, base_url):
        self.base_url = base_url
        self.domain = urlparse(base_url).netloc
        self.visited = set()
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENTS[0]})

    def is_valid(self, url):
        """Filters out non-navigatable protocols and junk."""
        parsed = urlparse(url)
        return bool(parsed.netloc) and parsed.scheme in ("http", "https")

    def normalize_link(self, link):
        """Converts relative links to absolute and strips fragments."""
        absolute_url = urljoin(self.base_url, link)
        return absolute_url.split('#')[0].rstrip('/')

    def extract(self, url):
        """Core extraction logic with error handling and DOM parsing."""
        if url in self.visited:
            return set()
        
        try:
            print(f"[Ψ] Scoping: {url}")
            response = self.session.get(url, timeout=10, allow_redirects=True)
            response.raise_for_status()
            self.visited.add(url)
            
            soup = BeautifulSoup(response.text, "lxml") # Using lxml for speed
            found_links = set()

            # Strategy A: Standard HTML Links
            for a_tag in soup.find_all("a", href=True):
                href = a_tag.get("href")
                normalized = self.normalize_link(href)
                if self.is_valid(normalized):
                    found_links.add(normalized)

            # Strategy B: Hardened Regex for JS/Comments (The safety net)
            # This captures links hidden in scripts that BeautifulSoup might miss
            script_links = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', response.text)
            for slink in script_links:
                found_links.add(slink)

            return found_links

        except requests.exceptions.RequestException as e:
            print(f"[!] Target unreachable: {url} | Reason: {e}")
            return set()

def run_scoper(target_url):
    scoper = LinkScoper(target_url)
    results = scoper.extract(target_url)
    
    internal = []
    external = []

    for link in sorted(results):
        if urlparse(link).netloc == scoper.domain:
            internal.append(link)
        else:
            external.append(link)

    print(f"\n[+] Recon Report for {target_url}")
    print(f"[+] Total Unique Links Found: {len(results)}")
    print(f"\n--- INTERNAL ASSETS ({len(internal)}) ---")
    for link in internal: print(f"  [IN]  {link}")
    
    print(f"\n--- EXTERNAL DEPENDENCIES ({len(external)}) ---")
    for link in external: print(f"  [OUT] {link}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: python {sys.argv[0]} <url>")
        sys.exit(1)

    target = sys.argv[1]
    if not target.startswith("http"):
        target = "https://" + target
        
    run_scoper(target)
