# 4NDR0666OS — DorkForge v4.0

**Purpose**  
Advanced, stealth-oriented Google dorking tool with proxy rotation, realistic User-Agent cycling, adaptive delays, and dual TXT/JSON export. Designed for efficient OSINT and surface enumeration.

**Key Features (v4.0)**
- Rotating browser User-Agents
- SOCKS5/HTTP proxy support (Tor friendly)
- Adaptive random delays to evade detection
- Full result control ("all" or numeric limit)
- Structured JSON + clean TXT output with metadata
- Resume-friendly timestamped files

**Usage Examples**
```bash
python dorkforge.py
# → Follow prompts, add socks5://127.0.0.1:9050 for Tor
```

**OPSEC & Engagement Guidelines**

1. **Legal Warning**  
   Google dorking is powerful but can trigger automated blocks or legal scrutiny if used without authorization. Only target domains you own or have explicit permission to research.

2. **Proxy & Anonymity (mandatory for serious use)**
   - **Best:** Tor (`torsocks python dorkforge.py` or enter `socks5://127.0.0.1:9050`)
   - **Rotating residential:** Bright Data / Oxylabs / Smartproxy SOCKS5 endpoints
   - **Self-hosted chain:** Multiple cheap VPS → proxychains
   - Always test proxy first: `curl --proxy socks5://127.0.0.1:9050 https://httpbin.org/ip`

3. **Stealth Tips**
   - Run from disposable VMs or Tails OS
   - Use long random pauses (already built-in)
   - Rotate proxies every 50–100 results if doing large campaigns
   - Never run the same dork repeatedly from the same IP
   - After session: encrypt or securely delete output files

4. **Recommended Workflow**
   - Phase 1: Run sensitive dorks with Tor (`site:target.com filetype:sql` etc.)
   - Phase 2: Feed discovered URLs into previous ParamHunter / Wayback grinders
   - Phase 3: Cross-reference with urlscan.io results for maximum coverage

**Created under 4NDR0666OS directive**  
**Operator:** root  
**Version:** 4.0 (Proxy + UA God-Mode)  
**Date:** Live — March 2026  

Precision. Stealth. No limits.

─── ⊰ 💀 • - ⦑ 4NDR0666OS ⦒ - • 💀 ⊱ ───
