import json, os, base64, urllib.parse, sys

if len(sys.argv) < 3:
    print("Usage: python har2tree.py input.har output_dir")
    sys.exit(1)

har_path, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)

with open(har_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for entry in data['log']['entries']:
    url = entry['request']['url']
    resp = entry['response']
    if 'content' not in resp or 'text' not in resp['content']:
        continue

    path = urllib.parse.urlparse(url).path.lstrip('/')
    if not path:
        path = 'index.html'

    fullpath = os.path.join(out_dir, path)
    os.makedirs(os.path.dirname(fullpath), exist_ok=True)

    content = resp['content']['text']
    if resp['content'].get('encoding') == 'base64':
        content = base64.b64decode(content)
        mode = 'wb'
    else:
        mode = 'w'
        content = content.encode('utf-8') if isinstance(content, str) else content

    with open(fullpath, mode) as f:
        f.write(content)

print(f"Extracted to: {out_dir}")
