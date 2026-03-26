# CORS DeathStar v5.0 — Engagement OPSEC Guide
**4NDR0666OS Weaponized CORS PoC**

**Purpose**
Single-file HTML/JS tool for demonstrating and exploiting misconfigured CORS policies (Access-Control-Allow-Origin: *, reflected origin, null origin, etc.) with full method/header/body control.

**Quick Start**
1. Save as `cors-deathstar.html`
2. Open locally in browser or host on attacker-controlled domain
3. Enter target endpoint known to have weak CORS
4. Fire and exfiltrate sensitive data (JSON, cookies with credentials, etc.)

**Engagement OPSEC (Critical)**

1. **Never open directly from file:// when testing real targets**
   - Use a controlled origin (your VPS, ngrok, custom domain) so the browser sends proper Origin header.

2. **Proxy / Anonymity Layer**
   - Run browser through Burp Suite, mitmproxy, or FoxyProxy with residential/Tor chain.
   - Recommended: Whonix + Tor Browser for high-risk engagements.
   - Never use your personal or corporate IP.

3. **Scope & Authorization**
   - ONLY use against targets with explicit written permission.
   - Unauthorized CORS testing can still be considered unauthorized access under CFAA / similar laws.

4. **Evidence Handling**
   - All output is client-side only. Screenshot or export JSON immediately.
   - Encrypt exported data (`gpg -c` or VeraCrypt container).
   - Delete the HTML file and any local copies after engagement hand-off.

5. **Detection Avoidance**
   - Add random delays between tests.
   - Rotate User-Agents if chaining multiple requests manually.
   - Combine with previous recon tools (urlscan/wayback/otx) to discover vulnerable endpoints quietly.

6. **Post-Engagement**
   - Shred or securely delete the HTML file.
   - Clear browser history/cookies/cache.
   - Archive findings only in encrypted engagement folder.

**Created under 4NDR0666OS directive**
**Version:** 5.0
**Date:** Live — March 2026

Precision. Stealth. No limits.

─── ⊰ 💀 • - ⦑ 4NDR0666OS ⦒ - • 💀 ⊱ ───
