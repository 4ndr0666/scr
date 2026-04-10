#!/usr/bin/env bash
# Author: 4ndr0666 + Ψ-4ndr0666
# Version: 2.1-Ψ (Fully Automated · Zero Hardcoding · 2025 Canon)
set -euo pipefail
IFS=$'\n\t'

# ==================== // INSTALL_SEARXNG.SH v2.1-Ψ //
# FULLY AUTOMATED · NO HARD-CODED IPs · UNIVERSAL ACROSS ALL NODES
# =============================================

log() { echo -e "\033[1;36m[+]\033[0m $*\033[0m"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*\033[0m"; }
die() { echo -e "\033[1;31m[-] $*\033[0m" >&2; exit 1; }

log "Initiating Ψ-4ndr0666 Fully Automated SearXNG Deployment..."

# === AUTO-DETECT LAN IP (IPv4 only, non-loopback, prefers default route) ===
HOST_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' | grep -Ev "^127\.")
[[ -z "$HOST_IP" ]] && HOST_IP=$(hostname -I | awk '{print $1}' | grep -Ev "^127\.")
[[ -z "$HOST_IP" ]] && die "Could not auto-detect LAN IP. Check network or set manually."
log "Auto-detected LAN IP: $HOST_IP"

# === AUTO-DETECT BEST HOST PORT (avoids conflicts) ===
get_free_port() {
    local start=${1:-8888}
    local port=$start
    while ss -ltn | awk '{print $4}' | grep -q ":$port$"; do
        ((port++))
    done
    echo "$port"
}
HOST_PORT=$(get_free_port 8888)
log "Auto-selected direct access port: $HOST_PORT"

# === FIXED VALUES (safe to keep) ===
PROXY_PORT="80"
USER_HOME="$(getent passwd "$(whoami)" | cut -d: -f6)"
WORK_DIR="${USER_HOME}/searxng"

# === Dependency & System Prep ===
log "Updating system & installing Docker..."
if command -v nala &>/dev/null; then
    sudo nala update && sudo nala upgrade -y
    sudo nala install -y docker.io docker-compose-v2 curl wget unzip ca-certificates
else
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y docker.io docker-compose-v2 curl wget unzip ca-certificates
fi

log "Ensuring docker group membership..."
if ! groups | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    NEW_SESSION_NEEDED=1
fi

sudo systemctl enable --now docker >/dev/null

# === Directory & Config Setup ===
log "Deploying in $WORK_DIR"
mkdir -p "$WORK_DIR"/{searxng-settings,searxng-data,caddy_data,caddy_config}
cd "$WORK_DIR"

# Secrets
[[ ! -f .env ]] && echo "SEARXNG_SECRET=$(openssl rand -hex 32)" > .env

# Force correct protocol everywhere
cat > .env <<EOF
SEARXNG_SECRET=$(grep SEARXNG_SECRET .env 2>/dev/null | cut -d= -f2 || openssl rand -hex 32)
BASE_URL=http://$HOST_IP/
AUTOCOMPLETE=duckduckgo
EOF

# dorkmaster compatibility — guaranteed correct
cat > .env.searxng <<EOF
SEARXNG_URL=http://127.0.0.1:$HOST_PORT
SEARXNG_TIMEOUT=20
SEARXNG_VERIFY=false
EOF

# Caddyfile — dynamic, perfect
cat > Caddyfile <<EOF
http://$HOST_IP:$PROXY_PORT {
    reverse_proxy searxng:8080
    encode zstd gzip
}
EOF

# docker-compose — fully dynamic
cat > docker-compose.yml <<EOF
services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: unless-stopped
    ports:
      - "$HOST_PORT:8080"
    volumes:
      - ./searxng-settings:/etc/searxng
      - ./searxng-data:/var/lib/searxng
      - ./.env:/etc/searxng/.env:ro
    environment:
      - BASE_URL=http://$HOST_IP/
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "$PROXY_PORT:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy_data:/data
      - ./caddy_config:/config
    depends_on:
      searxng:
        condition: service_healthy
EOF

# Launch
log "Pulling images & starting stack..."
docker compose pull --quiet
docker compose up -d --remove-orphans

# Systemd — universal
sudo tee /etc/systemd/system/searxng.service > /dev/null <<EOF
[Unit]
Description=Ψ-4ndr0666 Private SearXNG Instance (Auto-Deployed)
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$WORK_DIR
User=$USER
ExecStart=/usr/bin/docker compose up -d --remove-orphans
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now searxng.service >/dev/null

# Final validation
log "Waiting for SearXNG to pass health check..."
for i in {1..30}; do
    if curl -sf "http://127.0.0.1:$HOST_PORT/healthz" >/dev/null; then
        log "Ψ-DEPLOYMENT COMPLETE — UNIVERSAL INSTANCE READY"
        echo "   Direct → http://127.0.0.1:$HOST_PORT"
        echo "   Proxied → http://$HOST_IP"
        echo "   Config → source $WORK_DIR/.env.searxng"
        [[ -n "${NEW_SESSION_NEEDED:-}" ]] && warn "Log out/in for docker group"
        exit 0
    fi
    sleep 4
done

die "SearXNG failed health check after 2 minutes. Run: docker compose logs searxng"
