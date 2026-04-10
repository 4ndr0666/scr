#!/bin/bash

# ==============================================================================
# Ars0n Sentinel - Master Installation Script v4.0 (Final Kali ARM Doctrine)
# This script automates the complete deployment and hardening of the
# ars0n-framework payload on a prepared Kali Linux Raspberry Pi system.
# Run this from your home directory as the 'kali' user.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Define Global Variables ---
DEPLOY_DIR="/home/kali/ars0n-deployment"
FRAMEWORK_DIR_PATTERN="ars0n-framework-v2-*"
LAN_IP=$(hostname -I | awk '{print $1}')

# --- Safety Check: Ensure script is not run as root initially ---
if [ "$(id -u)" -eq 0 ]; then
  echo "This script should be run as the 'kali' user, not as root. It will use 'sudo' where necessary." >&2
  exit 1
fi

echo "[INFO] Starting Ars0n Sentinel Payload Deployment..."
echo "[INFO] This process will take a significant amount of time."

# --- Step 1: Acquire the Stable Release ---
echo "[TASK 1/6] Acquiring ars0n-framework stable release..."
rm -rf $DEPLOY_DIR
mkdir -p $DEPLOY_DIR && cd $DEPLOY_DIR
wget $(curl -s https://api.github.com/repos/R-s0n/ars0n-framework-v2/releases/latest | grep "browser_download_url.*zip" | cut -d '"' -f 4)
unzip *.zip
rm *.zip
cd $FRAMEWORK_DIR_PATTERN
FRAMEWORK_DIR=$(pwd)
echo "[SUCCESS] Framework acquired at: $FRAMEWORK_DIR"

# --- Step 2: Configure Environment & Compose File for Fetching ---
echo "[TASK 2/6] Configuring environment for network communication..."
# Create the .env file
echo "REDIS_HOST=$LAN_IP" > .env
echo "[SUCCESS] .env file created with REDIS_HOST=$LAN_IP"

# Modify docker-compose.yml to pass the LAN IP as a build argument
sed -i "/build:/a \    args:\n      - REACT_APP_SERVER_IP=$LAN_IP" docker-compose.yml
# Modify port mapping back to 3000:3000 for stability
sed -i 's/"80:3000"/"3000:3000"/' docker-compose.yml
echo "[SUCCESS] docker-compose.yml modified for client build and port mapping."

# --- Step 3: Harden UFW Firewall ---
echo "[TASK 3/6] Configuring UFW Firewall..."
sudo ufw allow ssh
sudo ufw allow 3000/tcp  # ars0n frontend
sudo ufw allow 8443/tcp  # ars0n API
sudo ufw allow 5432/tcp  # PostgreSQL
sudo ufw allow from 172.17.0.0/16 to any # Allow Docker network
sudo ufw default allow outgoing
sudo ufw --force enable
echo "[SUCCESS] UFW configured and enabled."

# --- Step 4: Launch the Framework Stack ---
echo "[TASK 4/6] IGNITION! Building and launching ars0n-framework stack..."
echo "[INFO] This will take a long time as container images are downloaded and built."
docker compose up -d --build
echo "[SUCCESS] Framework stack is building/running in the background."

# --- Step 5: Forge and Enable Autostart Service ---
echo "[TASK 5/6] Forging and enabling systemd autostart service..."
sudo bash -c "cat << EOF > /etc/systemd/system/ars0n.service
[Unit]
Description=Ars0n Framework Sentinel Service
Requires=docker.service
After=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=kali
Group=kali
WorkingDirectory=$FRAMEWORK_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF"
sudo systemctl daemon-reload
sudo systemctl enable --now ars0n.service
echo "[SUCCESS] ars0n.service created and enabled."

# --- Step 6: Final Verification & Instructions ---
echo "[TASK 6/6] Final verification..."
sleep 20 # Give services time to stabilize
if sudo systemctl is-active --quiet ars0n.service && docker ps | grep -q "ars0n-framework"; then
    echo ""
    echo "================================================================"
    echo "  Ars0n Sentinel Deployment Complete and Service is ACTIVE."
    echo "================================================================"
    echo "  Access the web interface at: http://$LAN_IP:3000"
    echo "  The service is enabled and will start on every boot."
    echo "  To manage the service, use 'sudo systemctl [start|stop|status] ars0n.service'."
    echo "  Reboot now ('sudo reboot') to confirm full autonomous functionality."
    echo "================================================================"
else
    echo ""
    echo "[ERROR] Post-flight check failed. The ars0n.service may not be running correctly." >&2
    echo "Please check the status with 'systemctl status ars0n.service' and logs with 'journalctl -u ars0n.service'."
    exit 1
fi

exit 0
