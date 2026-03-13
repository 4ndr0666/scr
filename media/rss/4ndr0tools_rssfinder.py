#!/usr/bin/env python3
"""
rss-feed-finder.py  –  discovers likely RSS/Atom/JSON Feed URLs on a website

Usage:
  python rss-feed-finder.py https://example.com
  python rss-feed-finder.py https://example.com --aggressive
"""

import sys
import argparse
import requests
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from typing import List, Set

COMMON_PATHS = [
    "/feed", "/feed/", "/rss", "/rss/", "/feed.xml", "/rss.xml",
    "/feeds/posts/default", "/atom.xml", "/feed/atom", "/index.xml",
    "/feeds/all.atom", "/wp-feed/", "/?feed=rss2", "/?feed=atom",
    "/feed/rss", "/rssfeed", "/feeds", "/blog/feed"
]

FEED_TYPES = [
    "application/rss+xml",
    "application/atom+xml",
    "application/feed+json",
    "application/json",  # some JSON feeds
]

def is_likely_feed_url(url: str) -> bool:
    lower = url.lower()
    return any(x in lower for x in ["/feed", "/rss", "/atom", "xml", "?feed=", "feeds."])

def extract_from_html(base_url: str, html: str) -> List[str]:
    soup = BeautifulSoup(html, "html.parser")
    candidates = set()

    # Classic <link rel="alternate" type="application/rss+xml" href="...">
    for link in soup.find_all("link", rel="alternate"):
        href = link.get("href")
        typ = link.get("type", "").lower()
        if href and any(t in typ for t in FEED_TYPES):
            candidates.add(urljoin(base_url, href))

    # Also check any <a> that looks suspicious
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if is_likely_feed_url(href):
            candidates.add(urljoin(base_url, href))

    return sorted(candidates)

def probe_common_paths(base_url: str, session: requests.Session) -> List[str]:
    found = set()

    for path in COMMON_PATHS:
        test_url = urljoin(base_url, path)
        try:
            r = session.head(test_url, timeout=6, allow_redirects=True)
            if r.status_code < 400:
                ct = r.headers.get("content-type", "").lower()
                if "xml" in ct or "json" in ct or "rss" in ct or "atom" in ct:
                    found.add(r.url)
        except:
            pass

    return sorted(found)

def find_feeds(url: str, aggressive: bool = False) -> Set[str]:
    session = requests.Session()
    session.headers["User-Agent"] = "RSS-Feed-Finder/1.0 (+https://github.com/yourname)"

    found: Set[str] = set()

    # Step 1: try direct HTML parse
    try:
        r = session.get(url, timeout=10, allow_redirects=True)
        if r.ok:
            from_html = extract_from_html(r.url, r.text)
            found.update(from_html)
    except Exception as e:
        print(f"[!] HTML fetch failed: {e}", file=sys.stderr)

    # Step 2: probe common paths (more aggressive if requested)
    if aggressive or not found:
        common = probe_common_paths(url, session)
        found.update(common)

    return found

def main():
    parser = argparse.ArgumentParser(description="Discover RSS/Atom/JSON Feed URLs")
    parser.add_argument("url", help="Website URL to scan")
    parser.add_argument("--aggressive", "-a", action="store_true",
                        help="Also probe many common feed paths")
    args = parser.parse_args()

    print(f"\nScanning → {args.url}")
    if args.aggressive:
        print("Aggressive mode enabled — checking many common paths\n")

    feeds = find_feeds(args.url, args.aggressive)

    if feeds:
        print("Possible feed URLs found:")
        for f in feeds:
            print(f"  • {f}")
        print(f"\nTotal: {len(feeds)}\n")
    else:
        print("No feed URLs discovered.\nTry --aggressive or check manually.\n")

if __name__ == "__main__":
    main()
