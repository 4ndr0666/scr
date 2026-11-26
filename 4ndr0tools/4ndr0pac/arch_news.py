#!/usr/bin/env python3
"""arch_news.py — Stdlib-only Arch Linux News RSS reader (consolidated from 4ndr0update).

Zero third-party dependencies (replaces xmltodict + python-dateutil with Python 3
stdlib xml.etree.ElementTree + email.utils). Enforces an explicit network timeout
and safe terminal-width detection.
"""
from __future__ import annotations

import argparse
import datetime
import email.utils
import html
import re
import shutil
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Optional, Tuple

FEED_URL = "https://archlinux.org/feeds/news/"
DEFAULT_TIMEOUT_SECS = 15
USER_AGENT = "4ndr0pac-arch-news/1.7.0 (+https://github.com/4ndr0666/scr)"

_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\n{3,}")


def clean_html(raw_html: str) -> str:
    text = _TAG_RE.sub("", raw_html or "")
    text = html.unescape(text).strip()
    return _WS_RE.sub("\n\n", text)


def parse_date(value: str) -> Optional[datetime.datetime]:
    if not value:
        return None
    try:
        dt = email.utils.parsedate_to_datetime(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt.astimezone(datetime.timezone.utc)
    except (TypeError, ValueError):
        pass
    try:
        dt = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt.astimezone(datetime.timezone.utc)
    except ValueError:
        return None


def parse_rss_items(xml_bytes: bytes) -> List[Tuple[str, str, Optional[datetime.datetime], str]]:
    root = ET.fromstring(xml_bytes)
    items: List[Tuple[str, str, Optional[datetime.datetime], str]] = []
    for item in root.findall("./channel/item"):
        title = (item.findtext("title") or "").strip()
        pub_raw = (item.findtext("pubDate") or "").strip()
        desc = clean_html(item.findtext("description") or "")
        items.append((title, pub_raw, parse_date(pub_raw), desc))
    return items


def fetch_feed(url: str, timeout: int) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Fetch and display Arch Linux News RSS items.")
    parser.add_argument("--since", default="", help="Only show posts on or after this ISO/RFC date.")
    parser.add_argument("--limit", type=int, default=5, help="Maximum number of posts to show (0 = all).")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECS, help="HTTP timeout in seconds.")
    parser.add_argument("--feed-file", default="", help="Read RSS XML from a local file instead of the network.")
    parser.add_argument("--url", default=FEED_URL, help="RSS feed URL.")
    args = parser.parse_args(argv)

    since_dt: Optional[datetime.datetime] = None
    if args.since:
        since_dt = parse_date(args.since)
        if since_dt is None:
            print(f"arch_news: invalid --since date: {args.since!r}", file=sys.stderr)
            return 2

    try:
        if args.feed_file:
            raw_xml = Path(args.feed_file).read_bytes()
        else:
            raw_xml = fetch_feed(args.url, max(1, args.timeout))
        items = parse_rss_items(raw_xml)
    except (OSError, urllib.error.URLError, ET.ParseError) as exc:
        print(f"arch_news: failed to load Arch Linux news: {exc}", file=sys.stderr)
        return 1

    filtered = []
    for title, pub_raw, pub_dt, desc in items:
        if since_dt is not None and pub_dt is not None and pub_dt < since_dt:
            continue
        filtered.append((title, pub_raw, desc))

    if args.limit > 0:
        filtered = filtered[: args.limit]

    if not filtered:
        print("No matching Arch Linux news items.")
        return 0

    cols = max(40, min(100, shutil.get_terminal_size((80, 24)).columns))
    sep = "~" * cols
    for title, pub_raw, desc in filtered:
        print(sep)
        print(f"TITLE: {title}")
        print(f"DATE:  {pub_raw}")
        print(f"\n{desc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
