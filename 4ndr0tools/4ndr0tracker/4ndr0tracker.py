#!/usr/bin/env python3
# by 4ndr0666 — refactored by claude
"""
4NDR0-TRACKER — Ephemeral State Machine compliant rewrite.

Fixes over original:
  - Single-pass URL extraction with one unified junk filter (no duplicated logic)
  - Atomic filename allocation via O_EXCL to eliminate TOCTOU race
  - Hard timeout on font fetch (no hung DNS stall)
  - JS undo stack stores URL strings, not serialized DOM (no innerHTML re-injection)
  - Click handler keys on li.dataset.url, not browser-resolved a.href
  - Dead visibleCount variable removed; counter driven solely by visited.size
  - HTML/JS boundary crossed via json.dumps(), not raw f-string interpolation
  - <noscript> fallback included
"""

import base64
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from html import escape, unescape


# ─── FILENAME ALLOCATION ──────────────────────────────────────────────────────

def allocate_output_filename() -> str:
    """
    Atomically allocate the next 4NDR0-TRACKER*.html filename.
    Uses O_EXCL to prevent TOCTOU races between concurrent invocations.
    Falls back to scanning existing files to determine the next integer slot.
    """
    pattern = re.compile(r"^4NDR0-TRACKER(\d+)")
    existing = glob.glob("4NDR0-TRACKER*.html")
    numbers = []
    for f in existing:
        m = pattern.match(os.path.basename(f))
        if m:
            numbers.append(int(m.group(1)))

    now = datetime.datetime.now()
    date_str = f"{now.month}-{now.day}-{now.strftime('%y')}"
    time_str = now.strftime("%I-%M%p").lstrip("0")
    next_num = (max(numbers) + 1) if numbers else 1

    # Atomic allocation: increment until we win the O_EXCL race.
    while True:
        candidate = f"4NDR0-TRACKER{next_num}_{date_str}_{time_str}.html"
        try:
            fd = os.open(candidate, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
            os.close(fd)
            return candidate
        except FileExistsError:
            next_num += 1


# ─── INPUT ────────────────────────────────────────────────────────────────────

def select_file_with_fzf() -> str | None:
    try:
        result = subprocess.run(
            ["fzf", "--height=20", "--border", "--prompt=Select Source > "],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return None


def read_raw_input() -> str:
    print("TARGET INPUT METHOD:")
    print("  1. Select File (fzf)")
    print("  2. Paste URLs / HTML")
    print("")
    choice = input("> ").strip() or "2"

    if choice == "1":
        filepath = select_file_with_fzf()
        if filepath and os.path.exists(filepath):
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                    raw = f.read()
                print(f"\n[Ψ] Loaded: {filepath}")
                return raw
            except OSError as e:
                print(f"[Ψ] Read error: {e} — falling back to paste.")

    print("\nPaste URLs or HTML (two consecutive blank lines or Ctrl+D to end):")
    lines: list[str] = []
    try:
        while True:
            line = input()
            lines.append(line)
            if len(lines) >= 2 and lines[-1].strip() == "" and lines[-2].strip() == "":
                break
    except EOFError:
        pass

    return "\n".join(lines)


# ─── EXTRACTION ───────────────────────────────────────────────────────────────

_JUNK_SUBSTRINGS = frozenset([
    "gravatar.com/avatar",
    "data:image/svg+xml",
    "data:image/png;base64",
    "wp-content/uploads",
    "output-onlinepngtools",
])

_IMAGE_EXTENSION_RE = re.compile(
    r"\.(jpg|jpeg|png|gif|webp|svg|ico|bmp)(?:[?#]|$)", re.IGNORECASE
)

_EXTRACT_PATTERNS = [
    re.compile(r'(https?://[^\s"\'<>`\\]+)'),
    re.compile(r'(//[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[^\s"\'<>`\\]+)'),
    re.compile(r'(?i)href=["\']([^"\']+)["\']'),
    re.compile(r'(?i)src=["\']([^"\']+)["\']'),
    re.compile(r'(?i)data-[a-z]+=["\'](https?://[^"\']+)["\']'),
    re.compile(
        r'((?:https?://|//)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+[^\s<>"\'\\]*)'
    ),
]


def _normalize(raw: str) -> str | None:
    """Return a normalized https:// URL or None if it should be rejected."""
    url = raw.strip().strip("\"'<>\\")
    if not url or len(url) < 8:
        return None

    lower = url.lower()

    if any(junk in lower for junk in _JUNK_SUBSTRINGS):
        return None
    if _IMAGE_EXTENSION_RE.search(lower):
        return None

    if url.startswith("//"):
        url = "https:" + url
    elif not url.startswith(("http://", "https://")):
        return None

    return url


def extract_urls(text: str) -> list[str]:
    """
    Single-pass extraction pipeline.
    Decode → unescape → apply patterns → normalize/filter → deduplicate → sort.
    """
    if not text:
        return []

    # Decode escape layers
    text = unescape(text)
    text = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), text)
    text = text.replace("\\/", "/").replace('\\"', '"')

    urls: set[str] = set()
    for pattern in _EXTRACT_PATTERNS:
        for match in pattern.findall(text):
            raw = match[0] if isinstance(match, tuple) else match
            normalized = _normalize(str(raw))
            if normalized:
                urls.add(normalized)

    result = sorted(urls)
    print(f"[Ψ] {len(result)} valid video vectors synthesized.")
    return result


# ─── FONTS ────────────────────────────────────────────────────────────────────

_FONT_CSS_URL = (
    "https://fonts.googleapis.com/css2"
    "?family=Roboto+Mono:wght@500"
    "&family=Cinzel+Decorative:wght@700"
    "&family=Orbitron:wght@700"
    "&display=swap"
)
_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
_FONT_TIMEOUT = 15  # seconds — hard wall per Directive 3


def _fetch(url: str, headers: dict) -> bytes:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=_FONT_TIMEOUT) as r:
        return r.read()


def fetch_base64_fonts() -> str:
    """
    Fetch Google Fonts CSS, embed each woff2 as a Base64 data URI.
    Hard timeout on every network call. Falls back to remote <link> on any error.
    """
    print("[Ψ] Synthesizing Base64 offline fonts...")
    headers = {"User-Agent": _UA}
    try:
        css = _fetch(_FONT_CSS_URL, headers).decode("utf-8")
        woff2_urls = re.findall(r"url\((https://[^)]+\.woff2)\)", css)
        for woff_url in set(woff2_urls):
            font_bytes = _fetch(woff_url, headers)
            b64 = base64.b64encode(font_bytes).decode("utf-8")
            data_uri = f"data:font/woff2;charset=utf-8;base64,{b64}"
            css = css.replace(woff_url, data_uri)
        print("[Ψ] Base64 font synthesis complete.")
        return f"<style>\n{css}\n</style>"
    except (urllib.error.URLError, OSError, TimeoutError) as exc:
        print(f"[Ψ] Font embedding failed ({exc}). Falling back to remote links.")
        return (
            '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
            '    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
            f'    <link href="{_FONT_CSS_URL}" rel="stylesheet">'
        )


# ─── HTML GENERATION ─────────────────────────────────────────────────────────

def generate_html(urls: list[str], output_file: str) -> None:
    total = len(urls)

    # Build list items — sanitize every value at the boundary
    items_html = ""
    for url in urls:
        label = url.split("/")[-1] or url
        safe_url = escape(url, quote=True)
        safe_label = escape(label)
        items_html += (
            f'        <li data-url="{safe_url}">'
            f'<a href="{safe_url}" target="_blank" rel="noopener noreferrer">'
            f"{safe_label}</a></li>\n"
        )

    font_styles = fetch_base64_fonts()

    # Cross the HTML/JS boundary with json.dumps() — never raw f-string interpolation
    js_total = json.dumps(total)
    js_storage_visited = json.dumps("psiTrackerVisited")
    js_storage_undo = json.dumps("psiTrackerUndoStack")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>4NDR0-TRACKER — {escape(str(total))} Units</title>
    {font_styles}
    <style>
        :root {{
            --bg:           #0A0F1A;
            --cyan:         #15fafa;
            --cyan-mid:     #15adad;
            --cyan-dark:    #157d7d;
            --text:         #e0ffff;
            --card-bg:      rgba(16,24,39,0.8);
            --card-border:  rgba(21,173,173,0.4);
        }}

        *, *::before, *::after {{ box-sizing: border-box; }}

        body {{
            background: var(--bg);
            color: var(--text);
            font-family: 'Roboto Mono', monospace;
            padding: 40px 20px;
            text-align: center;
            margin: 0;
            min-height: 100vh;
        }}

        /* CRT scanline overlay */
        body::after {{
            content: "";
            display: block;
            position: fixed;
            inset: 0;
            background:
                linear-gradient(rgba(18,16,16,0) 50%, rgba(0,0,0,.25) 50%),
                linear-gradient(90deg, rgba(255,0,0,.06), rgba(0,255,0,.02), rgba(0,0,255,.06));
            background-size: 100% 2px, 3px 100%;
            pointer-events: none;
            z-index: 999;
        }}

        .container {{
            max-width: 800px;
            margin: 0 auto;
            position: relative;
            z-index: 2;
        }}

        /* Glyph */
        .glyph {{
            width: 160px; height: 160px;
            margin: 20px auto;
            filter: drop-shadow(0 0 30px var(--cyan));
            animation: pulse 4s infinite alternate;
        }}
        @keyframes pulse {{
            from {{ filter: drop-shadow(0 0 20px var(--cyan)); }}
            to   {{ filter: drop-shadow(0 0 40px var(--cyan)); }}
        }}

        h1 {{
            font-family: 'Cinzel Decorative', serif;
            font-size: clamp(1.8rem, 5vw, 3rem);
            font-weight: 700;
            background: linear-gradient(to right, var(--cyan), var(--cyan-mid), var(--cyan-dark));
            -webkit-background-clip: text;
            background-clip: text;
            color: transparent;
            margin-bottom: 20px;
        }}

        .counter {{
            margin: 24px 0;
            font-size: 1.25rem;
            color: var(--cyan);
        }}

        /* List */
        ul {{ list-style: none; padding: 0; margin: 0; }}

        li {{
            margin: 16px 0;
            overflow: hidden;
            max-height: 200px;
            transition: max-height .8s cubic-bezier(.4,0,.2,1),
                        opacity .8s ease,
                        margin .8s ease;
        }}

        li.vanished {{
            max-height: 0;
            opacity: 0;
            margin: 0;
            pointer-events: none;
        }}

        @keyframes dematerialize {{
            0%   {{ opacity: 1; transform: scale(1)    translateY(0);    filter: blur(0);    }}
            50%  {{ opacity: .3; transform: scale(1.05) translateY(-10px); filter: blur(5px);  }}
            100% {{ opacity: 0; transform: scale(.95) translateY(-20px); filter: blur(15px); }}
        }}
        li.leaving {{ animation: dematerialize 1.2s forwards; }}

        @keyframes rematerialize {{
            0%   {{ opacity: 0; transform: scale(.95) translateY(-20px); filter: blur(15px); }}
            50%  {{ opacity: .3; transform: scale(1.05) translateY(-10px); filter: blur(5px); }}
            100% {{ opacity: 1; transform: scale(1)    translateY(0);    filter: blur(0);    }}
        }}
        li.entering {{ animation: rematerialize 1.2s forwards; }}

        a {{
            display: block;
            padding: 18px 24px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            color: var(--cyan);
            text-decoration: none;
            font-size: 1rem;
            transition: background .4s, border-color .4s, box-shadow .4s, transform .4s;
            box-shadow: 0 4px 15px rgba(21,250,250,.2);
            word-break: break-all;
        }}
        a:hover, a:focus-visible {{
            background: rgba(21,250,250,.15);
            border-color: var(--cyan);
            box-shadow: 0 8px 30px rgba(21,250,250,.5);
            transform: translateY(-4px);
            outline: none;
        }}

        .hint {{
            margin-top: 50px;
            font-size: .85rem;
            opacity: .65;
            line-height: 2;
        }}

        footer {{
            margin-top: 60px;
            font-size: .75rem;
            opacity: .4;
            letter-spacing: .15em;
        }}

        @media (prefers-reduced-motion: reduce) {{
            *, *::before, *::after {{ animation-duration: .01ms !important; transition-duration: .01ms !important; }}
        }}
    </style>
</head>
<body>
<div class="container">

    <svg class="glyph" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg"
         fill="none" stroke="var(--cyan)" stroke-width="3"
         stroke-linecap="round" stroke-linejoin="round"
         aria-hidden="true">
        <path d="M64,12 A52,52 0 1 1 63.9,12 Z"
              stroke-dasharray="21.78 21.78" stroke-width="2"/>
        <path d="M64,20 A44,44 0 1 1 63.9,20 Z"
              stroke-dasharray="10 10" stroke-width="1.5" opacity=".7"/>
        <path d="M64 30 L91.3 47 L91.3 81 L64 98 L36.7 81 L36.7 47 Z"/>
        <text x="64" y="67" text-anchor="middle" dominant-baseline="middle"
              fill="var(--cyan)" stroke="none" font-size="56" font-weight="700"
              style="font-family:'Orbitron',sans-serif;">Ψ</text>
    </svg>

    <h1>4NDR0 // TRACKER</h1>
    <div class="counter" id="counter" role="status" aria-live="polite">
        Loading…
    </div>

    <ul id="url-list" aria-label="Video vectors">
{items_html}    </ul>

    <div class="hint" aria-label="Keyboard shortcuts">
        Persistence via localStorage &nbsp;·&nbsp;
        <kbd>Ctrl+Z</kbd> restore last &nbsp;·&nbsp;
        <kbd>Ctrl+Shift+X</kbd> purge all
    </div>

    <footer>4NDR0666OS Ψ 4NDR0TRACKER · 2026</footer>
</div>

<noscript>
    <style>li {{ display: block !important; opacity: 1 !important; }}</style>
    <p style="color:#f55;font-family:monospace;text-align:center">
        [Ψ] JavaScript required for visit tracking. Links remain clickable above.
    </p>
</noscript>

<script>
(function () {{
    'use strict';

    const STORAGE_VISITED = {js_storage_visited};
    const STORAGE_UNDO    = {js_storage_undo};
    const TOTAL           = {js_total};

    // ── State ──────────────────────────────────────────────────────────────
    // Undo stack stores URL strings, not serialized DOM.
    // DOM is rebuilt from the authoritative data-url attribute on restore.
    let visited   = new Set(JSON.parse(localStorage.getItem(STORAGE_VISITED) || '[]'));
    let undoStack = JSON.parse(localStorage.getItem(STORAGE_UNDO)    || '[]');

    const ul      = document.getElementById('url-list');
    const counter = document.getElementById('counter');

    function persist() {{
        localStorage.setItem(STORAGE_VISITED, JSON.stringify([...visited]));
        localStorage.setItem(STORAGE_UNDO,    JSON.stringify(undoStack));
    }}

    function updateCounter() {{
        counter.textContent =
            `${{visited.size}} of ${{TOTAL}} visited · Ctrl+Z to restore`;
    }}

    // ── Initial sweep: hide already-visited items without animation ────────
    ul.querySelectorAll('li[data-url]').forEach(li => {{
        if (visited.has(li.dataset.url)) {{
            li.classList.add('vanished');
            li.hidden = true;
        }}
    }});
    updateCounter();

    // ── Click handler ──────────────────────────────────────────────────────
    // Key on li.dataset.url (raw extracted URL) — never a.href
    // (browsers mutate href: trailing slash normalization, protocol expansion, etc.)
    ul.addEventListener('click', e => {{
        const a = e.target.closest('a');
        if (!a) return;
        e.preventDefault();

        const li = a.closest('li[data-url]');
        const url = li ? li.dataset.url : a.href;

        if (!visited.has(url)) {{
            visited.add(url);
            undoStack.push(url);
            persist();
            updateCounter();

            if (li) {{
                li.classList.add('leaving');
                li.addEventListener('animationend', () => {{
                    li.classList.remove('leaving');
                    li.classList.add('vanished');
                    li.hidden = true;
                }}, {{ once: true }});
            }}
        }}

        window.open(url, '_blank', 'noopener,noreferrer');
    }});

    // ── Keyboard handlers ──────────────────────────────────────────────────
    document.addEventListener('keydown', e => {{

        // Restore: Ctrl+Z (or Cmd+Z)
        if ((e.ctrlKey || e.metaKey) && !e.shiftKey && e.key === 'z') {{
            if (undoStack.length === 0) return;
            e.preventDefault();

            const url = undoStack.pop();
            visited.delete(url);
            persist();
            updateCounter();

            const li = ul.querySelector(`li[data-url="${{CSS.escape(url)}}"]`);
            if (li) {{
                li.hidden = false;
                li.classList.remove('vanished');
                li.classList.add('entering');
                li.addEventListener('animationend', () => li.classList.remove('entering'),
                    {{ once: true }});
            }}
        }}

        // Purge: Ctrl+Shift+X
        if (e.ctrlKey && e.shiftKey && e.key.toUpperCase() === 'X') {{
            e.preventDefault();
            if (confirm('[Ψ] WARNING: TOTAL MEMORY PURGE. All persistence vectors erased. Proceed?')) {{
                localStorage.removeItem(STORAGE_VISITED);
                localStorage.removeItem(STORAGE_UNDO);
                location.reload();
            }}
        }}
    }});

    console.log(
        `%cΨ 4NDR0-TRACKER INITIALIZED — ${{TOTAL}} vectors loaded`,
        'color:#00f0ff;font-family:Orbitron,monospace'
    );
}})();
</script>
</body>
</html>"""

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"\n[Ψ] Generated: {output_file} ({total} units locked)")


# ─── ENTRY POINT ─────────────────────────────────────────────────────────────

def main() -> None:
    raw = read_raw_input()
    if not raw.strip():
        print("[Ψ] Null input. Aborting.")
        sys.exit(1)

    urls = extract_urls(raw)
    if not urls:
        print("[Ψ] No valid vectors identified.")
        sys.exit(0)

    output_file = allocate_output_filename()
    generate_html(urls, output_file)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[Ψ] Session terminated.")
        sys.exit(130)
