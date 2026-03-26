# 4NDR0666OS — Wayback Machine CDX Grinder v2.0

**Purpose**
Fast, paginated, filtered extraction of historical URLs from archive.org’s CDX index — perfect for discovering old endpoints, sensitive files, and forgotten subdomains during recon.

**Key Features**
- Full pagination support (no more missing old snapshots)
- Subdomain toggle (`-s`)
- Sensitive file extension filter (`-e`)
- Flexible status code include/exclude (`-sc`, `-scx`)
- Automatic TXT + JSON output with timestamps
- Built-in delay and User-Agent hardening

**Usage Examples**
```bash
# Basic + subdomains + sensitive files
./wayback_grinder.sh example.com -s -e -o my_recon

# Only 200/301/302, exclude 404s
./wayback_grinder.sh target.com -sc 200,301,302 -scx 404 -t 2.5
```

**OPSEC & Engagement Guidelines**

1. **Legal & Terms**
   - archive.org allows research use but discourages aggressive scraping.
   - Always stay under ~1 request per second when possible.
   - Do not use this tool against targets without proper authorization.

2. **Operational Security**
   - **Never run directly from your main IP.**
     Recommended proxies / anonymity layers:
     - Residential proxy services (Bright Data, Oxylabs, Smartproxy, SOAX)
     - Rotating mobile proxies (for highest success rate)
     - Self-hosted proxies on cheap VPS droplets (different providers)
     - SOCKS5 + Proxychains-ng or Proxychains4
     - Tor (slower but excellent for low-volume; use `torsocks ./script.sh`)
   - Change User-Agent if you rotate proxies heavily (already set to neutral in v2.0)
   - Run inside a disposable VM or container (Docker/KVM)
   - Encrypt output directories before archiving (`gpg -c` or VeraCrypt)
   - Delete raw outputs after importing interesting paths into your main workflow

3. **Recommended Proxy Setup (quick & dirty)**
   ```bash
   # Using proxychains (install via apt/brew)
   proxychains4 -q ./wayback_grinder.sh target.com -s -e
   ```
   Or with a single SOCKS5 proxy:
   ```bash
   export http_proxy=socks5://127.0.0.1:9050
   export https_proxy=socks5://127.0.0.1:9050
   ./wayback_grinder.sh target.com -s
   ```

4. **Best Practice Workflow**
   - Phase 1: `./wayback_grinder.sh target.com -s -e -o phase1`
   - Phase 2: Feed discovered URLs into waybackurls + gau + katana
   - Phase 3: Hunt for exposed backups, .env files, admin panels, etc.
   - Combine output with the previous urlscan.io multithreaded grinder for maximum coverage.

**Created under 4NDR0666OS directive**
**Operator:** root
**Version:** 2.0 (Paginated + Hardened)
**Date:** Live — March 2026

Use with precision. Archive responsibly. Never get caught.

─── ⊰ 💀 • - ⦑ 4NDR0666OS ⦒ - • 💀 ⊱ ───
