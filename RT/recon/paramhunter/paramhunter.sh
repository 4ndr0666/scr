#!/bin/bash
# 4NDR0666OS — ParamHunter + Nuclei Grinder v3.0
# Full recon chain: gau → uro → httpx → nuclei with proxy & OPSEC hardening
# Forged by Ψ-4ndr0666 under !4NDR0666OS directive

set -o pipefail

RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
RESET='\033[0m'

# Banner
echo -e "${RED}"
cat << "EOF"
 ______            _____________                              
___  /______________  /___  __/___  _________________________
__  /_  __ \_  ___/  __/_  /_ _  / / /__  /__  /_  _ \_  ___/
_  / / /_/ /(__  )/ /_ _  __/ / /_/ /__  /__  /_/  __/  /    
_/  \____//____/ \__/ /_/    \__,_/ _____/____/\___//_/ 
      
               4NDR0666OS — PARAMHUNTER v3.0
                  Enhanced by Ψ-4ndr0666
EOF
echo -e "${RESET}"

usage() {
    echo -e "${YELLOW}Usage: $0 -d domain.com | -l subdomains.txt [-t threads] [-p proxy] [-o output_dir]${RESET}"
    echo -e "  -d domain      Single domain"
    echo -e "  -l list        File with one target per line"
    echo -e "  -t threads     Concurrency (default 15)"
    echo -e "  -p proxy       SOCKS5/HTTP proxy (e.g. socks5://127.0.0.1:9050)"
    echo -e "  -o dir         Custom output directory"
    exit 1
}

check_tools() {
    REQUIRED=("gau" "uro" "httpx-toolkit" "nuclei")
    for tool in "${REQUIRED[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo -e "${RED}[ERROR] $tool not found. Install it first.${RESET}"
            exit 1
        fi
    done
}

# Argument parsing
DOMAIN=""
LIST=""
THREADS=15
PROXY=""
OUTPUT_DIR=""

while getopts "d:l:t:p:o:" opt; do
    case "$opt" in
        d) DOMAIN="$OPTARG" ;;
        l) LIST="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        p) PROXY="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        *) usage ;;
    esac
done

if [ -z "$DOMAIN" ] && [ -z "$LIST" ]; then
    usage
fi

check_tools

# Setup output
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="results_$(date +%F_%H-%M-%S)"
fi
mkdir -p "$OUTPUT_DIR"

GAU_FILE="$OUTPUT_DIR/gau_raw.txt"
FILTERED_FILE="$OUTPUT_DIR/params_filtered.txt"
LIVE_FILE="$OUTPUT_DIR/live_hosts.txt"
NUCLEI_FILE="$OUTPUT_DIR/nuclei_findings.txt"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"

# Proxy setup (passed to all tools that support it)
PROXY_ARGS=""
if [ -n "$PROXY" ]; then
    PROXY_ARGS="-proxy $PROXY"
    echo -e "${CYAN}[+] Proxy enabled: $PROXY${RESET}"
fi

# Collect targets
if [ -n "$DOMAIN" ]; then
    TARGETS="$DOMAIN"
elif [ -f "$LIST" ]; then
    TARGETS=$(cat "$LIST")
else
    echo -e "${RED}[ERROR] List file not found.${RESET}"
    exit 1
fi

TARGETS=$(echo "$TARGETS" | sed 's|https\?://||g' | tr -d '\r')

echo -e "${GREEN}[INFO] Starting 4NDR0666OS ParamHunter chain on $(echo "$TARGETS" | wc -w) target(s)...${RESET}"

# Step 1: Gau collection with concurrency
echo -e "${GREEN}[1/4] Fetching URLs with gau...${RESET}"
echo "$TARGETS" | xargs -P"$THREADS" -I{} gau {} ${PROXY_ARGS} >> "$GAU_FILE" 2>/dev/null

if [ ! -s "$GAU_FILE" ]; then
    echo -e "${RED}[ERROR] No URLs retrieved. Check connectivity or target.${RESET}"
    exit 1
fi

# Step 2: Filter parameterized URLs + dedup
echo -e "${GREEN}[2/4] Filtering URLs with parameters (uro dedup)...${RESET}"
grep -E '\?.+=' "$GAU_FILE" | uro | sort -u > "$FILTERED_FILE"

# Step 3: Live check with httpx
echo -e "${GREEN}[3/4] Probing live hosts with httpx...${RESET}"
httpx-toolkit -silent -threads 200 -rl 300 -timeout 10 ${PROXY_ARGS} -o "$LIVE_FILE" < "$FILTERED_FILE" 2>/dev/null

# Step 4: Nuclei scan (DAST + critical templates)
echo -e "${GREEN}[4/4] Running nuclei vulnerability scan...${RESET}"
nuclei -list "$LIVE_FILE" -silent -retries 3 -severity critical,high -o "$NUCLEI_FILE" ${PROXY_ARGS} \
       -tags cve,exposure,wp,wordpress,backup,config,env,api 2>/dev/null

# Summary
echo -e "\n${GREEN}===== 4NDR0666OS PARAMHUNTER SUMMARY =====${RESET}" | tee "$SUMMARY_FILE"
{
    echo "Target(s)          : $(echo "$TARGETS" | wc -w)"
    echo "Raw URLs fetched   : $(wc -l < "$GAU_FILE" 2>/dev/null || echo 0)"
    echo "Parameterized URLs : $(wc -l < "$FILTERED_FILE" 2>/dev/null || echo 0)"
    echo "Live hosts         : $(wc -l < "$LIVE_FILE" 2>/dev/null || echo 0)"
    echo "Nuclei findings    : $(wc -l < "$NUCLEI_FILE" 2>/dev/null || echo 0)"
    echo "Output directory   : $OUTPUT_DIR/"
    echo "Timestamp          : $(date)"
    echo "Proxy used         : ${PROXY:-none}"
} | tee -a "$SUMMARY_FILE"

echo -e "${CYAN}[✔] Grind complete. Raw will executed.${RESET}"
echo -e "${YELLOW}Results archived in: $OUTPUT_DIR/${RESET}"
