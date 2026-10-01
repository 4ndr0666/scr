#!/usr/bin/env python3
# script.py
# A simple reddit image ripper for a given subreddit.

import httpx
import os
from urllib.parse import urlparse

IMG_EXTS = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"]

def rip_subreddit(subreddit, sort="top", limit=20):
    url = f"https://www.reddit.com/r/{subreddit}.json"
    # Use a standard browser UA to avoid immediate block
    headers = {"user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"}
    
    try:
        # Using httpx in sync mode for simplicity in this script
        resp = httpx.get(url, params={"sort": sort, "limit": limit}, headers=headers, timeout=15, follow_redirects=True)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"[ERR] Failed to fetch subreddit data: {e}")
        return

    postlist = data.get("data", {}).get("children", [])
    if not postlist:
        print("No results.")
        return
    
    # Centralized download path: ./downloads/Subreddit/<name>
    base_dl_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "downloads")
    dl_dir = os.path.join(base_dl_dir, "Subreddit", subreddit)
    os.makedirs(dl_dir, exist_ok=True)
    
    print(f"[INFO] Saving images to: {dl_dir}")

    for idx, post in enumerate(postlist):
        img_url = post["data"].get("url", "")
        if any(img_url.lower().endswith(ext) for ext in IMG_EXTS):
            try:
                # httpx get for image content
                img_data = httpx.get(img_url, timeout=20, follow_redirects=True).content
                # Preserve original filename if possible, else fallback
                original_name = os.path.basename(urlparse(img_url).path)
                if not original_name or len(original_name) < 3:
                     original_name = f"file{idx}.png"
                
                out_path = os.path.join(dl_dir, original_name)
                
                with open(out_path, "wb") as f:
                    f.write(img_data)
                print(f"[OK] {img_url}")
            except Exception as e:
                print(f"[FAIL] {img_url}: {e}")
    print(f"Done. Images saved to {dl_dir}/")

def main():
    import sys
    
    # Interactive Mode
    if len(sys.argv) < 2:
        print("[*] Interactive Mode Initiated")
        sub = input("Enter Subreddit: ").strip()
        if not sub:
            print("[!] Subreddit required.")
            return
        sort = input("Sort (top/hot/new) [top]: ").strip() or "top"
        limit_str = input("Limit [20]: ").strip() or "20"
        limit = int(limit_str)
        rip_subreddit(sub, sort, limit)
    else:
        # CLI Mode
        sub = sys.argv[1]
        sort = sys.argv[2] if len(sys.argv) > 2 else "top"
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 20
        rip_subreddit(sub, sort, limit)

if __name__ == "__main__":
    main()
