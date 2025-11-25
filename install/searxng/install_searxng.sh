#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ==================== // INSTALL_SEARXNG.SH //
# Description: Installer for docker instance of searxng
# and the caddy reverse proxy.
# =============================================
# Update 
echo "[+] Updating system packages..."
if command -v nala &>/dev/null; then
    sudo nala clean
    sudo nala autoremove -y
    sudo nala update
    sudo nala upgrade -y
else
    sudo apt-get clean
    sudo apt-get autoremove -y
    sudo apt-get update
    sudo apt-get upgrade -y
fi

# Install
echo "[+] Installing Docker, Docker Compose, wget, unzip..."
if command -v nala &>/dev/null; then
    sudo nala install -y docker.io docker-compose wget unzip
else
    sudo apt-get install -y docker.io docker-compose wget unzip
fi

# Group
echo "[+] Ensuring user 'kali' is in the docker group (idempotent)"
if ! groups kali | grep -q '\bdocker\b'; then
    sudo usermod -aG docker kali
    echo "[!] User 'kali' added to 'docker' group. You may need to log out and back in for changes to take effect."
fi

# Docker Service
echo "[+] Enabling and starting Docker service"
sudo systemctl enable docker
sudo systemctl start docker

# Dir
echo "[+] Creating working directory ~/searxng"
mkdir -p ~/searxng  && chown $USER:$USER ~/searxng
cd ~/searxng

echo "[+] Creating config and data directories (idempotent)"
mkdir -p searxng-settings searxng-data

# Searx Secret
echo "[+] Creating .env file for SearXNG (idempotent)"
if [ ! -f .env ]; then
    echo "SEARXNG_SECRET=$(openssl rand -hex 32)" > .env
fi

# Caddy
echo "[+] Creating Caddyfile for reverse proxy (idempotent)"
cat > Caddyfile <<'EOF'
192.168.1.91:80 {
  reverse_proxy searxng:8080
  encode zstd gzip
}
EOF

# Docker Compose File
echo "[+] Creating docker-compose.yml (idempotent)"
cat > docker-compose.yml <<'EOF'
services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: always
    env_file:
      - .env
    environment:
      - BASE_URL=http://192.168.1.91/
    ports:
      - "8888:8080"
    volumes:
      - ./searxng-settings:/etc/searxng
      - ./searxng-data:/etc/searxng/data

  caddy:
    image: caddy:2
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF

# Searxng Image
echo "[+] Pulling required docker images (optional, docker-compose will do this if missing)"
docker pull searxng/searxng:latest || true
docker pull caddy:2 || true

echo "[+] Bringing up SearXNG and Caddy containers"
docker compose up -d

# Autostart w SystemD
info "Creating systemd service file..."
sudo tee /etc/systemd/system/searxng.service > /dev/null <<EOF
[Unit]
Description=SearXNG Docker Compose Stack
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/kali/searxng
User=kali
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
EOF

# Systemd Enable
info "Reloading systemd daemon and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable searxng.service

echo "[+] SearXNG should now be available at: http://192.168.1.91:8888"
echo "[+] And proxied via Caddy at: http://192.168.1.91"
