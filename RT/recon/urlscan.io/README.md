# 4NDR0666OS — urlscan.io Multithreaded Scanner v3.0

**Purpose**
High-speed, full-pagination reconnaissance tool for extracting subdomains and indexed URLs from urlscan.io public scan database.

**Features**
- Full cursor-based pagination (gets everything, not just first page)
- Multithreaded scanning (configurable worker count)
- Automatic TXT + structured JSON output per domain
- Built-in rate-limit handling
- Clean, sanitized domain processing
- Zero hardcoded limits — designed for serious volume

**Usage Examples**
```bash
# Single domain, 12 threads
python urlscan_grinder.py -m subdomains -d example.com -t 12 -o my_recon

# Bulk from file
python urlscan_grinder.py -m urls -df domains.txt --threads 20 --delay 1.0
```

**OPSEC & Engagement Notes (Archival)**

1. **Legal / ToS**
   - This tool only queries publicly available data from urlscan.io.
   - Respect their rate limits (the built-in delay helps).
   - Do not use this tool against any target you do not have explicit authorization to reconnaissance.
   - urlscan.io may temporarily block aggressive API keys — rotate or add longer delays if needed.

2. **Operational Security**
   - Never commit your real API key to version control. Use environment variables or a separate `config.py` ignored by git.
   - Run from air-gapped or burner infrastructure when possible.
   - Consider proxy/VPN/Tor chaining for high-volume campaigns (though urlscan may flag heavy Tor exit nodes).
   - Output files contain sensitive subdomain/URL data — encrypt or securely delete after use.
   - Timestamped filenames prevent accidental overwrites during repeated engagements.

3. **Recommended Workflow**
   - Phase 1: `python grinder.py -m subdomains -df targets.txt -t 15`
   - Phase 2: Feed discovered subdomains into mass DNS brute-force / certificate transparency tools
   - Phase 3: Use discovered live URLs for further spidering / parameter fuzzing

4. **Customization Tips**
   - Increase `--delay` if you see 429 responses
   - Lower threads on shared infrastructure
   - Pipe output directories into encrypted archives for engagement handoff

**Created under 4NDR0666OS directive**
**Operator:** root
**Version:** 3.0 (Multithreaded God-Mode)
**Date:** Live — March 2026

Use with precision. Archive responsibly.

─── ⊰ 💀 • - ⦑ 4NDR0666OS ⦒ - • 💀 ⊱ ───
