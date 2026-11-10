#!/usr/bin/env python3
# by 4ndr0666 — refactored by claude — hardened under 4ndr0neering v8.0.0
"""
4NDR0-TRACKER — Ephemeral State Machine compliant rewrite (Superset Round 1).

Fixes over original & Round 1 Hardening:
  - Single-pass URL extraction with one unified junk filter (no duplicated logic)
  - Expanded data-* attribute extraction for hyphenated/numeric keys & protocol-relative URLs
  - Safe UTF-16 surrogate pair consolidation after \\uXXXX decoding (prevents UnicodeEncodeError)
  - Netloc host validation and control-character rejection in URL normalization
  - Atomic filename allocation via O_EXCL with guaranteed descriptor closure
  - Atomic HTML file write (mkstemp + fsync + os.replace) & orphan cleanup on interrupt/error
  - Cumulative monotonic deadline on font fetching (strict 15s total wall-clock cap)
  - FZF interactive stderr preservation + explicit subprocess timeout
  - Graceful EOFError handling on menu input & non-destructive piped stdin fallback
  - JS localStorage / JSON.parse exception guards for private/sandboxed browsing resilience
  - Race-free dematerialize/rematerialize animation state machine with background-tab fallback
  - JS undo stack stores URL strings, not serialized DOM (no innerHTML re-injection)
  - Click handler keys on li.dataset.url, not browser-resolved a.href
  - Dead visibleCount variable removed; counter driven solely by visited.size
  - HTML/JS boundary crossed via json.dumps() with </script> breakout protection
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
import tempfile
import time
import urllib.error
import urllib.parse
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
    time_str = now.strftime("%I-%M%p").lstrip("0") or now.strftime("%I-%M%p")
    next_num = (max(numbers) + 1) if numbers else 1

    # Atomic allocation: increment until we win the O_EXCL race.
    while True:
        candidate = f"4NDR0-TRACKER{next_num}_{date_str}_{time_str}.html"
        try:
            fd = os.open(candidate, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
            try:
                pass
            finally:
                os.close(fd)
            return candidate
        except FileExistsError:
            next_num += 1


# ─── INPUT ────────────────────────────────────────────────────────────────────

_FZF_TIMEOUT = 120  # seconds — explicit bound on interactive file picker


def select_file_with_fzf() -> str | None:
    """
    Launch fzf to pick a source file.
    Captures stdout while leaving stderr attached to the terminal so the
    interactive fzf UI renders properly when /dev/tty is unavailable.
    """
    try:
        result = subprocess.run(
            ["fzf", "--height=20", "--border", "--prompt=Select Source > "],
            stdout=subprocess.PIPE,
            stderr=None,
            text=True,
            check=False,
            timeout=_FZF_TIMEOUT,
        )
        if result.returncode == 0 and result.stdout and result.stdout.strip():
            return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def read_raw_input() -> str:
    """
    Acquire raw text or HTML from CLI file argument, fzf selection, or stdin paste.
    Handles immediate EOF cleanly and preserves piped URLs when stdin does not
    begin with a menu selection digit.
    """
    if len(sys.argv) > 1 and os.path.isfile(sys.argv[1]):
        filepath = sys.argv[1]
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                raw = f.read()
            print(f"\n[Ψ] Loaded: {filepath}")
            return raw
        except OSError as e:
            print(f"[Ψ] Read error: {e} — falling back to interactive input.")

    print("TARGET INPUT METHOD:")
    print("  1. Select File (fzf)")
    print("  2. Paste URLs / HTML")
    print("")
    try:
        raw_choice = input("> ").strip()
    except EOFError:
        return ""

    choice = raw_choice or "2"
    lines: list[str] = []

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
    elif choice != "2":
        # Non-menu first line (e.g., direct stdin pipe of URLs/HTML): preserve it.
        lines.append(raw_choice)

    print("\nPaste URLs or HTML (two consecutive blank lines or Ctrl+D to end):")
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

_CONTROL_OR_SPACE_RE = re.compile(r"[\s\x00-\x1f\x7f]")

_EXTRACT_PATTERNS = [
    re.compile(r'(https?://[^\s"\'<>`\\]+)'),
    re.compile(r'(//[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[^\s"\'<>`\\]+)'),
    re.compile(r'(?i)href=["\']([^"\']+)["\']'),
    re.compile(r'(?i)src=["\']([^"\']+)["\']'),
    re.compile(r'(?i)data-[a-z0-9_-]+=["\']((?:https?:)?//[^"\']+)["\']'),
    re.compile(
        r'((?:https?://|//)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+[^\s<>"\'\\]*)'
    ),
]


def _normalize(raw: str) -> str | None:
    """Return a normalized http(s):// URL or None if it should be rejected."""
    url = raw.strip().strip("\"'<>`\\")
    if not url or len(url) < 8:
        return None

    if _CONTROL_OR_SPACE_RE.search(url):
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

    try:
        parsed = urllib.parse.urlsplit(url)
    except ValueError:
        return None

    if not parsed.netloc or "." not in parsed.netloc:
        return None

    return url


def extract_urls(text: str) -> list[str]:
    """
    Single-pass extraction pipeline.
    Decode → unescape → apply patterns → normalize/filter → deduplicate → sort.
    """
    if not text:
        return []

    # Decode escape layers and consolidate any UTF-16 surrogate pairs safely
    text = unescape(text)
    text = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), text)
    text = text.encode("utf-16", "surrogatepass").decode("utf-16", "replace")
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


def _fetch(url: str, headers: dict, timeout: float = _FONT_TIMEOUT) -> bytes:
    if timeout <= 0:
        raise TimeoutError("Font fetch deadline exceeded")
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def fetch_base64_fonts() -> str:
    """
    Fetch Google Fonts CSS, embed each woff2 as a Base64 data URI.
    Enforces a cumulative monotonic deadline across all network calls.
    Falls back to remote <link> on any error.
    """
    print("[Ψ] Synthesizing Base64 offline fonts...")
    headers = {"User-Agent": _UA}
    deadline = time.monotonic() + _FONT_TIMEOUT
    try:
        remaining = deadline - time.monotonic()
        css = _fetch(_FONT_CSS_URL, headers, timeout=remaining).decode("utf-8")
        woff2_urls = re.findall(
            r"url\(['\"]?(https://[^)'\"]+\.woff2[^)'\"]*)['\"]?\)", css
        )
        for woff_url in sorted(set(woff2_urls)):
            remaining = deadline - time.monotonic()
            font_bytes = _fetch(woff_url, headers, timeout=remaining)
            b64 = base64.b64encode(font_bytes).decode("utf-8")
            data_uri = f"data:font/woff2;charset=utf-8;base64,{b64}"
            css = css.replace(woff_url, data_uri)
        print("[Ψ] Base64 font synthesis complete.")
        return f"<style>\n{css}\n</style>"
    except (urllib.error.URLError, OSError, TimeoutError, UnicodeDecodeError, ValueError) as exc:
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
        label = url.rstrip("/").split("/")[-1] if url.rstrip("/") else url
        if not label or label in ("http:", "https:"):
            label = url
        safe_url = escape(url, quote=True)
        safe_label = escape(label)
        items_html += (
            f'        <li data-url="{safe_url}">'
            f'<a href="{safe_url}" target="_blank" rel="noopener noreferrer">'
            f"{safe_label}</a></li>\n"
        )

    font_styles = fetch_base64_fonts()

    # Cross the HTML/JS boundary with json.dumps() and neutralize </script> sequences
    js_total = json.dumps(total)
    js_storage_visited = json.dumps("psiTrackerVisited").replace("</", "<\\/")
    js_storage_undo = json.dumps("psiTrackerUndoStack").replace("</", "<\\/")

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
            0%   {{ opacity: 1; transform: scale(1)    translateY(0);     filter: blur(0);    }}
            50%  {{ opacity: .3; transform: scale(1.05) translateY(-10px); filter: blur(5px);  }}
            100% {{ opacity: 0; transform: scale(.95) translateY(-20px); filter: blur(15px); }}
        }}
        li.leaving {{ animation: dematerialize 1.2s forwards; }}

        @keyframes rematerialize {{
            0%   {{ opacity: 0; transform: scale(.95) translateY(-20px); filter: blur(15px); }}
            50%  {{ opacity: .3; transform: scale(1.05) translateY(-10px); filter: blur(5px);  }}
            100% {{ opacity: 1; transform: scale(1)    translateY(0);     filter: blur(0);    }}
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

    function safeLoadArray(key) {{
        try {{
            const raw = localStorage.getItem(key);
            if (!raw) return [];
            const parsed = JSON.parse(raw);
            return Array.isArray(parsed) ? parsed.filter(v => typeof v === 'string') : [];
        }} catch (_) {{
            return [];
        }}
    }}

    // ── State ──────────────────────────────────────────────────────────────
    // Undo stack stores URL strings, not serialized DOM.
    // DOM is rebuilt from the authoritative data-url attribute on restore.
    let visited   = new Set(safeLoadArray(STORAGE_VISITED));
    let undoStack = safeLoadArray(STORAGE_UNDO);
    const pendingTimers = new WeakMap();

    const ul      = document.getElementById('url-list');
    const counter = document.getElementById('counter');

    function persist() {{
        try {{
            localStorage.setItem(STORAGE_VISITED, JSON.stringify([...visited]));
            localStorage.setItem(STORAGE_UNDO,    JSON.stringify(undoStack));
        }} catch (_) {{
            // Continue operating with in-memory state if storage is blocked/full.
        }}
    }}

    function updateCounter() {{
        counter.textContent =
            `${{visited.size}} of ${{TOTAL}} visited · Ctrl+Z to restore`;
    }}

    function clearPendingTimer(li) {{
        const tid = pendingTimers.get(li);
        if (tid !== undefined) {{
            clearTimeout(tid);
            pendingTimers.delete(li);
        }}
    }}

    function finalizeLeave(li, url) {{
        clearPendingTimer(li);
        if (!visited.has(url)) return;
        li.classList.remove('leaving', 'entering');
        li.classList.add('vanished');
        li.hidden = true;
    }}

    function finalizeEnter(li, url) {{
        clearPendingTimer(li);
        if (visited.has(url)) return;
        li.classList.remove('entering', 'leaving', 'vanished');
        li.hidden = false;
    }}

    function findItemByUrl(url) {{
        if (typeof CSS !== 'undefined' && typeof CSS.escape === 'function') {{
            const match = ul.querySelector(`li[data-url="${{CSS.escape(url)}}"]`);
            if (match) return match;
        }}
        const items = ul.querySelectorAll('li[data-url]');
        for (let i = 0; i < items.length; i++) {{
            if (items[i].dataset.url === url) return items[i];
        }}
        return null;
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
                clearPendingTimer(li);
                li.classList.remove('entering', 'vanished');
                li.classList.add('leaving');
                const onLeaveEnd = ev => {{
                    if (ev && ev.animationName && ev.animationName !== 'dematerialize') return;
                    li.removeEventListener('animationend', onLeaveEnd);
                    finalizeLeave(li, url);
                }};
                li.addEventListener('animationend', onLeaveEnd);
                pendingTimers.set(li, setTimeout(() => {{
                    li.removeEventListener('animationend', onLeaveEnd);
                    finalizeLeave(li, url);
                }}, 1300));
            }}
        }}

        window.open(url, '_blank', 'noopener,noreferrer');
    }});

    // ── Keyboard handlers ──────────────────────────────────────────────────
    document.addEventListener('keydown', e => {{

        // Restore: Ctrl+Z (or Cmd+Z)
        if ((e.ctrlKey || e.metaKey) && !e.shiftKey && e.key.toLowerCase() === 'z') {{
            if (undoStack.length === 0) return;
            e.preventDefault();

            const url = undoStack.pop();
            visited.delete(url);
            persist();
            updateCounter();

            const li = findItemByUrl(url);
            if (li) {{
                clearPendingTimer(li);
                li.hidden = false;
                li.classList.remove('vanished', 'leaving');
                li.classList.add('entering');
                const onEnterEnd = ev => {{
                    if (ev && ev.animationName && ev.animationName !== 'rematerialize') return;
                    li.removeEventListener('animationend', onEnterEnd);
                    finalizeEnter(li, url);
                }};
                li.addEventListener('animationend', onEnterEnd);
                pendingTimers.set(li, setTimeout(() => {{
                    li.removeEventListener('animationend', onEnterEnd);
                    finalizeEnter(li, url);
                }}, 1300));
            }}
        }}

        // Purge: Ctrl+Shift+X (or Cmd+Shift+X)
        if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toUpperCase() === 'X') {{
            e.preventDefault();
            let confirmed = true;
            try {{
                confirmed = confirm('[Ψ] WARNING: TOTAL MEMORY PURGE. All persistence vectors erased. Proceed?');
            }} catch (_) {{
                confirmed = true;
            }}
            if (confirmed) {{
                try {{
                    localStorage.removeItem(STORAGE_VISITED);
                    localStorage.removeItem(STORAGE_UNDO);
                }} catch (_) {{}}
                visited.clear();
                undoStack.length = 0;
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

    target_dir = os.path.dirname(os.path.abspath(output_file)) or "."
    fd, tmp_path = tempfile.mkstemp(prefix=".4ndr0tracker_", suffix=".tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(html)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, output_file)
    finally:
        if os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

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
    try:
        generate_html(urls, output_file)
    except BaseException:
        if os.path.exists(output_file):
            try:
                if os.path.getsize(output_file) == 0:
                    os.unlink(output_file)
            except OSError:
                pass
        raise


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[Ψ] Session terminated.")
        sys.exit(130)
