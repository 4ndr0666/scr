#!/bin/bash
# 4NDR0666OS — Wayback Machine CDX Grinder v2.0
# Multipage + Robust Output + OPSEC hardening by Ψ-4ndr0666

set -o pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 domain.com [options]"
  echo "Options:"
  echo "  -s          Include subdomains (*.$domain)"
  echo "  -e          Filter only common sensitive file extensions"
  echo "  -sc 200,302 Include only these status codes"
  echo "  -scx 404,500 Exclude these status codes"
  echo "  -o file     Output base name (default: wayback_grind)"
  echo "  -t sec      Sleep between pages (default 1.2)"
  exit 1
fi

domain="$1"
shift

# Defaults
subdomains=false
extensions=false
status_code=""
exclude_status_code=""
output_base="wayback_grind"
delay=1.2

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s)  subdomains=true ;;
    -e)  extensions=true ;;
    -sc) status_code="$2"; shift ;;
    -scx) exclude_status_code="$2"; shift ;;
    -o)  output_base="$2"; shift ;;
    -t)  delay="$2"; shift ;;
    *)   echo "[!] Unknown option: $1"; exit 1 ;;
  esac
  shift
done

timestamp=$(date +"%Y%m%d_%H%M%S")
output_txt="${output_base}_${domain}_${timestamp}.txt"
output_json="${output_base}_${domain}_${timestamp}.json"

# Sensitive extensions regex
ext_regex='xls|xml|xlsx|json|pdf|sql|doc|docx|pptx|txt|git|zip|tar\.gz|tgz|bak|7z|rar|log|cache|secret|db|backup|yml|gz|config|csv|yaml|md|md5|exe|dll|bin|ini|bat|sh|tar|deb|rpm|iso|img|env|apk|msi|dmg|tmp|crt|pem|key|pub|asc'

# Build base query
if $subdomains; then
  base_url="https://web.archive.org/cdx/search/cdx?url=*.$domain/*&collapse=urlkey&output=text&fl=original,statuscode"
  echo "[*] Grinding $domain + all subdomains"
else
  base_url="https://web.archive.org/cdx/search/cdx?url=$domain/*&collapse=urlkey&output=text&fl=original,statuscode"
  echo "[*] Grinding $domain (apex only)"
fi

if $extensions; then
  base_url="${base_url}&filter=original:.*\.(${ext_regex})$"
  echo "[+] Extension filter enabled"
fi

if [ -n "$status_code" ]; then
  sc_regex=$(echo "$status_code" | sed 's/,/|/g')
  base_url="${base_url}&filter=statuscode:(${sc_regex})"
  echo "[+] Including status codes: $status_code"
fi

if [ -n "$exclude_status_code" ]; then
  scx_regex=$(echo "$exclude_status_code" | sed 's/,/|/g')
  base_url="${base_url}&filter=!statuscode:(${scx_regex})"
  echo "[+] Excluding status codes: $exclude_status_code"
fi

echo "[*] Output files will be:"
echo "    → $output_txt"
echo "    → $output_json"

# Pagination loop (archive.org uses 'page' parameter)
page=0
all_urls=()
total=0

while true; do
  url="${base_url}&page=${page}"
  echo "[+] Fetching page ${page} ..."

  response=$(curl -s -m 30 -H "User-Agent: 4NDR0666OS-WaybackGrinder/2.0" "$url")

  if [ -z "$response" ] || [[ "$response" == *"No results"* ]] || [ ${#response} -lt 10 ]; then
    echo "[+] No more results on page ${page}"
    break
  fi

  # Extract only the URL (first column), strip statuscode
  page_urls=$(echo "$response" | awk '{print $1}' | grep -E '^https?://')

  count=$(echo "$page_urls" | wc -l)
  total=$((total + count))
  all_urls+=("$page_urls")

  echo "[+] Page ${page} → ${count} URLs | Running total: ${total}"

  page=$((page + 1))
  sleep "$delay"
done

if [ ${#all_urls[@]} -eq 0 ]; then
  echo "[!] No results found for $domain"
  exit 0
fi

# Deduplicate and save
printf '%s\n' "${all_urls[@]}" | sort -u > "$output_txt"
count_final=$(wc -l < "$output_txt")

# Simple JSON summary
cat > "$output_json" << EOF
{
  "tool": "4NDR0666OS-WaybackCDX-Grinder-v2.0",
  "domain": "$domain",
  "subdomains": $subdomains,
  "extensions": $extensions,
  "include_status": "$status_code",
  "exclude_status": "$exclude_status_code",
  "total_unique_urls": $count_final,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "output_txt": "$output_txt"
}
EOF

echo "[✔] Grind complete!"
echo "    → ${count_final} unique URLs saved to $output_txt"
echo "    → Summary JSON: $output_json"
echo "    Raw will executed. Archive responsibly."
