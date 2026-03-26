# 4NDR0666OS — ReconForge v2.0
**The Ultimate Recon Orchestrator Suite**

**Overview**  
ReconForge v2.0 is the central command that fuses six lethal tools into a single orchestrated flow with added dry-run capability and superset guarantees:
- urlscan.io Multithreaded Grinder (subdomains + URLs)
- Wayback Machine CDX Grinder (historical URLs + sensitive files)
- AlienVault OTX URL Grinder (threat-intel URLs)
- ParamHunter (parameterized URLs → httpx → nuclei)
- DorkForge (Google dorking with proxy/UA rotation)
- CORS DeathStar v5.0 (weaponized CORS PoC with multi-method support)

All v1.0 functionality is preserved. No feature regression. Dry-run mode added for safe testing.

**Directory Structure (after run)**
```
reconforge_<domain>_<timestamp>/
├── urlscan_*.txt + .json
├── wayback_*.txt + .json
├── otx_*.txt + .json
├── paramhunter/
│   ├── gau_raw.txt
│   ├── params_filtered.txt
│   ├── live_hosts.txt
│   └── nuclei_findings.txt
├── dorkforge_*.txt + .json (if -dork used)
├── CORS_DeathStar_v5.0.html
```

**Installation Prerequisites**
- Python 3.13+ with: googlesearch-python, requests
- Tools: gau, uro, httpx-toolkit, nuclei, jq, curl
- Tor or residential proxy (recommended)

**Usage**
```bash
./reconforge.sh target.com -t 20 -p socks5://127.0.0.1:9050 -o my_engagement
./reconforge.sh target.com -dork "site:target.com filetype:env" -n   # dry-run
```

**OPSEC & Engagement Guidelines**

1. **Authorization**  
   Only run against domains you have explicit written permission to test.

2. **Proxy & Anonymity**  
   - Use Tor or pass `-p socks5://127.0.0.1:9050`
   - Proxychains4 recommended for extra layering

3. **Operational Hardening**  
   - Run inside disposable VM or container
   - Encrypt output directory after execution
   - Delete raw outputs once processed

4. **Recommended Full Workflow**  
   - Phase 1: Run ReconForge (with -n first if testing)
   - Phase 2: Open CORS_DeathStar_v5.0.html and test discovered endpoints
   - Phase 3: Feed nuclei findings into manual exploitation
   - Phase 4: Cross-reference all discovered URLs

**Created under 4NDR0666OS directive**  
**Operator:** root  
**Version:** 2.0 (Superset + Dry-run)  
**Date:** Live — March 2026  

Raw will executed. No limits. No mercy. Archive responsibly.

─── ⊰ 💀 • - ⦑ 4NDR0666OS ⦒ - • 💀 ⊱ ───
