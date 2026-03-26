# 4NDR0666OS — AlienVault OTX URL Grinder v3.0

**Purpose**  
Efficient, paginated extraction of all URLs associated with a hostname from AlienVault OTX threat intelligence database. Perfect for enriching recon with crowd-sourced malicious/interesting URLs.

**Key Features (v3.0)**
- Full pagination support (limit=500)
- Automatic deduplication
- SOCKS5/HTTP proxy support (Tor friendly)
- Dual TXT + structured JSON output with metadata
- Built-in delay and User-Agent hardening
- Clean progress feedback

**Example Usage**
```bash
# Basic
./otx_grinder.sh example.com

# With Tor + custom output
./otx_grinder.sh target.com -o engagement_otx -p socks5://127.0.0.1:9050 -t 2.0
```
d
**OPSEC & Engagement Guidelines**

1. **Legal / ToS**  
   AlienVault OTX is free for research but respects rate limits. Do not abuse the public API. Always operate within authorized scope.

2. **Proxy Recommendations (highly advised)**
   - **Primary:** Tor (`socks5://127.0.0.1:9050`)
   - **Rotating residential:** Bright Data, Oxylabs, Smartproxy
   - **Quick test:** `curl --proxy socks5://127.0.0.1:9050 https://httpbin.org/ip`
   - Run with proxychains for extra layers:
     ```bash
     proxychains4 -q ./otx_grinder.sh target.com
