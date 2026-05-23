#!/bin/bash

set -euo pipefail

VPNCTL=/bin/expressvpnctl
IPCHECK="https://api.ipify.org"

VPN_SERVERS=(
  "smart"
  "dominican-republic"
  "jamaica"
  "puerto-rico"
  "bermuda"
  "trinidad-and-tobago"
  "cuba"
  "usa-little-rock"
  "usa-new-orleans"
  "usa-jackson"
  "usa-oklahoma-city"
  "usa-wichita"
  "usa-houston"
  "usa-miami"
  "usa-lincoln-park"
  "usa-honolulu"
  "usa-chicago"
  "usa-las-vegas"
  "usa-tampa-1"
  "usa-phoenix"
  "usa-los-angeles-2"
  "usa-los-angeles-3"
  "usa-miami-2"
  "usa-los-angeles-1"
  "usa-denver"
  "usa-albuquerque"
  "usa-louisville"
  "usa-baltimore"
  "usa-charlotte"
  "usa-virginia-beach"
  "usa-charleston-west-virginia"
  "usa-new-york"
  "usa-washington-dc"
  "usa-bridgeport"
  "usa-indianapolis"
  "usa-portland-maine"
  "usa-detroit"
  "usa-minneapolis"
  "usa-st.-louis"
  "usa-omaha"
  "usa-fargo"
  "usa-columbus"
  "usa-philadelphia"
  "usa-sioux-falls"
  "usa-burlington"
  "usa-milwaukee"
  "usa-new-jersey-2"
  "usa-wilmington"
  "usa-des-moines"
  "usa-manchester"
  "usa-providence"
  "usa-san-francisco"
  "usa-new-jersey-3"
  "usa-brooklyn"
  "usa-salt-lake-city"
  "usa-new-jersey-1"
  "usa-dallas"
  "usa-boston"
  "usa-seattle"
  "usa-atlanta"
  "usa-boise"
  "usa-cheyenne"
  "usa-billings"
  "usa-portland-oregon"
  "usa-anchorage"
  "usa-birmingham"
  "usa-charleston-south-carolina"
  "usa-nashville"
  "usa-santa-monica"
  "usa-los-angeles-5"
  "cayman-islands"
  "honduras"
  "costa-rica"
  "bahamas"
  "canada-toronto"
  "canada-montreal"
  "canada-toronto-2"
  "canada-vancouver"
  "mexico"
  "greenland"
  "colombia"
  "uk-east-london"
  "uk-tottenham"
  "uk-midlands"
  "uk-london"
  "uk-docklands"
  "uk-manchester"
  "uk-wembley"
  "netherlands-the-hague"
  "netherlands-rotterdam"
  "netherlands-amsterdam"
  "india-(via-uk)"
  "india-(via-singapore)"
  "germany-nuremberg"
  "gaming-europe"
  "germany-frankfurt-1"
  "germany-frankfurt-3"
  "germany-berlin"
  "ghana"
  "morocco"
  "france-paris-2"
  "france-marseille"
  "france-strasbourg"
  "france-paris-1"
  "france-alsace"
  "egypt"
  "liechtenstein"
  "cyprus"
  "algeria"
  "kenya"
  "lebanon"
  "belgium"
  "turkey"
  "andorra"
  "italy-naples"
  "italy-milan"
  "italy-cosenza"
  "armenia"
  "uzbekistan"
  "malta"
  "belarus"
  "jersey"
  "monaco"
  "montenegro"
  "bosnia-and-herzegovina"
  "north-macedonia"
  "luxembourg"
  "slovenia"
  "denmark"
  "spain-madrid"
  "spain-valencia"
  "spain-barcelona"
  "spain-barcelona-2"
  "czech-republic"
  "switzerland"
  "switzerland-2"
  "isle-of-man"
  "austria"
  "ireland"
  "japan-osaka"
  "japan-tokyo"
  "japan-shibuya"
  "japan-yokohama"
  "finland"
  "sweden-2"
  "sweden"
  "hungary"
  "chile"
  "portugal"
  "lithuania"
  "albania"
  "norway"
  "croatia"
  "ukraine"
  "peru"
  "ecuador"
  "panama"
  "bolivia"
  "uruguay"
  "guatemala"
  "venezuela"
  "brazil"
  "brazil-2"
  "poland"
  "serbia"
  "new-zealand"
  "latvia"
  "bulgaria"
  "estonia"
  "romania"
  "greece"
  "moldova"
  "australia-sydney"
  "australia-melbourne"
  "australia-brisbane"
  "australia-sydney-2"
  "australia-adelaide"
  "australia-woolloomooloo"
  "australia-perth"
  "south-korea-2"
  "slovakia"
  "hong-kong-1"
  "hong-kong-2"
  "georgia"
  "taiwan-3"
  "israel"
  "azerbaijan"
  "singapore-cbd"
  "singapore-jurong"
  "singapore-marina-bay"
  "philippines"
  "guam"
  "vietnam"
  "kazakhstan"
  "macau"
  "indonesia"
  "bangladesh"
  "thailand"
  "iceland"
  "mongolia"
  "cambodia"
  "bhutan"
  "pakistan"
  "nepal"
  "brunei"
  "laos"
  "sri-lanka"
  "malaysia"
  "myanmar"
  "united-arab-emirates"
  "south-africa"
  "argentina"
)

# Query exit IP through the tunnel. Requires Split Tunnel OFF so this
# process's traffic routes through tun0 like all other non-split traffic.
exit_ip() {
  curl -s --max-time 10 "$IPCHECK" 2>/dev/null || echo ""
}

# --- Step 1: Disable Split Tunnel so curl routes through the VPN tunnel ---
sudo "$VPNCTL" set splittunnel false 2>/dev/null || true
sleep 1

# --- Step 2: Snapshot pre-cycle exit IP ---
OLD_IP=$(exit_ip)
if ! [[ "$OLD_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  # Restore split tunnel before aborting
  sudo "$VPNCTL" set splittunnel true 2>/dev/null || true
  exit 1
fi

# --- Step 3: Drop Network Lock and confirm ---
sudo "$VPNCTL" set networklock false 2>/dev/null || true
sleep 2
LOCK_ELAPSED=0
while [ $LOCK_ELAPSED -lt 10 ]; do
  LOCK_STATE=$(sudo "$VPNCTL" get networklock 2>/dev/null || echo "unknown")
  { [ "$LOCK_STATE" = "false" ] || [ "$LOCK_STATE" = "disabled" ]; } && break
  sleep 1
  LOCK_ELAPSED=$((LOCK_ELAPSED + 1))
done

# --- Step 4: Select a target server different from current region ---
OLD_REGION=$(sudo "$VPNCTL" get region 2>/dev/null || echo "")
SERVER=""
for _ in $(seq 1 20); do
  CANDIDATE="${VPN_SERVERS[$RANDOM % ${#VPN_SERVERS[@]}]}"
  if [ "$CANDIDATE" != "$OLD_REGION" ]; then
    SERVER="$CANDIDATE"
    break
  fi
done
[ -z "$SERVER" ] && SERVER="usa-new-york"

# --- Step 5: Set region, disconnect, wait for Disconnected ---
sudo "$VPNCTL" set region "$SERVER"
sudo "$VPNCTL" disconnect 2>/dev/null || true
ELAPSED=0
while [ $ELAPSED -lt 20 ]; do
  STATE=$(sudo "$VPNCTL" get connectionstate 2>/dev/null || echo "Unknown")
  [ "$STATE" = "Disconnected" ] && break
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done

# --- Step 6: Connect ---
sudo "$VPNCTL" connect

# --- Step 7: Restore Network Lock ---
sudo "$VPNCTL" set networklock true 2>/dev/null || true

# --- Step 8: Poll exit IP until it differs from OLD_IP ---
# Split Tunnel is still off so curl routes through the tunnel.
# Network Lock is back on but allows tunnel-routed traffic.
ELAPSED=0
NEW_IP=""
while [ $ELAPSED -lt 60 ]; do
  CANDIDATE=$(exit_ip)
  if [[ "$CANDIDATE" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$CANDIDATE" != "$OLD_IP" ]; then
    NEW_IP="$CANDIDATE"
    break
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

# --- Step 9: Restore Split Tunnel unconditionally ---
sudo "$VPNCTL" set splittunnel true 2>/dev/null || true

# --- Step 10: Honest exit code ---
if [ -n "$NEW_IP" ]; then
  exit 0
else
  exit 1
fi
