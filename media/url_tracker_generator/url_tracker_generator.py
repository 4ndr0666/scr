# url_tracker_generator.py
# Run: python3 url_tracker_generator.py
# Outputs: url-tracker.html — visited vanish, Ctrl+Z undo with reverse animation + localStorage persistence
urls = [
    "https://gofile.io/d/05v5zB",
    "https://gofile.io/d/0QQ7gc",
    "https://gofile.io/d/0QQvnt",
    "https://gofile.io/d/0fWK28",
    "https://gofile.io/d/0ucFNF",
    "https://gofile.io/d/10vnXs",
    "https://gofile.io/d/11778e-424b-4f00-a637-a4d5fc421022",
    "https://gofile.io/d/16jgvq",
    "https://gofile.io/d/1eUvIu",
    "https://gofile.io/d/219fdd-0ea4-426e-914f-41f0c6ea7853",
    "https://gofile.io/d/21EeMR",
    "https://gofile.io/d/21UtAd",
    "https://gofile.io/d/24c968-8c67-4ee1-a47a-f59ccfeb038b",
    "https://gofile.io/d/2PjHSX",
    "https://gofile.io/d/2Qbk1S",
    "https://gofile.io/d/2XgEwL",
    "https://gofile.io/d/3OEWcM",
    "https://gofile.io/d/3YcNqk",
    "https://gofile.io/d/3d1fc8-db2d-4c74-b712-9d15cf074418",
    "https://gofile.io/d/3hIJOM",
    "https://gofile.io/d/44gu1X",
    "https://gofile.io/d/4JwAYK",
    "https://gofile.io/d/4QyXvI",
    "https://gofile.io/d/4kBs6G",
    "https://gofile.io/d/4uaRWt",
    "https://gofile.io/d/4xDE9j",
    "https://gofile.io/d/5ydZ0c",
    "https://gofile.io/d/67SuEH",
    "https://gofile.io/d/6YwfDv",
    "https://gofile.io/d/6jXRHE",
    "https://gofile.io/d/6lIfFv",
    "https://gofile.io/d/6ts7K1",
    "https://gofile.io/d/6zPKhJ",
    "https://gofile.io/d/70HmZw",
    "https://gofile.io/d/7g1jSk",
    "https://gofile.io/d/7w9YtN",
    "https://gofile.io/d/87CoWl",
    "https://gofile.io/d/8OxaaI",
    "https://gofile.io/d/8UB1fv",
    "https://gofile.io/d/8ee982-edd1-4a7a-99dd-65072210a0a7",
    "https://gofile.io/d/8o0s0R",
]

html_template = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>URL Ψ TRACKER</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto+Mono:wght@500&family=Cinzel+Decorative:wght@700&display=swap">
    <style>
        :root {{
            --bg-dark: #0A131A;
            --accent-cyan: #15fafa;
            --text-primary: #e0ffff;
        }}
        body {{ background: var(--bg-dark); color: var(--text-primary); font-family: 'Roboto Mono', monospace; padding: 40px; text-align: center; }}
        h1 {{ font-family: 'Cinzel Decorative', serif; font-size: 2.5rem; background: linear-gradient(to right, #15fafa, #15adad); -webkit-background-clip: text; background-clip: text; color: transparent; margin-bottom: 20px; }}
        .glyph {{ width: 120px; height: 120px; margin: 20px auto; filter: drop-shadow(0 0 20px var(--accent-cyan)); animation: pulse 4s infinite; }}
        @keyframes pulse {{ 0%,100% {{ filter: drop-shadow(0 0 20px var(--accent-cyan)); }} 50% {{ filter: drop-shadow(0 0 30px var(--accent-cyan)); }} }}
        ul {{ list-style: none; padding: 0; max-width: 600px; margin: 0 auto; }}
        li {{ 
            margin: 12px 0; 
            overflow: hidden;
            max-height: 80px;
            transition: max-height 0.8s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.8s ease, margin 0.8s ease;
        }}
        li.vanished {{ 
            max-height: 0; 
            opacity: 0;
            margin: 0;
        }}
        a {{ 
            display: block; 
            padding: 14px 20px; 
            background: rgba(10,15,26,0.7); 
            border: 1px solid transparent; 
            border-radius: 10px; 
            color: #15fafa; 
            text-decoration: none; 
            font-size: 14px; 
            transition: all 0.4s ease; 
            box-shadow: 0 0 12px rgba(21,250,250,0.2);
        }}
        a:hover {{ 
            background: rgba(21,250,250,0.2); 
            box-shadow: 0 0 25px rgba(21,250,250,0.6); 
            transform: translateY(-3px); 
        }}
        a:visited {{ animation: dematerialize 1s forwards; }}
        @keyframes dematerialize {{
            0% {{ opacity: 1; transform: scale(1); filter: blur(0); }}
            60% {{ opacity: 0.4; transform: scale(1.08); filter: blur(3px); }}
            100% {{ opacity: 0; transform: scale(0.9); filter: blur(10px); }}
        }}
        @keyframes rematerialize {{
            0% {{ opacity: 0; transform: scale(0.9); filter: blur(10px); max-height: 0; }}
            60% {{ opacity: 0.4; transform: scale(1.08); filter: blur(3px); }}
            100% {{ opacity: 1; transform: scale(1); filter: blur(0); max-height: 80px; }}
        }}
        li.rematerializing {{ animation: rematerialize 1s forwards; }}
        .info {{ margin-top: 40px; font-size: 14px; opacity: 0.8; }}
        .counter {{ margin: 20px 0; font-size: 18px; }}
        .undo-hint {{ margin-top: 10px; font-size: 12px; opacity: 0.6; }}
    </style>
    <script>
        const totalCount = {count};
        let visibleCount = totalCount;
        let undoStack = JSON.parse(localStorage.getItem('gofileUndoStack') || '[]');

        function saveUndoStack() {{
            localStorage.setItem('gofileUndoStack', JSON.stringify(undoStack));
        }}

        document.addEventListener('DOMContentLoaded', () => {{
            const ul = document.querySelector('ul');
            const lis = ul.querySelectorAll('li');

            lis.forEach(li => {{
                const a = li.querySelector('a');
                if (a.matches(':visited')) {{
                    li.classList.add('vanished');
                    visibleCount--;
                }}
            }});
            updateCounter();

            lis.forEach(li => {{
                const a = li.querySelector('a');
                a.addEventListener('click', e => {{
                    setTimeout(() => {{
                        if (!li.classList.contains('vanished')) {{
                            const liClone = li.cloneNode(true);
                            undoStack.push({{html: li.outerHTML, url: a.href}});
                            saveUndoStack();
                            li.classList.add('vanished');
                            visibleCount--;
                            updateCounter();
                        }}
                    }}, 300);
                }});
            }});
        }});

        function updateCounter() {{
            document.querySelector('.counter').textContent = `Remaining: ${{visibleCount}} / ${{totalCount}}`;
        }}

        // Ctrl+Z Undo with reverse animation
        document.addEventListener('keydown', e => {{
            if ((e.ctrlKey || e.metaKey) && e.key === 'z' && undoStack.length > 0) {{
                e.preventDefault();
                const last = undoStack.pop();
                saveUndoStack();

                const ul = document.querySelector('ul');
                const tempDiv = document.createElement('div');
                tempDiv.innerHTML = last.html;
                const restoredLi = tempDiv.firstChild;

                const existing = [...ul.children].find(li => li.querySelector('a').href === last.url);
                if (existing) {{
                    ul.replaceChild(restoredLi, existing);
                }} else {{
                    ul.appendChild(restoredLi);
                }}

                restoredLi.classList.add('rematerializing');
                visibleCount++;
                updateCounter();

                restoredLi.addEventListener('animationend', () => {{
                    restoredLi.classList.remove('rematerializing');
                }}, {{once: true}});
            }}
        }});
    </script>
</head>
<body>
    <svg class="glyph" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
      <path d="M 64,12 A 52,52 0 1 1 63.9,12 Z" stroke="#15fafa" stroke-dasharray="21.78 21.78" stroke-width="2" opacity="0.8"/>
      <path d="M 64,20 A 44,44 0 1 1 63.9,20 Z" stroke="#15fafa" stroke-dasharray="10 10" stroke-width="1.5" opacity="0.5"/>
      <path d="M64 30 L91.3 47 L91.3 81 L64 98 L36.7 81 L36.7 47 Z" stroke="#15fafa" fill="none" stroke-width="3"/>
      <text x="64" y="74" text-anchor="middle" dominant-baseline="middle" fill="#15fafa" font-size="56" font-weight="700" font-family="'Cinzel Decorative', serif">
        Ψ
      </text>
    </svg>

    <h1>URL Ψ TRACKER — {count} LINKS</h1>
    <div class="counter">Remaining: {count} / {count}</div>

    <ul>
{links}    </ul>

    <div class="info">
        Click → open + dematerialize<br>
        Ctrl+Z → undo (reverse animation)<br>
        <span class="undo-hint">Undo stack persists across sessions</span>
    </div>
</body>
</html>"""

links_html = ""
for url in urls:
    short = url.replace("https://gofile.io/d/", "").replace("http://gofile.io/d/", "")
    links_html += f'        <li><a href="{url}" target="_blank">{short}</a></li>\n'

total_count = len(urls)
output = html_template.format(count=total_count, links=links_html)

with open("url-tracker.html", "w", encoding="utf-8") as f:
    f.write(output)

print(f"Resurrection complete: url-tracker.html generated with {len(urls)} links.")
print("Click → dematerialize")
print("Ctrl+Z → rematerialize with reverse animation")
print("Undo stack persists via localStorage — eternal across sessions")
