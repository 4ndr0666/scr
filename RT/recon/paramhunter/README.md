# 4NDR0666OS — ParamHunter + Nuclei Grinder v3.0

**Purpose**  
Automated parameterized URL discovery → live checking → high-severity vulnerability scanning using gau, uro, httpx-toolkit and nuclei. Designed for efficient recon-to-exploit chains.

**Key Features (v3.0)**
- Full concurrency control
- SOCKS5/HTTP proxy support across all tools
- Clean deduplication with uro
- Timestamped output directory
- Summary report with counts
- OPSEC-hardened (proxy, silent flags, retries)

**Usage examples:**
```bash
# Single domain + proxy
./paramhunter.sh -d target.com -t 20 -p socks5://127.0.0.1:9050

# Bulk list
./paramhunter.sh -l subdomains.txt -t 30 -o engagement_2026
```

**OPSEC & Engagement Guidelines**

1. **Authorization**  
   Only run against targets you have explicit written permission to test. Unauthorized scanning can violate laws (CFAA, etc.).

2. **Proxy Recommendations (critical for OPSEC)**
   - **Primary:** Residential rotating proxies (Bright Data, Oxylabs, Smartproxy)
   - **Stealth:** SOCKS5 via Tor (`torsocks` or `proxychains4`)
   - **Self-hosted:** Cheap VPS chain (different providers) + `proxychains`
   - Example command with proxychains:
     ```bash
     proxychains4 -q ./paramhunter.sh -d target.com -t 15
     ```
   - Always test proxy connectivity first with `curl --proxy socks5://127.0.0.1:9050 https://httpbin.org/ip`

3. **Operational Hardening**
   - Run inside disposable VMs or Docker containers
   - Never store API keys or sensitive findings on persistent storage without encryption
   - Use separate API keys for nuclei templates if needed
   - Monitor for WAF blocks and lower threads/delay if detected
   - After engagement: `shred -u -z` sensitive files or move to encrypted volume

4. **Recommended Workflow**
   - Phase 1: `./paramhunter.sh -l targets.txt -t 25 -p socks5://127.0.0.1:1080`
   - Phase 2: Manually review nuclei findings + live_urls.txt
   - Phase 3: Chain interesting params into manual testing or custom scripts
   - Combine with previous Wayback + urlscan grinders for maximum surface coverage

**Created under 4NDR0666OS directive**  
**Operator:** root  
**Version:** 3.0 (Proxy-ready God-Mode)  
**Date:** Live — March 2026  

Precision. Stealth. No limits.

─── ⊰ 💀 • - ⦑ 4NDR0666OS ⦒ - • 💀 ⊱ ───
