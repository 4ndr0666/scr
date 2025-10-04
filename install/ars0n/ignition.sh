#!/bin/bash

# ==============================================================================
# Ars0n Sentinel - Master Installation Script v4.0 (Final Kali ARM Doctrine)
# This script automates the full installation, hardening, and deployment of
# the ars0n-framework on a prepared Kali Linux ARM system.
# Run this from the home directory of your non-root user.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

echo "[INFO] Starting Ars0n Sentinel Full Deployment Protocol..."

# --- Step 1: System Preparation & Hardening ---
echo "[TASK 1/6] Updating system and installing core payload..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2 postgresql-client redis-tools git
echo "[SUCCESS] Core payload installed."

echo "[TASK 2/6] Configuring user permissions for Docker..."
sudo usermod -aG docker ${USER}
echo "[SUCCESS] User added to Docker group. A reboot will be required after this script completes."

echo "[TASK 3/6] Hardening UFW for Docker compatibility..."
sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 8443/tcp
sudo ufw allow 5432/tcp
sudo ufw allow from 172.17.0.0/16 to any port 5432
sudo ufw default allow outgoing
sudo ufw --force enable
echo "[SUCCESS] UFW configured and enabled."

# --- Step 2: Payload Deployment ---
echo "[TASK 4/6] Acquiring and preparing ars0n-framework stable release..."
mkdir -p ~/ars0n-deployment && cd ~/ars0n-deployment
wget -q --show-progress $(curl -s https://api.github.com/repos/R-s0n/ars0n-framework-v2/releases/latest | grep "browser_download_url.*zip" | cut -d '"' -f 4)
unzip -q *.zip
rm *.zip
cd ars0n-framework-v2-*
echo "REDIS_HOST=$(hostname -I | awk '{print $1}')" > .env
sed -i 's/"3000:3000"/"80:3000"/' docker-compose.yml
FRAMEWORK_DIR=$(pwd)
echo "[SUCCESS] Framework prepared in: $FRAMEWORK_DIR"

# --- Step 3: Autostart Service Configuration ---
echo "[TASK 5/6] Forging and enabling systemd autostart service..."
SERVICE_FILE_CONTENT="[Unit]
Description=Ars0n Framework Sentinel Service
Requires=docker.service
After=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=${USER}
Group=${USER}
WorkingDirectory=${FRAMEWORK_DIR}
ExecStart=/usr/bin/docker compose up -d --build
ExecStop=/usr/bin/docker compose down
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
"
echo "$SERVICE_FILE_CONTENT" | sudo tee /etc/systemd/system/ars0n.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now ars0n.service
echo "[SUCCESS] ars0n.service created and enabled."

# --- Step 4: Final Ignition ---
echo "[TASK 6/6] Final verification..."
sleep 20 # Give services time to initialize
if ! systemctl is-active --quiet ars0n.service; then
    echo "[ERROR] ars0n.service failed to start. Check 'journalctl -xeu ars0n.service'." >&2
    exit 1
fi
echo "[SUCCESS] ars0n.service is active."
docker compose ps

echo -e "\n\n[PROTOCOL COMPLETE]"
echo "The Ars0n Sentinel is LIVE and operational."
echo "Access the web interface at: http://$(hostname -I | awk '{print $1}')"
echo "A reboot is required to finalize user group permissions for interactive Docker commands."
echo "Reboot now? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo reboot
fi

exit 0
