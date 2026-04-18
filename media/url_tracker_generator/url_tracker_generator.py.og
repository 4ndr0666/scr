#!/usr/bin/env python3
# url_tracker_generator2.py
# Takes a list of urls and outputs an html file to track visited links.
import os
import re
import sys
import glob
from html import unescape


def find_next_filename():
    files = glob.glob("url-tracker-*.html")
    numbers = []
    for f in files:
        base = os.path.basename(f)
        if base.startswith("url-tracker-") and base.endswith(".html"):
            try:
                num = int(base[len("url-tracker-") : -5])
                numbers.append(num)
            except:
                pass
    next_num = 1 if not numbers else max(numbers) + 1
    return f"url-tracker-{next_num}.html"


def select_file_with_fzf():
    try:
        import subprocess

        result = subprocess.run(
            ["fzf", "--height=20", "--border"], input="", capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except:
        pass
    return None


def get_urls_from_input():
    print("Ψ Select input method:")
    print("   [1] Pick a file containing URLs")
    print("   [2] Paste URLs directly (end with blank line or Ctrl+D)")
    choice = input("Choose (1 or 2) [default: 2]: ").strip() or "2"

    raw_text = ""
    if choice == "1":
        filepath = select_file_with_fzf()
        if not filepath or not os.path.exists(filepath):
            print("No file selected or file not found. Falling back to paste.")
        else:
            with open(filepath, "r", encoding="utf-8") as f:
                raw_text = f.read()
            print(f"Loaded from: {filepath}")
    else:
        print("\nPaste URLs or HTML (multi-line OK). Finish with blank line or Ctrl+D:")
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
        print("No input received. Exiting.")
        sys.exit(1)

    return extract_and_reconstruct_urls(raw_text)


def extract_and_reconstruct_urls(text):
    urls = set()

    # 1. Extract from HTML href attributes (handles escaped HTML entities)
    hrefs = re.findall(r'href=["\']([^"\']+)["\']', text)
    for h in hrefs:
        h = unescape(h.strip())
        if h.startswith(("http://", "https://")):
            urls.add(h)

    # 2. Find any potential URL patterns in plain text
    # Full URLs + domain/path fragments that look like streaming links
    candidates = re.findall(
        r'(https?://[^\s<>"\']+|(//)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+[^\s<>"\']*)',
        text,
    )
    for candidate in candidates:
        url = candidate[0] if candidate[0] else candidate[1]
        url = url.strip()

        if url.startswith("//"):
            url = "https:" + url
        elif url.startswith(("http://", "https://")):
            pass
        elif re.match(r"^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+", url):
            # Common streaming path pattern without scheme/domain → prepend https://
            url = "https://" + url
        else:
            continue  # skip garbage

        urls.add(url)

    # 3. Clean numbered lists and re-scan
    cleaned = re.sub(r"^\d+\.\s*", "", text, flags=re.MULTILINE)
    extra_candidates = re.findall(
        r'(https?://[^\s<>"\']+|(//)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+[^\s<>"\']*)',
        cleaned,
    )
    for candidate in extra_candidates:
        url = candidate[0] if candidate[0] else candidate[1]
        url = url.strip()

        if url.startswith("//"):
            url = "https:" + url
        elif url.startswith(("http://", "https://")):
            pass
        elif re.match(r"^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/(?:e|d|f)/[a-zA-Z0-9]+", url):
            url = "https://" + url
        else:
            continue

        urls.add(url)

    # Final validation: only keep proper http/https URLs
    valid_urls = {u for u in urls if u.startswith(("http://", "https://"))}

    url_list = sorted(list(valid_urls))
    print(
        f"Universal extraction complete: {len(url_list)} unique valid URLs reconstructed."
    )
    return url_list


def generate_html(urls, output_file):
    total_count = len(urls)
    links_html = ""
    for url in urls:
        short = url.split("/")[-1]
        links_html += f'        <li data-url="{url}"><a href="{url}" target="_blank">{short}</a></li>\n'

    html_template = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ψ URL TRACKER</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto+Mono:wght@500&family=Cinzel+Decorative:wght@700&family=Orbitron:wght@700&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg-dark: #0A0F1A;
            --accent-cyan: #15fafa;
            --accent-mid: #15adad;
            --text-primary: #e0ffff;
            --text-secondary: #a0f0f0;
        }}
        body {{ background: var(--bg-dark); color: var(--text-primary); font-family: 'Roboto Mono', monospace; padding: 40px; text-align: center; margin: 0; min-height: 100vh; }}
        h1 {{ font-family: 'Cinzel Decorative', serif; font-size: 3rem; background: linear-gradient(to right, #15fafa, #15adad, #157d7d); -webkit-background-clip: text; background-clip: text; color: transparent; margin-bottom: 20px; }}
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
    <svg class="glyph" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
      <path d="M 64,12 A 52,52 0 1 1 63.9,12 Z" stroke="#15fafa" stroke-dasharray="21.78 21.78" stroke-width="2" opacity="0.8"/>
      <path d="M 64,20 A 44,44 0 1 1 63.9,20 Z" stroke="#15fafa" stroke-dasharray="10 10" stroke-width="1.5" opacity="0.5"/>
      <path d="M64 30 L91.3 47 L91.3 81 L64 98 L36.7 81 L36.7 47 Z" stroke="#15fafa" fill="none" stroke-width="3"/>
      <text x="64" y="74" text-anchor="middle" dominant-baseline="middle" fill="#15fafa" font-size="56" font-weight="700" font-family="'Cinzel Decorative', serif">Ψ</text>
    </svg>
        <h1>Ψ URL TRACKER</h1>
        <div class="counter">Remaining: {total_count} / {total_count}</div>
        <ul id="url-list">
{links_html}        </ul>
        <div class="info">
            Click → open + dematerialize<br>
            Ctrl+Z → undo last removal<br>
            <span class="undo-hint">Persistence eternal via localStorage</span>
        </div>
    </div>

    <script>
        const STORAGE_KEY_VISITED = 'psiTrackerVisited';
        const STORAGE_KEY_UNDO = 'psiTrackerUndoStack';
        let visited = new Set(JSON.parse(localStorage.getItem(STORAGE_KEY_VISITED) || '[]'));
        let undoStack = JSON.parse(localStorage.getItem(STORAGE_KEY_UNDO) || '[]');
        let totalCount = {total_count};
        let visibleCount = totalCount - visited.size;
        const ul = document.getElementById('url-list');
        const counter = document.querySelector('.counter');

        function saveVisited() {{ localStorage.setItem(STORAGE_KEY_VISITED, JSON.stringify([...visited])); }}
        function saveUndo() {{ localStorage.setItem(STORAGE_KEY_UNDO, JSON.stringify(undoStack)); }}
        function updateCounter() {{ counter.textContent = `Remaining: ${{visibleCount}} / ${{totalCount}}`; }}

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
    print(f"Ψ URL TRACKER GENERATED → {output_file} ({total_count} links)")


if __name__ == "__main__":
    urls = get_urls_from_input()
    if not urls:
        print("No valid URLs found. Exiting.")
        sys.exit(1)
    output_file = find_next_filename()
    generate_html(urls, output_file)
    print("Undo Visited Links: Ctrl+Z")
