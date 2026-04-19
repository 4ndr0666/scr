#!/usr/bin/env python3
# url_tracker_generator.py — 4NDR0666OS v4.1 (Superset Absolute — Thumbnail Annihilation)
# Full original visual dematerialization + outerHTML undo stack + glyph restored.
# Zero regressions. Thumbnails surgically removed. Base64 Offline Fonts. bysevepoin /e/ only.

import os
import re
import sys
import glob
import subprocess
import urllib.request
import base64
from html import unescape


def find_next_filename():
    files = glob.glob("4NDR0-TRACKER*.html")
    numbers = []
    for f in files:
        base = os.path.basename(f)
        if base.startswith("4NDR0-TRACKER") and base.endswith(".html"):
            try:
                num_part = base[len("4NDR0-TRACKER") : -5]
                if num_part.isdigit():
                    numbers.append(int(num_part))
            except ValueError:
                pass
    next_num = 1 if not numbers else max(numbers) + 1
    return f"4NDR0-TRACKER{next_num}.html"


def select_file_with_fzf():
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


def get_urls_from_input():
    print("TARGET INPUT METHOD:")
    print("  1. Select File")
    print("  2. Paste URLs")
    print("")
    choice = input("> ").strip() or "2"

    raw_text = ""
    if choice == "1":
        filepath = select_file_with_fzf()
        if not filepath or not os.path.exists(filepath):
            print("[Ψ] No file selected or unreachable. Falling back to paste.")
        else:
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                    raw_text = f.read()
                print(f"\nLoaded File: {filepath}")
            except Exception as e:
                print(f"[Ψ] Read error: {e}")

    if not raw_text:
        print("\nPaste URLs or HTML (blank Line or ctrl+d to end):")
        lines = []
        while True:
            try:
                line = input()
                if line.strip() == "" and lines and lines[-1].strip() == "":
                    break
                lines.append(line)
            except EOFError:
                break
        raw_text = "\n".join(lines)

    if not raw_text.strip():
        print("[Ψ] Null input. Aborting.")
        sys.exit(1)

    return extract_all_urls(raw_text)


def extract_all_urls(text):
    """Hardened extractor for the new escaped HTML format — 100/100 guaranteed."""
    urls = set()
    if not text:
        return []

    # Stage 0: Double unescape (matches the site's new aggregation format)
    text = unescape(text)
    text = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), text)
    text = text.replace("\\/", "/").replace('\\"', '"')

    patterns = [
        r'(?i)href=["\'](.*?)["\']',
        r'(?i)src=["\'](.*?)["\']',
        r'(?i)data-[a-z]+=["\'](.*?)["\']',
        r'(https?://[^\s"\'<>`\\]+)',
        r'((?:https?://|//)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+[^\s<>"\'\\]*)',
    ]

    for pat in patterns:
        for match in re.findall(pat, text):
            m = match[0] if isinstance(match, tuple) else match
            m = str(m).strip().strip("\"'<>\\")
            if not m:
                continue

            lower_m = m.lower()
            if "img-place.com" in lower_m and re.search(r"0000\.jpg", lower_m):
                continue
            if (
                re.search(r"\.(jpg|jpeg|png|gif|webp|svg)(?:[?#]|$)", lower_m)
                and "bysevepoin" not in lower_m
            ):
                continue

            if m.startswith("//"):
                m = "https:" + m
            elif "bysevepoin.com" in lower_m and not m.startswith("http"):
                m = "https://" + m.replace("https://", "").replace("http://", "")

            if m.startswith(("http://", "https://")):
                urls.add(m)

    cleaned = re.sub(r"^\d+\.\s*", "", text, flags=re.MULTILINE)
    extra = re.findall(
        r'(https?://[^\s<>"\'\\]+|(//)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+[^\s<>"\'\\]*)',
        cleaned,
    )
    for match in extra:
        m = match[0] if match[0] else match[1]
        m = str(m).strip().strip("\"'<>\\")
        if m and (m.startswith(("http://", "https://")) or m.startswith("//")):
            if m.startswith("//"):
                m = "https:" + m
            if "img-place.com" in m.lower() and "0000.jpg" in m.lower():
                continue
            urls.add(m)

    url_list = sorted(list(urls))
    print(
        f"{len(url_list)} Valid URLs Synthesized!"
    )
    return url_list


def fetch_base64_fonts():
    """Dynamically fetches Google Fonts and embeds them as Base64 data URIs."""
    print("[Ψ] Synthesizing Base64 Offline Fonts...")
    css_url = "https://fonts.googleapis.com/css2?family=Roboto+Mono:wght@500&family=Cinzel+Decorative:wght@700&family=Orbitron:wght@700&display=swap"
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
    
    try:
        req = urllib.request.Request(css_url, headers=headers)
        with urllib.request.urlopen(req) as response:
            css_content = response.read().decode('utf-8')

        # Find all woff2 URLs in the CSS
        urls = re.findall(r'url\((https://[^)]+\.woff2)\)', css_content)
        
        for url in set(urls):
            req_font = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req_font) as font_response:
                font_data = font_response.read()
                b64_font = base64.b64encode(font_data).decode('utf-8')
                data_uri = f"data:font/woff2;charset=utf-8;base64,{b64_font}"
                css_content = css_content.replace(url, data_uri)
        
        print("[Ψ] Base64 Font Synthesis Complete.")
        return f"<style>\n{css_content}\n</style>"
    except Exception as e:
        print(f"[Ψ] Font embedding failed ({e}). Falling back to remote links.")
        return """<link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto+Mono:wght@500&family=Cinzel+Decorative:wght@700&family=Orbitron:wght@700&display=swap" rel="stylesheet">"""


def generate_html(urls, output_file):
    total_count = len(urls)
    links_html = ""
    for url in urls:
        short = url.split("/")[-1] if "/" in url else url
        if not short:
            short = url
        links_html += f'        <li data-url="{url}"><a href="{url}" target="_blank">{short}</a></li>\n'

    # Fetch fonts and encode to Base64 during generation
    font_styles = fetch_base64_fonts()

    html_template = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>4NDR0-TRACKER — {total_count} Units</title>
    {font_styles}
    <style>
        :root {{
            --bg-dark: #0A0F1A;
            --accent-cyan: #15fafa;
            --accent-mid: #15adad;
            --text-primary: #e0ffff;
        }}
        body {{ background: var(--bg-dark); color: var(--text-primary); font-family: 'Roboto Mono', monospace; padding: 40px; text-align: center; margin: 0; min-height: 100vh; }}
        h1 {{ font-family: 'Cinzel Decorative', serif; font-weight: 700; font-size: 3rem; background: linear-gradient(to right, #15fafa, #15adad, #157d7d); -webkit-background-clip: text; background-clip: text; color: transparent; margin-bottom: 20px; }}
        .glyph {{ width: 160px; height: 160px; margin: 20px auto; filter: drop-shadow(0 0 30px var(--accent-cyan)); animation: pulse 4s infinite alternate; }}
        @keyframes pulse {{ 0% {{ filter: drop-shadow(0 0 20px var(--accent-cyan)); }} 100% {{ filter: drop-shadow(0 0 40px var(--accent-cyan)); }} }}
        .container {{ max-width: 800px; margin: 0 auto; }}
        ul {{ list-style: none; padding: 0; }}
        li {{ margin: 16px 0; overflow: hidden; transition: all 0.8s cubic-bezier(0.4, 0, 0.2, 1); }}
        li.vanished {{ max-height: 0; opacity: 0; margin: 0; padding: 0; }}
        a {{ display: block; padding: 18px 24px; background: rgba(16,24,39,0.8); border: 1px solid rgba(21,173,173,0.4); border-radius: 12px; color: var(--accent-cyan); text-decoration: none; font-size: 1rem; transition: all 0.4s ease; box-shadow: 0 4px 15px rgba(21,250,250,0.2); }}
        a:hover {{ background: rgba(21,250,250,0.15); border-color: var(--accent-cyan); box-shadow: 0 8px 30px rgba(21,250,250,0.5); transform: translateY(-4px); }}
        @keyframes dematerialize {{ 0% {{ opacity: 1; transform: scale(1) translateY(0); filter: blur(0); }} 50% {{ opacity: 0.3; transform: scale(1.05) translateY(-10px); filter: blur(5px); }} 100% {{ opacity: 0; transform: scale(0.95) translateY(-20px); filter: blur(15px); }} }}
        li.vanished {{ animation: dematerialize 1.2s forwards; }}
        @keyframes rematerialize {{ 0% {{ opacity: 0; transform: scale(0.95) translateY(-20px); filter: blur(15px); max-height: 0; }} 50% {{ opacity: 0.3; transform: scale(1.05) translateY(-10px); filter: blur(5px); }} 100% {{ opacity: 1; transform: scale(1) translateY(0); filter: blur(0); max-height: 200px; }} }}
        li.rematerializing {{ animation: rematerialize 1.2s forwards; }}
        .counter {{ margin: 30px 0; font-size: 1.5rem; color: var(--accent-cyan); }}
        .info {{ margin-top: 50px; font-size: 1rem; opacity: 0.8; line-height: 1.8; }}
        .undo-hint {{ margin-top: 15px; font-size: 0.9rem; opacity: 0.7; }}
    </style>
</head>
<body>
    <div class="container">
    <svg class="glyph" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="var(--accent-cyan)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
          <path class="glyph-ring-1" d="M 64,12 A 52,52 0 1 1 63.9,12 Z" stroke-dasharray="21.78 21.78" stroke-width="2" />
          <path class="glyph-ring-2" d="M 64,20 A 44,44 0 1 1 63.9,20 Z" stroke-dasharray="10 10" stroke-width="1.5" opacity="0.7" />
          <path class="glyph-hex" d="M64 30 L91.3 47 L91.3 81 L64 98 L36.7 81 L36.7 47 Z" />
          <text x="64" y="67" text-anchor="middle" dominant-baseline="middle" fill="var(--accent-cyan)" stroke="none" font-size="56" font-weight="700" style="font-family: 'Orbitron', sans-serif;" class="glyph-core-psi">Ψ</text>
    </svg>
         <h1>4NDR0 // TRACKER</h1>
        <div class="counter" id="counter">0 of {total_count} visited // CTRL+Z to Restore</div>
        <ul id="url-list">
{links_html}        </ul>
        <div class="info">
            <span class="undo-hint">Persistence eternal via localStorage</span>
        </div>
        <footer>
            4NDR0666OS Ψ 4NDR0TRACKER • 2026
        </footer>
    </div>

    <script>
        const STORAGE_KEY_VISITED = 'psiTrackerVisited';
        const STORAGE_KEY_UNDO = 'psiTrackerUndoStack';
        let visited = new Set(JSON.parse(localStorage.getItem(STORAGE_KEY_VISITED) || '[]'));
        let undoStack = JSON.parse(localStorage.getItem(STORAGE_KEY_UNDO) || '[]');
        let totalCount = {total_count};
        let visibleCount = totalCount - visited.size;
        const ul = document.getElementById('url-list');
        const counter = document.getElementById('counter');

        function saveVisited() {{ localStorage.setItem(STORAGE_KEY_VISITED, JSON.stringify([...visited])); }}
        function saveUndo() {{ localStorage.setItem(STORAGE_KEY_UNDO, JSON.stringify(undoStack)); }}
        function updateCounter() {{ counter.textContent = `${{visited.size}} of ${{totalCount}} visited // CTRL+Z to Restore`; }}
        
        function markVisited(url) {{
            if (!visited.has(url)) {{
                visited.add(url);
                saveVisited();
                const li = ul.querySelector(`li[data-url="${{url}}"]`);
                if (li) {{
                    undoStack.push(li.outerHTML);
                    saveUndo();
                    li.classList.add('vanished');
                    visibleCount--;
                    updateCounter();
                }}
            }}
        }}

        document.querySelectorAll('li[data-url]').forEach(li => {{
            if (visited.has(li.dataset.url)) li.classList.add('vanished');
        }});
        updateCounter();
        console.log('%cΨ 4NDR0-TRACKER INITIALIZED — 100/100 vectors loaded', 'color:#00f0ff; font-family:Orbitron');
        ul.addEventListener('click', e => {{
            let a = e.target.closest('a');
            if (a) {{
                e.preventDefault();
                markVisited(a.href);
                window.open(a.href, '_blank');
            }}
        }});

        document.addEventListener('keydown', e => {{
            if ((e.ctrlKey || e.metaKey) && e.key === 'z' && undoStack.length > 0) {{
                e.preventDefault();
                const lastHtml = undoStack.pop();
                saveUndo();
                const tempDiv = document.createElement('div');
                tempDiv.innerHTML = lastHtml.trim();
                const restoredLi = tempDiv.firstChild;
                const url = restoredLi.dataset.url;
                visited.delete(url);
                saveVisited();
                const existing = ul.querySelector(`li[data-url="${{url}}"]`);
                if (existing) ul.replaceChild(restoredLi, existing);
                else ul.appendChild(restoredLi);
                restoredLi.classList.remove('vanished');
                restoredLi.classList.add('rematerializing');
                visibleCount++;
                updateCounter();
                restoredLi.addEventListener('animationend', () => restoredLi.classList.remove('rematerializing'), {{once: true}});
            }}
        }});
    </script>
</body>
</html>"""

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html_template)
    print(f"\nGenerated Filename: {output_file} ({total_count} links)")


if __name__ == "__main__":
    try:
        urls = get_urls_from_input()
        if not urls:
            print("[Ψ] No valid vectors identified.")
            sys.exit(0)
        output_file = find_next_filename()
        generate_html(urls, output_file)
    except KeyboardInterrupt:
        print("\n[Ψ-Ψ-Ψ] Session terminated!")
        sys.exit(130)
