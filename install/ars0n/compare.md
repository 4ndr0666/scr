# Ars0n Sentinel Node - Genesis Protocol (v4.0 - Final Kali ARM Doctrine)

## 1. Project Objective

To forge a headless, autonomous, and low-power ARM-based appliance for persistent reconnaissance operations. This device, the "Ars0n Sentinel," is engineered for maximum stability and performance on a Raspberry Pi 4. Its function is to serve as a 24/7 foundation for the `ars0n-framework` Docker stack.

This protocol is a battle-tested, two-stage process. **Stage A** details the manual creation of the hardened Kali Linux foundation. **Stage B** details the manual deployment and configuration of the `ars0n-framework` payload. An automated script that performs all of Stage B is provided in this repository.

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

1.  **Update System:** Ensure all packages are current.
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
2.  **Install Core Payload:** Install Docker, the modern Docker Compose v2 plugin, PostgreSQL client utilities, Redis tools, and Git.
    ```bash
    sudo apt install -y docker.io docker-compose-v2 postgresql-client redis-tools git
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
6.  **Reboot:** A reboot is recommended to ensure all changes, including user group modifications and firewall rules, are correctly applied.
    ```bash
    sudo reboot
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
    cd ars0n-framework-v2-*
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

## 5. Phase 2: Autostart Service Configuration

### Step 2.1: Create the Autostart Service

Forge a `systemd` service file to manage the framework automatically.

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

### Step 2.2: Enable the Service

Reload `systemd` and enable the new service to start on every boot.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ars0n.service
```

## 6. Phase 3: API Key Configuration

For the framework's tools to function, you must provide API keys.
1.  Access the web interface at `http://<YOUR_PI_IP_ADDRESS>`.
2.  Navigate to the "Resources" tab, then "Configure API Keys."
3.  Input your keys for services like Shodan, SecurityTrails, etc.

## 7. Verification

After a final reboot (`sudo reboot`), all systems should be operational.
- `systemctl status ars0n.service` should show `active (exited)`.
- `docker ps` should show all `ars0n` containers running.
- The web UI should be accessible and fully functional for starting scans.

## Conclusion

The Genesis Protocol is complete. The Sentinel is operational.
