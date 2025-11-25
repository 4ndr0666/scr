#!/usr/bin/env python3
# image_enum.py
# A simple tool for enumerating and downloading images from a web page or URL list.

import requests
from bs4 import BeautifulSoup
import sys
import os

IMG_EXTS = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]

def fetch_page(url):
    try:
        resp = requests.get(url, timeout=15)
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        print(f"[ERR] Failed to fetch {url}: {e}")
        return ""

def extract_images(html, base_url):
    soup = BeautifulSoup(html, "html.parser")
    images = set()
    for tag in soup.find_all("img"):
        src = tag.get("src", "")
        if any(src.lower().endswith(e) for e in IMG_EXTS):
            if src.startswith("http"):
                images.add(src)
            else:
                # Make absolute
                images.add(requests.compat.urljoin(base_url, src))
    return list(images)

def download_images(img_urls, out_dir="imgs"):
    os.makedirs(out_dir, exist_ok=True)
    for i, url in enumerate(img_urls, 1):
        try:
            ext = os.path.splitext(url)[-1]
            fname = f"img_{i}{ext}"
            path = os.path.join(out_dir, fname)
            r = requests.get(url, timeout=15)
            with open(path, "wb") as f:
                f.write(r.content)
            print(f"[OK] {url} -> {path}")
        except Exception as e:
            print(f"[FAIL] {url}: {e}")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <url>")
        sys.exit(1)
    url = sys.argv[1]
    html = fetch_page(url)
    if not html:
        return
    imgs = extract_images(html, url)
    print(f"Found {len(imgs)} images.")
    download_images(imgs)

if __name__ == "__main__":
    main()
