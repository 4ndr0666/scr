#!/usr/bin/env python3
"""ig_extract.py — decode page source into mp4 URLs. FINAL REVISION.

Two routes, in strict order:

  Route 1 — structural: json.loads + recursive walk.
      JSON parsing resolves \\/, \\uXXXX, and surrogate pairs natively, so
      payloads that parse are handled with zero string surgery.
      Yields: video_versions (progressive) + video_dash_manifest BaseURLs (dash).

  Route 2 — fallback net: regex over the _clean()-normalized raw text.
      Catches what JSON parsing rejects: JS string literals with escaped
      colons (https\\u003A\\u002F...), entity-encoded bodies, double-encoded
      \\u00253D forms, non-JSON script tags.

  Ordering constraint: _clean() is NEVER applied to text before json.loads —
  html.unescape() and the '\\"' replacement corrupt raw JSON. It only ever
  sees text that has already failed to parse, and only for URL hunting.

usage:
  python ig_extract.py page.html                  # saved source or bare JSON blob
  cat blob.txt | python ig_extract.py -           # piped raw encoded text
  python ig_extract.py https://... --cookie "sessionid=..."
  append --save out.mp4 to also download the best progressive URL
"""
import html
import json
import re
import sys
from xml.etree import ElementTree as ET

SCRIPT_RE = re.compile(r'<script[^>]*type="application/json"[^>]*>(.*?)</script>', re.S)
MP4_RE    = re.compile(r'https://[^\s"\'<>\\]+?\.mp4(?:\?[^\s"\'<>\\]*)?')
NS        = "{urn:mpeg:dash:schema:mpd:2011}"

# ── Route 2: the clean chain (surrogate-safe, pairs before singles) ──────────

_PAIR_RE = re.compile(r"\\u(d[89ab][0-9a-fA-F]{2})\\u(d[cdef][0-9a-fA-F]{2})", re.I)
_CHAR_RE = re.compile(r"\\u([0-9a-fA-F]{4})", re.I)


def _clean(text: str) -> str:
    """Entity decode → surrogate-pair-safe \\u decode → slash/quote unescape."""
    text = html.unescape(text)                     # &amp; &quot; &#x..;
    text = _PAIR_RE.sub(                           # \ud83d\ude00 → one char
        lambda m: chr(0x10000 + ((int(m.group(1), 16) - 0xD800) << 10)
                     + (int(m.group(2), 16) - 0xDC00)),
        text,
    )
    text = _CHAR_RE.sub(lambda m: chr(int(m.group(1), 16)), text)  # \u0026 → &
    return text.replace("\\/", "/").replace('\\"', '"')            # never re-parse this


# ── Route 1: structural walk ─────────────────────────────────────────────────

def _walk(node, prog: dict, dash: list) -> None:
    if isinstance(node, dict):
        for entry in node.get("video_versions") or ():
            if isinstance(entry, dict) and entry.get("url"):
                url, t = entry["url"], entry.get("type") or 999
                prog[url] = min(prog.get(url, 999), t)     # keep lowest type = best
        manifest = node.get("video_dash_manifest")
        if isinstance(manifest, str):
            try:
                for rep in ET.fromstring(manifest).iter(NS + "Representation"):
                    base = rep.find(NS + "BaseURL")
                    if base is not None and base.text:
                        # ET already unescapes &amp;; the replace is belt-and-suspenders
                        dash.append((rep.get("FBQualityLabel") or "?",
                                     base.text.strip().replace("&amp;", "&")))
            except ET.ParseError:
                pass
        for value in node.values():
            _walk(value, prog, dash)
    elif isinstance(node, list):
        for value in node:
            _walk(value, prog, dash)


def extract(text: str):
    prog, dash = {}, []

    payloads = []
    try:
        payloads.append(json.loads(text))              # Route 1a: input IS the blob
    except ValueError:
        for body in SCRIPT_RE.findall(text):           # Route 1b: HTML → script tags
            try:
                payloads.append(json.loads(body))
            except ValueError:
                pass                                   # Route 2 fodder
    for payload in payloads:
        _walk(payload, prog, dash)

    # Route 2: fallback net over cleaned raw text, deduped against Route 1
    seen = set(prog) | {u for _, u in dash}
    extra = []
    for url in MP4_RE.findall(_clean(text)):
        url = url.replace("&amp;", "&").rstrip(".,;")
        if url not in seen:
            seen.add(url)
            extra.append(url)

    return prog, dash, extra


# ── IO ───────────────────────────────────────────────────────────────────────

def _fetch(url: str, cookie: str | None) -> str:
    try:
        import requests
    except ImportError:
        sys.exit("pip install requests  (only needed for URL / --save mode)")
    headers = {
        "User-Agent": ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                       "(KHTML, like Gecko) Chrome/131.0 Safari/537.36"),
        "Accept-Language": "en-US,en;q=0.9",
    }
    if cookie:
        headers["Cookie"] = cookie
    r = requests.get(url, headers=headers, timeout=30)
    r.raise_for_status()
    return r.text


def main() -> None:
    argv = sys.argv[1:]
    cookie = save = None
    for flag in ("--cookie", "--save"):
        while flag in argv:
            i = argv.index(flag)
            if flag == "--cookie":
                cookie = argv[i + 1]
            else:
                save = argv[i + 1] or "best.mp4"
            del argv[i:i + 2]

    src = argv[0] if argv else "-"
    if src == "-":
        text = sys.stdin.read()
    elif re.match(r"https?://", src):
        text = _fetch(src, cookie)
    else:
        text = open(src, encoding="utf-8", errors="replace").read()

    if not text.strip():
        sys.exit("null input")

    prog, dash, extra = extract(text)

    shown = set()
    for url, t in sorted(prog.items(), key=lambda kv: kv[1]):   # type 101 first
        shown.add(url)
        print(f"[progressive type {t} — video+audio]\n  {url}")
    for label, url in dash:
        if url not in shown:
            shown.add(url)
            print(f"[dash {label} — video-only]\n  {url}")
    for url in extra:
        shown.add(url)
        print(f"[fallback net]\n  {url}")

    if not shown:
        sys.exit("no mp4 found — likely a login wall; pass --cookie or feed a "
                 "page saved from your browser")

    if save:
        import requests
        best = min(prog.items(), key=lambda kv: kv[1])[0]       # lowest type wins
        if not best:
            sys.exit("--save needs a progressive URL; none found")
        r = requests.get(best, headers={"Referer": "https://www.instagram.com/"},
                         timeout=60)
        r.raise_for_status()
        with open(save, "wb") as f:
            f.write(r.content)
        print(f"saved -> {save} ({len(r.content)} bytes)")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
