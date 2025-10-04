# Ars0n Framework - Raspberry Pi Flavor

## 1. Project Objective

To forge a headless, autonomous, and low-power ARM-based appliance for persistent reconnaissance operations. This guide is engineered for maximum stability and performance on a Raspberry Pi 4. Its function is to serve as a 24/7 foundation for the `ars0n-framework` Docker stack.

This protocol is a battle-tested, two-stage process. **Stage A** details the manual creation of the hardened Kali Linux foundation. **Stage B** details the manual deployment and configuration of the `ars0n-framework` payload. An automated script that performs all of Stage B is provided in the end of this document.

## 2. Phase 0: Ordnance Acquisition

*   **Compute Unit:** Raspberry Pi 4 Model B (8GB RAM variant is mandatory).
*   **Storage Medium:** 64GB+ High-Endurance or Industrial-Grade MicroSD Card.
*   **Power Unit:** Official Raspberry Pi USB-C Power Supply.
*   **OS Image:** The official **Kali Linux Raspberry Pi** image from [Kali's website](https://www.kali.org/get-kali/#kali-arm).

## 3. Phase 1, Stage A: Foundation Forging (Kali Linux)

### Step 1.1: OS Installation

1.  Flash the Kali Linux ARM image to your MicroSD card using Raspberry Pi Imager.
2.  Boot the Raspberry Pi and complete the initial setup (user creation, network connection, etc.). It is recommended to configure a static IP address.
3.  Once booted, open a terminal for the following steps.

### Step 1.2: System Preparation & Hardening

1.  **Update and Upgrade:**
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
2.  **Install Core Payload:**
    ```bash
    sudo apt install -y docker.io docker-compose postgresql-client redis-tools git
    ```
3.  **Enable Docker Service:** Ensure the Docker daemon starts on every boot.
    ```bash
    sudo systemctl enable --now docker
    ```
4.  **Configure User Permissions:** Add your current user to the `docker` group. **This is critical.** You must log out and log back in for this to take effect.
    ```bash
    sudo usermod -aG docker ${USER}
    newgrp docker
    ```
5.  **Harden System Firewall (UFW):** The default firewall policy blocks Docker's network traffic. These steps are mandatory for the framework to function.

    *   **Edit the UFW configuration** to allow forwarded packets. This is the root cause of most Docker networking issues.
        ```bash
        sudo nano /etc/default/ufw
        ```
        Find the line `DEFAULT_FORWARD_POLICY="DROP"` and change it to `DEFAULT_FORWARD_POLICY="ACCEPT"`. Save the file (CTRL+X, Y, Enter).

    *   **Apply Firewall Rules:** Allow access for essential services.
        ```bash
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 3000/tcp
        sudo ufw allow 8443/tcp
        sudo ufw allow 5432/tcp
        sudo ufw allow from 172.17.0.0/16 to any port 5432
        sudo ufw default allow outgoing
        sudo ufw --force enable
        ```
6. **PostgreSQL Authoritative Reconfiguration**

The default PostgreSQL installation is hardened against network connections and must be given a direct, authoritative order to comply.

1. **Issue the `listen_addresses` Override:** Use `ALTER SYSTEM` to write a high-priority configuration that forces the database to listen on all network interfaces.
    ```bash
    sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = '*';"
    ```
2. **Configure Host-Based Authentication:** Command the system to trust local network connections for all users.
    ```bash
    echo "host    all             all             127.0.0.1/32            md5" | sudo tee -a /etc/postgresql/17/main/pg_hba.conf
    ```
3. **Restart the Service:** Ingest the new configuration.
    ```bash
    sudo systemctl restart postgresql
    ```

## 4. Phase 1, Stage B: Payload Deployment

After rebooting and logging back in, proceed with the framework installation.

### Step 1.3: Acquire & Prepare the Framework

1.  **Download the Stable Release:** Create a directory for the deployment and download the official release package. **Do not `git clone` the main branch.**
    ```bash
    mkdir ~/ars0n-deployment && cd ~/ars0n-deployment
    wget $(curl -s https://api.github.com/repos/R-s0n/ars0n-framework-v2/releases/latest | grep "browser_download_url.*zip" | cut -d '"' -f 4)
    ```
2.  **Extract and Position:** Unzip the archive and navigate into the correct operational directory.
    ```bash
    unzip *.zip
    cd ars0n-framework-v2-beta-0.0.1*
    ```
3.  **Configure the Environment:** Create a `.env` file that dynamically tells the framework containers the correct LAN IP address of your Raspberry Pi.
    ```bash
    echo "REDIS_HOST=$(hostname -I | awk '{print $1}')" > .env
    ```
4.  **Reconfigure for Primary Port:** Modify the deployment manifest to make the UI accessible on the standard Port 80.
    ```bash
    sed -i 's/"3000:3000"/"80:3000"/' docker-compose.yml
    ```

### Step 1.4: The Ignition

Launch the stack. This will build all container images and start the framework in the background.

```bash
docker compose up -d --build
```
This process will take a significant amount of time.

## 5. Phase 2: Autostart

### Step 2.1: Systemd Automation

You can leverage `systemd` and create a service file to manage the framework automatically on each boot. To forge the new `systemd` service:

```bash
sudo bash -c 'cat << EOF > /etc/systemd/system/ars0n.service
[Unit]
Description=Ars0n Framework Sentinel Service
Requires=docker.service
After=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=kali
Group=kali
WorkingDirectory=/home/kali/ars0n-deployment/ars0n-framework-v2-beta-0.0.1
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF'
```
> **CRITICAL:** The `User`, `Group`, and `WorkingDirectory` paths must be **exact**. Adjust them if your username or installation path is different.

### Step 2.2: Service Configuration

Reload `systemd` and enable the framework as new system service.
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ars0n.service
```

As a system service, you can operate the framework like this:
  - **Start:** `sudo systemctl start ars0n.service`
  - **Stop:** `sudo systemctl stop ars0n.service`
  - **Status:** `sudo systemctl status ars0n.service`
  - **Logs:** `sudo journalctl -fu ars0n.service`

## 6. Phase 3: API Key Configuration

The `ars0n-framework` leverages numerous third-party services. You must configure API keys for these tools to function.

1.  **Access the Web Interface:** Navigate to `http://<YOUR_PI_IP_ADDRESS>:3000`.
2.  **Navigate to Configuration:** Click the "Resources" tab, then "Configure API Keys".
3.  **Enter Keys:** Input your API keys for services like Shodan, SecurityTrails, Censys, etc.

## 7. Final System Verification

1.  **Verify Core Services:**
    `docker --version && docker compose version && sudo systemctl status redis-server`
2.  **Verify PostgreSQL Network Readiness:**
    `pg_isready -h 127.0.0.1 -p 5432`
3.  **Verify Autostart Service:**
    `systemctl status ars0n.service` (Should be `active (exited)` in green)
4.  **Verify Container Status:**
    `docker ps` (Should show ars0n containers running)
5.  **Confirm Web Interface Access:** Open a web browser and navigate to `http://<YOUR_PI_IP_ADDRESS>`.

## Conclusion

The genesis protocol is complete. The Sentinel is now fully operational and awaiting a target for engagement.

---

# Ignition Script

`ignition.sh` automates all of the afforementioned steps on a **Raspberry Pi 4 running a fresh Kali Linux 64bit image**. It is **NOT** meant for any other setup.

```bash
#!/bin/bash
# Author: 4ndr0666
set -e
# =================== // IGNITION.SH //
# Description: Automates the full installation and deployment of
# the ars0n-framework on a prepared Kali Linux ARM system.
# Run this from the home directory of your non-root user.
# ==============================================================================
echo "[INFO] Starting Ars0n Sentinel Full Deployment Protocol..."

# --- Step 1: System Preparation & Hardening ---
echo "[TASK 1/6] Updating system and installing core payload..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose postgresql-client redis-tools git
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
sudo ufw allow from 172.17.0.0/16
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
```
