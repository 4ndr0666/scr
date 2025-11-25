#!/usr/bin/env bash
# SearXNG Enterprise-Polished Installer/Uninstaller & systemd stack
set -euo pipefail

USERNAME="${SUDO_USER:-$USER}"
INSTALL_DIR="/opt/searxng"
SERVICE_NAME="searxng.service"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/arm64}"

FQDN=""
HTTP_PORT="80"
CLEAN=0
INSTALL_LOG="/var/log/searxng_install.log"

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean) CLEAN=1 ;;
        --fqdn) shift; FQDN="$1" ;;
        --http-port) shift; HTTP_PORT="$1" ;;
        *) ;;
    esac
    shift
done

function info { echo "[+] $*"; echo "[+] $*" >> "$INSTALL_LOG"; }
function error_exit { echo "[!] $*" >&2; echo "[!] $*" >> "$INSTALL_LOG"; exit 1; }

if [[ ! -f "$INSTALL_LOG" ]]; then sudo touch "$INSTALL_LOG" && sudo chown "$USERNAME" "$INSTALL_LOG"; fi

if [[ -z "$FQDN" ]]; then
    FQDN=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$FQDN" ]] && FQDN=$(ip -4 addr show scope global | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
    [[ -z "$FQDN" ]] && FQDN="localhost"
fi

backup() {
    local path="$1"
    if [[ -d "$path" || -f "$path" ]]; then
        local ts
        ts="$(date '+%Y%m%d-%H%M%S')"
        local archive="${path}_backup_${ts}.tar.gz"
        info "Backing up $path to $archive..."
        tar czf "$archive" "$path"
        info "Backup complete: $archive"
    fi
}

port_in_use() {
    local port="$1"
    ss -ltn | awk '{print $4}' | grep -q ":$port\$"
}

# 1. Clean previous installation with explicit backup and user warning
if [[ "$CLEAN" == "1" ]]; then
  info "You are about to REMOVE ALL previous SearXNG containers, images, configs, and data at ${INSTALL_DIR}."
  read -rp "Are you SURE? This is DESTRUCTIVE and will backup then delete all persistent data. Type 'yes' to proceed: " CONFIRM
  [[ "$CONFIRM" != "yes" ]] && error_exit "User aborted."
  backup "${INSTALL_DIR}/searxng-settings"
  backup "${INSTALL_DIR}/searxng-data"
  docker compose -f "${INSTALL_DIR}/docker-compose.yml" down --volumes --remove-orphans || true
  docker stop searxng caddy 2>/dev/null || true
  docker rm searxng caddy 2>/dev/null || true
  docker rmi searxng/searxng:latest caddy:2 2>/dev/null || true
  docker volume rm ${SERVICE_NAME}_caddy_data ${SERVICE_NAME}_caddy_config 2>/dev/null || true
  rm -rf "${INSTALL_DIR}"
  docker system prune -af --volumes
  info "Clean‑uninstall complete. All old SearXNG and Caddy remnants have been purged."
fi

# 2. Detect port conflicts and abort if in use
for PORT in "$HTTP_PORT" 443 8888; do
    if port_in_use "$PORT"; then
        error_exit "Port $PORT is already in use. Please free the port or choose a different one with --http-port."
    fi
done

# 3. Ensure installation directory
info "Creating installation directory ${INSTALL_DIR}..."
sudo mkdir -p "${INSTALL_DIR}"
sudo chown "${USERNAME}:${USERNAME}" "${INSTALL_DIR}"

cd "${INSTALL_DIR}"

# 4. System update and package install
info "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

info "Installing Docker, Docker Compose, wget, unzip..."
sudo apt-get install -y docker.io docker-compose wget unzip

# 5. Add user to docker group
info "Ensuring user '${USERNAME}' is in docker group..."
if ! groups "${USERNAME}" | grep -q '\bdocker\b'; then
  sudo usermod -aG docker "${USERNAME}"
  info "User '${USERNAME}' added to docker group. A logout/login may be required."
fi

# 6. Enable and start Docker service
info "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# 7. Create config/data directories per official docs
info "Setting up config and data directories per SearXNG documentation..."
mkdir -p searxng-settings searxng-data

# 8. Create .env file
info "Creating .env..."
if [ ! -f .env ]; then
  echo "SEARXNG_SECRET=$(openssl rand -hex 32)" > .env
fi

# 9. Create Caddyfile (dynamic IP/FQDN and port)
info "Creating Caddyfile for host ${FQDN}:${HTTP_PORT}..."
cat > Caddyfile <<EOF
${FQDN}:${HTTP_PORT} {
  reverse_proxy searxng:8080
  encode zstd gzip
}
EOF

# 10. Create docker-compose.yml using ONLY the recommended persistent mount points
info "Creating docker-compose.yml using official persistent settings..."
cat > docker-compose.yml <<EOF
version: "3.7"

services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: always
    env_file:
      - .env
    environment:
      - BASE_URL=http://${FQDN}:${HTTP_PORT}/
    ports:
      - "8888:8080"
    volumes:
      - ./searxng-settings:/etc/searxng
      - ./searxng-data:/var/cache/searxng
    platform: ${DOCKER_PLATFORM}

  caddy:
    image: caddy:2
    container_name: caddy
    restart: always
    ports:
      - "${HTTP_PORT}:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    platform: ${DOCKER_PLATFORM}

volumes:
  caddy_data:
  caddy_config:
EOF

# 11. Create systemd service file
info "Creating systemd service file for ${SERVICE_NAME}..."
sudo tee /etc/systemd/system/${SERVICE_NAME} > /dev/null <<EOF
[Unit]
Description=SearXNG Docker Compose Stack
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
User=${USERNAME}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
EOF

# 12. Reload systemd, enable service
info "Reloading systemd daemon and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}

# 13. Start the stack
info "Starting the stack via systemd..."
sudo systemctl start ${SERVICE_NAME}

# 14. Post-deploy health check
info "Performing post-install health check..."
sleep 5
if curl -fs "http://${FQDN}:8888" >/dev/null; then
  info "SearXNG appears up at http://${FQDN}:8888"
elif curl -fs "http://${FQDN}:${HTTP_PORT}" >/dev/null; then
  info "SearXNG is reverse-proxied and up at http://${FQDN}:${HTTP_PORT}"
else
  error_exit "WARNING: SearXNG does not appear to be running or responding on http://${FQDN}:8888 or http://${FQDN}:${HTTP_PORT}"
fi

info "Installation complete. SearXNG is now running and healthy."
info "Access the stack at: http://${FQDN}:8888 (or http://${FQDN} via Caddy reverse proxy)"
