#!/usr/bin/env python3
# script.py
# A simple reddit image ripper for a given subreddit.

import requests
import os

IMG_EXTS = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"]

def rip_subreddit(subreddit, sort="top", limit=20):
    url = f"https://www.reddit.com/r/{subreddit}.json"
    headers = {"user-agent": "my-app/0.0.1"}
    resp = requests.get(url, params={"sort": sort, "limit": limit}, headers=headers, timeout=15)
    postlist = resp.json()["data"]["children"]
    if not postlist:
        print("No results.")
        return
    dl_dir = f"Subreddit/{subreddit}"
    os.makedirs(dl_dir, exist_ok=True)
    for idx, post in enumerate(postlist):
        img_url = post["data"].get("url", "")
        if any(img_url.lower().endswith(ext) for ext in IMG_EXTS):
            try:
                img_data = requests.get(img_url, timeout=20).content
                out_path = os.path.join(dl_dir, f"file{idx}.png")
                with open(out_path, "wb") as f:
                    f.write(img_data)
                print(f"[OK] {img_url}")
            except Exception as e:
                print(f"[FAIL] {img_url}: {e}")
    print(f"Done. Images saved to {dl_dir}/")

def main():
    import sys
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <subreddit> [sort] [limit]")
        return
    sub = sys.argv[1]
    sort = sys.argv[2] if len(sys.argv) > 2 else "top"
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    rip_subreddit(sub, sort, limit)

if __name__ == "__main__":
    main()
