#!/bin/bash

# ==============================================================================
# Ars0n Sentinel - Master Installation Script v1.1
# This script automates the installation and configuration of all required
# software and the ars0n-framework itself.
# Run this as root on a freshly provisioned DietPi system.
# ==============================================================================

# --- Safety Check: Ensure the script is run as root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo ./install.sh' or log in as root." >&2
  exit 1
fi

set -e # Exit immediately if a command exits with a non-zero status.

echo "[INFO] Starting Ars0n Sentinel Payload Deployment..."

# --- Step 1: System Interrogation for Software IDs ---
echo "[TASK 1/8] Acquiring ground truth for software IDs..."
ID_DOCKER_COMPOSE=$(dietpi-software list | grep 'Docker Compose:' | awk '{print $2}')
ID_POSTGRES=$(dietpi-software list | grep 'PostgreSQL:' | awk '{print $2}')
ID_REDIS=$(dietpi-software list | grep 'Redis:' | awk '{print $2}')
ID_GIT=$(dietpi-software list | grep 'Git:' | awk -F'|' '{print $1}' | awk '{print $2}')
if [ -z "$ID_DOCKER_COMPOSE" ] || [ -z "$ID_POSTGRES" ] || [ -z "$ID_REDIS" ] || [ -z "$ID_GIT" ]; then
    echo "[ERROR] Could not dynamically determine all required software IDs. Aborting." >&2
    exit 1
fi
echo "[SUCCESS] Software IDs acquired."

# --- Step 2: Install Core Software Payload ---
echo "[TASK 2/8] Installing core software via dietpi-software..."
dietpi-software install $ID_DOCKER_COMPOSE $ID_POSTGRES $ID_REDIS $ID_GIT
echo "[SUCCESS] Core services installed."

# --- Step 3: Authoritative PostgreSQL Reconfiguration ---
echo "[TASK 3/8] Performing authoritative reconfiguration of PostgreSQL..."
sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = '*';"
echo "host    all             all             127.0.0.1/32            md5" >> /etc/postgresql/17/main/pg_hba.conf
systemctl restart postgresql
sleep 5
if ! pg_isready -h 127.0.0.1 -p 5432 | grep -q "accepting connections"; then
    echo "[ERROR] PostgreSQL failed to become network-ready. Aborting." >&2
    exit 1
fi
echo "[SUCCESS] PostgreSQL is configured and accepting connections."

# --- Step 4: Deploy ars0n-framework ---
echo "[TASK 4/8] Deploying ars0n-framework..."
rm -rf /opt/ars0n-framework
wget -P /opt/ "https://github.com/R-s0n/ars0n-framework-v2/releases/download/beta-0.0.1/ars0n-framework-v2-beta-0.0.1.zip"
unzip /opt/ars0n-framework-v2-beta-0.0.1.zip -d /opt/
mv /opt/ars0n-framework-v2 /opt/ars0n-framework
rm /opt/ars0n-framework-v2-beta-0.0.1.zip
cd /opt/ars0n-framework
echo "[SUCCESS] Framework acquired and extracted."

# --- Step 5: Configure Framework Environment ---
echo "[TASK 5/8] Configuring framework environment for Port 80 and host communication..."
echo "REDIS_HOST=172.17.0.1" > .env
sed -i 's/ports:/ports:\n      - "80:3000"/' docker-compose.yml
echo "[SUCCESS] Environment configured."

# --- Step 6: Create Autostart Service ---
echo "[TASK 6/8] Forging systemd autostart service..."
cat << 'EOF' > /etc/systemd/system/ars0n.service
[Unit]
Description=Ars0n Framework Sentinel Service
Requires=docker.service
After=network-online.target docker.service

[Service]
User=root
WorkingDirectory=/opt/ars0n-framework
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
echo "[SUCCESS] Service file created."

# --- Step 7: Enable Autostart Service ---
echo "[TASK 7/8] Enabling and reloading systemd services..."
systemctl enable ars0n.service
systemctl daemon-reload
echo "[SUCCESS] ars0n.service enabled."

# --- Step 8: Final Ignition ---
echo "[TASK 8/8] IGNITION! Building and launching ars0n-framework stack..."
echo "[INFO] This will take a long time as container images are downloaded and built."
make up

# --- Final Verification ---
sleep 15
echo "[INFO] Final verification..."
docker compose ps
echo ""
echo "[SUCCESS] Ars0n Sentinel Deployment Complete."
echo "Access the web interface at http://$(hostname -I | awk '{print $1}')"
echo "Reboot now ('sudo reboot') to confirm autostart functionality."
exit 0
