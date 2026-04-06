# Dorkmaster.py + Universal Gallery Temple

**Version:** 7.0.0 (4NDR0666OS hardened)  
**Author:** 4ndr0666  
**Date:** April 02, 2026  
**Purpose:** Professional-grade NSFW leak hunting + mass gallery enumeration tool

## What is this?

Dorkmaster is a powerful, modular Python toolkit designed for:
- Google/Bing/SearxNG dorking with rich NSFW pattern database
- Image brute-forcing on numeric CDN buckets (the celebhottie-style attack)
- Recursive crawling
- Reddit ripping
- Telegram !MEGAHUNT mirror harvesting
- WordPress sitemap → gallery → media extraction
- Aria2c-powered multi-connection downloading
- Persistent Mycelial session tree
- Plugin system

The **Universal Gallery Enumeration Temple** (option 12) is the crown jewel: it turns any WordPress site + CDN into a full media firehose.

## Features

- XDG-compliant config & downloads
- Auto-onboarding (creates config on first run)
- Rich console UI with progress bars and tables
- Full async httpx + BeautifulSoup scraping
- Intermediate + final saving of every discovered link
- Keyboard-interrupt safe (saves what it has)
- OPSEC warnings built-in
- Seamless ATSCAN hybrid potential

## Installation

```bash
# 1. Clone or place the file
cp compare.py dorkmaster.py

# 2. Install dependencies
pip install httpx beautifulsoup4 rich

# 3. Install aria2c (recommended for downloads)
# Ubuntu/Debian
sudo apt install aria2

# Arch
sudo pacman -S aria2

# 4. Make executable
chmod +x dorkmaster.py
```

## Basic Usage

```bash
python3 dorkmaster.py
```

Main menu options:

1. Dork & Hunt (SearxNG + Telegram fallback)  
2. Image Brute-Forcer (numeric pattern attack)  
3. Recursive Image Crawler  
4. Reddit Ripper  
5. Analyze Single URL  
6. Spider Leak Domains  
7. Recurse URL Chains  
8. Export Session  
9. View Session Tree  
10. Plugins  
11. Settings  
12. **Universal Gallery Enumeration Temple** ← this is the one we are using

**Option 12 workflow (celebhottie example):**

- Domain: `celebhottie.com`
- CDN base: `https://cdn.celebhottie.com`

The temple will:
- Pull all WP sitemaps
- Extract gallery URLs
- Scrape media from each gallery (now prefers full-res where possible)
- Brute numeric buckets
- Save every link to `~/.local/share/dorkmaster/downloads/temple_results/media_*.txt`
- Ask if you want to download with aria2c
