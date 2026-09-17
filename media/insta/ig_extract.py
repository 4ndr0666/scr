#!/usr/bin/env python3
"""ig_extract.py — decode page source into media URLs (video + images). FINAL REVISION.

Two routes, in strict order:

  Route 1 — structural: json.loads + recursive walk.
      JSON parsing resolves \\/, \\uXXXX, and surrogate pairs natively, so
      payloads that parse are handled with zero string surgery.
      Yields: video_versions (progressive) + video_dash_manifest BaseURLs (dash)
      + the single best-resolution image_versions2 candidate per media node.
      Stories/reels need no special handling: their media objects use this
      same image_versions2/video_versions contract, so the walker — which is
      structure-driven, not schema-driven — picks them up automatically.

  Route 2 — fallback net: regex over the _clean()-normalized raw text.
      Catches what JSON parsing rejects: JS string literals with escaped
      colons (https\\u003A\\u002F...), entity-encoded bodies, double-encoded
      \\u00253D forms, non-JSON script tags. Nets both .mp4 and image
      extensions (jpg/jpeg/png/webp/heic).

  Ordering constraint: _clean() is NEVER applied to text before json.loads —
  html.unescape() and the '\\"' replacement corrupt raw JSON. It only ever
  sees text that has already failed to parse, and only for URL hunting.

usage:
  python ig_extract.py page.html                  # saved source or bare JSON blob
  cat blob.txt | python ig_extract.py -           # piped raw encoded text
  python ig_extract.py https://... --cookie "sessionid=..."
  append --save out.mp4 to also download the single best progressive video
  append --save-all DIR to download every video/image found into DIR
"""
import html
import json
import re
import sys
from xml.etree import ElementTree as ET

SCRIPT_RE = re.compile(r'<script[^>]*type="application/json"[^>]*>(.*?)</script>', re.S)
MP4_RE    = re.compile(r'https://[^\s"\'<>\\]+?\.mp4(?:\?[^\s"\'<>\\]*)?')
IMG_RE    = re.compile(r'https://[^\s"\'<>\\]+?\.(?:jpg|jpeg|png|webp|heic)(?:\?[^\s"\'<>\\]*)?', re.I)
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

def _walk(node, prog: dict, dash: list, images: dict, seen_image_urls: set) -> None:
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
        # Images: a photo's image_versions2.candidates lists ~10 resolutions
        # of the SAME picture, so — unlike video_versions, whose few entries
        # are genuinely distinct encodings worth keeping all of — we reduce
        # `images` to the single highest-width candidate per node. Without
        # this a 10-photo carousel would otherwise surface as 100 near-
        # duplicate download targets. The non-best candidates are still real,
        # structurally-parsed URLs though — seen_image_urls records ALL of
        # them so the Route 2 fallback net below doesn't mistake "URLs we
        # deliberately deprioritized" for "URLs JSON parsing missed" and
        # re-surface them as if they were a Route 2 catch.
        candidates = ((node.get("image_versions2") or {}).get("candidates")
                      if isinstance(node.get("image_versions2"), dict) else None)
        if candidates:
            valid = [c for c in candidates if isinstance(c, dict) and c.get("url")]
            for c in valid:
                seen_image_urls.add(c["url"])
            best = max(valid, key=lambda c: c.get("width") or 0, default=None)
            if best:
                images[best["url"]] = max(images.get(best["url"], 0), best.get("width") or 0)
        for value in node.values():
            _walk(value, prog, dash, images, seen_image_urls)
    elif isinstance(node, list):
        for value in node:
            _walk(value, prog, dash, images, seen_image_urls)


def extract(text: str):
    prog, dash, images, seen_image_urls = {}, [], {}, set()

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
        _walk(payload, prog, dash, images, seen_image_urls)

    # Route 2: fallback net over cleaned raw text, deduped against Route 1
    seen = set(prog) | {u for _, u in dash} | seen_image_urls
    extra = []
    cleaned = _clean(text)
    for url in MP4_RE.findall(cleaned):
        url = url.replace("&amp;", "&").rstrip(".,;")
        if url not in seen:
            seen.add(url)
            extra.append(url)
    for url in IMG_RE.findall(cleaned):
        url = url.replace("&amp;", "&").rstrip(".,;")
        if url not in seen:
            seen.add(url)
            images[url] = 0   # width unknown from a regex-only hit; ranked last

    return prog, dash, images, extra


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


# ── Download ─────────────────────────────────────────────────────────────────

def _slugify(text: str, limit: int = 60) -> str:
    """Filesystem-safe filename fragment."""
    text = re.sub(r"[^\w.\-]+", "_", text)
    return text.strip("_")[:limit] or "media"


def _ext_from_url(url: str, default: str) -> str:
    m = re.search(r"\.(mp4|jpg|jpeg|png|webp|heic)(?:\?|$)", url, re.I)
    return m.group(1).lower() if m else default


def download(url: str, dest_dir, *, name: str | None = None,
             cookie: str | None = None, timeout: int = 60):
    """Fetch one media URL into dest_dir. Streams to a `.part` file and only
    renames to the final name on success, so a network drop or Ctrl-C mid
    transfer can never leave a truncated file sitting under its real name.
    Raises on failure — callers doing a batch should catch per item rather
    than let one bad URL abort the rest (see download_all)."""
    import requests
    from pathlib import Path

    dest_dir = Path(dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    ext = _ext_from_url(url, "mp4" if ".mp4" in url else "jpg")
    filename = f"{name or _slugify(url.rsplit('/', 1)[-1].split('?')[0])}.{ext}"
    final_path = dest_dir / filename
    tmp_path = final_path.with_name(final_path.name + ".part")

    headers = {"Referer": "https://www.instagram.com/"}
    if cookie:
        headers["Cookie"] = cookie

    r = requests.get(url, headers=headers, timeout=timeout, stream=True)
    r.raise_for_status()
    try:
        with open(tmp_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 16):
                f.write(chunk)
    except BaseException:
        tmp_path.unlink(missing_ok=True)   # never leave a half-written .part-less file
        raise
    tmp_path.rename(final_path)
    return final_path


def download_all(prog: dict, dash: list, images: dict, extra: list,
                  dest_dir, *, cookie: str | None = None, stagger: float = 0.0):
    """Download every asset extract() found — progressive video, dash video,
    images, and the regex-fallback hits — into dest_dir. Images, videos, and
    stories all flow through this one path: extract() already normalized
    them into the same four buckets regardless of which post/story/reel they
    came from, so there is nothing story-specific to special-case here.
    One item's failure is logged and the batch continues; these are
    independent files, not steps in a single doomed operation."""
    import time

    jobs: list[tuple[str, str]] = []
    for url, _t in sorted(prog.items(), key=lambda kv: kv[1]):      # best type first
        jobs.append(("video", url))
    for label, url in dash:
        jobs.append((f"dash-{label}", url))
    for url, _w in sorted(images.items(), key=lambda kv: -kv[1]):   # widest first
        jobs.append(("image", url))
    for url in extra:
        jobs.append(("fallback", url))

    results = []
    for i, (kind, url) in enumerate(jobs, 1):
        try:
            path = download(url, dest_dir, name=f"{i:03d}_{kind}", cookie=cookie)
            print(f"saved -> {path}")
            results.append((url, path, None))
        except Exception as exc:               # EAFP: attempt, catch, keep going
            print(f"failed -> {url}  ({exc})", file=sys.stderr)
            results.append((url, None, str(exc)))
        if stagger:
            time.sleep(stagger)
    return results


def main() -> None:
    argv = sys.argv[1:]
    cookie = save = save_all = None
    for flag in ("--cookie", "--save", "--save-all"):
        while flag in argv:
            i = argv.index(flag)
            if flag == "--cookie":
                cookie = argv[i + 1]
            elif flag == "--save":
                save = argv[i + 1] or "best.mp4"
            else:
                save_all = argv[i + 1] or "downloads"
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

    prog, dash, images, extra = extract(text)

    shown = set()
    for url, t in sorted(prog.items(), key=lambda kv: kv[1]):   # type 101 first
        shown.add(url)
        print(f"[progressive type {t} — video+audio]\n  {url}")
    for label, url in dash:
        if url not in shown:
            shown.add(url)
            print(f"[dash {label} — video-only]\n  {url}")
    for url, w in sorted(images.items(), key=lambda kv: -kv[1]):
        shown.add(url)
        print(f"[image{f' {w}px' if w else ''}]\n  {url}")
    for url in extra:
        shown.add(url)
        print(f"[fallback net]\n  {url}")

    if not shown:
        sys.exit("nothing found — likely a login wall; pass --cookie or feed a "
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

    if save_all:
        download_all(prog, dash, images, extra, save_all, cookie=cookie, stagger=0.2)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
