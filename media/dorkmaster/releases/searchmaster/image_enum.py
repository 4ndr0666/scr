#!/usr/bin/env python3
# image_enum.py
# A simple tool for enumerating and downloading images from a web page or URL list.

import httpx
from bs4 import BeautifulSoup
import sys
import os
from urllib.parse import urlparse

IMG_EXTS = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]

def fetch_page(url):
    try:
        resp = httpx.get(url, timeout=15, follow_redirects=True)
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
                # Make absolute using requests.compat.urljoin equivalent or urllib
                images.add(httpx.URL(base_url).join(src))
    return list(images)

def download_images(img_urls, base_out_dir="downloads"):
    # Centralized path: ./downloads/imgs_<hostname> or generic
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Create a timestamped or hostname-based folder ideally, but for now just "Enumerated"
    out_dir = os.path.join(script_dir, base_out_dir, "Enumerated")
    
    os.makedirs(out_dir, exist_ok=True)
    print(f"[INFO] Saving images to: {out_dir}")
    
    for i, url in enumerate(img_urls, 1):
        try:
            ext = os.path.splitext(str(url))[-1] # Convert httpx.URL to str
            if not ext: ext = ".jpg"
            # Sanitize filename from URL if possible
            fname = os.path.basename(urlparse(str(url)).path)
            if not fname or len(fname) < 4:
                fname = f"img_{i}{ext}"
            
            path = os.path.join(out_dir, fname)
            r = httpx.get(str(url), timeout=15, follow_redirects=True)
            with open(path, "wb") as f:
                f.write(r.content)
            print(f"[OK] {url} -> {path}")
        except Exception as e:
            print(f"[FAIL] {url}: {e}")

def main():
    if len(sys.argv) < 2:
        print("[*] Interactive Mode Initiated")
        url = input("Enter Target URL: ").strip()
        if not url:
            print("[!] URL required.")
            sys.exit(1)
    else:
        url = sys.argv[1]
        
    html = fetch_page(url)
    if not html:
        return
    imgs = extract_images(html, url)
    print(f"Found {len(imgs)} images.")
    download_images(imgs)

if __name__ == "__main__":
    main()
