#!/bin/bash
# 4NDR0666OS — AlienVault OTX URL Grinder v3.0
# Full pagination + dedup + proxy + JSON export by Ψ-4ndr0666

set -o pipefail

if ! command -v jq &>/dev/null; then
  echo "[ERROR] jq is required but not installed. Install with: apt install jq / brew install jq"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: $0 <domain> [-o output_base] [-p proxy] [-t delay]"
  echo "Example: $0 example.com -o otx_grind -p socks5://127.0.0.1:9050 -t 1.5"
  exit 1
fi

domain="$1"
shift

# Defaults
output_base="otx_urls"
delay=1.2
proxy=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output_base="$2"; shift ;;
    -p) proxy="$2"; shift ;;
    -t) delay="$2"; shift ;;
    *) echo "[!] Unknown option: $1"; exit 1 ;;
  esac
  shift
done

timestamp=$(date +"%Y%m%d_%H%M%S")
txt_file="${output_base}_${domain}_${timestamp}.txt"
json_file="${output_base}_${domain}_${timestamp}.json"

# Proxy setup for curl
CURL_PROXY=""
if [ -n "$proxy" ]; then
  CURL_PROXY="--proxy $proxy"
  echo "[+] Proxy enabled: $proxy"
fi

page=1
limit=500
all_urls=()
total=0

echo "[*] 4NDR0666OS OTX Grinder v3.0 launching against → $domain"
echo "[*] Output files will be:"
echo "    → $txt_file"
echo "    → $json_file"

while true; do
  echo "[+] Fetching page $page..."

  response=$(curl -s $CURL_PROXY \
    -H "User-Agent: 4NDR0666OS-OTXGrinder/3.0" \
    "https://otx.alienvault.com/api/v1/indicators/hostname/${domain}/url_list?limit=${limit}&page=${page}")

  # Check for errors or empty response
  if [[ -z "$response" || "$response" == *"error"* || "$response" == *"not found"* ]]; then
    echo "[!] Empty or error response on page $page. Stopping."
    break
  fi

  # Extract URLs safely
  page_urls=$(echo "$response" | jq -r '.url_list[]?.url // empty' 2>/dev/null)

  if [[ -z "$page_urls" ]]; then
    echo "[+] No more URLs on page $page. Finishing."
    break
  fi

  count=$(echo "$page_urls" | wc -l)
  total=$((total + count))
  all_urls+=("$page_urls")

  echo "[+] Page $page → $count URL(s) | Running total: $total"

  # Check if last page
  if (( count < limit )); then
    echo "[+] Reached final page."
    break
  fi

  page=$((page + 1))
  sleep "$delay"
done

if [ ${#all_urls[@]} -eq 0 ]; then
  echo "[!] No URLs found for $domain"
  exit 0
fi

# Deduplicate and save TXT
printf '%s\n' "${all_urls[@]}" | sort -u > "$txt_file"
final_count=$(wc -l < "$txt_file")

# Save structured JSON summary
cat > "$json_file" << EOF
{
  "tool": "4NDR0666OS_OTX_URL_Grinder_v3.0",
  "domain": "$domain",
  "total_unique_urls": $final_count,
  "pages_fetched": $page,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "proxy_used": "${proxy:-none}",
  "results_file": "$txt_file"
}
EOF

echo "[✔] OTX grind complete!"
echo "    → $final_count unique URLs saved to $txt_file"
echo "    → Summary JSON: $json_file"
echo "[RAW WILL EXECUTED] 4NDR0666OS — No limits. No mercy."
